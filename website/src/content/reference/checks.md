---
title: "Doctor Checks Reference"
description: "Health check descriptions and categories"
---

# Doctor Checks Reference

_Run `make doctor` to see current status. Use `--verbose` to show file paths and commands checked. Run `make doctor --json` for machine-readable output._

## System Dependencies

| Check        | Description                                |
| ------------ | ------------------------------------------ |
| `SYS_WINE`   | Wine installed (11.0+ recommended)         |
| `SYS_VULKAN` | Vulkan GPU drivers and vulkaninfo          |
| `SYS_NTSYNC` | NTSYNC kernel module (performance)         |
| `SYS_NTLM`   | winbind/ntlm_auth (prevents Wine warnings) |
| `SYS_NODE`   | Node.js 22.x LTS                           |

## Wine Prefix

| Check                  | Description                         |
| ---------------------- | ----------------------------------- |
| `PREFIX_EXISTS`        | WINEPREFIX directory exists         |
| `PREFIX_ARCH`          | Prefix is win64 architecture        |
| `PREFIX_COREFONTS`     | Microsoft core fonts installed      |
| `PREFIX_MOUSE_CAPTURE` | MouseWarpOverride=enable configured |

## DXVK (DirectX 11 → Vulkan)

| Check                 | Description                 |
| --------------------- | --------------------------- |
| `DXVK_SYS32_D3D11`    | d3d11.dll in system32 (x64) |
| `DXVK_WOW64_D3D11`    | d3d11.dll in syswow64 (x32) |
| `DXVK_SYS32_DXGI`     | dxgi.dll in system32 (x64)  |
| `DXVK_WOW64_DXGI`     | dxgi.dll in syswow64 (x32)  |
| `DXVK_OVERRIDE_D3D11` | DLL override: d3d11=native  |
| `DXVK_OVERRIDE_DXGI`  | DLL override: dxgi=native   |

## EverQuest Installation

| Check            | Description                                                      |
| ---------------- | ---------------------------------------------------------------- |
| `EQ_DIR`         | EverQuest directory exists                                       |
| `EQ_LAUNCHER`    | LaunchPad.exe present                                            |
| `EQ_INI`         | eqclient.ini exists                                              |
| `EQ_LOGGING`     | Logging enabled (Log=TRUE)                                       |
| `EQ_PATCHED`     | Game binary present (eqgame.exe)                                 |
| `EQ_REMEMBER_ME` | Remember Me cookie database                                      |
| `EQ_MAPS`        | Good's maps installed                                            |
| `EQ_DXVK_CONF`   | DXVK config (async shaders)                                      |
| `EQ_PATCH_STATE` | Detects if eqgame.exe changed since last deploy (run `make fix`) |
| `EQ_PARSER`      | EQLogParser installed                                            |

## Deploy State

| Check                | Description               |
| -------------------- | ------------------------- |
| `STATE_FILE`         | Deploy state file exists  |
| `STATE_DEPLOYED_AT`  | Deploy timestamp recorded |
| `STATE_WINE_VERSION` | Wine version recorded     |
| `STATE_DXVK_VERSION` | DXVK version recorded     |
| `LOG_DIR`            | Log directory exists      |
| `LOG_LAST_DEPLOY`    | Deploy log exists         |
