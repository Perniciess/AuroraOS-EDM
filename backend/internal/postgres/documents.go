// SPDX-License-Identifier: BSD-3-Clause

package postgres

import (
	"context"
	"database/sql"
	"errors"

	"github.com/Perniciess/AuroraOS-EDM/backend/internal/documents"
)

// Queryer is implemented by both sql.DB and sql.Tx.
type Queryer interface {
	QueryContext(context.Context, string, ...any) (*sql.Rows, error)
	QueryRowContext(context.Context, string, ...any) *sql.Row
}

type Documents struct{ DB Queryer }

var _ documents.Reader = Documents{}

func (s Documents) Assignments(ctx context.Context, userID, after string, limit int) (documents.Page, error) {
	page := documents.Page{Items: []documents.Assignment{}}
	if limit < 1 || limit > 100 {
		return page, errors.New("invalid page limit")
	}
	if after == "" {
		after = "00000000-0000-0000-0000-000000000000"
	}
	rows, err := s.DB.QueryContext(ctx, `SELECT id, document_id, version_id, status, revision, created_at
		FROM edm.assignments WHERE assignee_id = $1 AND status = 'pending' AND id > $2::uuid
		ORDER BY id LIMIT $3`, userID, after, limit+1)
	if err != nil {
		return page, err
	}
	defer rows.Close()
	for rows.Next() {
		var a documents.Assignment
		if err := rows.Scan(&a.ID, &a.DocumentID, &a.VersionID, &a.Status, &a.Revision, &a.CreatedAt); err != nil {
			return page, err
		}
		page.Items = append(page.Items, a)
	}
	if err := rows.Err(); err != nil {
		return page, err
	}
	if len(page.Items) > limit {
		page.Items = page.Items[:limit]
		page.NextAfter = page.Items[limit-1].ID
	}
	return page, nil
}

func (s Documents) Assignment(ctx context.Context, userID, id string) (documents.Assignment, error) {
	var a documents.Assignment
	err := s.DB.QueryRowContext(ctx, `SELECT id, document_id, version_id, status, revision, created_at
		FROM edm.assignments WHERE assignee_id = $1 AND id = $2 AND status = 'pending'`, userID, id).
		Scan(&a.ID, &a.DocumentID, &a.VersionID, &a.Status, &a.Revision, &a.CreatedAt)
	return a, documentError(err)
}

func (s Documents) Document(ctx context.Context, userID, id string) (documents.Document, error) {
	var d documents.Document
	err := s.DB.QueryRowContext(ctx, `SELECT d.id, d.title, d.created_at FROM edm.documents d
		WHERE d.id = $2 AND EXISTS (SELECT 1 FROM edm.assignments a
		WHERE a.document_id = d.id AND a.assignee_id = $1 AND a.status = 'pending')`, userID, id).
		Scan(&d.ID, &d.Title, &d.CreatedAt)
	return d, documentError(err)
}

func (s Documents) Version(ctx context.Context, userID, documentID, id string) (documents.Version, error) {
	var v documents.Version
	err := s.DB.QueryRowContext(ctx, `SELECT v.id, v.document_id, v.number, v.media_type, v.size_bytes,
		v.checksum_algorithm, v.checksum, v.created_at FROM edm.document_versions v
		WHERE v.document_id = $2 AND v.id = $3 AND EXISTS (SELECT 1 FROM edm.assignments a
		WHERE a.version_id = v.id AND a.document_id = v.document_id AND a.assignee_id = $1 AND a.status = 'pending')`, userID, documentID, id).
		Scan(&v.ID, &v.DocumentID, &v.Number, &v.MediaType, &v.SizeBytes, &v.ChecksumAlgorithm, &v.Checksum, &v.CreatedAt)
	return v, documentError(err)
}

func documentError(err error) error {
	if errors.Is(err, sql.ErrNoRows) {
		return documents.ErrNotFound
	}
	return err
}
