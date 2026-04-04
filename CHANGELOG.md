# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
## [2.0.0] - 2026-04-04

### Added

- **State manifest** — deploy records wine_version, dxvk_version, timestamps to state.json
- **Doctor JSON output** — `make doctor --json` for machine-readable diagnostics
- **23 structured health checks** with stable IDs (SYS_WINE, DXVK_*, EQ_*, etc.)
- **Support bundle** — `make support-bundle` generates tarball with doctor + logs
- **35 new tests** for dxvk-resolver.ts (total: 49 tests)
- **TypeDoc** API reference generation at docs/api/
- **Auto-generated docs** — command reference, check reference from source
- **Project-level config** — norrath-native.yaml with 4 performance profiles
- **Dry-run on launch** — `make launch --dry-run` previews without starting Wine

### Fixed

- Resolution drift: launch now uses configured resolution (was hardcoded 1920x1080)
- Doctor reads prefix from config (was hardcoded ~/.wine-eq)
- Consistent -h/--help across all scripts
- Portable DXVK URL parsing (removed Perl regex dependency)
- Atomic downloads prevent corruption on interrupt
- SIGKILL escalation on shutdown timeout
- Case-sensitive LaunchPad.exe filename

### Changed

- MANAGED_INI_SETTINGS in TS marked as reference (canonical source: configure_eq.sh)
- dxvk-resolver.ts documented as reference implementation
- ESLint rules relaxed for test files (long describe blocks)
- CI adds TypeDoc build verification


## [1.2.0] - 2026-04-04

### Added

- `scripts/doctor.sh` — 18-point health check validating all components
- `scripts/configure_eq.sh` — standalone INI settings manager
- `make doctor` — run health check
- `make configure` / `make configure-dry` — manage eqclient.ini
- `make purge` — remove Wine prefix with confirmation prompt
- E2E verified launcher screenshot in docs/
- Comprehensive README with architecture decisions, troubleshooting, verified hardware

### Fixed

- Atomic downloads (DXVK tarball + EQ installer) prevent corruption on interrupt
- GitHub API rate limit detection with GITHUB_TOKEN suggestion
- SIGKILL escalation after 5-second SIGTERM timeout in graceful shutdown
- Missing arg validation on all flag-based CLI options
- Module-level cleanup trap (was function-scoped, leaked tmpdirs)
- Config injection wired into deploy flow (was never called)

### Changed

- Deploy script now runs configure_eq.sh automatically after EQ installation
- Improved final deploy message with next-step guidance

## [1.1.0] - 2026-04-04

### Added

- `scripts/install_prerequisites.sh` — automated system dependency installer
- `make prereqs` / `make prereqs-dry` — prerequisite installation targets
- Automated EverQuest silent installation in deploy script
- `winbind` added to prerequisites (fixes NTLM authentication warnings)

### Fixed

- DXVK x32 DLLs now installed to syswow64 (LaunchPad.exe is 32-bit PE32)
- Wine binary detection (Ubuntu 24.04 uses `wine` not `wine64`)
- tmpdir cleanup trap scope (unbound variable on exit)
- CI workflow: `pnpm run test:run` (was `pnpm test run --coverage`)
- `@types/node@22` added for CI type declarations

### Verified

- E2E tested on Intel Iris Xe / Ubuntu 24.04 LTS
- Daybreak Launcher renders correctly (not black box)
- DXVK v2.7.1 initializes on Vulkan 1.4.318

## [1.0.0] - 2026-04-04

### Added

- TypeScript configuration orchestrator with strict type safety
- INI config injector with idempotent updates, path traversal protection, and 14 tests
- DXVK resolver fetching latest stable release from GitHub API
- `deploy_eq_env.sh` — idempotent Wine prefix setup with DXVK and virtual desktop
- `start_eq.sh` — multi-instance launcher with graceful shutdown
- `--dry-run` support for deployment preview without side effects
- Makefile with unified `deploy`, `launch`, `launch-multi` targets
- GitHub Actions CI with TypeScript, ESLint, Vitest, and ShellCheck
- Comprehensive README with architecture decisions and troubleshooting
