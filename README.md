# Norrath-Native

A deterministic, idempotent deployment toolkit to run EverQuest natively on Ubuntu 24.04 LTS via Wine and DXVK. One command to deploy, one command to launch.

EverQuest's recent upgrade to DirectX 11 introduced several pain points on Linux: aggressive focus stealing, a broken launcher (black box rendering), and CPU thrashing when multiboxing. Norrath-Native solves all three with an Infrastructure-as-Code approach that creates an isolated Wine prefix with DXVK, a virtual desktop, and tuned client settings.

## Prerequisites

| Requirement | Minimum Version | Notes |
|---|---|---|
| Ubuntu | 24.04 LTS | Target platform |
| Wine | 9.0 (stable) | 64-bit prefix |
| Vulkan drivers | mesa-vulkan-drivers | GPU must support Vulkan |
| Node.js | 22.x LTS | TypeScript config tooling |
| pnpm | 9.x | Package manager |

Your GPU must support Vulkan. Verify with `vulkaninfo | grep deviceName`.

## Quick Start

```bash
git clone https://github.com/williamzujkowski/norrath-native.git
cd norrath-native
make install
make deploy        # Creates Wine prefix, installs DXVK, configures virtual desktop
make launch        # Launches EverQuest
```

For a dry run that shows what the deploy script will do without touching your system:

```bash
make deploy-dry
```

## Architecture Decisions

### Why Virtual Desktop?

EverQuest aggressively steals mouse and keyboard focus, making it impossible to use your Linux desktop while the game runs. Wine's virtual desktop traps the game inside a managed window, preventing focus theft on both X11 and Wayland compositors. The resolution is configurable (default: 1920x1080).

### Why `--disable-gpu` on the Launcher?

The Daybreak Launchpad uses an embedded Chromium browser. On Linux, this Chromium instance fails to render properly, appearing as a solid black box. The `--disable-gpu` flag forces software rendering for the launcher only (not the game itself), solving the black box issue. DXVK still handles all in-game DirectX 11 rendering via Vulkan.

### Why Are CPU Cores Unassigned (`ClientCore=-1`)?

Setting `ClientCore0` through `ClientCore11` to `-1` tells the game to let the operating system manage CPU affinity. The Linux kernel's CFS scheduler is far better at distributing game threads across cores than EverQuest's hardcoded core pinning, which causes threads to fight when multiboxing. This is especially important on laptops where thermal throttling requires dynamic scheduling.

### Why X11 by Default?

Wine's Wayland driver is experimental and may introduce input lag or rendering artifacts with DXVK. X11 via XWayland is the stable, tested path. If you want to try Wayland:

```bash
NORRATH_WAYLAND=1 make launch
```

### Why DXVK?

EverQuest uses DirectX 11. DXVK translates DX11 calls to Vulkan, which runs natively on Linux GPUs. This gives near-native performance without the overhead of Wine's built-in D3D translation layer.

## Multiboxing

Launch multiple instances with staggered startup to avoid GPU initialization races:

```bash
make launch-multi                          # 3 instances, 5s stagger (default)
bash scripts/start_eq.sh --instances 4     # 4 instances
bash scripts/start_eq.sh --instances 2 --stagger-delay 10  # 2 instances, 10s delay
```

Each instance gets its own log file at `~/.local/share/norrath-native/eq-instance-N.log`.

Press Ctrl+C to gracefully shut down all instances.

## Configuration

The deployment creates an `eqclient.ini` with optimized settings for Linux multiboxing:

| Setting | Value | Rationale |
|---|---|---|
| `WindowedMode` | `TRUE` | Required for virtual desktop |
| `UpdateInBackground` | `1` | Keeps unfocused clients responsive |
| `MaxBGFPS` | `30` | Reduces CPU/GPU load on background clients |
| `ClientCore0-11` | `-1` | Lets Linux scheduler manage CPU affinity |

The config injector is idempotent: it updates managed keys without touching your custom settings (UI layout, keybinds, etc.).

## Troubleshooting

### "Missing wine64" Error

Install Wine from the WineHQ repository:

```bash
sudo dpkg --add-architecture i386
sudo apt update
sudo apt install wine64 wine32
```

### Launcher Shows a Black Box

The deploy script applies the `--disable-gpu` flag automatically. If you still see a black box, verify the launch command includes it:

```bash
wine64 Launchpad.exe --disable-gpu
```

### DXVK Version Mismatch / Vulkan Errors

Verify your GPU supports Vulkan:

```bash
vulkaninfo | grep deviceName
```

If no device is listed, install Vulkan drivers:

```bash
sudo apt install mesa-vulkan-drivers libvulkan1 vulkan-tools
```

### Game Crashes on Launch

Check the per-instance log:

```bash
cat ~/.local/share/norrath-native/eq-instance-1.log
```

Common causes: outdated Wine (need 9.0+), missing 32-bit Vulkan drivers (`mesa-vulkan-drivers:i386`).

## Project Structure

```
norrath-native/
  scripts/
    deploy_eq_env.sh        # Wine prefix + DXVK setup (idempotent)
    start_eq.sh             # Launch wrapper (multibox support)
  src/
    config-injector.ts      # INI file manager (idempotent, path-safe)
    dxvk-resolver.ts        # GitHub API DXVK release fetcher
    types/
      interfaces.ts         # TypeScript contract definitions
  tests/
    config-injector.test.ts # 14 tests covering all critical paths
  Makefile                  # Unified task runner
```

## Development

```bash
pnpm install               # Install dependencies
pnpm typecheck             # TypeScript strict mode
pnpm lint                  # ESLint (complexity < 10, functions < 50 lines)
pnpm test run              # Run test suite
pnpm test run --coverage   # Coverage report
```

CI runs on every push: TypeScript check, ESLint, Vitest, and ShellCheck for bash scripts.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Write tests first (TDD required)
4. Ensure all quality gates pass: `make typecheck && make lint && make test`
5. Open a pull request

This project does not include, reference, or support any third-party memory injectors, bots, or automation tools. Vanilla EverQuest only.

## License

MIT
