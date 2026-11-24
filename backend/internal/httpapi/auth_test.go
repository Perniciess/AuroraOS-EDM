// SPDX-License-Identifier: MIT

package httpapi

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/Perniciess/AuroraOS-EDM/backend/internal/auth"
	"github.com/Perniciess/AuroraOS-EDM/backend/internal/postgres"
)

func TestLoginInput(t *testing.T) {
	router := NewRouter(slog.New(slog.NewJSONHandler(io.Discard, nil)), nil, nil, nil)
	for _, tt := range []struct {
		body, contentType string
		status            int
	}{
		{`{}`, "text/plain", 415},
		{`{`, "application/json", 400},
		{`{"unknown":true}`, "application/json", 400},
		{`{} {}`, "application/json", 400},
		{`{"username":"` + strings.Repeat("x", 10000) + `"}`, "application/json", 413},
	} {
		req := httptest.NewRequest(http.MethodPost, "/api/v1/auth/login", strings.NewReader(tt.body))
		req.Header.Set("Content-Type", tt.contentType)
		w := httptest.NewRecorder()
		router.ServeHTTP(w, req)
		if w.Code != tt.status {
			t.Fatalf("status %d, want %d: %s", w.Code, tt.status, w.Body)
		}
	}
}

// Runs the public API against real migrations and PostgreSQL, not a session mock.
func TestAccountsIntegration(t *testing.T) {
	url := os.Getenv("TEST_DATABASE_URL")
	if url == "" {
		t.Skip("set TEST_DATABASE_URL to run PostgreSQL integration tests")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()
	db, err := postgres.Open(ctx, url)
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	if err := postgres.Migrate(ctx, db); err != nil {
		t.Fatal(err)
	}
	store := postgres.Accounts{DB: db}
	service := auth.New(store)
	username := "test-" + strings.ToLower(time.Now().Format("20060102150405.000000000"))
	password := "pilot-secret-password"
	user, err := service.CreateUser(ctx, username, password)
	if err != nil {
		t.Fatal(err)
	}
	defer func() {
		_, _ = db.ExecContext(context.Background(), "DELETE FROM edm.users WHERE id = $1", user.ID)
		_, _ = db.ExecContext(context.Background(), "DELETE FROM edm.login_attempts WHERE username IN ($1, $2)", username, username+"-missing")
	}()
	if _, err := service.CreateUser(ctx, strings.ToUpper(username), password); err != auth.ErrConflict {
		t.Fatalf("duplicate account: %v", err)
	}
	var logs bytes.Buffer
	logger := slog.New(slog.NewJSONHandler(&logs, nil))
	router := NewRouter(logger, db.PingContext, service, postgres.Documents{DB: db})
	call := func(method, path, body, token string, status int) *httptest.ResponseRecorder {
		t.Helper()
		req := httptest.NewRequest(method, path, strings.NewReader(body)).WithContext(ctx)
		if body != "" {
			req.Header.Set("Content-Type", "application/json")
		}
		if token != "" {
			req.Header.Set("Authorization", "Bearer "+token)
		}
		w := httptest.NewRecorder()
		router.ServeHTTP(w, req)
		if w.Code != status {
			t.Fatalf("%s %s: status %d, want %d: %s", method, path, w.Code, status, w.Body)
		}
		if w.Header().Get("Cache-Control") != "no-store" {
			t.Fatal("authentication response can be cached")
		}
		if status >= 400 {
			var response ErrorResponse
			if err := json.Unmarshal(w.Body.Bytes(), &response); err != nil || response.Error.RequestID == "" {
				t.Fatal("missing API error")
			}
		}
		return w
	}
	login := func(name, secret string, status int) *httptest.ResponseRecorder {
		t.Helper()
		body, _ := json.Marshal(map[string]string{"username": name, "password": secret})
		return call("POST", "/api/v1/auth/login", string(body), "", status)
	}
	call("GET", "/api/v1/me", "", "", 401)
	call("GET", "/api/v1/me", "", "malformed", 401)
	call("GET", "/api/v1/me", "", strings.Repeat("A", 43), 401)
	call("POST", "/api/v1/auth/logout", "", strings.Repeat("A", 43), 204)
	login(username, "wrong-password", 401)
	login(username+"-missing", password, 401)
	// Concurrent API instances must share one atomic attempt quota.
	if _, err := db.ExecContext(ctx, "DELETE FROM edm.login_attempts WHERE username = $1", username+"-missing"); err != nil {
		t.Fatal(err)
	}
	type attempt struct {
		allowed bool
		err     error
	}
	results := make(chan attempt, 20)
	for range 20 {
		go func() {
			allowed, err := (postgres.Accounts{DB: db}).AllowLogin(ctx, username+"-missing")
			results <- attempt{allowed, err}
		}()
	}
	allowedCount := 0
	for range 20 {
		result := <-results
		if result.err != nil {
			t.Fatal(result.err)
		}
		if result.allowed {
			allowedCount++
		}
	}
	if allowedCount != 10 {
		t.Fatalf("concurrent quota allowed %d attempts, want 10", allowedCount)
	}
	w := login(strings.ToUpper(username), password, 200)
	var session auth.Session
	if err := json.Unmarshal(w.Body.Bytes(), &session); err != nil {
		t.Fatal(err)
	}
	if session.User != user || session.TokenType != "Bearer" || time.Until(session.ExpiresAt) < 23*time.Hour {
		t.Fatal("invalid session response")
	}
	decoded, err := base64.RawURLEncoding.DecodeString(session.AccessToken)
	if err != nil || len(decoded) != 32 {
		t.Fatal("invalid access token")
	}
	digest := sha256.Sum256(decoded)
	var stored []byte
	if err := db.QueryRowContext(ctx, "SELECT token_hash FROM edm.sessions WHERE user_id = $1", user.ID).Scan(&stored); err != nil || !bytes.Equal(stored, digest[:]) {
		t.Fatal("session token was not hashed")
	}
	w = call("GET", "/api/v1/me", "", session.AccessToken, 200)
	var current auth.User
	if err := json.Unmarshal(w.Body.Bytes(), &current); err != nil || current != user {
		t.Fatal("wrong current user")
	}
	var independent auth.Session
	w = login(username, password, 200)
	if err := json.Unmarshal(w.Body.Bytes(), &independent); err != nil {
		t.Fatal(err)
	}
	if independent.AccessToken == session.AccessToken {
		t.Fatal("sessions share a token")
	}
	call("POST", "/api/v1/auth/logout", "", independent.AccessToken, 204)
	call("GET", "/api/v1/me", "", session.AccessToken, 200)
	// Sessions survive a new service/router instance (process restart).
	router = NewRouter(logger, db.PingContext, auth.New(store), postgres.Documents{DB: db})
	call("GET", "/api/v1/me", "", session.AccessToken, 200)
	if _, err := db.ExecContext(ctx, "UPDATE edm.users SET disabled = true WHERE id = $1", user.ID); err != nil {
		t.Fatal(err)
	}
	call("GET", "/api/v1/me", "", session.AccessToken, 401)
	login(username, password, 401)
	if _, err := db.ExecContext(ctx, "UPDATE edm.users SET disabled = false WHERE id = $1", user.ID); err != nil {
		t.Fatal(err)
	}
	if _, err := db.ExecContext(ctx, "UPDATE edm.sessions SET expires_at = now() - interval '1 second' WHERE user_id = $1", user.ID); err != nil {
		t.Fatal(err)
	}
	call("GET", "/api/v1/me", "", session.AccessToken, 401)
	call("POST", "/api/v1/auth/logout", "", session.AccessToken, 204)
	w = login(username, password, 200)
	if err := json.Unmarshal(w.Body.Bytes(), &session); err != nil {
		t.Fatal(err)
	}
	call("POST", "/api/v1/auth/logout", "", session.AccessToken, 204)
	call("POST", "/api/v1/auth/logout", "", session.AccessToken, 204)
	call("GET", "/api/v1/me", "", session.AccessToken, 401)
	// Exhaust the shared bucket without doing unnecessary password work.
	for range 10 {
		if _, err := store.AllowLogin(ctx, username); err != nil {
			t.Fatal(err)
		}
	}
	w = login(username, password, 429)
	if w.Header().Get("Retry-After") != "900" {
		t.Fatal("missing retry guidance")
	}
	if _, err := db.ExecContext(ctx, "UPDATE edm.login_attempts SET window_start = now() - interval '16 minutes' WHERE username = $1", username); err != nil {
		t.Fatal(err)
	}
	login(username, password, 200)
	if strings.Contains(logs.String(), password) || strings.Contains(logs.String(), session.AccessToken) || strings.Contains(logs.String(), username) {
		t.Fatal("credentials leaked to logs")
	}
	// A database failure must never be mistaken for an anonymous/valid session.
	closedDB, err := postgres.Open(ctx, url)
	if err != nil {
		t.Fatal(err)
	}
	if err := closedDB.Close(); err != nil {
		t.Fatal(err)
	}
	router = NewRouter(logger, db.PingContext, auth.New(postgres.Accounts{DB: closedDB}), postgres.Documents{DB: closedDB})
	call("GET", "/api/v1/me", "", session.AccessToken, 500)
	login(username, password, 500)
}
