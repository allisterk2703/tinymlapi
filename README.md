<p align="center"><img src=".github/logo-tinymlapi.png" width="300"/></p>

# tinymlapi

Dockerized Flask/FastAPI random-integer inference API with Gunicorn/Uvicorn + Nginx.

## Endpoints

| Method | Route | Description |
|---|---|---|
| GET | `/health` | Health check |
| POST | `/invocations` | Returns a random integer within a range |

```json
// POST /invocations
{ "min_val": 10, "max_val": 50 }

// Response
{ "value": 27, "range": "10-50" }
```

---

## Prerequisites

- [OrbStack](https://orbstack.dev/)
- [fzf](https://github.com/junegunn/fzf) — `brew install fzf`
- [uv](https://docs.astral.sh/uv/) — `brew install uv`

---

## Run locally

```bash
make run-container     # build and start (select Flask or FastAPI via fzf)
make check-health      # GET /health
make call-api          # POST /invocations
make stop-container    # stop the container
make remove-containers # stop and remove images
```

> If a port conflict occurs (K8s services running), free the ports first: `make teardown-kubernetes`

---

## Test suite

Both containers must be running simultaneously. Flask is mapped to port **5001** to avoid conflicts with K8s services when both are active.

```bash
make install-deps      # create .venv and install dependencies (once)

# Start both containers
make run-container     # → FastAPI (port 8000)
make run-container     # → Flask (port 5000)

make run-tests         # run all 52 tests
```

---

## Deploy on Kubernetes (OrbStack)

Requires a `.env` file at the project root:

```bash
cp .env.example .env   # then fill in your values
```

```bash
make deploy-kubernetes    # build, push to GHCR, deploy (first time)
make redeploy-kubernetes  # quick redeploy (images already pushed)
make check-deployments    # pods, services, deployments
make tail-pod-logs        # Flask and FastAPI logs
make teardown-kubernetes  # remove all resources
```

**Services:**

| Framework | URL |
|---|---|
| FastAPI | `http://k8s.orb.local:8000` |
| Flask | `http://k8s.orb.local:5000` |

---

## All make targets

```bash
make help        # list all commands
```

| Target | Description |
|---|---|
| `make build-image` | Build a Docker image |
| `make run-container` | Build and start a container |
| `make stop-container` | Stop a running container |
| `make remove-containers` | Stop and remove all images |
| `make purge-all` | `remove-containers` + remove `.venv` and caches |
| `make call-api` | POST sample request to `/invocations` |
| `make check-health` | GET `/health` |
| `make push-image` | Build and push image to GHCR |
| `make install-deps` | Create `.venv` and install test dependencies |
| `make run-tests` | Run the full test suite (52 tests) |
| `make deploy-kubernetes` | Full Kubernetes deployment |
| `make redeploy-kubernetes` | Quick redeploy |
| `make check-deployments` | Show pods, services, deployments |
| `make tail-pod-logs` | Show logs |
| `make teardown-kubernetes` | Remove all Kubernetes resources |
