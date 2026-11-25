// SPDX-License-Identifier: BSD-3-Clause

package auth

import (
	"context"
	"crypto/pbkdf2"
	"crypto/rand"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/base64"
	"encoding/hex"
	"errors"
	"fmt"
	"regexp"
	"strings"
	"time"
	"unicode/utf8"
)

var (
	ErrUnauthorized = errors.New("invalid credentials or session")
	ErrRateLimited  = errors.New("too many login attempts")
	ErrInvalidInput = errors.New("invalid username or password")
	ErrConflict     = errors.New("username already exists")
	usernamePattern = regexp.MustCompile(`^[a-z0-9][a-z0-9_.-]{2,63}$`)
)

const (
	SessionLifetime = 24 * time.Hour
	iterations      = 600000
)

type User struct {
	ID       string `json:"id"`
	Username string `json:"username"`
}

type Account struct {
	User
	PasswordHash string
	Disabled     bool
}

type Session struct {
	AccessToken string    `json:"access_token"`
	TokenType   string    `json:"token_type"`
	ExpiresAt   time.Time `json:"expires_at"`
	User        User      `json:"user"`
}

// Store implementations must return ErrUnauthorized for absent users/sessions.
type Store interface {
	CreateUser(context.Context, Account) error
	Account(context.Context, string) (Account, error)
	AllowLogin(context.Context, string) (bool, error)
	CreateSession(context.Context, []byte, string, time.Time) error
	SessionUser(context.Context, []byte) (User, error)
	DeleteSession(context.Context, []byte) error
}

type Service struct {
	store         Store
	passwordSlots chan struct{}
}

func New(store Store) *Service {
	return &Service{store: store, passwordSlots: make(chan struct{}, 4)}
}

func normalizeUsername(username string) (string, bool) {
	username = strings.ToLower(strings.TrimSpace(username))
	return username, usernamePattern.MatchString(username)
}

func (s *Service) CreateUser(ctx context.Context, username, password string) (User, error) {
	username, valid := normalizeUsername(username)
	if !valid || len(password) < 12 || len(password) > 1024 || !utf8.ValidString(password) {
		return User{}, ErrInvalidInput
	}
	var salt [16]byte
	if _, err := rand.Read(salt[:]); err != nil {
		return User{}, err
	}
	key, err := pbkdf2.Key(sha256.New, password, salt[:], iterations, 32)
	if err != nil {
		return User{}, err
	}
	user := User{ID: newID(), Username: username}
	hash := fmt.Sprintf("pbkdf2-sha256$%d$%s$%s", iterations, hex.EncodeToString(salt[:]), hex.EncodeToString(key))
	if err := s.store.CreateUser(ctx, Account{User: user, PasswordHash: hash}); err != nil {
		return User{}, err
	}
	return user, nil
}

func newID() string {
	var id [16]byte
	// crypto/rand.Read cannot fail on supported Go platforms.
	_, _ = rand.Read(id[:])
	id[6] = (id[6] & 0x0f) | 0x40
	id[8] = (id[8] & 0x3f) | 0x80
	return fmt.Sprintf("%x-%x-%x-%x-%x", id[:4], id[4:6], id[6:8], id[8:10], id[10:])
}

func (s *Service) Login(ctx context.Context, username, password string) (Session, error) {
	username, valid := normalizeUsername(username)
	if !valid || len(password) == 0 || len(password) > 1024 {
		return Session{}, ErrUnauthorized
	}
	allowed, err := s.store.AllowLogin(ctx, username)
	if err != nil {
		return Session{}, err
	}
	if !allowed {
		return Session{}, ErrRateLimited
	}
	// Bound expensive password checks independently from the database pool.
	select {
	case s.passwordSlots <- struct{}{}:
		defer func() { <-s.passwordSlots }()
	default:
		return Session{}, ErrRateLimited
	}
	account, err := s.store.Account(ctx, username)
	missing := errors.Is(err, ErrUnauthorized)
	if err != nil && !missing {
		return Session{}, err
	}
	// Same KDF work for absent and disabled accounts as for a wrong password.
	hash := account.PasswordHash
	if missing {
		hash = "pbkdf2-sha256$600000$00000000000000000000000000000000$0000000000000000000000000000000000000000000000000000000000000000"
	}
	matched := checkPassword(hash, password)
	if !matched || missing || account.Disabled {
		return Session{}, ErrUnauthorized
	}
	if err := ctx.Err(); err != nil {
		return Session{}, err
	}
	var token [32]byte
	if _, err := rand.Read(token[:]); err != nil {
		return Session{}, err
	}
	session := Session{AccessToken: base64.RawURLEncoding.EncodeToString(token[:]), TokenType: "Bearer", ExpiresAt: time.Now().UTC().Add(SessionLifetime), User: account.User}
	digest := sha256.Sum256(token[:])
	if err := s.store.CreateSession(ctx, digest[:], account.ID, session.ExpiresAt); err != nil {
		return Session{}, err
	}
	return session, nil
}

func checkPassword(encoded, password string) bool {
	parts := strings.Split(encoded, "$")
	if len(parts) != 4 || parts[0] != "pbkdf2-sha256" || parts[1] != "600000" {
		return false
	}
	salt, err := hex.DecodeString(parts[2])
	if err != nil || len(salt) != 16 {
		return false
	}
	expected, err := hex.DecodeString(parts[3])
	if err != nil || len(expected) != 32 {
		return false
	}
	actual, err := pbkdf2.Key(sha256.New, password, salt, iterations, 32)
	return err == nil && subtle.ConstantTimeCompare(actual, expected) == 1
}

func tokenHash(token string) ([]byte, error) {
	if len(token) != 43 {
		return nil, ErrUnauthorized
	}
	decoded, err := base64.RawURLEncoding.Strict().DecodeString(token)
	if err != nil || len(decoded) != 32 {
		return nil, ErrUnauthorized
	}
	digest := sha256.Sum256(decoded)
	return digest[:], nil
}

func (s *Service) CurrentUser(ctx context.Context, token string) (User, error) {
	hash, err := tokenHash(token)
	if err != nil {
		return User{}, err
	}
	return s.store.SessionUser(ctx, hash)
}

// Logout is idempotent, including already revoked and expired tokens.
func (s *Service) Logout(ctx context.Context, token string) error {
	hash, err := tokenHash(token)
	if err != nil {
		return err
	}
	return s.store.DeleteSession(ctx, hash)
}
