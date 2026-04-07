---
title: "Troubleshooting"
description: "Common issues and fixes for norrath-native"
---

# Troubleshooting

Run diagnostics first:

```bash
make doctor        # 30-point health check
make status        # Display/window dashboard
make support-bundle # Generate debug bundle for sharing
```

## Common Issues

### "not responding" dialog on zone load

GNOME shows this when EQ blocks its main thread during zone loads.
Workaround (applied automatically):

```bash
gsettings set org.gnome.mutter check-alive-timeout 60000
```

### Launcher shows black box

CEF (Chromium) needs software rendering. Applied automatically via
`--disable-gpu` flag. If it still happens:

```bash
WINEPREFIX=~/.wine-eq wine LaunchPad.exe --disable-gpu
```

### Can't click on a window after tiling

Run `make fix` to re-tile. If the issue persists, check `make status`
for window positions.

### Wrong character in main window

```bash
make tile-set-main  # Re-identify which window is your main
make fix            # Re-tile with correct mapping
```

### Settings lost after closing EQ

eqclient.ini is set read-only after `make configure` to prevent the
multibox exit race condition. To update settings:

```bash
make configure      # Temporarily makes writable, applies, re-locks
```

### Wine version too old

```bash
make prereqs        # Upgrades to Wine 11 from WineHQ
make doctor         # Verify: should show "wine 11.x"
```

### DXVK / Vulkan errors

```bash
vulkaninfo | grep deviceName  # Should show your GPU
make doctor                   # Check DXVK DLL status
```

### EQLogParser crashes

See [EQLogParser Setup](/norrath-native/guides/eqlogparser-setup/#troubleshooting).

## Support Bundle

```bash
make support-bundle
```

Generates `norrath-native-support.tar.gz` containing:

- Doctor check results (JSON)
- System info (kernel, distro, Wine/Node versions, Vulkan, xrandr)
- Instance logs
- Deploy state (versions, timestamps, profile)
