.PHONY: help build-image run-container stop-container remove-containers purge-all call-api push-image check-health login-registry create-namespace create-pull-secret deploy-kubernetes redeploy-kubernetes check-deployments teardown-kubernetes tail-pod-logs inspect-pods install-deps run-tests recreate-repo

ENV_FILE?=.env
-include $(ENV_FILE)

PROJECT_NAME=tinymlapi
NAMESPACE=$(PROJECT_NAME)
IMAGE_NAME=$(PROJECT_NAME)-image
CONTAINER_NAME=$(PROJECT_NAME)-container
PORT_FLASK=5001
PORT_FASTAPI=8000
REGISTRY=ghcr.io/$(GITHUB_USERNAME)

GITHUB_DESC = "Dockerized Flask/FastAPI random-integer inference API with Nginx and Gunicorn/Uvicorn"
GITHUB_TOPICS = "api,docker,nginx,kubernetes,inference"

help: ## Show this help
	@grep -hE '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

recreate-repo: ## Delete and recreate the GitHub repository to wipe activity/history
	-gh repo delete $(GITHUB_USERNAME)/$(PROJECT_NAME) --yes
	gh repo create $(PROJECT_NAME) --public --description $(GITHUB_DESC)
	gh repo edit $(GITHUB_USERNAME)/$(PROJECT_NAME) --add-topic $(GITHUB_TOPICS)
	rm -rf .git
	git init
	git add .
	git commit -m "[ADD] $$(date +'%Y-%m-%d %H:%M:%S')"
	git branch -M main
	git remote add origin https://github.com/$(GITHUB_USERNAME)/$(PROJECT_NAME).git
	git push -u origin main --force
	gh secret set GHCR_TOKEN --body "$(GHCR_TOKEN)" -R $(GITHUB_USERNAME)/$(PROJECT_NAME)

install-deps: ## Create Python virtual environment and install test dependencies (requires uv)
	uv sync

run-tests: ## Run unit tests (requires both containers to be running)
	uv run pytest tests/ -v

build-image: ## Build a Docker image
	$(eval FRAMEWORK := $(shell printf "Flask\tflask\nFastAPI\tfastapi" | fzf --prompt="Select a framework to build > " --height=20% --layout=reverse --border --with-nth=1 --delimiter=$$'\t' | cut -f2))
	docker build -t $(IMAGE_NAME)-$(FRAMEWORK) $(FRAMEWORK)/

run-container: build-image ## Build and run a container
	$(eval FRAMEWORK := $(shell printf "Flask\tflask\nFastAPI\tfastapi" | fzf --prompt="Select a framework to run > " --height=20% --layout=reverse --border --with-nth=1 --delimiter=$$'\t' | cut -f2))
	$(eval PORT := $(if $(filter flask,$(FRAMEWORK)),$(PORT_FLASK),$(PORT_FASTAPI)))
	@echo "Starting $(FRAMEWORK) API at http://127.0.0.1:$(PORT)"
	docker run --rm -p $(PORT):$(if $(filter flask,$(FRAMEWORK)),5000,$(PORT)) --name $(CONTAINER_NAME)-$(FRAMEWORK) $(IMAGE_NAME)-$(FRAMEWORK)

stop-container: ## Stop a running container
	$(eval FRAMEWORK := $(shell printf "Flask\tflask\nFastAPI\tfastapi" | fzf --prompt="Select a framework to stop > " --height=20% --layout=reverse --border --with-nth=1 --delimiter=$$'\t' | cut -f2))
	docker stop $(CONTAINER_NAME)-$(FRAMEWORK) || true

remove-containers: ## Stop all containers and remove Docker images
	docker stop $(CONTAINER_NAME) $(CONTAINER_NAME)-flask $(CONTAINER_NAME)-fastapi 2>/dev/null || true
	docker rmi $(IMAGE_NAME)-flask $(IMAGE_NAME)-fastapi || true

purge-all: remove-containers ## Remove Docker images, Python venv and caches
	rm -rf .venv .pytest_cache __pycache__ tests/__pycache__ flask/__pycache__ fastapi/__pycache__
	find . -name "*.pyc" -delete

call-api: ## Send a test request with cURL
	$(eval FRAMEWORK := $(shell printf "Flask\tflask\nFastAPI\tfastapi" | fzf --prompt="Select a framework to test > " --height=20% --layout=reverse --border --with-nth=1 --delimiter=$$'\t' | cut -f2))
	$(eval PORT := $(if $(filter flask,$(FRAMEWORK)),$(PORT_FLASK),$(PORT_FASTAPI)))
	curl -X POST http://127.0.0.1:$(PORT)/invocations \
		-H "Content-Type: application/json" \
		-d '{"min_val": 10, "max_val": 50}'
	@echo "\nTest completed."

push-image: ## Build and push an image to GitHub Container Registry
	$(eval FRAMEWORK := $(shell printf "Flask\tflask\nFastAPI\tfastapi" | fzf --prompt="Select a framework to push > " --height=20% --layout=reverse --border --with-nth=1 --delimiter=$$'\t' | cut -f2))
	docker build -t $(REGISTRY)/$(PROJECT_NAME)-$(FRAMEWORK):latest $(FRAMEWORK)/
	docker push $(REGISTRY)/$(PROJECT_NAME)-$(FRAMEWORK):latest

check-health: ## Test the health check endpoint
	$(eval FRAMEWORK := $(shell printf "Flask\tflask\nFastAPI\tfastapi" | fzf --prompt="Select a framework to ping > " --height=20% --layout=reverse --border --with-nth=1 --delimiter=$$'\t' | cut -f2))
	$(eval PORT := $(if $(filter flask,$(FRAMEWORK)),$(PORT_FLASK),$(PORT_FASTAPI)))
	curl -i http://127.0.0.1:$(PORT)/health

login-registry: ## Login to GitHub Container Registry
	@if [ -z "$(GHCR_TOKEN)" ]; then \
		echo "ERROR: GHCR_TOKEN not found in $(ENV_FILE)"; \
		exit 1; \
	fi
	@cat $(ENV_FILE) | grep GHCR_TOKEN | cut -d= -f2 | docker login ghcr.io -u $(GITHUB_USERNAME) --password-stdin
	@echo "Logged in to GHCR"

create-namespace: ## Create the tinymlapi namespace
	kubectl apply -f k8s/namespace.yaml

create-pull-secret: create-namespace ## Create the ghcr.io pull secret in Kubernetes
	@if kubectl get secret ghcr-secret -n $(NAMESPACE) >/dev/null 2>&1; then \
		echo "Secret ghcr-secret already exists"; \
	else \
		if [ -z "$(GHCR_TOKEN)" ]; then \
			echo "ERROR: GHCR_TOKEN not found in $(ENV_FILE)"; \
			echo "Please create a .env file with: GHCR_TOKEN=your_token_here"; \
			exit 1; \
		fi; \
		kubectl create secret docker-registry ghcr-secret \
			--docker-server=ghcr.io \
			--docker-username=$(GITHUB_USERNAME) \
			--docker-password=$(GHCR_TOKEN) \
			-n $(NAMESPACE) && \
		echo "Secret created successfully"; \
	fi

deploy-kubernetes: ## Complete k8s deployment (build, push, create secret, deploy)
	orbctl start
	$(MAKE) login-registry
	$(MAKE) create-pull-secret
	docker build -t $(REGISTRY)/$(PROJECT_NAME)-flask:latest flask/
	docker build -t $(REGISTRY)/$(PROJECT_NAME)-fastapi:latest fastapi/
	docker push $(REGISTRY)/$(PROJECT_NAME)-flask:latest
	docker push $(REGISTRY)/$(PROJECT_NAME)-fastapi:latest
	for f in k8s/*.yaml; do GITHUB_USERNAME=$(GITHUB_USERNAME) envsubst '$$GITHUB_USERNAME' < $$f; done | kubectl apply -f -

redeploy-kubernetes: ## Quick deploy (assumes images are already pushed)
	orbctl start
	$(MAKE) create-pull-secret
	for f in k8s/*.yaml; do GITHUB_USERNAME=$(GITHUB_USERNAME) envsubst '$$GITHUB_USERNAME' < $$f; done | kubectl apply -f -

check-deployments: ## Show pods and services status
	@echo "Pods:"
	@kubectl get pods -n $(NAMESPACE) -o wide
	@echo "\nServices:"
	@kubectl get svc -n $(NAMESPACE)
	@echo "\nDeployment status:"
	@kubectl get deployments -n $(NAMESPACE)

tail-pod-logs: ## Show logs from all pods
	@echo "Flask pod logs:"
	@kubectl logs -l app=flask -n $(NAMESPACE) --tail=50 || true
	@echo "\nFastAPI pod logs:"
	@kubectl logs -l app=fastapi -n $(NAMESPACE) --tail=50 || true

inspect-pods: ## Debug: show detailed pod info and events
	@echo "Pod details:"
	@kubectl describe pods -n $(NAMESPACE)
	@echo "\nRecent events:"
	@kubectl get events -n $(NAMESPACE) --sort-by='.lastTimestamp'

teardown-kubernetes: ## Remove all deployed resources
	for f in k8s/*.yaml; do GITHUB_USERNAME=$(GITHUB_USERNAME) envsubst '$$GITHUB_USERNAME' < $$f; done | kubectl delete -f -
