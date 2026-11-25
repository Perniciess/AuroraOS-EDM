// SPDX-License-Identifier: BSD-3-Clause

package httpapi

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"mime"
	"net/http"
	"strings"
	"time"

	"github.com/Perniciess/AuroraOS-EDM/backend/internal/auth"
)

type Authenticator interface {
	Login(context.Context, string, string) (auth.Session, error)
	CurrentUser(context.Context, string) (auth.User, error)
	Logout(context.Context, string) error
}

func loginHandler(service Authenticator) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		mediaType, _, err := mime.ParseMediaType(r.Header.Get("Content-Type"))
		if err != nil || mediaType != "application/json" {
			writeError(w, r, http.StatusUnsupportedMediaType, "unsupported_media_type", "Expected application/json")
			return
		}
		r.Body = http.MaxBytesReader(w, r.Body, 8192)
		decoder := json.NewDecoder(r.Body)
		decoder.DisallowUnknownFields()
		var input struct {
			Username string `json:"username"`
			Password string `json:"password"`
		}
		err = decoder.Decode(&input)
		if err == nil {
			var extra any
			err = decoder.Decode(&extra)
			if err == io.EOF {
				err = nil
			} else if err == nil {
				err = errors.New("extra JSON value")
			}
		}
		if err != nil {
			var tooLarge *http.MaxBytesError
			if errors.As(err, &tooLarge) {
				writeError(w, r, http.StatusRequestEntityTooLarge, "body_too_large", "Request body exceeds 8192 bytes")
			} else {
				writeError(w, r, http.StatusBadRequest, "invalid_request", "Expected one JSON object with username and password")
			}
			return
		}
		ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
		defer cancel()
		session, err := service.Login(ctx, input.Username, input.Password)
		if err != nil {
			writeAuthError(w, r, err)
			return
		}
		writeJSON(w, http.StatusOK, session)
	}
}

func bearerToken(r *http.Request) (string, error) {
	values := r.Header.Values("Authorization")
	if len(values) != 1 {
		return "", auth.ErrUnauthorized
	}
	parts := strings.Fields(values[0])
	if len(parts) != 2 || !strings.EqualFold(parts[0], "Bearer") {
		return "", auth.ErrUnauthorized
	}
	return parts[1], nil
}

func sessionHandler(service Authenticator, logout bool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		token, err := bearerToken(r)
		if err != nil {
			writeAuthError(w, r, err)
			return
		}
		ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
		defer cancel()
		if logout {
			if err := service.Logout(ctx, token); err != nil {
				writeAuthError(w, r, err)
				return
			}
			w.Header().Set("Cache-Control", "no-store")
			w.WriteHeader(http.StatusNoContent)
			return
		}
		user, err := service.CurrentUser(ctx, token)
		if err != nil {
			writeAuthError(w, r, err)
			return
		}
		writeJSON(w, http.StatusOK, user)
	}
}

func writeAuthError(w http.ResponseWriter, r *http.Request, err error) {
	switch {
	case errors.Is(err, auth.ErrUnauthorized):
		w.Header().Set("WWW-Authenticate", "Bearer")
		writeError(w, r, http.StatusUnauthorized, "unauthorized", "Invalid credentials or session")
	case errors.Is(err, auth.ErrRateLimited):
		w.Header().Set("Retry-After", "900")
		writeError(w, r, http.StatusTooManyRequests, "rate_limited", "Too many login attempts; retry later")
	default:
		writeError(w, r, http.StatusInternalServerError, "internal_error", "Internal server error")
	}
}
