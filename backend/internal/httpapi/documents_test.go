// SPDX-License-Identifier: MIT

package httpapi

import (
	"context"
	"encoding/json"
	"io"
	"log/slog"
	"net/http/httptest"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/Perniciess/AuroraOS-EDM/backend/internal/auth"
	"github.com/Perniciess/AuroraOS-EDM/backend/internal/documents"
	"github.com/Perniciess/AuroraOS-EDM/backend/internal/postgres"
)

func TestDocumentsIntegration(t *testing.T) {
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
	accounts := auth.New(postgres.Accounts{DB: db})
	var sessions []auth.Session
	for _, suffix := range []string{"a", "b"} {
		username := "docs-" + time.Now().Format("150405.000000000") + suffix
		user, err := accounts.CreateUser(ctx, username, "test-document-password")
		if err != nil {
			t.Fatal(err)
		}
		defer func() {
			_, _ = db.ExecContext(context.Background(), "DELETE FROM edm.users WHERE id = $1", user.ID)
			_, _ = db.ExecContext(context.Background(), "DELETE FROM edm.login_attempts WHERE username = $1", username)
		}()
		session, err := accounts.Login(ctx, username, "test-document-password")
		if err != nil {
			t.Fatal(err)
		}
		sessions = append(sessions, session)
	}
	// Roll back fixtures, including immutable versions, without bypassing their trigger.
	tx, err := db.BeginTx(ctx, nil)
	if err != nil {
		t.Fatal(err)
	}
	defer tx.Rollback()
	exec := func(query string, args ...any) {
		t.Helper()
		if _, err := tx.ExecContext(ctx, query, args...); err != nil {
			t.Fatal(err)
		}
	}
	const (
		doc      = "10000000-0000-4000-8000-000000000001"
		otherDoc = "10000000-0000-4000-8000-000000000002"
		v1       = "20000000-0000-4000-8000-000000000001"
		v2       = "20000000-0000-4000-8000-000000000002"
		v3       = "20000000-0000-4000-8000-000000000003"
		a1       = "30000000-0000-4000-8000-000000000001"
		a2       = "30000000-0000-4000-8000-000000000002"
		missing  = "40000000-0000-4000-8000-000000000001"
	)
	exec("INSERT INTO edm.documents (id, title) VALUES ($1, 'Договор'), ($2, 'Другой документ')", doc, otherDoc)
	for i, id := range []string{v1, v2, v3} {
		exec(`INSERT INTO edm.document_versions (id, document_id, number, media_type, size_bytes, checksum_algorithm, checksum)
			VALUES ($1, $2, $3, 'application/pdf', 123, 'sha256', $4)`, id, doc, i+1, strings.Repeat("a", 64))
	}
	for i, id := range []string{a1, a2} {
		exec("INSERT INTO edm.assignments (id, document_id, version_id, assignee_id) VALUES ($1, $2, $3, $4)", id, doc, []string{v1, v2}[i], sessions[0].User.ID)
	}
	logger := slog.New(slog.NewJSONHandler(io.Discard, nil))
	router := NewRouter(logger, db.PingContext, accounts, postgres.Documents{DB: tx})
	call := func(path, token string, status int) *httptest.ResponseRecorder {
		t.Helper()
		r := httptest.NewRequest("GET", path, nil).WithContext(ctx)
		if token != "" {
			r.Header.Set("Authorization", "Bearer "+token)
		}
		w := httptest.NewRecorder()
		router.ServeHTTP(w, r)
		if w.Code != status {
			t.Fatalf("%s: got %d want %d: %s", path, w.Code, status, w.Body)
		}
		if w.Header().Get("Cache-Control") != "no-store" || w.Header().Get("X-Request-ID") == "" {
			t.Fatal("missing response metadata")
		}
		if status >= 400 {
			var response ErrorResponse
			if err := json.Unmarshal(w.Body.Bytes(), &response); err != nil || response.Error.RequestID == "" {
				t.Fatal("invalid error response")
			}
			if status == 404 && (response.Error.Code != "not_found" || response.Error.Message != "Resource not found") {
				t.Fatal("object existence disclosed")
			}
		}
		return w
	}
	token := sessions[0].AccessToken
	paths := []string{"/api/v1/assignments/" + a1, "/api/v1/documents/" + doc, "/api/v1/documents/" + doc + "/versions/" + v1}
	for _, path := range append([]string{"/api/v1/assignments"}, paths...) {
		call(path, "", 401)
		call(path, "invalid", 401)
	}
	for _, path := range paths {
		call(path, token, 200)
		call(path, sessions[1].AccessToken, 404)
	}
	w := call("/api/v1/assignments?limit=1", token, 200)
	var page documents.Page
	if err := json.Unmarshal(w.Body.Bytes(), &page); err != nil || len(page.Items) != 1 || page.Items[0].ID != a1 || page.NextAfter != a1 {
		t.Fatalf("invalid first page: %s", w.Body)
	}
	w = call("/api/v1/assignments?limit=1&after="+page.NextAfter, token, 200)
	page = documents.Page{}
	if err := json.Unmarshal(w.Body.Bytes(), &page); err != nil || len(page.Items) != 1 || page.Items[0].ID != a2 || page.NextAfter != "" {
		t.Fatalf("invalid last page: %s", w.Body)
	}
	for _, path := range []string{"/api/v1/assignments?after=" + a2, "/api/v1/assignments"} {
		who := token
		if path == "/api/v1/assignments" {
			who = sessions[1].AccessToken
		}
		if w := call(path, who, 200); w.Body.String() != "{\"items\":[]}\n" {
			t.Fatalf("empty inbox: %s", w.Body)
		}
	}
	for _, query := range []string{"limit=0", "limit=101", "limit=x", "limit=1&limit=2", "after=invalid", "after=" + a1 + "&after=" + a2} {
		call("/api/v1/assignments?"+query, token, 400)
	}
	for _, path := range []string{
		"/api/v1/assignments/" + missing,
		"/api/v1/documents/" + missing,
		"/api/v1/documents/not-a-uuid",
		"/api/v1/documents/" + doc + "/versions/" + v3,
		"/api/v1/documents/" + otherDoc + "/versions/" + v1,
		"/api/v1/documents/" + doc + "/versions/invalid",
	} {
		call(path, token, 404)
	}
	w = call("/api/v1/documents/"+doc+"/versions/"+v1, token, 200)
	var version documents.Version
	if err := json.Unmarshal(w.Body.Bytes(), &version); err != nil || version.ID != v1 || version.DocumentID != doc || version.ChecksumAlgorithm != "sha256" || version.Checksum != strings.Repeat("a", 64) || version.SizeBytes != 123 {
		t.Fatalf("incorrect version: %s", w.Body)
	}
	// Cancellation immediately removes the exact grant, but another version's grant survives.
	exec("UPDATE edm.assignments SET status = 'cancelled', revision = revision + 1 WHERE id = $1", a1)
	call(paths[0], token, 404)
	call(paths[2], token, 404)
	call(paths[1], token, 200)
	exec("UPDATE edm.assignments SET status = 'cancelled', revision = revision + 1 WHERE id = $1", a2)
	call(paths[1], token, 404)
	if w := call("/api/v1/assignments", token, 200); w.Body.String() != "{\"items\":[]}\n" {
		t.Fatal("cancelled assignments leaked")
	}
	// Database constraints protect content and document/version association independently of HTTP.
	for _, query := range []string{
		"UPDATE edm.document_versions SET checksum = '" + strings.Repeat("b", 64) + "' WHERE id = '" + v1 + "'",
		"DELETE FROM edm.document_versions WHERE id = '" + v3 + "'",
		"INSERT INTO edm.assignments (id, document_id, version_id, assignee_id) VALUES ('" + missing + "', '" + otherDoc + "', '" + v1 + "', '" + sessions[0].User.ID + "')",
	} {
		exec("SAVEPOINT invalid_change")
		if _, err := tx.ExecContext(ctx, query); err == nil {
			t.Fatalf("invalid mutation accepted: %s", query)
		}
		exec("ROLLBACK TO SAVEPOINT invalid_change")
	}
	closedDB, err := postgres.Open(ctx, url)
	if err != nil {
		t.Fatal(err)
	}
	_ = closedDB.Close()
	router = NewRouter(logger, db.PingContext, accounts, postgres.Documents{DB: closedDB})
	call("/api/v1/assignments", token, 500)
	call(paths[1], token, 500)
	router = NewRouter(logger, db.PingContext, accounts, postgres.Documents{DB: tx})
	if err := accounts.Logout(ctx, token); err != nil {
		t.Fatal(err)
	}
	call("/api/v1/assignments", token, 401)
}
