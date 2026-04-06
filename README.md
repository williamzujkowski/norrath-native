# Norrath-Native

[![CI](https://github.com/williamzujkowski/norrath-native/actions/workflows/ci.yml/badge.svg)](https://github.com/williamzujkowski/norrath-native/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Node.js](https://img.shields.io/badge/node-%3E%3D22-brightgreen)](https://nodejs.org/)
[![OpenSSF Scorecard](https://api.securityscorecards.dev/projects/github.com/williamzujkowski/norrath-native/badge)](https://securityscorecards.dev/viewer/?uri=github.com/williamzujkowski/norrath-native)

A deterministic, idempotent deployment toolkit to run EverQuest natively on Ubuntu 24.04 LTS via Wine and DXVK. One command to deploy, one command to launch.

EverQuest's recent upgrade to DirectX 11 introduced several pain points on Linux: aggressive focus stealing, a broken launcher (black box rendering), and CPU thrashing when multiboxing. Norrath-Native solves all three with an Infrastructure-as-Code approach that creates an isolated Wine prefix with DXVK and tuned client settings. Each EQ instance runs as a native XWayland window with full click-to-focus support.

![EverQuest multibox layout on Ubuntu 24.04](docs/multibox-screenshot.png)

_Three EQ instances tiled on an ultrawide monitor — Grenlan (main, 16:9) with two box characters stacked right._

## Prerequisites

| Requirement    | Minimum Version      | Notes                                             |
| -------------- | -------------------- | ------------------------------------------------- |
| Ubuntu         | 24.04 LTS            | Target platform (Mint, Pop!\_OS also work)        |
| Wine           | 11.0 (WineHQ stable) | Auto-installed from WineHQ repo by `make prereqs` |
| Vulkan drivers | mesa-vulkan-drivers  | GPU must support Vulkan (Intel, AMD, NVIDIA)      |
| Node.js        | 22.x LTS             | TypeScript config tooling                         |
| pnpm           | 10.x                 | Package manager                                   |

Don't worry about installing these manually — `make prereqs` handles everything.

## Quick Start

```bash
git clone https://github.com/williamzujkowski/norrath-native.git
cd norrath-native
make prereqs       # Installs Wine, Vulkan drivers, winbind, etc. (needs sudo)
make install       # Installs Node.js/pnpm dev dependencies
make deploy        # Creates Wine prefix, installs DXVK + EverQuest, configures everything
make doctor        # Verify installation (should show all green)
make launch        # Launch EverQuest
```

Preview what each step will do without making changes:

```bash
make prereqs-dry   # Show what system packages would be installed
make deploy-dry    # Show what Wine prefix changes would be made
make configure-dry # Show what INI settings would be applied
```

## First Launch

The first launch requires a few extra steps. Subsequent launches skip straight to the game.

### 1. Launch and Log In

```bash
make launch        # Launch EverQuest
```

Log in with your Daybreak account. You can type your credentials directly into the launcher, or copy/paste them — right-click the password field and select "Paste" from the context menu.

Check **"Remember me on this computer"** to skip the login screen on future launches. This stores a session token that lasts about a year.

### 2. Accept the EULA

On first login, you'll be presented with the End User License Agreement. Accept it to proceed.

### 3. Wait for Patches

The launcher will download the full game client (~15-20 GB). This takes a while depending on your internet connection. The progress bar shows download status.

**Patches persist across restarts.** The game files are stored at `~/.wine-eq/drive_c/EverQuest/` on your actual filesystem, not in memory. You can:

- Close and reopen the launcher — patching resumes where it left off
- Reboot your machine — all downloaded data is preserved
- Run `make launch` again — the patcher only downloads what's missing

### 4. Play

Once patching completes, click "Play" to launch the game. Subsequent `make launch` commands skip the patching step and go straight to the login/play screen.

## What `make deploy` Does

The deployment is fully automated and idempotent (safe to run multiple times):

1. **Validates system dependencies** — checks for Wine, Vulkan, wget, tar
2. **Creates a 64-bit Wine prefix** at `~/.wine-eq` (skips if exists)
3. **Downloads DXVK** from GitHub (latest stable, currently v2.7.1)
4. **Installs DXVK DLLs** — both x64 (system32) and x32 (syswow64) for launcher compatibility
5. **Configures DLL overrides** — d3d11 and dxgi set to native
6. **Tunes Wine registry** — disables WM decorations, configures mouse capture, focus handling
7. **Downloads and installs EverQuest** — silent install via Daybreak installer
8. **Applies optimized INI settings** — WindowedMode, background FPS cap, CPU affinity

## Available Commands

```
make prereqs       Install system prerequisites (Wine, Vulkan, etc.)
make install       Install pnpm dependencies
make deploy        Full deployment (prefix + DXVK + EQ install + config)
make configure     Apply/update eqclient.ini settings
make doctor        Health check — validate entire installation
make launch        Launch a single EverQuest instance
make launch-multi  Launch 3 EverQuest instances (multibox)
make backup-session  Back up login session for disaster recovery
make restore-session Restore login session from backup
make purge         Remove Wine prefix and all EQ data (DESTRUCTIVE)
make help          Show all available commands
```

## Architecture Decisions

### Why Native Windows Instead of Wine Virtual Desktop?

Each EQ instance runs as its own top-level XWayland window. This gives native click-to-focus from your window manager (GNOME, KDE, etc.) without Wine's virtual desktop X11 stacking bugs that prevented click-to-focus on the first-launched process. Wine's `GrabFullscreen=Y` registry setting prevents EQ's aggressive focus-stealing without needing a virtual desktop container.

### Why `--disable-gpu` on the Launcher?

The Daybreak Launchpad uses an embedded Chromium browser (CEF). On Linux, this Chromium instance fails to render properly, appearing as a solid black box. The `--disable-gpu` flag forces software rendering for the launcher only (not the game itself). DXVK still handles all in-game DirectX 11 rendering via Vulkan.

### Why Both x32 and x64 DXVK DLLs?

The EverQuest game client is 64-bit, but `LaunchPad.exe` and its CEF (Chromium) library are 32-bit (PE32). Without 32-bit DXVK DLLs in `syswow64`, the launcher crashes immediately with `import_dll: Library dxgi.dll not found`.

### Why Are CPU Cores Unassigned (`ClientCore=-1`)?

Setting `ClientCore0` through `ClientCore11` to `-1` tells the game to let the operating system manage CPU affinity. The Linux kernel's CFS scheduler is far better at distributing game threads across cores than EverQuest's hardcoded core pinning, which causes threads to fight when multiboxing.

### Why X11 by Default?

Wine's Wayland driver is experimental and may introduce input lag or rendering artifacts with DXVK. X11 via XWayland is the stable, tested path. To try Wayland:

```bash
NORRATH_WAYLAND=1 make launch
# or
bash scripts/start_eq.sh --wayland
```

### Why DXVK?

EverQuest uses DirectX 11. DXVK translates DX11 calls to Vulkan, which runs natively on Linux GPUs. This gives near-native performance without the overhead of Wine's built-in D3D translation layer.

## Multiboxing

Launch multiple instances with staggered startup to avoid GPU initialization races:

```bash
make launch-multi                                     # 3 instances, 5s stagger
bash scripts/start_eq.sh --instances 4                # 4 instances
bash scripts/start_eq.sh --instances 2 --stagger-delay 10  # Custom delay
```

Each instance gets its own log file at `~/.local/share/norrath-native/eq-instance-N.log`.

Press Ctrl+C to gracefully shut down all instances (SIGTERM with 5-second SIGKILL escalation).

## Configuration

The deployment applies optimized `eqclient.ini` settings for Linux multiboxing:

| Setting              | Value  | Rationale                                  |
| -------------------- | ------ | ------------------------------------------ |
| `WindowedMode`       | `TRUE` | Required for windowed mode under Wine      |
| `UpdateInBackground` | `1`    | Keeps unfocused clients responsive         |
| `MaxBGFPS`           | `30`   | Reduces CPU/GPU load on background clients |
| `ClientCore0-11`     | `-1`   | Lets Linux scheduler manage CPU affinity   |

The config injector is idempotent: it updates managed keys without touching your custom settings (UI layout, keybinds, macros, etc.). Re-run anytime:

```bash
make configure      # Apply/update managed settings
make configure-dry  # Preview changes
```

## Troubleshooting

Run the health check first — it catches most issues:

```bash
make doctor
```

### Launcher Shows a Black Box

This happens when CEF (Chromium) tries to use GPU rendering. The deploy script automatically applies `--disable-gpu`. If you still see it:

1. Verify DXVK x32 DLLs are installed: `make doctor` should show green checkmarks for syswow64
2. Try: `WINEPREFIX=~/.wine-eq wine LaunchPad.exe --disable-gpu`

### "Missing wine64" or "Wine not found"

```bash
make prereqs  # Installs Wine and all dependencies
```

On Ubuntu 24.04, Wine installs as `wine` (not `wine64`). The scripts detect both names automatically.

### Vulkan Errors or DXVK Initialization Failed

```bash
vulkaninfo | grep deviceName  # Should show your GPU
```

If no device is listed:

- **Intel:** `sudo apt install mesa-vulkan-drivers`
- **AMD:** `sudo apt install mesa-vulkan-drivers`
- **NVIDIA:** Install proprietary drivers with Vulkan support

For 32-bit support (required by launcher): `sudo apt install mesa-vulkan-drivers:i386`

### NTLM Authentication Warnings

Install winbind to eliminate these:

```bash
sudo apt install winbind
```

Or just run `make prereqs` which includes it.

### Game Crashes After Launcher

Check the per-instance log:

```bash
cat ~/.local/share/norrath-native/eq-instance-1.log
```

Common causes: outdated Wine (need 9.0+), missing 32-bit Vulkan drivers, insufficient GPU memory.

### GitHub API Rate Limit During Deploy

DXVK download uses the GitHub API. If rate-limited:

```bash
export GITHUB_TOKEN=ghp_your_token_here
make deploy
```

### Starting Fresh

```bash
make purge   # Removes ~/.wine-eq and all logs (asks for confirmation)
make deploy  # Rebuild from scratch
```

## Project Structure

<!-- Counts verified by: npx tsx scripts/generate-stats.ts -->

```
norrath-native/
  src/
    cli.ts               — Unified CLI entry point (21 commands)
    config.ts            — YAML config, 5 profiles, 43 managed settings
    colors.ts            — 91-color WCAG AA-compliant chat scheme
    layout.ts            — 107-channel → 4-window chat routing
    resolution.ts        — Ultrawide detection, 16:9 clamping, tiling
    doctor.ts            — 29 structured health checks (JSON output)
    config-injector.ts   — Idempotent INI file manipulation
    dxvk-resolver.ts     — GitHub API DXVK release resolver
    metadata.ts          — Programmatic project stats (self-documenting)
    types/interfaces.ts  — Core TypeScript contracts
  scripts/               — 21 bash scripts (thin system wrappers)
  tests/                 — 9 test files
  layouts/               — 4 window layout templates
  helpers/wine_helper.c  — Wine API helper (SetWindowPos, HWND mapping)
  Makefile               — 29 targets (make help)
```

## Verified Hardware

Tested and confirmed working on:

| Component | Details                          |
| --------- | -------------------------------- |
| CPU       | Intel Alder Lake-P (12th Gen)    |
| GPU       | Intel Iris Xe Graphics (ADL GT2) |
| OS        | Ubuntu 24.04 LTS (Noble Numbat)  |
| Display   | Wayland + XWayland               |
| Wine      | 9.0 (Ubuntu package)             |
| DXVK      | 2.7.1 (auto-downloaded)          |
| Vulkan    | 1.4.318 (Mesa 25.2.8)            |

## Development

```bash
pnpm install               # Install dependencies
pnpm typecheck             # TypeScript strict mode
pnpm lint                  # ESLint (complexity < 10, functions < 50 lines)
pnpm run test:run          # Run test suite
pnpm run test:run --coverage  # Coverage report
```

CI runs on every push: TypeScript check, ESLint, Vitest, and ShellCheck for bash scripts.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for full details. In short:

1. Fork the repository
2. Write tests first (TDD required)
3. Ensure all quality gates pass
4. Open a pull request

This project does not include, reference, or support any third-party memory injectors, bots, or automation tools. Vanilla EverQuest only.

## License

MIT — see [LICENSE](LICENSE)
