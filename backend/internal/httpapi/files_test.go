// SPDX-License-Identifier: MIT

package httpapi

import (
	"bytes"
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net/http/httptest"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/Perniciess/AuroraOS-EDM/backend/internal/auth"
	"github.com/Perniciess/AuroraOS-EDM/backend/internal/documents"
	documentpg "github.com/Perniciess/AuroraOS-EDM/backend/internal/documents/postgres"
	"github.com/Perniciess/AuroraOS-EDM/backend/internal/postgres"
)

func TestFileImportDownloadIntegration(t *testing.T) {
	url := os.Getenv("TEST_DATABASE_URL")
	if url == "" {
		t.Skip("set TEST_DATABASE_URL to run PostgreSQL integration tests")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 90*time.Second)
	defer cancel()
	db, err := postgres.Open(ctx, url)
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	if err := postgres.Migrate(ctx, db); err != nil {
		t.Fatal(err)
	}
	id := func() string { return fmt.Sprintf("%x", rand.Text()) } // used only for unique usernames
	uuid := func() string {
		var b [16]byte
		if _, err := rand.Read(b[:]); err != nil {
			t.Fatal(err)
		}
		return fmt.Sprintf("%x-%x-%x-%x-%x", b[:4], b[4:6], b[6:8], b[8:10], b[10:])
	}
	accounts := auth.New(postgres.Accounts{DB: db})
	user, err := accounts.CreateUser(ctx, "file-"+id()[:20], "test-file-password")
	if err != nil {
		t.Fatal(err)
	}
	session, err := accounts.Login(ctx, user.Username, "test-file-password")
	if err != nil {
		t.Fatal(err)
	}
	other, err := accounts.CreateUser(ctx, "file-"+id()[:20], "test-file-password")
	if err != nil {
		t.Fatal(err)
	}
	otherSession, err := accounts.Login(ctx, other.Username, "test-file-password")
	if err != nil {
		t.Fatal(err)
	}
	files := documents.Files{Reader: postgres.Documents{DB: db}, Store: documentpg.Files{DB: db}}
	opts := documents.ImportOptions{ID: uuid(), Title: "Пилотный PDF", AssigneeID: user.ID}
	pdf := []byte("%PDF-1.7\n" + strings.Repeat("synthetic content\n", documents.ChunkSize/8) + "\n%%EOF\n")
	var result documents.Imported
	// Concurrent retries must produce one version and one assignment.
	results := make(chan error, 2)
	for range 2 {
		go func() { _, err := files.Import(ctx, opts, bytes.NewReader(pdf)); results <- err }()
	}
	for range 2 {
		if err := <-results; err != nil {
			t.Fatal(err)
		}
	}
	result, err = files.Import(ctx, opts, bytes.NewReader(pdf))
	if err != nil {
		t.Fatal(err)
	}
	digest := sha256.Sum256(pdf)
	if result.Version.Checksum != hex.EncodeToString(digest[:]) || result.Version.SizeBytes != int64(len(pdf)) || result.Version.Number != 1 {
		t.Fatalf("bad metadata: %+v", result)
	}
	var count int
	if err := db.QueryRowContext(ctx, `SELECT count(*) FROM edm.document_versions WHERE document_id=$1`, result.Version.DocumentID).Scan(&count); err != nil || count != 1 {
		t.Fatalf("duplicate version: %d %v", count, err)
	}
	for _, change := range []func(*documents.ImportOptions){
		func(o *documents.ImportOptions) { o.Title = "different" },
		func(o *documents.ImportOptions) { o.AssigneeID = other.ID },
	} {
		changed := opts
		change(&changed)
		if _, err := files.Import(ctx, changed, bytes.NewReader(pdf)); !errors.Is(err, documents.ErrImportConflict) {
			t.Fatalf("expected conflict: %v", err)
		}
	}
	if _, err := files.Import(ctx, opts, bytes.NewReader(append([]byte("%PDF-1.7\nchanged\n"), []byte("%%EOF")...))); !errors.Is(err, documents.ErrImportConflict) {
		t.Fatalf("content conflict: %v", err)
	}

	// Invalid, truncated, interrupted and oversized input leaves no committed staging rows.
	for name, source := range map[string]io.Reader{
		"not-pdf":    strings.NewReader("not a PDF"),
		"truncated":  strings.NewReader("%PDF-1.7\nno EOF"),
		"read-error": io.MultiReader(bytes.NewReader(pdf[:documents.ChunkSize]), errorReader{}),
		"oversize":   io.MultiReader(strings.NewReader("%PDF-1.7\n"), io.LimitReader(zeroReader{}, documents.MaxFileSize)),
	} {
		t.Run(name, func(t *testing.T) {
			bad := opts
			bad.ID = uuid()
			if _, err := files.Import(ctx, bad, source); err == nil {
				t.Fatal("expected failure")
			}
			if err := db.QueryRowContext(ctx, `SELECT count(*) FROM edm.file_uploads WHERE id=$1`, bad.ID).Scan(&count); err != nil || count != 0 {
				t.Fatalf("staging leak: %d %v", count, err)
			}
			if _, err := files.Import(ctx, bad, bytes.NewReader(pdf)); err != nil {
				t.Fatalf("retry failed: %v", err)
			}
		})
	}
	missing := opts
	missing.ID = uuid()
	missing.AssigneeID = uuid()
	if _, err := files.Import(ctx, missing, bytes.NewReader(pdf)); err == nil {
		t.Fatal("unknown assignee accepted")
	}
	second := opts
	second.ID = uuid()
	second.DocumentID = result.Version.DocumentID
	v2, err := files.Import(ctx, second, bytes.NewReader(pdf))
	if err != nil || v2.Version.Number != 2 {
		t.Fatalf("new version: %+v %v", v2, err)
	}
	// PostgreSQL also rejects content changes outside the service.
	if _, err := db.ExecContext(ctx, `UPDATE edm.file_chunks SET content='bad' WHERE upload_id=$1`, opts.ID); err == nil {
		t.Fatal("content mutation accepted")
	}
	if _, err := db.ExecContext(ctx, `INSERT INTO edm.file_chunks(upload_id,number,content) VALUES($1,99,'bad')`, opts.ID); err == nil {
		t.Fatal("finalized append accepted")
	}

	router := NewRouter(slog.New(slog.NewJSONHandler(io.Discard, nil)), db.PingContext, accounts, postgres.Documents{DB: db}, files)
	path := "/api/v1/documents/" + result.Version.DocumentID + "/versions/" + opts.ID + "/content"
	call := func(path, token, byteRange, ifRange string, status int) *httptest.ResponseRecorder {
		t.Helper()
		r := httptest.NewRequest("GET", path, nil).WithContext(ctx)
		if token != "" {
			r.Header.Set("Authorization", "Bearer "+token)
		}
		if byteRange != "" {
			r.Header.Set("Range", byteRange)
		}
		if ifRange != "" {
			r.Header.Set("If-Range", ifRange)
		}
		w := httptest.NewRecorder()
		router.ServeHTTP(w, r)
		if w.Code != status {
			t.Fatalf("%s: expected %d, got %d: %s", path, status, w.Code, w.Body.String())
		}
		return w
	}
	w := call(path, session.AccessToken, "", "", 200)
	if !bytes.Equal(w.Body.Bytes(), pdf) || w.Header().Get("Content-Type") != "application/pdf" || w.Header().Get("Cache-Control") != "no-store" {
		t.Fatal("download mismatch")
	}
	start, end := documents.ChunkSize-10, documents.ChunkSize+10
	w = call(path, session.AccessToken, fmt.Sprintf("bytes=%d-%d", start, end), w.Header().Get("ETag"), 206)
	if !bytes.Equal(w.Body.Bytes(), pdf[start:end+1]) {
		t.Fatal("cross-chunk range mismatch")
	}
	call(path, session.AccessToken, "bytes=0-10", `"wrong"`, 200)
	w = call(path, session.AccessToken, "bytes=999999999-", "", 416)
	var rangeError ErrorResponse
	if err := json.Unmarshal(w.Body.Bytes(), &rangeError); err != nil || rangeError.Error.Code != "invalid_range" || rangeError.Error.RequestID == "" {
		t.Fatalf("range error must use API envelope: %s (%v)", w.Body.String(), err)
	}
	for header, value := range map[string]string{"If-Match": `"wrong"`, "If-None-Match": `"` + result.Version.Checksum + `"`} {
		r := httptest.NewRequest("GET", path, nil).WithContext(ctx)
		r.Header.Set("Authorization", "Bearer "+session.AccessToken)
		r.Header.Set(header, value)
		response := httptest.NewRecorder()
		router.ServeHTTP(response, r)
		if header == "If-Match" {
			var apiError ErrorResponse
			if err := json.Unmarshal(response.Body.Bytes(), &apiError); err != nil || response.Code != 412 || apiError.Error.Code != "precondition_failed" {
				t.Fatalf("precondition response: %d %s", response.Code, response.Body.String())
			}
		} else if response.Code != 304 || response.Body.Len() != 0 {
			t.Fatalf("conditional response: %d %s", response.Code, response.Body.String())
		}
	}
	call(path, "", "", "", 401)
	call(path, otherSession.AccessToken, "", "", 404)
	assignmentID := uuid()
	assigned, err := files.Assign(ctx, assignmentID, opts.ID, other.ID)
	if err != nil || assigned.VersionID != opts.ID {
		t.Fatalf("assign version: %+v %v", assigned, err)
	}
	if again, err := files.Assign(ctx, assignmentID, opts.ID, other.ID); err != nil || again.ID != assigned.ID {
		t.Fatalf("repeat assignment: %+v %v", again, err)
	}
	if _, err := files.Assign(ctx, assignmentID, v2.Version.ID, other.ID); !errors.Is(err, documents.ErrImportConflict) {
		t.Fatalf("assignment ID reuse: %v", err)
	}
	if _, err := files.Assign(ctx, uuid(), opts.ID, other.ID); !errors.Is(err, documents.ErrImportConflict) {
		t.Fatalf("duplicate pending assignment: %v", err)
	}
	conflicting := opts
	conflicting.ID = assignmentID
	if _, err := files.Import(ctx, conflicting, bytes.NewReader(pdf)); !errors.Is(err, documents.ErrImportConflict) {
		t.Fatalf("operation ID used by assignment: %v", err)
	}
	call(path, otherSession.AccessToken, "", "", 200)
	call(strings.Replace(path, opts.ID+"/content", v2.Version.ID+"/content", 1), otherSession.AccessToken, "", "", 404)
	call(strings.Replace(path, result.Version.DocumentID, uuid(), 1), session.AccessToken, "", "", 404)
	call(strings.Replace(path, opts.ID+"/content", "bad/content", 1), session.AccessToken, "", "", 404)
	if _, err := db.ExecContext(ctx, `UPDATE edm.assignments SET status='cancelled',revision=revision+1 WHERE id=$1`, opts.ID); err != nil {
		t.Fatal(err)
	}
	call(path, session.AccessToken, "bytes=0-10", "", 404)
	if _, err := files.Import(ctx, opts, bytes.NewReader(pdf)); err != nil {
		t.Fatal(err)
	}
	call(path, session.AccessToken, "", "", 404) // retries must not resurrect cancelled grants
}

type errorReader struct{}

func (errorReader) Read([]byte) (int, error) { return 0, errors.New("simulated interrupted input") }

type zeroReader struct{}

func (zeroReader) Read(p []byte) (int, error) { clear(p); return len(p), nil }
