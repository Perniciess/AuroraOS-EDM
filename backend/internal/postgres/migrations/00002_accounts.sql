-- SPDX-License-Identifier: BSD-3-Clause
-- +goose Up
CREATE TABLE edm.users (
    id uuid PRIMARY KEY,
    username text NOT NULL UNIQUE CHECK (username ~ '^[a-z0-9][a-z0-9_.-]{2,63}$'),
    password_hash text NOT NULL,
    disabled boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE edm.sessions (
    token_hash bytea PRIMARY KEY CHECK (octet_length(token_hash) = 32),
    user_id uuid NOT NULL REFERENCES edm.users(id) ON DELETE CASCADE,
    expires_at timestamptz NOT NULL
);
CREATE INDEX sessions_expiry ON edm.sessions (expires_at);
CREATE INDEX sessions_user ON edm.sessions (user_id);

-- Account-independent buckets do not reveal whether a username exists.
CREATE TABLE edm.login_attempts (
    username text PRIMARY KEY,
    window_start timestamptz NOT NULL,
    attempts integer NOT NULL
);

-- +goose Down
DROP TABLE edm.login_attempts;
DROP TABLE edm.sessions;
DROP TABLE edm.users;
