// SPDX-License-Identifier: MIT

package documents

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"io"
	"strings"
	"unicode/utf8"
)

const ChunkSize = 1 << 20
const MaxFileSize = 100 << 20

var ErrInvalidFile = errors.New("expected a PDF with header and EOF marker, at most 100 MiB")
var ErrInvalidImport = errors.New("invalid import parameters")
var ErrImportConflict = errors.New("operation ID already used with different input")

// ImportOptions is supplied only by the trusted provisioning CLI, never by a mobile client.
// ID is a caller-generated UUID retained across retries. Empty DocumentID creates a document.
type ImportOptions struct {
	ID, DocumentID, Title, AssigneeID string
}

type Imported struct {
	Options    ImportOptions `json:"-"`
	Version    Version       `json:"version"`
	Assignment Assignment    `json:"assignment"`
}

type Upload interface {
	Existing(context.Context) (*Imported, error)
	WriteChunk(context.Context, int, []byte) error
	Finalize(context.Context, ImportOptions, int64, string) (Imported, error)
}

type FileStore interface {
	// WithUpload serializes the operation ID and commits only a successful callback.
	// Any error or interrupted process rolls back temporary chunks and metadata together.
	WithUpload(context.Context, string, func(Upload) error) error
	OpenContent(context.Context, Version) (io.ReadSeekCloser, error)
	Assign(context.Context, string, string, string) (Assignment, error)
}

type Files struct {
	Reader Reader
	Store  FileStore
}

func (s Files) Assign(ctx context.Context, operationID, versionID, assigneeID string) (Assignment, error) {
	if !ValidID(operationID) || !ValidID(versionID) || !ValidID(assigneeID) {
		return Assignment{}, ErrInvalidImport
	}
	return s.Store.Assign(ctx, strings.ToLower(operationID), strings.ToLower(versionID), strings.ToLower(assigneeID))
}

func (s Files) Import(ctx context.Context, opts ImportOptions, source io.Reader) (Imported, error) {
	opts.Title = strings.TrimSpace(opts.Title)
	if !ValidID(opts.ID) || !ValidID(opts.AssigneeID) || (opts.DocumentID != "" && !ValidID(opts.DocumentID)) || !utf8.ValidString(opts.Title) || utf8.RuneCountInString(opts.Title) < 1 || utf8.RuneCountInString(opts.Title) > 500 || strings.ContainsRune(opts.Title, 0) {
		return Imported{}, ErrInvalidImport
	}
	opts.ID, opts.DocumentID, opts.AssigneeID = strings.ToLower(opts.ID), strings.ToLower(opts.DocumentID), strings.ToLower(opts.AssigneeID)
	var result Imported
	err := s.Store.WithUpload(ctx, opts.ID, func(upload Upload) error {
		existing, err := upload.Existing(ctx)
		if err != nil {
			return err
		}
		hash := sha256.New()
		var size int64
		var head, tail []byte
		buf := make([]byte, ChunkSize)
		input := io.LimitReader(source, MaxFileSize+1)
		for index := 0; ; index++ {
			if err := ctx.Err(); err != nil {
				return err
			}
			n, err := io.ReadFull(input, buf)
			if err != nil && err != io.EOF && err != io.ErrUnexpectedEOF {
				return err
			}
			if n == 0 {
				break
			}
			size += int64(n)
			if size > MaxFileSize {
				return ErrInvalidFile
			}
			if head == nil {
				head = bytes.Clone(buf[:min(n, 8)])
			}
			tail = append(tail, buf[:n]...)
			if len(tail) > 1024 {
				tail = bytes.Clone(tail[len(tail)-1024:])
			}
			_, _ = hash.Write(buf[:n])
			if existing == nil {
				if err := upload.WriteChunk(ctx, index, buf[:n]); err != nil {
					return err
				}
			}
			if err != nil {
				break
			}
		}
		validHeader := len(head) == 8 && bytes.HasPrefix(head, []byte("%PDF-")) &&
			((head[5] == '1' && head[6] == '.' && head[7] >= '0' && head[7] <= '7') || bytes.Equal(head[5:], []byte("2.0")))
		if !validHeader || !bytes.HasSuffix(bytes.TrimSpace(tail), []byte("%%EOF")) {
			return ErrInvalidFile
		}
		digest := hex.EncodeToString(hash.Sum(nil))
		if existing != nil {
			if existing.Options != opts || existing.Version.Checksum != digest || existing.Version.SizeBytes != size {
				return ErrImportConflict
			}
			result = *existing
			return nil
		}
		result, err = upload.Finalize(ctx, opts, size, digest)
		return err
	})
	return result, err
}

func (s Files) Content(ctx context.Context, userID, documentID, versionID string) (Version, io.ReadSeekCloser, error) {
	v, err := s.Reader.Version(ctx, userID, documentID, versionID)
	if err != nil {
		return Version{}, nil, err
	}
	file, err := s.Store.OpenContent(ctx, v)
	return v, file, err
}
