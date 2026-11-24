// SPDX-License-Identifier: MIT

package httpapi

import (
	"context"
	"encoding/json"
	"log/slog"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
)

type ErrorResponse struct {
	Error APIError `json:"error"`
}

type APIError struct {
	Code      string `json:"code"`
	Message   string `json:"message"`
	RequestID string `json:"request_id"`
}

func NewRouter(logger *slog.Logger, checkDatabase func(context.Context) error, accounts Authenticator) http.Handler {
	r := chi.NewRouter()
	r.Use(middleware.RequestID)
	r.Use(observe(logger))
	r.Use(recoverPanic(logger))
	r.Post("/api/v1/auth/login", loginHandler(accounts))
	r.Post("/api/v1/auth/logout", sessionHandler(accounts, true))
	r.Get("/api/v1/me", sessionHandler(accounts, false))
	r.Get("/healthz", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, struct {
			Status string `json:"status"`
		}{Status: "ok"})
	})
	r.NotFound(func(w http.ResponseWriter, r *http.Request) {
		writeError(w, r, http.StatusNotFound, "not_found", "Resource not found")
	})
	r.Get("/readyz", func(w http.ResponseWriter, r *http.Request) {
		ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
		defer cancel()
		if err := checkDatabase(ctx); err != nil {
			writeError(w, r, http.StatusServiceUnavailable, "not_ready", "Service is not ready")
			return
		}
		writeJSON(w, http.StatusOK, struct {
			Status string `json:"status"`
		}{Status: "ok"})
	})
	r.MethodNotAllowed(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/api/v1/auth/login" || r.URL.Path == "/api/v1/auth/logout" {
			w.Header().Set("Allow", http.MethodPost)
		} else {
			w.Header().Set("Allow", http.MethodGet)
		}
		writeError(w, r, http.StatusMethodNotAllowed, "method_not_allowed", "Method not allowed")
	})
	return r
}

func writeJSON(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(value)
}

func writeError(w http.ResponseWriter, r *http.Request, status int, code, message string) {
	writeJSON(w, status, ErrorResponse{Error: APIError{
		Code: code, Message: message, RequestID: middleware.GetReqID(r.Context()),
	}})
}

func observe(logger *slog.Logger) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			start := time.Now()
			wrapped := middleware.NewWrapResponseWriter(w, r.ProtoMajor)
			wrapped.Header().Set("X-Request-ID", middleware.GetReqID(r.Context()))
			next.ServeHTTP(wrapped, r)
			// Log the route template, never query strings, credentials or document IDs.
			logger.InfoContext(r.Context(), "http request",
				"request_id", middleware.GetReqID(r.Context()),
				"method", r.Method, "route", chi.RouteContext(r.Context()).RoutePattern(),
				"status", wrapped.Status(), "duration_ms", time.Since(start).Milliseconds())
		})
	}
}

func recoverPanic(logger *slog.Logger) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			defer func() {
				if value := recover(); value != nil {
					if value == http.ErrAbortHandler {
						panic(value)
					}
					// Panic values can contain sensitive data; do not serialize them.
					logger.ErrorContext(r.Context(), "request panic", "request_id", middleware.GetReqID(r.Context()))
					if writer, ok := w.(middleware.WrapResponseWriter); ok && writer.Status() != 0 {
						panic(http.ErrAbortHandler)
					}
					writeError(w, r, http.StatusInternalServerError, "internal_error", "Internal server error")
				}
			}()
			next.ServeHTTP(w, r)
		})
	}
}
