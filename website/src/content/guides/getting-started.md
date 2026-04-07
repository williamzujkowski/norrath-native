---
title: "Getting Started"
description: "Quick start guide for norrath-native"
---

# Getting Started

## One-Command Setup

```bash
git clone https://github.com/williamzujkowski/norrath-native.git
cd norrath-native
make prereqs       # Installs Wine 11, Vulkan drivers, NTSYNC
make install       # Installs Node.js/pnpm dependencies
make deploy        # Creates Wine prefix, installs DXVK + EQ + maps
make doctor        # Verify installation
make launch        # Launch EverQuest
```

## Multiboxing (3 Characters)

```bash
make launch-multi  # Launches 3 instances with stagger delay
make tile-set-main # Identify which window is your main character
make fix           # Tiles windows (main gets 16:9, boxes stacked right)
```

## After Dock/Undock

```bash
make fix           # Re-tiles for new monitor, applies all settings
make status        # Diagnostic dashboard
```

## EQLogParser (DPS + Triggers)

```bash
make parser        # Auto-installs .NET 8 + EQLogParser + icon
```

First launch:

1. File → Open → `C:\EverQuest\Logs\`
2. Select your main character's log file
3. Settings → Triggers → enable "Use Piper TTS"

## Useful Commands

| Command               | What it does                             |
| --------------------- | ---------------------------------------- |
| `make fix`            | Fix everything (display, tiling, config) |
| `make tile`           | Re-tile windows                          |
| `make focus-next`     | Cycle focus between EQ windows           |
| `make doctor`         | Health check (30 checks)                 |
| `make status`         | Diagnostic dashboard                     |
| `make windows`        | List EQ windows                          |
| `make configure`      | Apply/update eqclient.ini                |
| `make colors`         | Apply chat color scheme                  |
| `make maps`           | Install/update Good's maps               |
| `make support-bundle` | Generate troubleshooting bundle          |
