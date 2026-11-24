// SPDX-License-Identifier: MIT

package postgres

import (
	"context"
	"database/sql"
	"embed"
	"errors"
	"io/fs"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/stdlib"
	"github.com/pressly/goose/v3"
	"github.com/pressly/goose/v3/lock"
)

//go:embed migrations/*.sql
var migrations embed.FS

// Open creates a bounded pool and verifies the connection before returning it.
// Driver errors are not exposed: they can contain credentials from the DSN.
func Open(ctx context.Context, url string) (*sql.DB, error) {
	cfg, err := pgx.ParseConfig(url)
	if err != nil {
		return nil, errors.New("invalid PostgreSQL configuration")
	}
	cfg.ConnectTimeout = 5 * time.Second
	db := stdlib.OpenDB(*cfg)
	db.SetMaxOpenConns(10)
	db.SetMaxIdleConns(5)
	db.SetConnMaxLifetime(30 * time.Minute)
	db.SetConnMaxIdleTime(5 * time.Minute)
	pingCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	if err := db.PingContext(pingCtx); err != nil {
		_ = db.Close()
		return nil, errors.New("PostgreSQL connection failed")
	}
	return db, nil
}

// Migrate applies embedded SQL migrations transactionally. The advisory lock
// serializes migrations when multiple API instances start simultaneously.
func Migrate(ctx context.Context, db *sql.DB) error {
	source, err := fs.Sub(migrations, "migrations")
	if err != nil {
		return errors.New("load PostgreSQL migrations failed")
	}
	locker, err := lock.NewPostgresSessionLocker()
	if err != nil {
		return errors.New("initialize PostgreSQL migration lock failed")
	}
	provider, err := goose.NewProvider(goose.DialectPostgres, db, source,
		goose.WithSessionLocker(locker), goose.WithDisableGlobalRegistry(true),
		// Creating edm can change the default search_path for the edm role.
		goose.WithTableName("public.goose_db_version"))
	if err != nil {
		return errors.New("initialize PostgreSQL migrations failed")
	}
	if _, err := provider.Up(ctx); err != nil {
		return errors.New("PostgreSQL migrations failed")
	}
	return nil
}
