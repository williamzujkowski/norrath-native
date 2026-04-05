---
title: Documentation Index
description: All norrath-native documentation
updated: auto-generated
---

# norrath-native Documentation

## User Guides

| Guide                                     | Description                               |
| ----------------------------------------- | ----------------------------------------- |
| [Getting Started](getting-started.md)     | Quick start, installation, first launch   |
| [Multiboxing](multiboxing.md)             | Multiple instances, tiling, focus cycling |
| [EQLogParser Setup](eqlogparser-setup.md) | DPS meter, triggers, GINA compatibility   |
| [Troubleshooting](troubleshooting.md)     | Common issues and fixes                   |

## Reference

| Document                         | Description                           |
| -------------------------------- | ------------------------------------- |
| [Command Reference](commands.md) | All make targets and script usage     |
| [Doctor Checks](checks.md)       | Health check descriptions and status  |
| [Chat Layout](chat-layout.md)    | 4-window chat channel routing         |
| [API Reference](api/)            | TypeDoc-generated TypeScript API docs |

## Architecture

Each EQ instance runs as a native XWayland window. Window management
uses `wine_helper.exe` (MinGW-compiled Win32 API calls via Wine).
EQLogParser runs in its own isolated Wine prefix.

For more details, see [AGENTS.md](../AGENTS.md) and the source code.
