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
layout-preview     Preview chat layout changes without applying
layout             Apply recommended 4-window chat layout (Social/Combat/Spam/Alerts)
lint               Run ESLint with project rules
maps               Install Brewall's map pack (FILE=path/to/downloaded.zip)
parser             Install EQLogParser DPS meter + trigger system (PARSER_FILE=path/to/downloaded.zip)
pip                Picture-in-picture: main window large, others stacked right
prereqs-dry        Preview prerequisite installation without changes
prereqs            Install system prerequisites (Wine, Vulkan, etc.)
purge              Remove Wine prefix and all EQ data (DESTRUCTIVE)
restore-session    Restore launcher session from backup
setup-all          Apply ALL customizations to ALL characters (config + colors + layout)
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

