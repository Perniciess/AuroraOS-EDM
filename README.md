# AuroraOS EDM

[Русская версия](README.ru.md)

Electronic document management for Aurora OS. The project is being rebuilt around
a Flutter mobile client and a Go backend with PostgreSQL.

The development sequence is mobile document approval, in-app electronic signatures,
an administration web UI, and a user web UI if needed. Decisions, milestones and
acceptance criteria are tracked in [ROADMAP.md](ROADMAP.md) (in Russian).

## Current status

Stage 1 is in progress: the foundation and the first end-to-end mobile workflow.

- **Backend:** personal accounts and sessions, access-controlled assignments,
  documents and immutable PDF versions, operator CLI for importing PDFs and
  assigning versions, and streaming downloads with range support.
- **Mobile:** sign-in and sign-out, a paginated assignment list, and document
  details for the assigned version. Downloading, private caching, SQLite storage
  and PDF viewing are under development; offline viewing is not yet a completed
  end-to-end workflow.
- **Planned:** approval decisions and reliable synchronization, native integration
  with a cryptographic provider, server-side signature verification, and web UIs.

Viewing a document, approving it, signing it and delivering it are separate actions.
An assignment always refers to an exact immutable document version.

## Repository structure

```text
backend/                    Go backend and operator CLI
  api/openapi.json          HTTP API contract
  cmd/api/                  HTTP server entry point
  cmd/edmctl/               User creation, PDF import and version assignment
  internal/                 Business modules, adapters and infrastructure
  compose.yaml              Local PostgreSQL 17
  ARCHITECTURE.md           Backend architecture and dependency rules
  README.md                 Backend setup, API, CLI and checks
mobile/                     Flutter mobile client
  lib/main.dart             Application entry point and dependency wiring
  lib/app/                  Application shell and theme
  lib/core/                 Shared technical code, including the HTTP client
  lib/features/workspace/   UI, application logic, domain and data access
  aurora/                   Native runner, CMake, desktop entry and RPM spec
  test/                     Client tests
presentation/               Presentation materials
.github/workflows/          Backend CI
ROADMAP.md                  Development plan and open technical questions
```

The former C++/QML client (`client/`) and Python/WebSocket server (`server/`)
are no longer part of the current repository tree. They remain available in Git
history; the new implementation uses its own architecture and HTTP API.

## Requirements and compatibility

- **Backend:** Go 1.26+, PostgreSQL 17; Docker Compose for the local database
  setup below.
- **Mobile:** Flutter for Aurora OS and Aurora SDK. The Dart SDK constraint is
  `^3.11.1`; dependencies are listed in [mobile/pubspec.yaml](mobile/pubspec.yaml),
  including plugins from the Aurora package repository.
- **Target:** Aurora OS. Supported OS versions, devices and CPU architectures
  still need to be confirmed. PDF plugins, the cryptographic provider and RPM
  packaging require validation on the target device. Android/iOS support is not
  promised for the first release.

## Run the backend locally

From the repository root:

```sh
cd backend
export POSTGRES_PASSWORD='local-development-password'
docker compose up -d --wait
export DATABASE_URL="postgres://edm:${POSTGRES_PASSWORD}@127.0.0.1:5432/edm?sslmode=disable"
go run ./cmd/api
```

The server applies embedded PostgreSQL migrations before accepting requests.
By default it listens on `127.0.0.1:8080`:

- `GET /healthz` checks the process.
- `GET /readyz` checks database connectivity.

Configuration is read from the process environment; [backend/.env.example](backend/.env.example)
lists the variables and is not loaded automatically. `sslmode=disable` in the
example is for the local database only. Expose the API to the mobile client
through HTTPS with a certificate trusted by the device.

### Prepare a pilot account and document

In another terminal, use `backend/` as the working directory and set the same
`DATABASE_URL`:

```sh
go run ./cmd/edmctl create-user USERNAME
```

The command reads the password from stdin (12–1024 bytes) and prints the user's
ID and username. There is no public registration. To prepare an assignment:

```sh
go run ./cmd/edmctl import-pdf \
  -operation '<operation-uuid>' -title 'Document' \
  -assignee '<user-uuid>' /private/path/document.pdf
```

Replace the placeholders with UUIDs and a local PDF path. Keep the same operation
UUID, parameters and file for retries. The pilot stores PDF content in PostgreSQL;
the maximum file size is 100 MiB. See [backend/README.md](backend/README.md) for
new versions, additional assignments, API behavior and integration tests.

## Run the mobile client

With Flutter for Aurora OS configured, run from the repository root:

```sh
cd mobile
flutter pub get
flutter devices
flutter run -d '<device-id>' --dart-define=EDM_API_URL=https://edm.example.org
```

Replace the device ID and server address. `EDM_API_URL` must be the HTTPS origin
of your API, without `/api/v1`, credentials, query parameters or a fragment.
The client does not accept plain HTTP or bypass certificate verification.
Sign in using the account created with `edmctl`.

## Development checks

Backend commands, run from `backend/`:

```sh
go test ./...
go vet ./...
go build ./...
```

Database integration tests require `TEST_DATABASE_URL` pointing to a disposable
test database; without it they are skipped. The
[backend workflow](.github/workflows/backend.yml) runs checks with PostgreSQL 17
and produces Linux/amd64 builds of `api` and `edmctl`.

Mobile commands, run from `mobile/` with the Aurora Flutter toolchain:

```sh
flutter analyze
flutter test
```

These checks do not establish device compatibility or validate RPM installation
and signing; those checks remain part of the target-device integration work.

## License and participation

The repository license is [BSD-3-Clause](LICENSE). See
[CONTRIBUTING.md](CONTRIBUTING.md) for contribution terms,
[AUTHORS.md](AUTHORS.md) for contributors, and
[CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) for community guidelines.
