// SPDX-License-Identifier: MIT

// edmctl provisions pilot accounts without exposing public registration.
package main

import (
	"context"
	"fmt"
	"io"
	"os"
	"strings"
	"time"

	"github.com/Perniciess/AuroraOS-EDM/backend/internal/auth"
	"github.com/Perniciess/AuroraOS-EDM/backend/internal/config"
	"github.com/Perniciess/AuroraOS-EDM/backend/internal/postgres"
)

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func run() error {
	if len(os.Args) != 3 || os.Args[1] != "create-user" {
		return fmt.Errorf("usage: edmctl create-user USERNAME (password from stdin, 12–1024 bytes)")
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
