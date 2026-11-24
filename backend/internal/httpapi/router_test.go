// SPDX-License-Identifier: MIT

package httpapi

import (
	"bytes"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
)

func TestRouterResponsesAndLogs(t *testing.T) {
	for _, tt := range []struct {
		method, path string
		status       int
		code         string
	}{
		{http.MethodGet, "/healthz", http.StatusOK, ""},
		{http.MethodGet, "/missing?token=secret-query", http.StatusNotFound, "not_found"},
		{http.MethodPost, "/healthz", http.StatusMethodNotAllowed, "method_not_allowed"},
	} {
		t.Run(tt.method+tt.path, func(t *testing.T) {
			var logs bytes.Buffer
			router := NewRouter(slog.New(slog.NewJSONHandler(&logs, nil)))
			recorder := httptest.NewRecorder()
			router.ServeHTTP(recorder, httptest.NewRequest(tt.method, tt.path, nil))
			if recorder.Code != tt.status {
				t.Fatalf("status = %d, want %d", recorder.Code, tt.status)
			}
			id := recorder.Header().Get("X-Request-ID")
			if id == "" || recorder.Header().Get("Content-Type") != "application/json" {
				t.Fatalf("missing response metadata: %v", recorder.Header())
			}
			if tt.status == http.StatusOK {
				var body map[string]string
				if err := json.Unmarshal(recorder.Body.Bytes(), &body); err != nil || body["status"] != "ok" {
					t.Fatalf("unexpected health response: %s", recorder.Body)
				}
			} else {
				var body ErrorResponse
				if err := json.Unmarshal(recorder.Body.Bytes(), &body); err != nil {
					t.Fatal(err)
				}
				if body.Error.Code != tt.code || body.Error.RequestID != id || body.Error.Message == "" {
					t.Fatalf("unexpected error: %+v", body)
				}
			}
			if tt.status == http.StatusMethodNotAllowed && recorder.Header().Get("Allow") != http.MethodGet {
				t.Fatal("405 must advertise supported methods")
			}
			var entry struct {
				RequestID string `json:"request_id"`
				Status    int    `json:"status"`
			}
			if err := json.Unmarshal(logs.Bytes(), &entry); err != nil {
				t.Fatal(err)
			}
			if entry.RequestID != id || entry.Status != tt.status || strings.Contains(logs.String(), "secret-query") {
				t.Fatalf("unexpected request log: %s", &logs)
			}
		})
	}
}

func TestPanicRecovery(t *testing.T) {
	var logs bytes.Buffer
	logger := slog.New(slog.NewJSONHandler(&logs, nil))
	router := chi.NewRouter()
	router.Use(middleware.RequestID, observe(logger), recoverPanic(logger))
	router.Get("/panic", func(http.ResponseWriter, *http.Request) { panic("secret-panic") })
	recorder := httptest.NewRecorder()
	router.ServeHTTP(recorder, httptest.NewRequest(http.MethodGet, "/panic", nil))
	var body ErrorResponse
	if err := json.Unmarshal(recorder.Body.Bytes(), &body); err != nil {
		t.Fatal(err)
	}
	if recorder.Code != http.StatusInternalServerError || body.Error.Code != "internal_error" || body.Error.RequestID == "" {
		t.Fatalf("unexpected recovery response: %d %s", recorder.Code, recorder.Body)
	}
	if strings.Contains(logs.String(), "secret-panic") || strings.Contains(recorder.Body.String(), "secret-panic") {
		t.Fatal("panic details leaked")
	}
}

func TestPanicAfterHeadersAbortsResponse(t *testing.T) {
	router := chi.NewRouter()
	logger := slog.New(slog.NewJSONHandler(io.Discard, nil))
	router.Use(middleware.RequestID, observe(logger), recoverPanic(logger))
	router.Get("/partial", func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
		panic("failed after sending headers")
	})
	defer func() {
		if value := recover(); value != http.ErrAbortHandler {
			t.Errorf("panic = %v, want http.ErrAbortHandler", value)
		}
	}()
	router.ServeHTTP(httptest.NewRecorder(), httptest.NewRequest(http.MethodGet, "/partial", nil))
}
