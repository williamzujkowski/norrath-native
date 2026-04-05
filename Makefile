.PHONY: install build prereqs launch-perf launch-safe logs prereqs-dry typecheck lint test test-coverage docs docs-check stats stats-check stats-fix deploy deploy-dry configure configure-dry colors colors-preview layout layout-preview layout-apply layout-show layout-templates resolution resolution-detect adapt adapt-dry profile-save profile-load profile-list setup-all tile tile-grid pip focus-next windows identify doctor support-bundle launch launch-multi backup-session restore-session maps parser clean purge help

install:            ## Install pnpm dependencies
	pnpm install

build:              ## Compile TypeScript to dist/ and Wine helpers
	pnpm build
	@if command -v x86_64-w64-mingw32-gcc >/dev/null 2>&1; then \
		x86_64-w64-mingw32-gcc -o helpers/wine_helper.exe helpers/wine_helper.c -luser32 2>/dev/null && \
		echo "Built helpers/wine_helper.exe"; \
	else \
		echo "WARNING: gcc-mingw-w64 not installed, Wine helper not built"; \
		echo "  Install: sudo apt install gcc-mingw-w64"; \
	fi

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

docs:               ## Generate API docs, command reference, and check reference
	bash scripts/generate-docs.sh

docs-check:         ## Verify generated docs are up to date (CI mode)
	bash scripts/generate-docs.sh --check

stats:              ## Show project statistics from source of truth
	npx tsx scripts/generate-stats.ts

stats-check:        ## Verify doc numbers match source (CI mode)
	npx tsx scripts/generate-stats.ts

stats-fix:          ## Fix stale numbers in documentation
	npx tsx scripts/generate-stats.ts --fix

deploy:             ## Full deployment (prefix + DXVK + EQ install + config)
	bash scripts/deploy_eq_env.sh

deploy-dry:         ## Preview deployment without making changes
	bash scripts/deploy_eq_env.sh --dry-run

configure:          ## Apply optimized eqclient.ini settings
	bash scripts/configure_eq.sh

configure-dry:      ## Preview INI changes without writing
	bash scripts/configure_eq.sh --dry-run

resolution:         ## Set Wine + EQ resolution to match your monitor (auto-detect)
	bash scripts/resolution_manager.sh apply

adapt:              ## Auto-adapt to current display (run after plugging/unplugging monitor)
	bash scripts/adapt_display.sh

adapt-dry:          ## Preview display adaptation without applying
	bash scripts/adapt_display.sh --dry-run

resolution-detect:  ## Show detected monitor resolution vs current Wine resolution
	bash scripts/resolution_manager.sh detect

TEMPLATE ?=

layout-apply:       ## Apply a layout template (TEMPLATE=name, e.g., multibox-bard-pull)
	@if [ -z "$(TEMPLATE)" ]; then bash scripts/layout_calculator.sh list; else bash scripts/layout_calculator.sh apply "$(TEMPLATE)"; fi

layout-show:        ## Preview a layout template's calculated positions
	@if [ -z "$(TEMPLATE)" ]; then bash scripts/layout_calculator.sh list; else bash scripts/layout_calculator.sh show "$(TEMPLATE)"; fi

layout-templates:   ## List available layout templates
	bash scripts/layout_calculator.sh list

PROFILE ?=

profile-save:       ## Save current UI layout as a named profile (PROFILE=name)
	@if [ -z "$(PROFILE)" ]; then echo "Usage: make profile-save PROFILE=my-layout"; exit 1; fi
	bash scripts/layout_profiles.sh save "$(PROFILE)"

profile-load:       ## Load a saved UI layout profile (PROFILE=name)
	@if [ -z "$(PROFILE)" ]; then bash scripts/layout_profiles.sh list; exit 1; fi
	bash scripts/layout_profiles.sh load "$(PROFILE)"

profile-list:       ## List available UI layout profiles
	bash scripts/layout_profiles.sh list

doctor:             ## Health check — validate entire installation
	bash scripts/doctor.sh

support-bundle:     ## Generate a support bundle for troubleshooting
	@mkdir -p /tmp/norrath-native-support
	@bash scripts/doctor.sh --json > /tmp/norrath-native-support/doctor.json 2>&1
	@cp ~/.local/share/norrath-native/*.log /tmp/norrath-native-support/ 2>/dev/null || true
	@cp ~/.local/share/norrath-native/state.json /tmp/norrath-native-support/ 2>/dev/null || true
	@tar -czf norrath-native-support.tar.gz -C /tmp norrath-native-support
	@rm -rf /tmp/norrath-native-support
	@echo "Support bundle: norrath-native-support.tar.gz"

setup-all:          ## Apply ALL customizations to ALL characters (config + colors + layout + resolution)
	@echo "=== Applying settings to all characters ==="
	@echo "Note: colors are safe while running (/loadskin to reload)."
	@echo "      layout + resolution changes require camping first."
	@echo ""
	bash scripts/resolution_manager.sh apply
	bash scripts/configure_eq.sh
	bash scripts/apply_colors.sh
	bash scripts/apply_layout.sh
	@echo ""
	@echo "Done. Restart EQ or /loadskin Default to reload UI."

launch:             ## Launch a single EverQuest instance
	bash scripts/start_eq.sh

launch-perf:        ## Launch with DXVK performance overlay (FPS, GPU, frame times)
	DXVK_HUD=fps,frametimes,devinfo,gpuload,compiler bash scripts/start_eq.sh

launch-safe:        ## Launch with minimal profile + diagnostics for troubleshooting
	DXVK_HUD=fps,devinfo DXVK_LOG_LEVEL=info bash scripts/start_eq.sh

logs:               ## Tail all EQ instance logs (color-coded)
	@tail -f ~/.local/share/norrath-native/eq-instance-*.log 2>/dev/null || echo "No instance logs found. Launch EQ first."

launch-multi:       ## Launch multibox instances (default: 3, set multibox_instances in config)
	bash scripts/start_eq.sh --multi

tile:               ## Smart tile — identifies characters, main gets large window
	bash scripts/smart_tile.sh auto

tile-grid:          ## Equal grid tile (all windows same size)
	bash scripts/smart_tile.sh equal

pip:                ## Picture-in-picture: main window large, others stacked right
	bash scripts/window_manager.sh pip

focus-next:         ## Cycle keyboard focus to the next EQ window
	bash scripts/window_manager.sh focus

windows:            ## List all detected EQ windows
	bash scripts/window_manager.sh list

identify:           ## Screenshot each EQ window to identify characters
	bash scripts/window_manager.sh identify

backup-session:     ## Back up launcher login session for disaster recovery
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

colors:             ## Apply optimized chat color scheme for raid readability
	bash scripts/apply_colors.sh

colors-preview:     ## Preview color scheme changes without applying
	bash scripts/apply_colors.sh --dry-run

layout:             ## Apply recommended 4-window chat layout (Social/Combat/Spam/Alerts)
	bash scripts/apply_layout.sh

layout-preview:     ## Preview chat layout changes without applying
	bash scripts/apply_layout.sh --dry-run

FILE ?=

maps:               ## Install Brewall's map pack (FILE=path/to/downloaded.zip)
	@if [ -z "$(FILE)" ]; then bash scripts/install_maps.sh --help; else bash scripts/install_maps.sh --file "$(FILE)"; fi

PARSER_FILE ?=

parser:             ## Install EQLogParser DPS meter + trigger system (PARSER_FILE=path/to/downloaded.zip)
	@if [ -z "$(PARSER_FILE)" ]; then bash scripts/install_parser.sh; else bash scripts/install_parser.sh --file "$(PARSER_FILE)"; fi

clean:              ## Remove build artifacts and coverage
	rm -rf dist/ coverage/

purge:              ## Remove Wine prefix and all EQ data (DESTRUCTIVE)
	@printf '\033[31mThis will delete ~/.wine-eq and all EQ data. Continue? [y/N] \033[0m'
	@read -r confirm && [ "$$confirm" = "y" ] && rm -rf ~/.wine-eq ~/.local/share/norrath-native || echo "Cancelled."

help:               ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-18s\033[0m %s\n", $$1, $$2}'

.DEFAULT_GOAL := help
