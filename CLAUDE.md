# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository state vs. README

The README describes a full Azure Terraform deployment (an `infra/` tree with `modules/networking`, `modules/compute`, `modules/database`, `modules/dns`, `modules/keyvault`, plus `environments/prod/`). **That tree does not exist in this checkout.** What is actually present is the application code only:

```
backend/                    # Go API (main.go, go.mod/go.sum, Dockerfile)
frontend/                   # Node/Express server, static index.html, Dockerfile
docker-local-deployment/    # docker-compose.yml + database/init.sql
README.md
```

If a task references the Terraform infra, treat it as not-yet-written rather than missing — don't assume a parallel directory exists elsewhere.

The Dockerfiles referenced by `docker-local-deployment/docker-compose.yml` (`../frontend/Dockerfile`, `../backend/Dockerfile`) do exist — both are alpine-based, backend is a multi-stage Go build running as a non-root `app` user.

## Commands

### Local stack (intended path, currently blocked on missing Dockerfiles)
```bash
cd docker-local-deployment && docker-compose up -d
```
Brings up frontend (`:3000`), backend (`:8080`), and Postgres 15 (`:5432`, db `goalsdb`, user/pass `postgres/postgres`).

### Backend (Go, Gin)
```bash
cd backend
go mod download
go run main.go        # listens on $PORT (default 8080)
go build ./...        # compile
go vet ./...
```
No tests exist; `go test ./...` is a no-op. The backend requires these env vars to start (it exits if it can't `db.Ping()`): `DB_USERNAME`, `DB_PASSWORD`, `DB_HOST`, `DB_PORT`, `DB_NAME`, `SSL` (e.g. `disable`).

### Frontend (Node/Express)
```bash
cd frontend
npm install
npm start             # node server.js
npm run dev           # nodemon
```
`npm test` is a placeholder that exits 1. `BACKEND_URL` (default `http://localhost:8080`) and `PORT` (default `3000`) are the only env vars.

## Architecture

Three-tier "goal tracker" — the data model is one table, `goals(id, goal_name)`.

- **`frontend/server.js`** — Express server. Two responsibilities: (1) serves the static SPA from `public/index.html`, (2) acts as a thin proxy: `/api/goals` (GET/POST) and `/api/goals/:id` (DELETE) forward to `${BACKEND_URL}/goals*`. The browser never talks to the Go service directly; it always goes through this proxy. CORS is enabled but in practice unused since same-origin via the proxy.

- **`backend/main.go`** — Single-file Gin app. All handlers, DB init, and Prometheus registration live in `main()` / `init()`. On startup it `CREATE TABLE IF NOT EXISTS goals` itself, so the schema is defined in two places (here and `docker-local-deployment/database/init.sql`); they currently agree on `id SERIAL` + a name column but disagree on the column type (`VARCHAR(255)` in Go vs `TEXT` in SQL) and column name vs. struct casing — keep both in sync if you change the schema.

- **Dual API surfaces in the backend.** The JSON API used by the frontend is `GET/POST /goals` and `DELETE /goals/:id`. There is also a *second* set of form-post endpoints (`POST /add_goal`, `POST /remove_goal`) and a `GET /` HTML route, all gated behind `if os.Getenv("KO_DATA_PATH") != ""`. These are leftover from a `ko`-based deployment and are dead code in the docker-compose path. If you're touching goal CRUD, update both call sites or the two will drift.

- **Observability.** Prometheus metrics are exposed at `/metrics`: `add_goal_requests_total`, `remove_goal_requests_total`, and `http_requests_total{path=...}`. Each handler increments `httpRequestsCounter` with its route as the label — when adding a new route, add the matching `.WithLabelValues(...).Inc()` call or it will be invisible in metrics.

- **CORS allowlist** in `main.go` is hardcoded to `http://localhost:3000` and `http://frontend:3000` (the docker-compose service name). Any new frontend origin must be added there.

## Conventions worth knowing

- Go module path is `github.com/itsBaivab/Terraform-Full-Course-Azure` — leftover from upstream; don't "fix" it without reason, imports depend on it.
- The `Goal` struct uses capitalized JSON field names (`"ID"`, `"Name"`) but the POST body uses snake_case (`"goal_name"`). The frontend has to match both shapes — check `index.html` before renaming fields.
- Database schema is bootstrapped in two places (Go `CREATE TABLE` and `init.sql`); keep them in lockstep.
