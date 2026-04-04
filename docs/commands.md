# Command Reference

*Auto-generated from script --help output. Do not edit manually.*

## Makefile Targets

```
make: Entering directory '/home/william/git/norrath-native'
backup-session     Back up launcher login session for disaster recovery
clean              Remove build artifacts and coverage
colors-preview     Preview color scheme changes without applying
colors             Apply optimized chat color scheme for raid readability
configure-dry      Preview INI changes without writing
configure          Apply optimized eqclient.ini settings
deploy-dry         Preview deployment without making changes
deploy             Full deployment (prefix + DXVK + EQ install + config)
docs-check         Verify generated docs are up to date (CI mode)
docs               Generate API docs, command reference, and check reference
doctor             Health check — validate entire installation
focus-next         Cycle keyboard focus to the next EQ window
help               Show this help
install            Install pnpm dependencies
launch-multi       Launch multibox instances (default: 3, set multibox_instances in config)
launch             Launch a single EverQuest instance
layout-apply       Apply a layout template (TEMPLATE=name, e.g., multibox-bard-pull)
layout-preview     Preview chat layout changes without applying
layout-show        Preview a layout template's calculated positions
layout-templates   List available layout templates
layout             Apply recommended 4-window chat layout (Social/Combat/Spam/Alerts)
lint               Run ESLint with project rules
maps               Install Brewall's map pack (FILE=path/to/downloaded.zip)
parser             Install EQLogParser DPS meter + trigger system (PARSER_FILE=path/to/downloaded.zip)
pip                Picture-in-picture: main window large, others stacked right
prereqs-dry        Preview prerequisite installation without changes
prereqs            Install system prerequisites (Wine, Vulkan, etc.)
profile-list       List available UI layout profiles
profile-load       Load a saved UI layout profile (PROFILE=name)
profile-save       Save current UI layout as a named profile (PROFILE=name)
purge              Remove Wine prefix and all EQ data (DESTRUCTIVE)
resolution-detect  Show detected monitor resolution vs current Wine resolution
resolution         Set Wine + EQ resolution to match your monitor (auto-detect)
restore-session    Restore launcher session from backup
setup-all          Apply ALL customizations to ALL characters (config + colors + layout + resolution)
support-bundle     Generate a support bundle for troubleshooting
test-coverage      Run tests with coverage report
test               Run Vitest test suite
tile               Arrange EQ windows in a grid layout (auto-detects count)
typecheck          Run TypeScript strict type checking
windows            List all detected EQ windows
make: Leaving directory '/home/william/git/norrath-native'
```

## apply_colors

```
Usage: apply_colors.sh [OPTIONS]

Apply an optimized chat color scheme to eqclient.ini.

The scheme is designed for raid readability:
  - Tells: bright pink (unmissable)
  - Guild: bright green
  - Group: soft blue
  - Raid:  orange
  - Your damage: warm yellow/gold
  - Your healing: cool mint/blue
  - Others' combat: dimmed gray (red[docs]   Written: /home/william/git/norrath-native/scripts/../docs/commands.md
[docs] Generating doctor checks reference...
[docs]   Written: /home/william/git/norrath-native/scripts/../docs/checks.md
[docs] Documentation generation complete
```

## install_prerequisites

```
Usage: install_prerequisites.sh [OPTIONS]

Install all system prerequisites for norrath-native (EverQuest on Linux).

Options:
    --dry-run         Show what would be installed without making changes
    --skip-optional   Skip optional packages (fonts, winetricks)
    -h, --help        Show this help message

Requires: Ubuntu 24.04 LTS, sudo access
```

## start_eq

```
Usage: start_eq.sh [OPTIONS]

Launch EverQuest instances under Wine with optional multi-boxing support.

Options:
  --multi                Use multibox_instances from config (default: 3)
  --instances N          Override instance count
  --stagger-delay SECS   Delay between instance launches (default: 5)
  --prefix PATH          WINEPREFIX path (default: ~/.wine-eq)
  --eq-dir PATH          EverQuest install directory (default: auto-detect)
  --wayland              Use Wayland display backend instead of X11
  --dry-run              Print what would be launched without starting Wine
  -h, --help             Show this help message

Environment:
  NORRATH_WAYLAND=1      Alternative way to enable Wayland backend

Examples:
  start_eq.sh                    # Launch 1 instance (raid focus)
  start_eq.sh --multi            # Launch multibox instances from config
  start_eq.sh --instances 4      # Launch exactly 4 instances
```

ng Wine
  -h, --help             Show this help message

Environment:
  NORRATH_WAYLAND=1      Alternative way to enable Wayland backend

Examples:
  start_eq.sh                    # Launch 1 instance (raid focus)
  start_eq.sh --multi            # Launch multibox instances from config
  start_eq.sh --instances 4      # Launch exactly 4 instances
```

    EverQuest install directory (default: auto-detect)
  --wayland              Use Wayland display backend instead of X11
  --dry-run              Print what would be launched without starting Wine
  -h, --help             Show this help message

Environment:
  NORRATH_WAYLAND=1      Alternative way to enable Wayland backend

Examples:
  start_eq.sh                    # Launch 1 instance (raid focus)
  start_eq.sh --multi            # Launch multibox instances from config
  start_eq.sh --instances 4      # Launch exactly 4 instances
```

m config
  start_eq.sh --instances 4      # Launch exactly 4 instances
```

ons:
    --dry-run         Show what would be installed without making changes
    --skip-optional   Skip optional packages (fonts, winetricks)
    -h, --help        Show this help message

Requires: Ubuntu 24.04 LTS, sudo access
```

## start_eq

```
Usage: start_eq.sh [OPTIONS]

Launch EverQuest instances under Wine with optional multi-boxing support.

Options:
  --multi                Use multibox_instances from config (default: 3)
  --instances N          Override instance count
  --stagger-delay SECS   Delay between instance launches (default: 5)
  --prefix PATH          WINEPREFIX path (default: ~/.wine-eq)
  --eq-dir PATH          EverQuest install directory (default: auto-detect)
  --wayland              Use Wayland display backend instead of X11
  --dry-run              Print what would be launched without starting Wine
  -h, --help             Show this help message

Environment:
  NORRATH_WAYLAND=1      Alternative way to enable Wayland backend

Examples:
  start_eq.sh                    # Launch 1 instance (raid focus)
  start_eq.sh --multi            # Launch multibox instances from config
  start_eq.sh --instances 4      # Launch exactly 4 instances
```

unch multibox instances from config
  start_eq.sh --instances 4      # Launch exactly 4 instances
```

       Use Wayland display backend instead of X11
  --dry-run              Print what would be launched without starting Wine
  -h, --help             Show this help message

Environment:
  NORRATH_WAYLAND=1      Alternative way to enable Wayland backend

Examples:
  start_eq.sh                    # Launch 1 instance (raid focus)
  start_eq.sh --multi            # Launch multibox instances from config
  start_eq.sh --instances 4      # Launch exactly 4 instances
```

  start_eq.sh --instances 4      # Launch exactly 4 instances
```

 start_eq.sh --multi            # Launch multibox instances from config
  start_eq.sh --instances 4      # Launch exactly 4 instances
```

   EverQuest install directory (default: auto-detect)
  --wayland              Use Wayland display backend instead of X11
  --dry-run              Print what would be launched without starting Wine
  -h, --help             Show this help message

Environment:
  NORRATH_WAYLAND=1      Alternative way to enable Wayland backend

Examples:
  start_eq.sh                    # Launch 1 instance (raid focus)
  start_eq.sh --multi            # Launch multibox instances from config
  start_eq.sh --instances 4      # Launch exactly 4 instances
```

id focus)
  start_eq.sh --multi            # Launch multibox instances from config
  start_eq.sh --instances 4      # Launch exactly 4 instances
```

h (default: ~/.wine-eq)
  --eq-dir PATH          EverQuest install directory (default: auto-detect)
  --wayland              Use Wayland display backend instead of X11
  --dry-run              Print what would be launched without starting Wine
  -h, --help             Show this help message

Environment:
  NORRATH_WAYLAND=1      Alternative way to enable Wayland backend

Examples:
  start_eq.sh                    # Launch 1 instance (raid focus)
  start_eq.sh --multi            # Launch multibox instances from config
  start_eq.sh --instances 4      # Launch exactly 4 instances
```

ow all detected EQ windows
  pip        Picture-in-picture: main window large, others small
  -h, --help Show this help

Replaces ISBoxer window management on Linux using native X11 tools.
```

 instead of X11
  --dry-run              Print what would be launched without starting Wine
  -h, --help             Show this help message

Environment:
  NORRATH_WAYLAND=1      Alternative way to enable Wayland backend

Examples:
  start_eq.sh                    # Launch 1 instance (raid focus)
  start_eq.sh --multi            # Launch multibox instances from config
  start_eq.sh --instances 4      # Launch exactly 4 instances
```

## window_manager

```
Usage: window_manager.sh <command>

Manage EverQuest windows for multiboxing.

Commands:
  tile       Arrange all EQ windows in a grid layout
  focus      Cycle focus to the next EQ window
  list       Show all detected EQ windows
  pip        Picture-in-picture: main window large, others small
  -h, --help Show this help

Replaces ISBoxer window management on Linux using native X11 tools.
```

     Picture-in-picture: main window large, others small
  -h, --help Show this help

Replaces ISBoxer window management on Linux using native X11 tools.
```

 tools.
```

n              Print what would be launched without starting Wine
  -h, --help             Show this help message

Environment:
  NORRATH_WAYLAND=1      Alternative way to enable Wayland backend

Examples:
  start_eq.sh                    # Launch 1 instance (raid focus)
  start_eq.sh --multi            # Launch multibox instances from config
  start_eq.sh --instances 4      # Launch exactly 4 instances
```

## window_manager

```
Usage: window_manager.sh <command>

Manage EverQuest windows for multiboxing.

Commands:
  tile       Arrange all EQ windows in a grid layout
  focus      Cycle focus to the next EQ window
  list       Show all detected EQ windows
  pip        Picture-in-picture: main window large, others small
  -h, --help Show this help

Replaces ISBoxer window management on Linux using native X11 tools.
```

ow all detected EQ windows
  pip        Picture-in-picture: main window large, others small
  -h, --help Show this help

Replaces ISBoxer window management on Linux using native X11 tools.
```

t:
  NORRATH_WAYLAND=1      Alternative way to enable Wayland backend

Examples:
  start_eq.sh                    # Launch 1 instance (raid focus)
  start_eq.sh --multi            # Launch multibox instances from config
  start_eq.sh --instances 4      # Launch exactly 4 instances
```

## window_manager

```
bash: warning: shell level (1000) too high, resetting to 1
Usage: window_manager.sh <command>

Manage EverQuest windows for multiboxing.

Commands:
  tile       Arrange all EQ windows in a grid layout
  focus      Cycle focus to the next EQ window
  list       Show all detected EQ windows
  pip        Picture-in-picture: main window large, others small
  -h, --help Show this help

Replaces ISBoxer window management on Linux using native X11 tools.
```

e: main window large, others small
  -h, --help Show this help

Replaces ISBoxer window management on Linux using native X11 tools.
```

t       Show all detected EQ windows
  pip        Picture-in-picture: main window large, others small
  -h, --help Show this help

Replaces ISBoxer window management on Linux using native X11 tools.
```

ces ISBoxer window management on Linux using native X11 tools.
```

