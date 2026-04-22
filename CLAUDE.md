# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**tinymlapi** is a dockerized inference API that generates random integers. It provides two parallel implementations (Flask and FastAPI) with identical functionality, each deployable via Docker or Kubernetes.

**Endpoints:**
- `GET /health` — service health check
- `POST /invocations` — returns a random integer within a range

## Architecture

### Framework Implementations

The project contains two independent implementations in separate directories:

- **`flask/`** — Flask-based API
  - `app.py` — application factory
  - `routes.py` — blueprint with `/health` and `/invocations` endpoints
  - `services.py` — `predict()` function that generates random integers
  - `wsgi.py` — WSGI entry point for Gunicorn
  - `Dockerfile` — containerization with Gunicorn

- **`fastapi/`** — FastAPI-based API
  - `app.py` — application factory and app instance
  - `routes.py` — router with endpoints
  - `services.py` — `predict()` function (same as Flask)
  - `Dockerfile` — containerization with Uvicorn

Both implementations share identical business logic (`services.py:predict()`) but differ in framework scaffolding. They are built and deployed as separate Docker images.

### Deployment

- **Docker**: Single container runs locally via `make run` at `http://localhost:8080`
- **Kubernetes**: Manifests in `k8s/` deploy both services to OrbStack
  - `k8s/flask-deployment.yaml` and `k8s/flask-service.yaml`
  - `k8s/fastapi-deployment.yaml` and `k8s/fastapi-service.yaml`
  - Images pulled from GitHub Container Registry (`ghcr.io/allisterk2703/`)

## Common Development Commands

| Command | Purpose |
|---|---|
| `make build` | Build Docker image (prompts to choose Flask or FastAPI) |
| `make run` | Build and run container locally |
| `make test` | Send sample POST request to `/invocations` |
| `make ping` | Check `/health` endpoint |
| `make stop` | Stop the running container |
| `make clean` | Remove the Docker image |
| `make push` | Build and push image to GHCR |
| `make k8s-deploy-all` | Full Kubernetes deployment (build, push, deploy) |
| `make k8s-deploy` | Quick Kubernetes deploy (assumes images already pushed) |
| `make k8s-status` | Show pods, services, and deployments |
| `make k8s-logs` | Show logs from Flask and FastAPI pods |
| `make k8s-delete` | Remove all Kubernetes resources |

## Configuration

- **`.env` file** — stores `GHCR_TOKEN` for pushing images to GitHub Container Registry
- **`Makefile`** — interactive framework selection (Flask vs FastAPI) for `build`, `run`, and `push` targets
- API runs on port **8080** by default (both Docker and Kubernetes)

## Key Development Notes

1. **Parallel Implementations**: Changes affecting business logic (e.g., `services.py:predict()`) must be applied to both `flask/` and `fastapi/` to keep them synchronized.

2. **Docker Builds**: The `make build`, `make run`, and `make push` targets use `fzf` for interactive framework selection — both frameworks are valid targets.

3. **Kubernetes Deployment**: 
   - Requires OrbStack
   - `GHCR_TOKEN` in `.env` is required for image authentication
   - Services are exposed at `127.0.0.1:8080` (FastAPI) and `127.0.0.1:8081` (Flask) via kubectl port-forward

4. **Image Registry**: Images are stored at `ghcr.io/allisterk2703/tinymlapi-{flask,fastapi}:latest`
