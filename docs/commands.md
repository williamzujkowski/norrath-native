# Command Reference

*Auto-generated from script --help output. Do not edit manually.*

## Makefile Targets

```
make: Entering directory '/home/william/git/norrath-native'
backup-session     Back up launcher login session for disaster recovery
clean              Remove build artifacts and coverage
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

## configure_eq

```
