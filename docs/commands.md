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
  - Others' combat: dimmed gray (reduces spam)
  - Death/Low HP: bright red alert

Options:
  --prefix PATH   Override WINEPREFIX
  --dry-run       Preview changes without writing
  -h, --help      Show this help
```

## apply_layout

```
Usage: apply_layout.sh [OPTIONS]

Apply the recommended 4-window chat layout to EverQuest.

Windows:
  0 "Social"  — Tells, guild, group, raid, say, emote, OOC
  1 "Combat"  — Your damage, heals, incoming, crits, pet
  2 "Spam"    — Others' combat, NPC, system (dimmed)
  3 "Alerts"  — Death, loot, XP, tasks, achievements

Options:
  --prefix PATH   Override WINEPREFIX
  --dry-run       Preview changes without writing
  --force         Apply even if EQ is running (changes may be lost)
  -h, --help      Show this help

See docs/chat-layout.md for the full design rationale.
```

## configure_eq

```
Usage: configure_eq.sh [OPTIONS]

Apply EQ[docs]   Written: /home/william/git/norrath-native/scripts/../docs/commands.md
[docs] Generating doctor checks reference...
[docs]   Written: /home/william/git/norrath-native/scripts/../docs/checks.md
[docs] Documentation generation complete
```

## install_maps

```
Usage: install_maps.sh [OPTIONS]

Install Brewall's EverQuest map pack into the Wine prefix.

Because the download link at https://www.eqmaps.info/eq-map-files/ requires
a browser click, download the ZIP manually first, then pass it to this script:

  1. Visit https://www.eqmaps.info/eq-map-files/ and download the ZIP
  2. Run: make maps FILE=~/Downloads/Brewalls-Maps.zip

Options:
  --file PATH     Path to the downloaded Brewall maps ZIP (required)
  --prefix PATH   Override WINEPREFIX (default from config: /home/william/.wine-eq)
  --dry-run       Show what would be done without making changes
  -h, --help      Show this help message

The maps are extracted to:
  ${PREFIX}/drive_c/EverQuest/maps/Brewall/

The script is idempotent — if maps are already installed and the file
count looks healthy (>100 .txt files), it exits successfully without
re-extracting.
```

## install_parser

```
Usage: install_parser.sh [OPTIONS]

Install EQLogParser (DPS meter + trigger system) into the Wine prefix.

EQLogParser requires the .NET 8.0 Desktop Runtime.  Because automated
.NET 8 installation via winetricks is unreliable, this script provides
clear manual-installation instructions or handles ZIP extraction when
you supply a pre-downloaded archive.

  Without --file:
    Print step-by-step download and Wine installation instructions.

  With --file PATH:
    Extract the downloaded EQLogParser ZIP into:
      ${PREFIX}/drive_c/Program Files/EQLogParser/

Options:
  --file PATH     Path to a downloaded EQLogParser ZIP (from GitHub releases)
  --prefix PATH   Override WINEPREFIX (default from config: /home/william/.wine-eq)
  --dry-run       Show what would be done without making changes
  -h, --help      Show this help message

Download links:
  EQLogParser releases : https://github.com/kauffman12/EQLogParser/releases
  .NET 8 Desktop x64   : https://dotnet.microsoft.com/en-us/download/dotnet/8.0

Note: On Linux/Wine, Windows TTS is unavailable.  EQLogParser bundles
Piper TTS as an alternative — enable it in the Triggers configuration.
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

