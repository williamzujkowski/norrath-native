.PHONY: install build prereqs prereqs-dry typecheck lint test test-coverage docs docs-check stats stats-check stats-fix deploy deploy-dry configure configure-dry fix fix-dry colors colors-preview layout layout-preview layout-apply layout-show layout-templates profile-save profile-load profile-list tile tile-set-main tile-grid pip focus-next windows identify status status-json doctor support-bundle launch launch-multi launch-perf launch-safe logs backup-session restore-session maps parser clean purge help

# ─── Setup ────────────────────────────────────────────────────────────────────

prereqs:            ## Install system prerequisites (Wine, Vulkan, etc.)
	bash scripts/install_prerequisites.sh

install:            ## Install pnpm dependencies
	pnpm install

build:              ## Compile TypeScript and Wine helper
	pnpm build
	@if command -v x86_64-w64-mingw32-gcc >/dev/null 2>&1; then \
		x86_64-w64-mingw32-gcc -o helpers/wine_helper.exe helpers/wine_helper.c -luser32 2>/dev/null && \
		echo "Built helpers/wine_helper.exe"; \
	else \
		echo "WARNING: gcc-mingw-w64 not installed, Wine helper not built"; \
		echo "  Install: sudo apt install gcc-mingw-w64"; \
	fi

deploy:             ## Full deployment (prefix + DXVK + EQ install + config)
	bash scripts/deploy_eq_env.sh

# ─── Play ─────────────────────────────────────────────────────────────────────

launch:             ## Launch a single EverQuest instance
	bash scripts/start_eq.sh

launch-multi:       ## Launch multibox instances (default: 3)
	bash scripts/start_eq.sh --multi

fix:                ## Fix everything — syncs display, tiles windows or applies config
	bash scripts/fix.sh

# ─── Window Management ───────────────────────────────────────────────────────

tile:               ## Tile windows — main character gets large window
	bash scripts/smart_tile.sh auto

tile-set-main:      ## Identify which window is your main character
	bash scripts/tile_set_main.sh

tile-grid:          ## Equal grid tile (all windows same size)
	bash scripts/smart_tile.sh equal

pip:                ## Picture-in-picture layout
	bash scripts/window_manager.sh pip

focus-next:         ## Cycle focus to next EQ window
	bash scripts/window_manager.sh focus

windows:            ## List all detected EQ windows
	bash scripts/window_manager.sh list

# ─── Customization ───────────────────────────────────────────────────────────

configure:          ## Apply optimized eqclient.ini settings
	bash scripts/configure_eq.sh

colors:             ## Apply WCAG-compliant chat color scheme
	bash scripts/apply_colors.sh

layout:             ## Apply 4-window chat layout (Social/Combat/Spam/Alerts)
	bash scripts/apply_layout.sh

TEMPLATE ?=
layout-apply:       ## Apply a layout template (TEMPLATE=name)
	@if [ -z "$(TEMPLATE)" ]; then bash scripts/layout_calculator.sh list; else bash scripts/layout_calculator.sh apply "$(TEMPLATE)"; fi

layout-templates:   ## List available layout templates
	bash scripts/layout_calculator.sh list

FILE ?=
maps:               ## Install Good's maps (auto-download, or FILE=path/to/custom.zip)
	@if [ -z "$(FILE)" ]; then bash scripts/install_maps.sh; else bash scripts/install_maps.sh --file "$(FILE)"; fi

PARSER_FILE ?=
parser:             ## Install EQLogParser DPS meter (auto-download from GitHub)
	@if [ -z "$(PARSER_FILE)" ]; then bash scripts/install_parser.sh; else bash scripts/install_parser.sh --file "$(PARSER_FILE)"; fi

# ─── Diagnostics ──────────────────────────────────────────────────────────────

doctor:             ## Health check — validate entire installation
	bash scripts/doctor.sh

status:             ## Show diagnostic dashboard (monitor, windows, config)
	bash scripts/status.sh

support-bundle:     ## Generate a support bundle for troubleshooting
	@mkdir -p /tmp/norrath-native-support
	@bash scripts/doctor.sh --json > /tmp/norrath-native-support/doctor.json 2>&1
	@cp ~/.local/share/norrath-native/*.log /tmp/norrath-native-support/ 2>/dev/null || true
	@cp ~/.local/share/norrath-native/state.json /tmp/norrath-native-support/ 2>/dev/null || true
	@tar -czf norrath-native-support.tar.gz -C /tmp norrath-native-support
	@rm -rf /tmp/norrath-native-support
	@echo "Support bundle: norrath-native-support.tar.gz"

logs:               ## Tail all EQ instance logs
	@tail -f ~/.local/share/norrath-native/eq-instance-*.log 2>/dev/null || echo "No instance logs found. Launch EQ first."

# ─── Session ──────────────────────────────────────────────────────────────────

backup-session:     ## Back up launcher login session
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

# ─── Maintenance ──────────────────────────────────────────────────────────────

clean:              ## Remove build artifacts and coverage
	rm -rf dist/ coverage/

purge:              ## Remove Wine prefix and all EQ data (DESTRUCTIVE)
	@printf '\033[31mThis will delete ~/.wine-eq and all EQ data. Continue? [y/N] \033[0m'
	@read -r confirm && [ "$$confirm" = "y" ] && rm -rf ~/.wine-eq ~/.local/share/norrath-native || echo "Cancelled."

# ─── Development (not shown in help) ─────────────────────────────────────────

typecheck:
	pnpm typecheck

lint:
	pnpm lint

test:
	pnpm test run

test-coverage:
	pnpm test run --coverage

format:
	pnpm run format

format-check:
	pnpm run format:check

docs:
	bash scripts/generate-docs.sh

docs-check:
	bash scripts/generate-docs.sh --check

stats:
	npx tsx scripts/generate-stats.ts

stats-check:
	npx tsx scripts/generate-stats.ts

stats-fix:
	npx tsx scripts/generate-stats.ts --fix

status-json:
	bash scripts/status.sh --json

prereqs-dry:
	bash scripts/install_prerequisites.sh --dry-run

deploy-dry:
	bash scripts/deploy_eq_env.sh --dry-run

configure-dry:
	bash scripts/configure_eq.sh --dry-run

fix-dry:
	bash scripts/fix.sh --dry-run

colors-preview:
	bash scripts/apply_colors.sh --dry-run

layout-preview:
	bash scripts/apply_layout.sh --dry-run

layout-show:
	@if [ -z "$(TEMPLATE)" ]; then bash scripts/layout_calculator.sh list; else bash scripts/layout_calculator.sh show "$(TEMPLATE)"; fi

identify:
	bash scripts/window_manager.sh identify

launch-perf:
	DXVK_HUD=fps,frametimes,devinfo,gpuload,compiler bash scripts/start_eq.sh

launch-safe:
	DXVK_HUD=fps,devinfo DXVK_LOG_LEVEL=info bash scripts/start_eq.sh

PROFILE ?=
profile-save:
	@if [ -z "$(PROFILE)" ]; then echo "Usage: make profile-save PROFILE=my-layout"; exit 1; fi
	bash scripts/layout_profiles.sh save "$(PROFILE)"

profile-load:
	@if [ -z "$(PROFILE)" ]; then bash scripts/layout_profiles.sh list; exit 1; fi
	bash scripts/layout_profiles.sh load "$(PROFILE)"

profile-list:
	bash scripts/layout_profiles.sh list

# ─── Help ─────────────────────────────────────────────────────────────────────

help:               ## Show available commands
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-18s\033[0m %s\n", $$1, $$2}'
	@printf '\n\033[2mDev targets (not shown): typecheck, lint, test, docs, stats, format\033[0m\n'
	@printf '\033[2mDry-run variants: prereqs-dry, deploy-dry, configure-dry, fix-dry\033[0m\n'

.DEFAULT_GOAL := help
