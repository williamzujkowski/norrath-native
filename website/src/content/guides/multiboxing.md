---
title: "Multiboxing Guide"
description: "Running multiple EQ instances with window tiling"
---

# Multiboxing Guide

## Launch

```bash
make launch-multi  # Launches 3 instances (configurable in norrath-native.yaml)
```

Each instance gets:

- Staggered startup (5s default) to avoid GPU initialization races
- Background priority for box characters (nice -n 10 + ionice)
- Separate log file (`~/.local/share/norrath-native/eq-instance-N.log`)

## Window Tiling

```bash
make fix           # Syncs display + tiles windows
make tile          # Re-tile only (main gets large window)
make tile-grid     # Equal grid (all same size)
make pip           # Picture-in-picture layout
```

### Ultrawide Support

On ultrawide monitors (21:9), the main window is clamped to 16:9
(2560x1440 on a 3440x1440 display). Box windows get the remaining space.

### Setting Your Main Character

The first time you tile, you need to tell norrath-native which window
is your main character:

```bash
make tile-set-main
```

This flashes each window and asks you to pick a number. The mapping
is saved to `~/.local/share/norrath-native/hwnd-character-map` and
persists across sessions.

Or set it in `norrath-native.yaml`:

```yaml
main_character: Grenlan
```

## Focus Cycling

```bash
make focus-next    # Cycle focus to the next EQ window
```

Uses Wine's `SetForegroundWindow` API for reliable focus switching.

## Architecture

Each EQ instance runs as a native XWayland top-level window (no Wine
virtual desktop). This provides:

- Native GNOME/Mutter click-to-focus
- Proper window decorations
- Normal alt-tab behavior
- No X11 stacking bugs

Window tiling uses `wine_helper.exe` (MinGW-compiled C program) which
calls Win32 APIs (`EnumWindows`, `SetWindowPos`, `SetForegroundWindow`)
through Wine. This is more reliable than X11 tools (xdotool was removed
after causing Wine focus routing corruption).

## Configuration

```yaml
# norrath-native.yaml
instances: 1 # Single launch count
multibox_instances: 3 # make launch-multi count
stagger_delay: 5 # Seconds between instance launches
main_character: Grenlan # Gets the large window
profile: raid # Performance profile for boxes
```

## Troubleshooting

### Windows not tiling

```bash
make status        # Check window detection
make windows       # List detected EQ windows
```

### eqclient.ini overwritten on exit

Settings are protected: `make configure` sets eqclient.ini to read-only
(444) after applying settings, preventing the multibox exit race condition.

### Performance

```bash
make doctor        # Check NTSYNC status (kernel-level Wine perf)
```

NTSYNC (kernel 6.14+) significantly reduces CPU overhead when running
multiple Wine instances. Enabled by `make prereqs`.
