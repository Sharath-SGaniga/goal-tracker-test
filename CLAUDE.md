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

### Local stack
```bash
cd docker-local-deployment && docker compose up -d
```
Brings up frontend (`:3000`), backend (`:8080`), and Postgres 15 (`:5432`, db `goalsdb`, user/pass `postgres/postgres`). Verified working end-to-end inside a GitHub Codespace.

### Build & push images (Docker Hub)
```bash
docker build -t <user>/goal-tracker-backend:v1  ./backend
docker build -t <user>/goal-tracker-frontend:v1 ./frontend
docker push <user>/goal-tracker-backend:v1
docker push <user>/goal-tracker-frontend:v1
```
Tag with an immutable version (`:v1`, git SHA, etc.), not just `:latest` — the README's eventual Terraform deploy uses `:latest`, which is mutable and a footgun. Push both tags if you must.

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

## Kubernetes deployment (`k8s/`)

Manifests live (or will live) under `k8s/`, one file per resource with numeric prefixes so `kubectl apply -f k8s/` orders correctly. Everything goes in a single namespace (e.g. `goal-tracker`).

**Service names are load-bearing — don't rename without updating the consumers:**
- Postgres `Service` must be named `postgres` → backend's `DB_HOST` defaults to this.
- Backend `Service` must be named `backend` → frontend's `BACKEND_URL` is `http://backend:8080`.
- Frontend `Service` is the only externally-reachable one. Inside a kind cluster, use `NodePort` + `kubectl port-forward`; with a real cloud LB or Ingress controller, switch type accordingly.

**Postgres tier specifics:**
- A single `Secret` (Opaque) holds DB credentials and is consumed by *both* the Postgres pod (`POSTGRES_USER`/`POSTGRES_PASSWORD`/`POSTGRES_DB`) and the backend pod (`DB_USERNAME`/`DB_PASSWORD`/`DB_NAME`). Design the keys so both consumers can `envFrom` it, or use explicit `valueFrom.secretKeyRef` per var.
- `init.sql` is delivered via a `ConfigMap` mounted at `/docker-entrypoint-initdb.d/init.sql` (use `subPath: init.sql` on the volumeMount, otherwise the whole directory is shadowed).
- Persistent storage: a `PersistentVolumeClaim` at `/var/lib/postgresql/data`. 1Gi is plenty for testing; leave `storageClassName` unset so the cluster default is used.
- A plain `Deployment` is acceptable for learning; `StatefulSet` is more correct for production (stable identity, ordered startup) but not required.

**Backend tier specifics:**
- `backend/main.go:93-97` does **not retry** the DB connection on startup. If Postgres isn't ready, the pod exits and K8s restarts it. Liveness probe handles this naturally; alternatively, add an `initContainer` that waits for Postgres.
- Probe target: HTTP GET `/health` on port 8080 (defined at `backend/main.go:340`). Use it for both readiness and liveness; give liveness a longer `initialDelaySeconds` (~15s) to absorb cold-start.
- All env vars from `backend/main.go:50-58` are required: `DB_HOST`, `DB_PORT`, `DB_USERNAME`, `DB_PASSWORD`, `DB_NAME`, `SSL`. `DB_PORT` and `PORT` are strings (env vars always are).

**Frontend tier specifics:**
- No `/health` endpoint exists; `server.js:63` catch-all serves `index.html` for any path, so `GET /` is a working readiness check.
- CORS allowlist in `backend/main.go:87` includes `http://frontend:3000` — that name happens to match the Service convention, so cross-tier requests originating from a backend caller named `frontend` would be allowed. In normal use the browser hits the frontend Service and the proxy talks to the backend in-cluster, so CORS never engages.

## Conventions worth knowing

- Go module path is `github.com/itsBaivab/Terraform-Full-Course-Azure` — leftover from upstream; don't "fix" it without reason, imports depend on it.
- The `Goal` struct uses capitalized JSON field names (`"ID"`, `"Name"`) but the POST body uses snake_case (`"goal_name"`). The frontend has to match both shapes — check `index.html` before renaming fields.
- Database schema is bootstrapped in two places (Go `CREATE TABLE` and `init.sql`); keep them in lockstep.
