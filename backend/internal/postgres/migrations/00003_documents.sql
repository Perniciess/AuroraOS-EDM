-- SPDX-License-Identifier: MIT
-- +goose Up
CREATE TABLE edm.documents (
    id uuid PRIMARY KEY,
    title text NOT NULL CHECK (length(btrim(title)) BETWEEN 1 AND 500),
    created_at timestamptz NOT NULL DEFAULT now()
);

-- Only finalized content belongs here; temporary uploads will have separate storage.
CREATE TABLE edm.document_versions (
    id uuid PRIMARY KEY,
    document_id uuid NOT NULL REFERENCES edm.documents(id),
    number bigint NOT NULL CHECK (number > 0),
    media_type text NOT NULL CHECK (media_type = 'application/pdf'),
    size_bytes bigint NOT NULL CHECK (size_bytes > 0),
    checksum_algorithm text NOT NULL CHECK (checksum_algorithm = 'sha256'),
    checksum text NOT NULL CHECK (checksum ~ '^[0-9a-f]{64}$'),
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (document_id, number),
    UNIQUE (document_id, id)
);

-- +goose StatementBegin
CREATE FUNCTION edm.reject_version_change() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'document versions are immutable' USING ERRCODE = '23514';
END;
$$;
-- +goose StatementEnd
CREATE TRIGGER immutable_document_version BEFORE UPDATE OR DELETE ON edm.document_versions
    FOR EACH ROW EXECUTE FUNCTION edm.reject_version_change();

CREATE TABLE edm.assignments (
    id uuid PRIMARY KEY,
    document_id uuid NOT NULL,
    version_id uuid NOT NULL,
    assignee_id uuid NOT NULL REFERENCES edm.users(id),
    status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'cancelled')),
    revision bigint NOT NULL DEFAULT 1 CHECK (revision > 0),
    created_at timestamptz NOT NULL DEFAULT now(),
    FOREIGN KEY (document_id, version_id) REFERENCES edm.document_versions(document_id, id)
);
CREATE INDEX assignments_inbox ON edm.assignments (assignee_id, id) WHERE status = 'pending';
CREATE INDEX assignments_access ON edm.assignments (assignee_id, document_id, version_id) WHERE status = 'pending';
CREATE UNIQUE INDEX assignments_pending_unique ON edm.assignments (assignee_id, version_id) WHERE status = 'pending';

-- +goose Down
DROP TABLE edm.assignments;
DROP TABLE edm.document_versions;
DROP FUNCTION edm.reject_version_change();
DROP TABLE edm.documents;
