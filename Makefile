.PHONY: install prereqs prereqs-dry typecheck lint test test-coverage deploy deploy-dry launch launch-multi clean help

install:            ## Install pnpm dependencies
	pnpm install

prereqs:            ## Install system prerequisites (Wine, Vulkan, etc.)
	bash scripts/install_prerequisites.sh

prereqs-dry:        ## Preview prerequisite installation without changes
	bash scripts/install_prerequisites.sh --dry-run

typecheck:          ## Run TypeScript strict type checking
	pnpm typecheck

lint:               ## Run ESLint with project rules
	pnpm lint

test:               ## Run Vitest test suite
	pnpm test run

test-coverage:      ## Run tests with coverage report
	pnpm test run --coverage

deploy:             ## Deploy the EverQuest Wine environment
	bash scripts/deploy_eq_env.sh

deploy-dry:         ## Preview deployment actions without executing
	bash scripts/deploy_eq_env.sh --dry-run

launch:             ## Launch a single EverQuest instance
	bash scripts/start_eq.sh

launch-multi:       ## Launch 3 EverQuest instances (multibox)
	bash scripts/start_eq.sh --instances 3

clean:              ## Remove build artifacts and coverage
	rm -rf dist/ coverage/

help:               ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-18s\033[0m %s\n", $$1, $$2}'

.DEFAULT_GOAL := help
