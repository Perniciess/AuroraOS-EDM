// SPDX-License-Identifier: MIT

package postgres

import (
	"context"
	"database/sql"
	"errors"
	"time"

	"github.com/Perniciess/AuroraOS-EDM/backend/internal/auth"
	"github.com/jackc/pgx/v5/pgconn"
)

type Accounts struct{ DB *sql.DB }

func (s Accounts) CreateUser(ctx context.Context, account auth.Account) error {
	_, err := s.DB.ExecContext(ctx, `INSERT INTO edm.users (id, username, password_hash) VALUES ($1, $2, $3)`, account.ID, account.Username, account.PasswordHash)
	var pgErr *pgconn.PgError
	if errors.As(err, &pgErr) && pgErr.Code == "23505" {
		return auth.ErrConflict
	}
	return err
}

func (s Accounts) Account(ctx context.Context, username string) (auth.Account, error) {
	var account auth.Account
	err := s.DB.QueryRowContext(ctx, `SELECT id, username, password_hash, disabled FROM edm.users WHERE username = $1`, username).Scan(&account.ID, &account.Username, &account.PasswordHash, &account.Disabled)
	if errors.Is(err, sql.ErrNoRows) {
		err = auth.ErrUnauthorized
	}
	return account, err
}

func (s Accounts) AllowLogin(ctx context.Context, username string) (bool, error) {
	var attempts int
	err := s.DB.QueryRowContext(ctx, `
		INSERT INTO edm.login_attempts (username, window_start, attempts) VALUES ($1, now(), 1)
		ON CONFLICT (username) DO UPDATE SET
		attempts = CASE WHEN edm.login_attempts.window_start <= now() - interval '15 minutes' THEN 1 ELSE LEAST(edm.login_attempts.attempts + 1, 11) END,
		window_start = CASE WHEN edm.login_attempts.window_start <= now() - interval '15 minutes' THEN now() ELSE edm.login_attempts.window_start END
		RETURNING attempts`, username).Scan(&attempts)
	return attempts <= 10, err
}

func (s Accounts) CreateSession(ctx context.Context, hash []byte, userID string, expires time.Time) error {
	// Recheck disabled under the same statement that issues the session.
	result, err := s.DB.ExecContext(ctx, `INSERT INTO edm.sessions (token_hash, user_id, expires_at)
		SELECT $1, id, $3 FROM edm.users WHERE id = $2 AND NOT disabled`, hash, userID, expires)
	if err != nil {
		return err
	}
	n, err := result.RowsAffected()
	if err == nil && n == 0 {
		return auth.ErrUnauthorized
	}
	return err
}

func (s Accounts) SessionUser(ctx context.Context, hash []byte) (auth.User, error) {
	var user auth.User
	err := s.DB.QueryRowContext(ctx, `SELECT u.id, u.username FROM edm.sessions s JOIN edm.users u ON u.id = s.user_id
		WHERE s.token_hash = $1 AND s.expires_at > now() AND NOT u.disabled`, hash).Scan(&user.ID, &user.Username)
	if errors.Is(err, sql.ErrNoRows) {
		err = auth.ErrUnauthorized
	}
	return user, err
}

func (s Accounts) DeleteSession(ctx context.Context, hash []byte) error {
	_, err := s.DB.ExecContext(ctx, `DELETE FROM edm.sessions WHERE token_hash = $1`, hash)
	return err
}
