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
help               Show this help
install            Install pnpm dependencies
launch-multi       Launch instances per config (default: from norrath-native.yaml)
launch             Launch a single EverQuest instance
lint               Run ESLint with project rules
maps               Install Brewall's map pack (FILE=path/to/downloaded.zip)
parser             Install EQLogParser DPS meter + trigger system (PARSER_FILE=path/to/downloaded.zip)
prereqs-dry        Preview prerequisite installation without changes
prereqs            Install system prerequisites (Wine, Vulkan, etc.)
purge              Remove Wine prefix and all EQ data (DESTRUCTIVE)
restore-session    Restore launcher session from backup
support-bundle     Generate a support bundle for troubleshooting
test-coverage      Run tests with coverage report
test               Run Vitest test suite
typecheck          Run TypeScript strict type checking
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
