// SPDX-License-Identifier: BSD-3-Clause

// edmctl provisions pilot accounts, documents and assignments through trusted DB access.
package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"os"
	"strings"
	"time"

	"github.com/Perniciess/AuroraOS-EDM/backend/internal/auth"
	"github.com/Perniciess/AuroraOS-EDM/backend/internal/config"
	"github.com/Perniciess/AuroraOS-EDM/backend/internal/documents"
	documentpg "github.com/Perniciess/AuroraOS-EDM/backend/internal/documents/postgres"
	"github.com/Perniciess/AuroraOS-EDM/backend/internal/postgres"
)

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func run() error {
	if len(os.Args) >= 2 && os.Args[1] == "import-pdf" {
		return importPDF(os.Args[2:])
	}
	if len(os.Args) >= 2 && os.Args[1] == "assign-version" {
		return assignVersion(os.Args[2:])
	}
	if len(os.Args) != 3 || os.Args[1] != "create-user" {
		return fmt.Errorf("usage: edmctl create-user USERNAME (password from stdin, 12–1024 bytes), import-pdf, or assign-version")
	}
	password, err := io.ReadAll(io.LimitReader(os.Stdin, 1027))
	if err != nil {
		return fmt.Errorf("read password failed")
	}
	defer clear(password)
	secret := strings.TrimSuffix(strings.TrimSuffix(string(password), "\n"), "\r")
	if len(secret) < 12 || len(secret) > 1024 {
		return auth.ErrInvalidInput
	}
	cfg, err := config.Load(os.Getenv)
	if err != nil {
		return err
	}
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	db, err := postgres.Open(ctx, cfg.DatabaseURL)
	if err != nil {
		return err
	}
	defer db.Close()
	if err := postgres.Migrate(ctx, db); err != nil {
		return err
	}
	user, err := auth.New(postgres.Accounts{DB: db}).CreateUser(ctx, os.Args[2], secret)
	if err != nil {
		if err == auth.ErrInvalidInput || err == auth.ErrConflict {
			return err
		}
		return fmt.Errorf("create user failed")
	}
	fmt.Fprintln(os.Stdout, user.ID, user.Username)
	return nil
}

func assignVersion(args []string) error {
	if len(args) != 3 {
		return fmt.Errorf("usage: edmctl assign-version OPERATION_UUID VERSION_UUID ASSIGNEE_UUID")
	}
	cfg, err := config.Load(os.Getenv)
	if err != nil {
		return err
	}
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	db, err := postgres.Open(ctx, cfg.DatabaseURL)
	if err != nil {
		return err
	}
	defer db.Close()
	if err := postgres.Migrate(ctx, db); err != nil {
		return err
	}
	a, err := (documents.Files{Store: documentpg.Files{DB: db}}).Assign(ctx, args[0], args[1], args[2])
	if err != nil {
		if err == documents.ErrInvalidImport || err == documents.ErrImportConflict {
			return err
		}
		return fmt.Errorf("assignment failed; check database, finalized version and active assignee; retry with the same operation ID")
	}
	return json.NewEncoder(os.Stdout).Encode(a)
}

func importPDF(args []string) error {
	flags := flag.NewFlagSet("import-pdf", flag.ContinueOnError)
	var opts documents.ImportOptions
	flags.StringVar(&opts.ID, "operation", "", "UUID retained across retries")
	flags.StringVar(&opts.DocumentID, "document", "", "existing document UUID; omit to create")
	flags.StringVar(&opts.Title, "title", "", "document title (required)")
	flags.StringVar(&opts.AssigneeID, "assignee", "", "active user UUID")
	if err := flags.Parse(args); err != nil {
		return err
	}
	if flags.NArg() != 1 {
		return fmt.Errorf("usage: edmctl import-pdf -operation UUID -title TITLE -assignee USER_UUID [-document UUID] FILE")
	}
	cfg, err := config.Load(os.Getenv)
	if err != nil {
		return err
	}
	file, err := os.Open(flags.Arg(0))
	if err != nil {
		return fmt.Errorf("open PDF failed")
	}
	defer file.Close()
	info, err := file.Stat()
	if err != nil || !info.Mode().IsRegular() {
		return fmt.Errorf("PDF must be a regular file")
	}
	if info.Size() > documents.MaxFileSize {
		return documents.ErrInvalidFile
	}
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()
	db, err := postgres.Open(ctx, cfg.DatabaseURL)
	if err != nil {
		return err
	}
	defer db.Close()
	if err := postgres.Migrate(ctx, db); err != nil {
		return err
	}
	result, err := (documents.Files{Store: documentpg.Files{DB: db}}).Import(ctx, opts, file)
	if err != nil {
		if err == documents.ErrInvalidFile || err == documents.ErrInvalidImport || err == documents.ErrImportConflict {
			return err
		}
		return fmt.Errorf("import failed; check database, document and active assignee; retry with the same operation ID")
	}
	return json.NewEncoder(os.Stdout).Encode(result)
}
