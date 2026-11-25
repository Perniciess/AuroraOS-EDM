// SPDX-License-Identifier: MIT

package httpapi

import (
	"context"
	"errors"
	"net/http"
	"strconv"
	"time"

	"github.com/Perniciess/AuroraOS-EDM/backend/internal/documents"
	"github.com/go-chi/chi/v5"
)

func documentHandler(accounts Authenticator, reader documents.Reader, resource string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
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
		if resource != "assignments" && (!documents.ValidID(id) || (resource == "version" && !documents.ValidID(versionID))) {
			writeDocumentError(w, r, documents.ErrNotFound)
			return
		}
		var result any
		switch resource {
		case "assignments":
			limit := 50
			query := r.URL.Query()
			if values, ok := query["limit"]; ok {
				if len(values) != 1 {
					limit = 0
				} else {
					limit, _ = strconv.Atoi(values[0])
				}
			}
			after := query.Get("after")
			if limit < 1 || limit > 100 || len(query["after"]) > 1 || (after != "" && !documents.ValidID(after)) {
				writeError(w, r, http.StatusBadRequest, "invalid_request", "Expected limit 1–100 and an optional UUID after")
				return
			}
			result, err = reader.Assignments(ctx, user.ID, after, limit)
		case "assignment":
			result, err = reader.Assignment(ctx, user.ID, id)
		case "document":
			result, err = reader.Document(ctx, user.ID, id)
		case "version":
			result, err = reader.Version(ctx, user.ID, id, versionID)
		}
		if err != nil {
			writeDocumentError(w, r, err)
			return
		}
		writeJSON(w, http.StatusOK, result)
	}
}

func writeDocumentError(w http.ResponseWriter, r *http.Request, err error) {
	if errors.Is(err, documents.ErrNotFound) {
		writeError(w, r, http.StatusNotFound, "not_found", "Resource not found")
		return
	}
	writeError(w, r, http.StatusInternalServerError, "internal_error", "Internal server error")
}
