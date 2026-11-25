// SPDX-License-Identifier: BSD-3-Clause

package auth

import (
	"context"
	"errors"
	"testing"
)

type captureStore struct {
	Store
	account Account
}

func (s *captureStore) CreateUser(_ context.Context, account Account) error {
	s.account = account
	return nil
}

func TestPasswordStorage(t *testing.T) {
	store := &captureStore{}
	service := New(store)
	password := "достаточно длинный пароль"
	user, err := service.CreateUser(context.Background(), "  Alice  ", password)
	if err != nil || user.Username != "alice" || len(user.ID) != 36 {
		t.Fatalf("create account: %+v %v", user, err)
	}
	first := store.account.PasswordHash
	if !checkPassword(first, password) || checkPassword(first, "wrong password") {
		t.Fatal("password verification failed")
	}
	if _, err := service.CreateUser(context.Background(), "alice", password); err != nil {
		t.Fatal(err)
	}
	if first == store.account.PasswordHash {
		t.Fatal("password salts must be unique")
	}
	for _, hash := range []string{"", "plaintext", "pbkdf2-sha256$1$00$00", "pbkdf2-sha256$600000$broken$broken"} {
		if checkPassword(hash, password) {
			t.Fatal("accepted malformed hash")
		}
	}
	for _, input := range []struct{ username, password string }{
		{"ab", password}, {"with space", password}, {"alice", "short"},
		{"alice", "invalid-utf8-\xff"},
	} {
		if _, err := service.CreateUser(context.Background(), input.username, input.password); !errors.Is(err, ErrInvalidInput) {
			t.Fatalf("invalid account accepted: %v", err)
		}
	}
}

func TestTokenValidation(t *testing.T) {
	for _, token := range []string{"", "secret", "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=", "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAB"} {
		if _, err := tokenHash(token); !errors.Is(err, ErrUnauthorized) {
			t.Fatalf("accepted malformed token %q", token)
		}
	}
}
