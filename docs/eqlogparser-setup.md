---
title: EQLogParser Setup
description: DPS meter and GINA-compatible trigger system for EQ on Linux
source: scripts/install_parser.sh, scripts/install_shortcuts.sh
updated: auto-generated
---

# EQLogParser Setup

EQLogParser is a .NET 8 WPF application for DPS parsing and audio triggers.
It runs in its own Wine prefix (`~/.wine-eqlogparser`) to avoid conflicts
with EQ's window management settings.

## Installation

```bash
make parser
```

This automatically:

1. Creates a dedicated Wine prefix (`~/.wine-eqlogparser`)
2. Installs Wine Mono (.NET support)
3. Installs .NET 8 Desktop Runtime
4. Installs core fonts (prevents WPF rendering crash)
5. Disables DWM composition (prevents minimize crash)
6. Downloads latest EQLogParser from GitHub (PiperTTS variant)
7. Silently installs via Inno Setup
8. Symlinks EQ directory for log access
9. Extracts icon from .exe and pins to taskbar

## First Launch

1. Click the EQLogParser icon in your taskbar (bar chart icon)
2. File → Open → navigate to `C:\EverQuest\Logs\`
3. Select your main character's log: `eqlog_YourCharacter_server.txt`
4. Settings → Triggers → enable **"Use Piper TTS"** (Windows TTS unavailable under Wine)

## Log File Location

EQ logs are at:

- **Linux path:** `~/.wine-eq/drive_c/EverQuest/Logs/`
- **Wine path (in EQLogParser):** `C:\EverQuest\Logs\`

The parser prefix has a symlink to the EQ prefix's game files, so
`C:\EverQuest\` in EQLogParser points to the actual EQ install.

## GINA Compatibility

EQLogParser can import GINA trigger packages (`.gtp` files):

- Settings → Triggers → Import
- Select your `.gtp` file
- Triggers will fire with PiperTTS audio alerts

## Troubleshooting

### Parser won't launch

Check if .NET 8 is installed:

```bash
WINEPREFIX=~/.wine-eqlogparser wine dotnet --list-runtimes
```

Should show `Microsoft.WindowsDesktop.App 8.x.x`.

### Crash on minimize

DWM composition should be disabled. Verify:

```bash
grep DisableComposition ~/.wine-eqlogparser/user.reg
```

Should show `"DisableComposition"="Y"`.

### Can't find logs

Verify the symlink exists:

```bash
ls -la ~/.wine-eqlogparser/drive_c/EverQuest
```

Should be a symlink to `~/.wine-eq/drive_c/EverQuest`.

### Reinstall

```bash
make parser PARSER_FILE=  # uses --update flag
# or manually:
rm -rf ~/.wine-eqlogparser
make parser
```
