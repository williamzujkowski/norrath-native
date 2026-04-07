# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2026-04-06

Major stability release. Native XWayland windows, Wine 11, comprehensive testing.

### Breaking Changes

- Removed Wine virtual desktop — EQ runs as native XWayland windows
- Removed xdotool dependency — Wine API for all window management
- Removed `make adapt`, `make setup-all` — use `make fix` instead

### Added

- `make fix` — one command to sync display, tile windows, apply config
- `make status` — diagnostic dashboard (monitor, windows, config)
- `make tile-set-main` — identify main character window
- `make parser` — auto-installs .NET 8 + EQLogParser with icon
- `make maps` — auto-downloads Good's maps from GitHub (2186 files)
- Wine 11 upgrade via WineHQ repo (WPF support, unified binary)
- NTSYNC kernel module for Wine performance
- Separate Wine prefix for EQLogParser (focus/minimize fixes)
- Desktop shortcuts with proper icons, pinned to GNOME taskbar
- DWM composition disable (prevents WPF minimize crash)
- Workarea-aware sizing (accounts for GNOME panels and title bar)
- Self-documenting metadata system with CI stats verification
- HH:MM:SS timestamps on all chat windows by default
- 47 managed eqclient.ini settings (was 43, added resolution)
- INI key deduplication prevents setting accumulation
- Read-only eqclient.ini after configure (multibox exit race fix)
- 211 tests (was 165), including integration test suite
- Comprehensive docs: getting-started, multiboxing, chat-setup,
  eqlogparser-setup, troubleshooting, UI architecture

### Fixed

- First-process X11 stacking bug (window unclickable after focus loss)
- Keyboard focus going to terminal instead of EQ window
- Wine desktop frame intercepting clicks near origin
- EQLogParser crash on minimize (DWM composition)
- .NET 8 download URL (was broken 400)
- Wine Mono interactive dialog during parser install
- GNOME "not responding" dialog (60s timeout workaround)
- Doctor checks synced between bash and TypeScript
- Ultrawide resolution logic deduplicated (bash delegates to TypeScript)

### Removed

- Wine virtual desktop (caused unfixable X11 stacking bugs)
- xdotool (corrupted Wine's internal input routing)
- Managed=N and Decorated=N registry settings (prevented focus)
- adapt_display.sh (replaced by make fix)
- wine_resize.c/exe (replaced by wine_helper.exe)
- Brewall maps (replaced by Good's maps)

## [0.1.0] - 2026-04-04

Initial pre-release.

### Core

- Deterministic Wine prefix + DXVK deployment (idempotent, --dry-run)
- EverQuest silent installer integration
- 47 managed eqclient.ini settings across 5 profiles (high/balanced/raid/low/minimal)
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

- 29 structured doctor health checks with JSON output
- Support bundle generation
- Wine API helper (list/find/map/resize/tile/focus/save)
- Session backup/restore
- EQLogParser installation support
- Good's map pack auto-installation from GitHub

### Developer Experience

- TypeScript-first architecture with full test coverage
- Pre-commit hooks (husky + lint-staged)
- CI: typecheck + build + lint + format + test + TypeDoc + ShellCheck + stats verification
- OpenSSF Scorecard workflow
- Dependabot for dependency updates
- CODING_STANDARDS.md compliance (ES2024, noUncheckedIndexedAccess)
