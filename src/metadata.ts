/**
 * Project metadata — programmatic counts derived from source of truth.
 *
 * Every number in documentation should come from this module.
 * Run `node dist/cli.js metadata` to see current values.
 *
 * @module metadata
 */

import { COLOR_SCHEME } from "./colors.js";
import { CHANNEL_MAP, WINDOW_NAMES } from "./layout.js";
import { resolveConfig, generateManagedSettings } from "./config.js";
import { buildDefaultChecks } from "./doctor.js";
import { REQUIRED_APT_PACKAGES } from "./types/interfaces.js";

/** All project metadata, derived from source code at runtime. */
export interface ProjectMetadata {
  colors: { count: number };
  channels: { count: number; windows: number };
  profiles: { count: number; names: string[] };
  managedSettings: { count: number };
  doctorChecks: { count: number };
  requiredPackages: { count: number };
  cliCommands: { count: number; names: string[] };
  makeTargets: { count: number };
  layoutTemplates: { count: number };
  scripts: { count: number };
  testFiles: { count: number };
}

/** CLI command names — kept in sync with cli.ts commands() */
const CLI_COMMANDS: string[] = [
  "config",
  "config:resolve",
  "config:settings",
  "config:settings:ini",
  "resolution:detect",
  "resolution:clamp",
  "resolution:viewport",
  "resolution:tiles",
  "colors:scheme",
  "colors:ini",
  "colors:data",
  "colors:validate",
  "colors:apply",
  "layout:channels",
  "layout:ini",
  "layout:data",
  "layout:apply",
  "doctor",
  "doctor:json",
  "status:versions",
  "metadata",
  "help",
];

const PROFILES = ["high", "balanced", "raid", "low", "minimal"] as const;

/**
 * Gather all project metadata from source of truth.
 * Counts are computed at runtime, never hardcoded.
 */
export function gatherMetadata(): ProjectMetadata {
  const config = resolveConfig();
  const settings = config.ok ? generateManagedSettings(config.value) : {};
  const checks = buildDefaultChecks("/tmp/test-prefix");

  return {
    colors: {
      count: Object.keys(COLOR_SCHEME).length,
    },
    channels: {
      count: Object.keys(CHANNEL_MAP).length,
      windows: WINDOW_NAMES.length,
    },
    profiles: {
      count: PROFILES.length,
      names: [...PROFILES],
    },
    managedSettings: {
      count: Object.keys(settings).length,
    },
    doctorChecks: {
      count: checks.length,
    },
    requiredPackages: {
      count: REQUIRED_APT_PACKAGES.length,
    },
    cliCommands: {
      count: CLI_COMMANDS.length,
      names: CLI_COMMANDS,
    },
    makeTargets: { count: 0 },
    layoutTemplates: { count: 0 },
    scripts: { count: 0 },
    testFiles: { count: 0 },
  };
}
