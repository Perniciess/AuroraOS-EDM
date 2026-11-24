// SPDX-License-Identifier: MIT

package httpapi

import (
	"context"
	"io"
	"net/http"
	"time"

	"github.com/Perniciess/AuroraOS-EDM/backend/internal/documents"
	"github.com/go-chi/chi/v5"
)

type ContentReader interface {
	Content(context.Context, string, string, string) (documents.Version, io.ReadSeekCloser, error)
}

func contentHandler(accounts Authenticator, files ContentReader) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx, cancel := context.WithTimeout(r.Context(), 25*time.Second)
		defer cancel()
		token, err := bearerToken(r)
		if err != nil {
			writeAuthError(w, r, err)
			return
		}
		user, err := accounts.CurrentUser(ctx, token)
		if err != nil {
			writeAuthError(w, r, err)
			return
		}
		id, versionID := chi.URLParam(r, "id"), chi.URLParam(r, "versionID")
		if !documents.ValidID(id) || !documents.ValidID(versionID) {
			writeDocumentError(w, r, documents.ErrNotFound)
			return
		}
		v, file, err := files.Content(ctx, user.ID, id, versionID)
		if err != nil {
			writeDocumentError(w, r, err)
			return
		}
		defer file.Close()
		w.Header().Set("Content-Type", "application/pdf")
		w.Header().Set("Content-Disposition", `attachment; filename="`+v.ID+`.pdf"`)
		w.Header().Set("Cache-Control", "no-store")
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("ETag", `"`+v.Checksum+`"`)
		// ServeContent handles byte ranges and If-Range without buffering the PDF.
		http.ServeContent(&contentResponse{ResponseWriter: w, request: r}, r.WithContext(ctx), v.ID+".pdf", time.Time{}, file)
	}
}

// Preserve the API error envelope for ServeContent's range/precondition errors.
// Errors after streaming starts are signalled by a truncated Content-Length body.
type contentResponse struct {
	http.ResponseWriter
	request *http.Request
	failed  bool
}

func (w *contentResponse) WriteHeader(status int) {
	if status < 400 {
		w.ResponseWriter.WriteHeader(status)
		return
	}
	w.failed = true
	w.Header().Del("Content-Length")
	w.Header().Del("Content-Disposition")
	code, message := "internal_error", "Internal server error"
	switch status {
	case http.StatusRequestedRangeNotSatisfiable:
		code, message = "invalid_range", "Requested byte range is invalid or unsatisfiable"
	case http.StatusPreconditionFailed:
		code, message = "precondition_failed", "Download precondition failed"
	}
	writeError(w.ResponseWriter, w.request, status, code, message)
}

func (w *contentResponse) Write(p []byte) (int, error) {
	if w.failed {
		return len(p), nil
	}
	return w.ResponseWriter.Write(p)
}
