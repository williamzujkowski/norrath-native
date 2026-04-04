# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
