-- SPDX-License-Identifier: BSD-3-Clause
-- +goose Up
-- Pending uploads exist only inside the import transaction. Rollback is cleanup.
CREATE TABLE edm.file_uploads (
    id uuid PRIMARY KEY,
    document_id uuid,
    title text NOT NULL DEFAULT '',
    assignee_id uuid REFERENCES edm.users(id),
    finalized boolean NOT NULL DEFAULT false,
    FOREIGN KEY (id) REFERENCES edm.document_versions(id) DEFERRABLE INITIALLY DEFERRED
);
CREATE TABLE edm.file_chunks (
    upload_id uuid NOT NULL REFERENCES edm.file_uploads(id),
    number integer NOT NULL CHECK (number >= 0 AND number < 100),
    content bytea NOT NULL CHECK (octet_length(content) BETWEEN 1 AND 1048576),
    PRIMARY KEY (upload_id, number)
);
-- +goose StatementBegin
CREATE FUNCTION edm.guard_file_content() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
    sealed boolean;
BEGIN
    IF TG_TABLE_NAME = 'file_uploads' THEN
        IF OLD.finalized THEN
            RAISE EXCEPTION 'finalized uploads are immutable' USING ERRCODE = '23514';
        END IF;
    ELSE
        IF TG_OP <> 'INSERT' THEN
            RAISE EXCEPTION 'file content is immutable' USING ERRCODE = '23514';
        END IF;
        SELECT finalized INTO sealed FROM edm.file_uploads WHERE id = NEW.upload_id FOR UPDATE;
        IF NOT FOUND OR sealed THEN
            RAISE EXCEPTION 'file content is immutable' USING ERRCODE = '23514';
        END IF;
    END IF;
    IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
    RETURN NEW;
END;
$$;
-- +goose StatementEnd
CREATE TRIGGER immutable_upload BEFORE UPDATE OR DELETE ON edm.file_uploads
    FOR EACH ROW EXECUTE FUNCTION edm.guard_file_content();
CREATE TRIGGER immutable_chunks BEFORE INSERT OR UPDATE OR DELETE ON edm.file_chunks
    FOR EACH ROW EXECUTE FUNCTION edm.guard_file_content();

-- +goose Down
DROP TABLE edm.file_chunks;
DROP TABLE edm.file_uploads;
DROP FUNCTION edm.guard_file_content();
