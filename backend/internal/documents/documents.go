// SPDX-License-Identifier: BSD-3-Clause

package documents

import (
	"context"
	"errors"
	"regexp"
	"time"
)

var ErrNotFound = errors.New("resource not found")

var idPattern = regexp.MustCompile(`^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$`)

func ValidID(id string) bool { return idPattern.MatchString(id) }

type Document struct {
	ID        string    `json:"id"`
	Title     string    `json:"title"`
	CreatedAt time.Time `json:"created_at"`
}

type Version struct {
	ID                string    `json:"id"`
	DocumentID        string    `json:"document_id"`
	Number            int64     `json:"number"`
	MediaType         string    `json:"media_type"`
	SizeBytes         int64     `json:"size_bytes"`
	ChecksumAlgorithm string    `json:"checksum_algorithm"`
	Checksum          string    `json:"checksum"`
	CreatedAt         time.Time `json:"created_at"`
}

type Assignment struct {
	ID         string    `json:"id"`
	DocumentID string    `json:"document_id"`
	VersionID  string    `json:"version_id"`
	Status     string    `json:"status"`
	Revision   int64     `json:"revision"`
	CreatedAt  time.Time `json:"created_at"`
}

type Page struct {
	Items     []Assignment `json:"items"`
	NextAfter string       `json:"next_after,omitempty"`
}

// Reader scopes every query to the authenticated user, never a client-supplied owner.
// Only pending assignments grant access; a document grant does not expose other versions.
type Reader interface {
	Assignments(context.Context, string, string, int) (Page, error)
	Assignment(context.Context, string, string) (Assignment, error)
	Document(context.Context, string, string) (Document, error)
	Version(context.Context, string, string, string) (Version, error)
}
