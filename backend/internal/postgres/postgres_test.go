// SPDX-License-Identifier: BSD-3-Clause

package postgres

import (
	"context"
	"os"
	"strings"
	"testing"
	"time"
)

func TestOpenFailure(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	db, err := Open(ctx, "postgres://user:secret@localhost/edm")
	if db != nil || err == nil || strings.Contains(err.Error(), "secret") {
		t.Fatalf("expected sanitized connection failure, got %v, %v", db, err)
	}
}

// TEST_DATABASE_URL must refer to a dedicated test database; migrations persist.
func TestPostgresIntegration(t *testing.T) {
	url := os.Getenv("TEST_DATABASE_URL")
	if url == "" {
		t.Skip("set TEST_DATABASE_URL to run PostgreSQL integration tests")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 45*time.Second)
	defer cancel()
	db, err := Open(ctx, url)
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()

	// Independent providers, as with two concurrently starting API instances.
	results := make(chan error, 2)
	for range 2 {
		go func() { results <- Migrate(ctx, db) }()
	}
	for range 2 {
		if err := <-results; err != nil {
			t.Fatal(err)
		}
	}
	if err := Migrate(ctx, db); err != nil {
		t.Fatalf("repeat migrations: %v", err)
	}
	var schema string
	if err := db.QueryRowContext(ctx, "SELECT schema_name FROM information_schema.schemata WHERE schema_name = 'edm'").Scan(&schema); err != nil {
		t.Fatalf("initial schema missing: %v", err)
	}
	var count int
	if err := db.QueryRowContext(ctx, "SELECT count(*) FROM public.goose_db_version WHERE version_id = 1 AND is_applied").Scan(&count); err != nil || count != 1 {
		t.Fatalf("migration must be recorded exactly once: count=%d, error=%v", count, err)
	}
	if err := db.PingContext(ctx); err != nil {
		t.Fatal(err)
	}
}
