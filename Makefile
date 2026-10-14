.DEFAULT_GOAL := help

SHELL := /bin/bash
ROOT_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
TF_DIR := $(ROOT_DIR)/terraform
MODULES_DIR := $(ROOT_DIR)/modules
SCRIPTS := $(ROOT_DIR)/scripts

TF_VARS_TO_UNSET := TF_VAR_cluster_name TF_VAR_location TF_VAR_domain TF_VAR_aro_version \
	TF_VAR_pull_secret_path TF_VAR_pull_secret TF_VAR_oidc_issuer_url \
	TF_VAR_api_visibility TF_VAR_ingress_visibility TF_VAR_worker_count

.PHONY: help fmt lint test setup docs-venv docs-preview docs-build cluster.%

help: ## Show available targets
	@grep -E '^[a-zA-Z0-9_.-]+:.*##' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "}; {printf "  %-28s %s\n", $$1, $$2}'
	@echo ""
	@echo "Cluster operations: make cluster.<name>.<operation>"
	@echo "  init plan apply destroy kubeconfig platform"
	@echo "Examples:"
	@echo "  make cluster.aro-classic-miwi.plan"
	@echo "  make cluster.aro-classic-miwi.apply"

cluster.%:
	@CLUSTER_PROFILE=$$(echo "$@" | cut -d'.' -f2); \
	OPERATION=$$(echo "$@" | cut -d'.' -f3-); \
	if [ -z "$$CLUSTER_PROFILE" ] || [ -z "$$OPERATION" ]; then \
		echo "Usage: make cluster.<name>.<operation>" >&2; \
		exit 1; \
	fi; \
	if [ ! -d "$(ROOT_DIR)/clusters/$$CLUSTER_PROFILE" ]; then \
		echo "Cluster directory clusters/$$CLUSTER_PROFILE does not exist" >&2; \
		ls -1 "$(ROOT_DIR)/clusters/" 2>/dev/null | sed 's/^/  - /' || true; \
		exit 1; \
	fi; \
	$(MAKE) -f Makefile.cluster CLUSTER_PROFILE=$$CLUSTER_PROFILE $$OPERATION

fmt: ## Format Terraform and shell scripts
	terraform -chdir=$(TF_DIR) fmt -recursive
	terraform -chdir=$(MODULES_DIR)/network fmt
	terraform -chdir=$(MODULES_DIR)/identities fmt
	terraform -chdir=$(MODULES_DIR)/cluster fmt
	terraform -chdir=$(MODULES_DIR)/bgp fmt
	terraform -chdir=$(MODULES_DIR)/routeserver fmt
	@command -v shfmt >/dev/null && shfmt -w -i 2 -ci -bn $(SCRIPTS) || echo "shfmt not installed; skipping"

lint: ## Run linters (terraform validate/tflint, shellcheck)
	terraform -chdir=$(TF_DIR) init -backend=false -input=false
	terraform -chdir=$(TF_DIR) validate
	terraform -chdir=$(MODULES_DIR)/network init -backend=false -input=false && terraform -chdir=$(MODULES_DIR)/network validate
	terraform -chdir=$(MODULES_DIR)/identities init -backend=false -input=false && terraform -chdir=$(MODULES_DIR)/identities validate
	terraform -chdir=$(MODULES_DIR)/cluster init -backend=false -input=false && terraform -chdir=$(MODULES_DIR)/cluster validate
	terraform -chdir=$(MODULES_DIR)/bgp init -backend=false -input=false && terraform -chdir=$(MODULES_DIR)/bgp validate
	terraform -chdir=$(MODULES_DIR)/routeserver init -backend=false -input=false && terraform -chdir=$(MODULES_DIR)/routeserver validate
	@command -v tflint >/dev/null && (cd $(TF_DIR) && tflint --init && tflint) || echo "tflint not installed; skipping"
	@command -v shellcheck >/dev/null && shellcheck --external-sources $(SCRIPTS)/*.sh || echo "shellcheck not installed; skipping"
	@command -v shfmt >/dev/null && shfmt -d -i 2 -ci -bn $(SCRIPTS) || true

test: lint ## Run unit tests (terraform test + bats)
	unset $(TF_VARS_TO_UNSET); \
	terraform -chdir=$(MODULES_DIR)/network test; \
	terraform -chdir=$(MODULES_DIR)/identities test; \
	terraform -chdir=$(MODULES_DIR)/cluster test; \
	terraform -chdir=$(MODULES_DIR)/bgp test; \
	terraform -chdir=$(MODULES_DIR)/routeserver test; \
	terraform -chdir=$(TF_DIR) test
	@if command -v bats >/dev/null; then bats $(ROOT_DIR)/tests/bats; else echo "bats not installed; skipping"; fi

setup: ## Verify az, terraform, and oc are installed
	bash $(SCRIPTS)/setup.sh

VENV_DOCS ?= .venv-docs
DOCS_MKDOCS := $(VENV_DOCS)/bin/mkdocs
DOCS_PIP := $(VENV_DOCS)/bin/pip

docs-venv: ## Create docs virtualenv
	@if ! command -v python3 >/dev/null 2>&1; then echo "python3 required" >&2; exit 1; fi
	@if [ ! -d "$(VENV_DOCS)" ]; then python3 -m venv "$(VENV_DOCS)"; fi
	@$(DOCS_PIP) install -q -r requirements-docs.txt

docs-preview: docs-venv ## Serve MkDocs locally
	@$(DOCS_MKDOCS) serve

docs-build: docs-venv ## Build MkDocs site (strict)
	@$(DOCS_MKDOCS) build --strict
