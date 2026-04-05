# Norrath-Native — Agent Operational Context

**Project:** Deterministic EverQuest deployment toolkit for Ubuntu 24.04 LTS
**Stack:** TypeScript (config orchestrator) + Bash (system scripts) + Wine/DXVK

## Quick Reference

```bash
pnpm install          # Install dependencies
pnpm typecheck        # TypeScript strict check
pnpm lint             # ESLint (complexity<10, fn<50 lines)
pnpm test run         # Run tests
make deploy           # Deploy Wine/DXVK environment
make launch           # Launch single EQ instance
make launch-multi     # Launch 3 instances (multibox)
```

## Architecture

- `src/types/interfaces.ts` — Contract definitions (IWineEnvironment, IClientConfig, ILaunchOptions)
- `src/config-injector.ts` — INI file manager (idempotent, path-safe)
- `src/dxvk-resolver.ts` — GitHub API DXVK release fetcher
- `scripts/deploy_eq_env.sh` — Idempotent environment bootstrap (Wine prefix, DXVK, registry tuning)
- `scripts/start_eq.sh` — Launch wrapper (multibox, graceful shutdown)

## Key Constraints

1. No host execution — generates IaC scripts only
2. Strict TDD — tests before implementation
3. No third-party game tools (MacroQuest, etc.) — vanilla only
4. Idempotent — safe to run multiple times
5. Pinned dependencies — no floating `latest`

## Quality Gates

- `pnpm typecheck` — zero errors
- `pnpm lint` — max 400 lines/file, 50 lines/fn, complexity < 10
- `pnpm test run` — all tests pass, >= 80% coverage on critical paths
- `shellcheck scripts/*.sh` — all bash scripts pass
