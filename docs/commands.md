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
  -h, --help      Show this help

See docs/chat-layout.md for the full design rationale.
```

## configure_eq

```
Usage: configure_eq.sh [OPTIONS]

Apply EQ client settings from norrath-native.yaml.

Options:
  --prefix PATH   Override WINEPREFIX (default from config: /home/william/.wine-eq)
  --profile NAME  Override profile (high|balanced|low|minimal)
  --dry-run       Show what would change without writing
  -h, --help      Show this help

Profiles:
  high      Full quality, single client (default)
  balanced  Good quality for 2-3 clients
  low       Reduced quality for background boxes
  minimal   Stick figures, minimum resources for AFK boxes
```

## deploy_eq_env

```
Usage: deploy_eq_env.sh [OPTIONS]

Provision a Wine prefix with DXVK for running EverQuest under Wine.

Options:
  --dry-run           Print every action without touching the filesystem
  --prefix PATH       Set WINEPREFIX (default: ~/.wine-eq)
  --resolution WxH    Virtual desktop resolution (default: 1920x1080)
  -h, --help          Show this help message

Examples:
  deploy_eq_env.sh
  deploy_eq_env.sh --dry-run
  deploy_eq_env.sh --prefix ~/my-wine --resolution 2560x1440
```

## doctor

```
Usage: doctor.sh [OPTIONS]

Run a health check on the norrath-native installation.

Options:
  --prefix PATH   Override WINEPREFIX to check (default from config: /home/william/.wine-eq)
  --json          Output results as JSON (suppresses ANSI output)
  -h, --help      Show this help message
```

## generate-docs

```
[docs] Generating TypeDoc API reference...
