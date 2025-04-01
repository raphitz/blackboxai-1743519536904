# Makefile for Eventoando project

# Environment variables
ENV ?= dev
FLUTTER = flutter
NPM = npm
TERRAFORM = terraform
AWS = aws

# Directories
FRONTEND_DIR = frontend
BACKEND_DIR = backend
INFRASTRUCTURE_DIR = infrastructure/terraform

# Colors for output
YELLOW = \033[1;33m
GREEN = \033[0;32m
RED = \033[0;31m
NC = \033[0m # No Color

.PHONY: help
help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  ${YELLOW}%-20s${NC} %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# Frontend Commands
.PHONY: frontend-install
frontend-install: ## Install frontend dependencies
	@echo "${YELLOW}Installing frontend dependencies...${NC}"
	@cd $(FRONTEND_DIR) && $(FLUTTER) pub get

.PHONY: frontend-run
frontend-run: ## Run frontend in development mode
	@echo "${YELLOW}Starting frontend development server...${NC}"
	@cd $(FRONTEND_DIR) && $(FLUTTER) run -d chrome

.PHONY: frontend-build
frontend-build: ## Build frontend for production
	@echo "${YELLOW}Building frontend...${NC}"
	@cd $(FRONTEND_DIR) && $(FLUTTER) build web --release

.PHONY: frontend-test
frontend-test: ## Run frontend tests
	@echo "${YELLOW}Running frontend tests...${NC}"
	@cd $(FRONTEND_DIR) && $(FLUTTER) test

.PHONY: frontend-clean
frontend-clean: ## Clean frontend build files
	@echo "${YELLOW}Cleaning frontend build files...${NC}"
	@cd $(FRONTEND_DIR) && $(FLUTTER) clean

# Backend Commands
.PHONY: backend-install
backend-install: ## Install backend dependencies
	@echo "${YELLOW}Installing backend dependencies...${NC}"
	@cd $(BACKEND_DIR) && $(NPM) install

.PHONY: backend-build
backend-build: ## Build backend TypeScript files
	@echo "${YELLOW}Building backend...${NC}"
	@cd $(BACKEND_DIR) && $(NPM) run build

.PHONY: backend-test
backend-test: ## Run backend tests
	@echo "${YELLOW}Running backend tests...${NC}"
	@cd $(BACKEND_DIR) && $(NPM) test

.PHONY: backend-clean
backend-clean: ## Clean backend build files
	@echo "${YELLOW}Cleaning backend build files...${NC}"
	@rm -rf $(BACKEND_DIR)/dist

# Infrastructure Commands
.PHONY: infra-init
infra-init: ## Initialize Terraform
	@echo "${YELLOW}Initializing Terraform...${NC}"
	@cd $(INFRASTRUCTURE_DIR) && $(TERRAFORM) init

.PHONY: infra-plan
infra-plan: ## Plan Terraform changes
	@echo "${YELLOW}Planning Terraform changes...${NC}"
	@cd $(INFRASTRUCTURE_DIR) && $(TERRAFORM) plan

.PHONY: infra-apply
infra-apply: ## Apply Terraform changes
	@echo "${YELLOW}Applying Terraform changes...${NC}"
	@cd $(INFRASTRUCTURE_DIR) && $(TERRAFORM) apply

.PHONY: infra-destroy
infra-destroy: ## Destroy Terraform infrastructure
	@echo "${RED}WARNING: This will destroy all infrastructure. Are you sure? (y/N)${NC}"
	@read -p "" response; \
	if [ "$$response" = "y" ]; then \
		cd $(INFRASTRUCTURE_DIR) && $(TERRAFORM) destroy; \
	else \
		echo "${GREEN}Destruction cancelled${NC}"; \
	fi

# Deployment Commands
.PHONY: deploy
deploy: ## Deploy the application to specified environment
	@if [ "$(ENV)" = "prod" ]; then \
		echo "${RED}WARNING: Deploying to production environment. Are you sure? (y/N)${NC}"; \
		read -p "" response; \
		if [ "$$response" != "y" ]; then \
			echo "${GREEN}Deployment cancelled${NC}"; \
			exit 1; \
		fi \
	fi
	@echo "${YELLOW}Deploying to $(ENV) environment...${NC}"
	@./deploy.sh $(ENV)

# Development Commands
.PHONY: dev-setup
dev-setup: frontend-install backend-install infra-init ## Set up development environment

.PHONY: dev-clean
dev-clean: frontend-clean backend-clean ## Clean all build files

.PHONY: test
test: frontend-test backend-test ## Run all tests

# Database Commands
.PHONY: db-migrate
db-migrate: ## Run database migrations
	@echo "${YELLOW}Running database migrations...${NC}"
	@cd $(BACKEND_DIR) && $(NPM) run migrate

.PHONY: db-seed
db-seed: ## Seed database with sample data
	@echo "${YELLOW}Seeding database...${NC}"
	@cd $(BACKEND_DIR) && $(NPM) run seed

# Utility Commands
.PHONY: lint
lint: ## Run linters
	@echo "${YELLOW}Running linters...${NC}"
	@cd $(FRONTEND_DIR) && $(FLUTTER) analyze
	@cd $(BACKEND_DIR) && $(NPM) run lint

.PHONY: format
format: ## Format code
	@echo "${YELLOW}Formatting code...${NC}"
	@cd $(FRONTEND_DIR) && $(FLUTTER) format .
	@cd $(BACKEND_DIR) && $(NPM) run format

.PHONY: check-env
check-env: ## Validate environment configuration
	@echo "${YELLOW}Checking environment configuration...${NC}"
	@test -f .env.$(ENV) || (echo "${RED}Error: .env.$(ENV) file not found${NC}" && exit 1)

# CI/CD Commands
.PHONY: ci-build
ci-build: frontend-build backend-build ## Build for CI environment

.PHONY: ci-test
ci-test: test lint ## Run tests and linting for CI environment

# Monitoring Commands
.PHONY: logs
logs: ## View application logs
	@echo "${YELLOW}Fetching logs...${NC}"
	@$(AWS) logs tail --follow

.PHONY: metrics
metrics: ## View application metrics
	@echo "${YELLOW}Fetching metrics...${NC}"
	@$(AWS) cloudwatch get-metric-statistics --namespace Eventoando --metric-name CPUUtilization

# Documentation Commands
.PHONY: docs
docs: ## Generate documentation
	@echo "${YELLOW}Generating documentation...${NC}"
	@cd $(FRONTEND_DIR) && $(FLUTTER) doc .
	@cd $(BACKEND_DIR) && $(NPM) run docs