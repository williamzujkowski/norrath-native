# Norrath-Native — Agent Operational Context

**Project:** Deterministic EverQuest deployment toolkit for Ubuntu 24.04 LTS
**Stack:** TypeScript (all logic) + Bash (system interaction wrappers) + Wine/DXVK

## Architecture

TypeScript is the source of truth for all logic. Bash scripts are thin wrappers
for system interaction only (wine, apt, wmctrl, xdotool).

```
src/cli.ts             — Unified CLI entry point (node dist/cli.js <cmd>)
src/config.ts          — YAML config parsing, profiles, managed settings
src/colors.ts          — 91-color WCAG-compliant chat color scheme
src/layout.ts          — 107-channel chat window routing (4-window layout)
src/resolution.ts      — Ultrawide detection, 16:9 clamping, viewport, tiling
src/doctor.ts          — 29 structured health checks with JSON output
src/config-injector.ts — Idempotent INI file manipulation
src/dxvk-resolver.ts   — GitHub API DXVK release resolver
scripts/*.sh           — Thin bash wrappers (call cli_cmd for TS logic)
layouts/*.conf         — Percentage-based layout templates
```

## Quick Reference

```bash
pnpm install          # Install dependencies
pnpm build            # Compile TypeScript to dist/
pnpm typecheck        # Strict type checking
pnpm lint             # ESLint (complexity<10, fn<50 lines)
pnpm run test:run     # Run 165 tests
make deploy           # Deploy Wine/DXVK/EQ environment
make launch           # Launch EQ (single instance)
make launch-multi     # Launch multibox instances
make doctor           # 29-point health check
make setup-all        # Apply all customizations to all characters
```

## Key Constraints

1. **TypeScript for logic, bash for system interaction only**
2. **Strict TDD** — tests before implementation
3. **No third-party game tools** (MacroQuest, etc.) — vanilla EQ only
4. **Idempotent scripts** — safe to run multiple times
5. **EQ max aspect ratio is 16:9** — ultrawide must be clamped
6. **EQ overwrites UI INIs on camp** — changes require camping first
7. **Wine CEF ignores synthetic input** — no automated login via xdotool

## Canonical Paths

| Concern              | Path                                      |
| -------------------- | ----------------------------------------- |
| User config          | `norrath-native.yaml`                     |
| Config parsing       | `src/config.ts`                           |
| Managed INI settings | `src/config.ts:generateManagedSettings()` |
| Color scheme         | `src/colors.ts:COLOR_SCHEME`              |
| Channel routing      | `src/layout.ts:CHANNEL_MAP`               |
| Health checks        | `src/doctor.ts:buildDefaultChecks()`      |
| CLI entry point      | `src/cli.ts` → `dist/cli.js`              |
| Bash→TS bridge       | `scripts/config_reader.sh:cli_cmd()`      |
| Layout templates     | `layouts/*.conf`                          |
| Wine prefix          | `~/.wine-eq` (configurable)               |
| State/logs           | `~/.local/share/norrath-native/`          |
| Profiles             | `~/.local/share/norrath-native/profiles/` |
