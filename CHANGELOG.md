# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-04-04

Initial pre-release. Full-featured but actively evolving.

### Core

- Deterministic Wine prefix + DXVK deployment (idempotent, --dry-run)
- EverQuest silent installer integration
- 43 managed eqclient.ini settings across 5 profiles (high/balanced/raid/low/minimal)
- dxvk.conf with async shaders and frame latency tuning
- Wine registry tuning (GrabFullscreen, VideoMemorySize, MouseWarpOverride)
- Microsoft corefonts via winetricks

### Multiboxing

- Multi-instance launch with stagger delay and nice/ionice priority
- Smart window tiling via Wine SetWindowPos API (triggers EQ re-render)
- Character identification via HWND→X11 WID→PID→login timestamp correlation
- Config-driven main character assignment
- Layout templates (bard-pull, raid-solo, standard-solo, standard-multi)

### Display & Resolution

- Auto-detect primary monitor resolution via xrandr
- Ultrawide (21:9) → 16:9 clamping with viewport centering
- Live display adaptation (make adapt) for dock/undock switching
- XWayland coordinate doubling compensation

### UI & Colors

- 91-color WCAG AA-compliant chat color scheme
- 4-window chat layout (Social/Combat/Spam/Alerts) with 107-channel routing
- Per-character UI position management

### Raid Optimizations

- Raid profile: spell effects off, server filter on, lit batches off
- LogInterval=1 (throttled writes, per April 2024 patch)
- Process priority: main=normal, boxes=nice -n 10 + ionice
- DXVK HUD diagnostics (make launch-perf)

### Tools & Diagnostics

- 30+ structured doctor health checks with JSON output
- Support bundle generation
- Wine API helper (list/find/map/resize/tile/focus/save)
- Session backup/restore
- EQLogParser installation support
- Brewall map pack installation

### Developer Experience

- TypeScript-first architecture (2100 lines src, 1750 lines tests)
- 165 tests across 8 files
- Pre-commit hooks (husky + lint-staged)
- CI: typecheck + build + lint + test + TypeDoc + ShellCheck
- OpenSSF Scorecard workflow
- Dependabot for dependency updates
- CODING_STANDARDS.md compliance (ES2024, noUncheckedIndexedAccess)
