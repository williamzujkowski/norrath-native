---
title: "Command Reference"
description: "All available make targets"
---

# Command Reference

_Auto-generated from `make help` output._

| Command                 | Description                                                     |
| ----------------------- | --------------------------------------------------------------- |
| `make prereqs`          | Install system prerequisites (Wine, Vulkan, etc.)               |
| `make install`          | Install pnpm dependencies                                       |
| `make build`            | Compile TypeScript and Wine helper                              |
| `make deploy`           | Full deployment (prefix + DXVK + EQ install + config)           |
| `make launch`           | Launch a single EverQuest instance                              |
| `make launch-multi`     | Launch multibox instances (default: 3)                          |
| `make fix`              | Fix everything — syncs display, tiles windows or applies config |
| `make tile`             | Tile windows — main character gets large window                 |
| `make tile-set-main`    | Identify which window is your main character                    |
| `make tile-grid`        | Equal grid tile (all windows same size)                         |
| `make pip`              | Picture-in-picture layout                                       |
| `make focus-next`       | Cycle focus to next EQ window                                   |
| `make windows`          | List all detected EQ windows                                    |
| `make configure`        | Apply optimized eqclient.ini settings                           |
| `make colors`           | Apply WCAG-compliant chat color scheme                          |
| `make layout`           | Apply 4-window chat layout (Social/Combat/Spam/Alerts)          |
| `make layout-apply`     | Apply a layout template (TEMPLATE=name)                         |
| `make layout-templates` | List available layout templates                                 |
| `make maps`             | Install Good's maps (auto-download, or FILE=path/to/custom.zip) |
| `make parser`           | Install EQLogParser DPS meter (auto-download from GitHub)       |
| `make doctor`           | Health check — validate entire installation                     |
| `make status`           | Show diagnostic dashboard (monitor, windows, config)            |
| `make support-bundle`   | Generate a support bundle for troubleshooting                   |
| `make logs`             | Tail all EQ instance logs                                       |
| `make backup-session`   | Back up launcher login session                                  |
| `make restore-session`  | Restore launcher session from backup                            |
| `make clean`            | Remove build artifacts and coverage                             |
| `make purge`            | Remove Wine prefix and all EQ data (DESTRUCTIVE)                |
| `make help`             | Show available commands                                         |
| `make Dev`              | targets (not shown): typecheck, lint, test, docs, stats, format |
| `make Dry-run`          | variants: prereqs-dry, deploy-dry, configure-dry, fix-dry       |

## Development Targets (hidden from help)

| Command          | Description                     |
| ---------------- | ------------------------------- |
| `make typecheck` | TypeScript strict type checking |
| `make lint`      | ESLint with project rules       |
| `make test`      | Run Vitest test suite           |
| `make format`    | Prettier formatting             |
| `make docs`      | Generate API docs               |
| `make stats`     | Project statistics              |
