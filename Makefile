.PHONY: install prereqs prereqs-dry typecheck lint test test-coverage deploy deploy-dry configure configure-dry doctor login login-copy launch launch-multi backup-session restore-session clean purge help

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

deploy:             ## Full deployment (prefix + DXVK + EQ install + config)
	bash scripts/deploy_eq_env.sh

deploy-dry:         ## Preview deployment without making changes
	bash scripts/deploy_eq_env.sh --dry-run

configure:          ## Apply optimized eqclient.ini settings
	bash scripts/configure_eq.sh

configure-dry:      ## Preview INI changes without writing
	bash scripts/configure_eq.sh --dry-run

doctor:             ## Health check — validate entire installation
	bash scripts/doctor.sh

login:              ## Auto-fill login credentials from pass store
	bash scripts/login_helper.sh

login-copy:         ## Copy password to clipboard for right-click paste in launcher
	@pass gaming/daybreak/password 2>/dev/null | tr -d '\n' | wl-copy 2>/dev/null \
		|| pass gaming/daybreak/password 2>/dev/null | tr -d '\n' | xclip -selection clipboard 2>/dev/null \
		|| (echo "ERROR: Install wl-clipboard or xclip"; exit 1)
	@echo "Password copied to clipboard. Right-click the password field in EQ and select Paste."

launch:             ## Launch a single EverQuest instance
	bash scripts/start_eq.sh

launch-multi:       ## Launch 3 EverQuest instances (multibox)
	bash scripts/start_eq.sh --instances 3

backup-session:     ## Back up launcher session (login cookies, DPAPI key)
	@mkdir -p ~/.local/share/norrath-native/backup
	@cp ~/.wine-eq/drive_c/EverQuest/LaunchPad.libs/LaunchPad.Cache/Cookies \
		~/.local/share/norrath-native/backup/Cookies 2>/dev/null \
		&& cp ~/.wine-eq/drive_c/EverQuest/LaunchPad.libs/LaunchPad.Cache/LocalPrefs.json \
		~/.local/share/norrath-native/backup/LocalPrefs.json 2>/dev/null \
		&& echo "Session backed up to ~/.local/share/norrath-native/backup/" \
		|| echo "No session to back up (log in first)"

restore-session:    ## Restore launcher session from backup
	@if [ -f ~/.local/share/norrath-native/backup/Cookies ]; then \
		cp ~/.local/share/norrath-native/backup/Cookies \
			~/.wine-eq/drive_c/EverQuest/LaunchPad.libs/LaunchPad.Cache/Cookies \
		&& cp ~/.local/share/norrath-native/backup/LocalPrefs.json \
			~/.wine-eq/drive_c/EverQuest/LaunchPad.libs/LaunchPad.Cache/LocalPrefs.json \
		&& echo "Session restored. Next launch should auto-login."; \
	else \
		echo "No backup found. Run make backup-session first."; \
	fi

clean:              ## Remove build artifacts and coverage
	rm -rf dist/ coverage/

purge:              ## Remove Wine prefix and all EQ data (DESTRUCTIVE)
	@printf '\033[31mThis will delete ~/.wine-eq and all EQ data. Continue? [y/N] \033[0m'
	@read -r confirm && [ "$$confirm" = "y" ] && rm -rf ~/.wine-eq ~/.local/share/norrath-native || echo "Cancelled."

help:               ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-18s\033[0m %s\n", $$1, $$2}'

.DEFAULT_GOAL := help
