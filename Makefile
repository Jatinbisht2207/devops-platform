OWNER ?= OWNER
.PHONY: install lint test build local-up local-down demo-good demo-bad tf-plan bootstrap
install:   ; cd app && pip install -r requirements-dev.txt
lint:      ; cd app && ruff check . && ruff format --check . && bandit -q -r main.py
test:      ; cd app && pytest --cov=main --cov-fail-under=80
build:     ; docker build -t orders-api:local --build-arg APP_VERSION=local app
local-up:  ; ./scripts/local-up.sh
local-down:; kind delete cluster --name devops-platform
demo-good: ; ./scripts/demo-rollout.sh good
demo-bad:  ; ./scripts/demo-rollout.sh bad
tf-plan:   ; terraform -chdir=terraform init && terraform -chdir=terraform plan -var-file=envs/prod.tfvars
bootstrap: ; ./scripts/bootstrap.sh
