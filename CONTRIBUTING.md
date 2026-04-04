# Contributing to Norrath-Native

Thank you for your interest in contributing.

## Development Setup

```bash
git clone https://github.com/williamzujkowski/norrath-native.git
cd norrath-native
pnpm install
```

## Quality Gates

All contributions must pass these checks before merge:

```bash
pnpm typecheck           # TypeScript strict mode — zero errors
pnpm lint                # ESLint — complexity < 10, functions < 50 lines
pnpm run test:run        # Vitest — all tests pass
shellcheck scripts/*.sh  # ShellCheck — bash static analysis
```

## Development Workflow

1. Fork the repository
2. Create a feature branch (`git checkout -b feat/my-feature`)
3. Write tests first (TDD required for all TypeScript code)
4. Implement the feature
5. Ensure all quality gates pass
6. Commit with conventional commits (`feat:`, `fix:`, `docs:`, `chore:`)
7. Open a pull request

## Constraints

- No third-party game tools, memory injectors, bots, or plugins
- All scripts must be idempotent (safe to run multiple times)
- All TypeScript code must use `Result<T, E>` for fallible operations
- No `any` types — use `unknown` with type guards
- Dependencies must be pinned to LTS versions

## Reporting Issues

Use GitHub Issues with clear reproduction steps. Include your Ubuntu version, Wine version, and GPU model for environment-related bugs.
