// SPDX-License-Identifier: MIT

package postgres

import (
	"context"
	"database/sql"
	"errors"
	"io"

	"github.com/Perniciess/AuroraOS-EDM/backend/internal/documents"
	"github.com/jackc/pgx/v5/pgconn"
)

type Files struct{ DB *sql.DB }

func (s Files) Assign(ctx context.Context, operationID, versionID, assigneeID string) (documents.Assignment, error) {
	var a documents.Assignment
	tx, err := s.DB.BeginTx(ctx, nil)
	if err != nil {
		return a, err
	}
	defer tx.Rollback()
	if _, err := tx.ExecContext(ctx, `SELECT pg_advisory_xact_lock(hashtextextended($1,0))`, operationID); err != nil {
		return a, err
	}
	var previousAssignee string
	err = tx.QueryRowContext(ctx, `SELECT id,document_id,version_id,status,revision,created_at,assignee_id FROM edm.assignments WHERE id=$1`, operationID).
		Scan(&a.ID, &a.DocumentID, &a.VersionID, &a.Status, &a.Revision, &a.CreatedAt, &previousAssignee)
	if err == nil {
		if a.VersionID != versionID || previousAssignee != assigneeID {
			return a, documents.ErrImportConflict
		}
		return a, tx.Commit()
	}
	if !errors.Is(err, sql.ErrNoRows) {
		return a, err
	}
	var activeUser string
	if err := tx.QueryRowContext(ctx, `SELECT id FROM edm.users WHERE id=$1 AND NOT disabled FOR SHARE`, assigneeID).Scan(&activeUser); err != nil {
		return a, err
	}
	err = tx.QueryRowContext(ctx, `INSERT INTO edm.assignments(id,document_id,version_id,assignee_id)
		SELECT $1,v.document_id,v.id,$3 FROM edm.document_versions v JOIN edm.file_uploads f ON f.id=v.id AND f.finalized WHERE v.id=$2
		RETURNING id,document_id,version_id,status,revision,created_at`, operationID, versionID, assigneeID).
		Scan(&a.ID, &a.DocumentID, &a.VersionID, &a.Status, &a.Revision, &a.CreatedAt)
	if err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" {
			return a, documents.ErrImportConflict
		}
		return a, err
	}
	return a, tx.Commit()
}

type upload struct {
	tx *sql.Tx
	id string
}

func (s Files) WithUpload(ctx context.Context, id string, fn func(documents.Upload) error) error {
	tx, err := s.DB.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()
	if _, err = tx.ExecContext(ctx, `SELECT pg_advisory_xact_lock(hashtextextended($1, 0))`, id); err != nil {
		return err
	}
	u := upload{tx, id}
	if err = fn(u); err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" {
			return documents.ErrImportConflict
		}
		return err
	}
	return tx.Commit()
}

func (u upload) Existing(ctx context.Context) (*documents.Imported, error) {
	var r documents.Imported
	r.Options.ID = u.id
	err := u.tx.QueryRowContext(ctx, `SELECT COALESCE(f.document_id::text, ''), f.title, f.assignee_id,
		v.id, v.document_id, v.number, v.media_type, v.size_bytes, v.checksum_algorithm, v.checksum, v.created_at,
		a.id, a.document_id, a.version_id, a.status, a.revision, a.created_at
		FROM edm.file_uploads f JOIN edm.document_versions v ON v.id=f.id
		JOIN edm.assignments a ON a.id=f.id WHERE f.id=$1 AND f.finalized`, u.id).Scan(
		&r.Options.DocumentID, &r.Options.Title, &r.Options.AssigneeID,
		&r.Version.ID, &r.Version.DocumentID, &r.Version.Number, &r.Version.MediaType, &r.Version.SizeBytes,
		&r.Version.ChecksumAlgorithm, &r.Version.Checksum, &r.Version.CreatedAt,
		&r.Assignment.ID, &r.Assignment.DocumentID, &r.Assignment.VersionID, &r.Assignment.Status, &r.Assignment.Revision, &r.Assignment.CreatedAt)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil
	}
	return &r, err
}

func (u upload) WriteChunk(ctx context.Context, number int, content []byte) error {
	if number == 0 {
		if _, err := u.tx.ExecContext(ctx, `INSERT INTO edm.file_uploads (id) VALUES ($1)`, u.id); err != nil {
			return err
		}
	}
	_, err := u.tx.ExecContext(ctx, `INSERT INTO edm.file_chunks (upload_id, number, content) VALUES ($1,$2,$3)`, u.id, number, content)
	return err
}

func (u upload) Finalize(ctx context.Context, opts documents.ImportOptions, size int64, checksum string) (documents.Imported, error) {
	var r documents.Imported
	documentID := opts.DocumentID
	if documentID == "" {
		documentID = u.id
		if _, err := u.tx.ExecContext(ctx, `INSERT INTO edm.documents (id,title) VALUES ($1,$2)`, documentID, opts.Title); err != nil {
			return r, err
		}
	}
	var locked string
	if err := u.tx.QueryRowContext(ctx, `SELECT id FROM edm.documents WHERE id=$1 FOR UPDATE`, documentID).Scan(&locked); err != nil {
		return r, err
	}
	var assignee string
	if err := u.tx.QueryRowContext(ctx, `SELECT id FROM edm.users WHERE id=$1 AND NOT disabled FOR SHARE`, opts.AssigneeID).Scan(&assignee); err != nil {
		return r, err
	}
	_, err := u.tx.ExecContext(ctx, `INSERT INTO edm.document_versions (id,document_id,number,media_type,size_bytes,checksum_algorithm,checksum)
		SELECT $1,$2,COALESCE(MAX(number),0)+1,'application/pdf',$3,'sha256',$4 FROM edm.document_versions WHERE document_id=$2`, u.id, documentID, size, checksum)
	if err != nil {
		return r, err
	}
	if _, err = u.tx.ExecContext(ctx, `INSERT INTO edm.assignments (id,document_id,version_id,assignee_id) VALUES ($1,$2,$1,$3)`, u.id, documentID, opts.AssigneeID); err != nil {
		return r, err
	}
	if _, err = u.tx.ExecContext(ctx, `UPDATE edm.file_uploads SET document_id=NULLIF($2::text,'')::uuid,title=$3,assignee_id=$4,finalized=true WHERE id=$1`, u.id, opts.DocumentID, opts.Title, opts.AssigneeID); err != nil {
		return r, err
	}
	existing, err := u.Existing(ctx)
	if err != nil {
		return r, err
	}
	return *existing, nil
}

func (s Files) OpenContent(ctx context.Context, v documents.Version) (io.ReadSeekCloser, error) {
	var exists bool
	if err := s.DB.QueryRowContext(ctx, `SELECT EXISTS(SELECT 1 FROM edm.file_uploads WHERE id=$1 AND finalized)`, v.ID).Scan(&exists); err != nil {
		return nil, err
	}
	if !exists {
		return nil, errors.New("version content missing")
	}
	return &contentReader{ctx: ctx, db: s.DB, id: v.ID, size: v.SizeBytes, chunk: -1}, nil
}

type contentReader struct {
	ctx          context.Context
	db           *sql.DB
	id           string
	size, offset int64
	chunk        int64
	data         []byte
}

func (r *contentReader) Read(p []byte) (int, error) {
	if len(p) == 0 {
		return 0, nil
	}
	if r.offset >= r.size {
		return 0, io.EOF
	}
	number := r.offset / documents.ChunkSize
	if number != r.chunk {
		if err := r.db.QueryRowContext(r.ctx, `SELECT content FROM edm.file_chunks WHERE upload_id=$1 AND number=$2`, r.id, number).Scan(&r.data); err != nil {
			return 0, err
		}
		r.chunk = number
	}
	start := r.offset % documents.ChunkSize
	if start >= int64(len(r.data)) {
		return 0, io.ErrUnexpectedEOF
	}
	n := copy(p, r.data[start:])
	r.offset += int64(n)
	return n, nil
}

func (r *contentReader) Seek(offset int64, whence int) (int64, error) {
	switch whence {
	case io.SeekStart:
	case io.SeekCurrent:
		offset += r.offset
	case io.SeekEnd:
		offset += r.size
	default:
		return 0, errors.New("invalid seek")
	}
	if offset < 0 {
		return 0, errors.New("negative offset")
	}
	r.offset = offset
	return offset, nil
}

func (r *contentReader) Close() error { r.data = nil; return nil }
