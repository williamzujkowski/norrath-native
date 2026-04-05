#!/usr/bin/env npx tsx
/**
 * generate-stats.ts — Verify and inject project statistics into docs.
 *
 * Reads runtime metadata from the CLI + filesystem counts, then checks
 * that all documentation files use the correct numbers. With --fix,
 * rewrites stale numbers in-place.
 *
 * Usage:
 *   npx tsx scripts/generate-stats.ts          # Check mode (CI)
 *   npx tsx scripts/generate-stats.ts --fix    # Fix stale numbers
 *   npx tsx scripts/generate-stats.ts --json   # Output raw stats as JSON
 */

import { execSync } from "node:child_process";
import { readFileSync, writeFileSync, readdirSync } from "node:fs";
import { join } from "node:path";

const ROOT = join(import.meta.dirname ?? ".", "..");
const FIX_MODE = process.argv.includes("--fix");
const JSON_MODE = process.argv.includes("--json");

// ---------------------------------------------------------------------------
// Gather stats from source of truth
// ---------------------------------------------------------------------------

interface Stats {
  colors: number;
  channels: number;
  windows: number;
  profiles: number;
  profileNames: string[];
  managedSettings: number;
  doctorChecks: number;
  requiredPackages: number;
  cliCommands: number;
  makeTargets: number;
  layoutTemplates: number;
  scripts: number;
  testFiles: number;
}

function gatherStats(): Stats {
  // Runtime metadata from compiled CLI
  const raw = execSync("node dist/cli.js metadata", { cwd: ROOT }).toString();
  const meta = JSON.parse(raw) as Record<string, unknown>;

  // Filesystem counts
  const layoutDir = join(ROOT, "layouts");
  const layouts = readdirSync(layoutDir).filter((f) => f.endsWith(".conf"));

  const scriptsDir = join(ROOT, "scripts");
  const scripts = readdirSync(scriptsDir).filter((f) => f.endsWith(".sh"));

  const testsDir = join(ROOT, "tests");
  const tests = readdirSync(testsDir).filter((f) => f.endsWith(".test.ts"));

  const makefileContent = readFileSync(join(ROOT, "Makefile"), "utf-8");
  const makeTargets = makefileContent
    .split("\n")
    .filter((line) => /^[a-zA-Z_-]+:.*##/.test(line)).length;

  const colorsObj = meta["colors"] as { count: number };
  const channelsObj = meta["channels"] as { count: number; windows: number };
  const profilesObj = meta["profiles"] as {
    count: number;
    names: string[];
  };
  const settingsObj = meta["managedSettings"] as { count: number };
  const checksObj = meta["doctorChecks"] as { count: number };
  const packagesObj = meta["requiredPackages"] as { count: number };
  const commandsObj = meta["cliCommands"] as { count: number };

  return {
    colors: colorsObj.count,
    channels: channelsObj.count,
    windows: channelsObj.windows,
    profiles: profilesObj.count,
    profileNames: profilesObj.names,
    managedSettings: settingsObj.count,
    doctorChecks: checksObj.count,
    requiredPackages: packagesObj.count,
    cliCommands: commandsObj.count,
    makeTargets: makeTargets,
    layoutTemplates: layouts.length,
    scripts: scripts.length,
    testFiles: tests.length,
  };
}

// ---------------------------------------------------------------------------
// Replacement rules: map regex patterns to their correct values
// ---------------------------------------------------------------------------

interface Rule {
  pattern: RegExp;
  replacement: string;
  description: string;
}

function buildRules(stats: Stats): Rule[] {
  return [
    // Color counts
    {
      pattern: /\b\d+-color WCAG/g,
      replacement: `${String(stats.colors)}-color WCAG`,
      description: `color count: ${String(stats.colors)}`,
    },
    {
      pattern: /\b\d+-entry.*chat color scheme/g,
      replacement: `${String(stats.colors)}-entry optimized chat color scheme`,
      description: `color entry count in JSDoc`,
    },
    // Channel counts
    {
      pattern: /\b\d+-channel chat/g,
      replacement: `${String(stats.channels)}-channel chat`,
      description: `channel count: ${String(stats.channels)}`,
    },
    {
      pattern: /\b\d+-entry chat channel/g,
      replacement: `${String(stats.channels)}-entry chat channel`,
      description: `channel entry count in JSDoc`,
    },
    {
      pattern: /with \d+-channel routing/g,
      replacement: `with ${String(stats.channels)}-channel routing`,
      description: `channel routing count`,
    },
    // Doctor checks
    {
      pattern: /\b\d+ structured health checks/g,
      replacement: `${String(stats.doctorChecks)} structured health checks`,
      description: `doctor checks: ${String(stats.doctorChecks)}`,
    },
    {
      pattern: /\b\d+-point health check/g,
      replacement: `${String(stats.doctorChecks)}-point health check`,
      description: `doctor check count in make reference`,
    },
    {
      pattern: /\b\d+\+ structured doctor health checks/g,
      replacement: `${String(stats.doctorChecks)} structured doctor health checks`,
      description: `doctor checks (fuzzy form)`,
    },
    {
      pattern: /Health check \(\d+ validation checks\)/g,
      replacement: `Health check (${String(stats.doctorChecks)} validation checks)`,
      description: `doctor check count in README`,
    },
    // Managed settings
    {
      pattern: /\b\d+ managed eqclient\.ini settings/g,
      replacement: `${String(stats.managedSettings)} managed eqclient.ini settings`,
      description: `managed settings: ${String(stats.managedSettings)}`,
    },
    {
      pattern: /Each profile is opinionated about \d+ EQ settings/g,
      replacement: `Each profile is opinionated about ${String(stats.managedSettings)} EQ settings`,
      description: `managed settings in example yaml`,
    },
    // Profiles
    {
      pattern: /across \d+ profiles/g,
      replacement: `across ${String(stats.profiles)} profiles`,
      description: `profile count: ${String(stats.profiles)}`,
    },
    {
      pattern: /\b\d+ profiles,/g,
      replacement: `${String(stats.profiles)} profiles,`,
      description: `profile count (inline)`,
    },
    // CLI commands (project structure)
    {
      pattern: /entry point \(\d+ commands\)/g,
      replacement: `entry point (${String(stats.cliCommands)} commands)`,
      description: `CLI command count: ${String(stats.cliCommands)}`,
    },
    // Channel → window routing
    {
      pattern: /\d+-channel → \d+-window/g,
      replacement: `${String(stats.channels)}-channel → ${String(stats.windows)}-window`,
      description: `channel→window routing`,
    },
    // Make targets
    {
      pattern: /— \d+ targets \(make help\)/g,
      replacement: `— ${String(stats.makeTargets)} targets (make help)`,
      description: `Makefile target count: ${String(stats.makeTargets)}`,
    },
    // Scripts count
    {
      pattern: /— \d+ bash scripts/g,
      replacement: `— ${String(stats.scripts)} bash scripts`,
      description: `bash script count: ${String(stats.scripts)}`,
    },
    // Test files count
    {
      pattern: /— \d+ test files/g,
      replacement: `— ${String(stats.testFiles)} test files`,
      description: `test file count: ${String(stats.testFiles)}`,
    },
    // Layout templates count
    {
      pattern: /— \d+ window layout templates/g,
      replacement: `— ${String(stats.layoutTemplates)} window layout templates`,
      description: `layout template count: ${String(stats.layoutTemplates)}`,
    },
    // Settings count (inline form)
    {
      pattern: /\b\d+ managed settings/g,
      replacement: `${String(stats.managedSettings)} managed settings`,
      description: `managed settings (inline)`,
    },
  ];
}

// ---------------------------------------------------------------------------
// Check/fix docs
// ---------------------------------------------------------------------------

const DOC_FILES = [
  "README.md",
  "CHANGELOG.md",
  "AGENTS.md",
  "norrath-native.example.yaml",
  "src/colors.ts",
  "src/layout.ts",
  "src/doctor.ts",
];

function checkAndFix(stats: Stats): boolean {
  const rules = buildRules(stats);
  let allClean = true;

  for (const relPath of DOC_FILES) {
    const fullPath = join(ROOT, relPath);
    let content: string;
    try {
      content = readFileSync(fullPath, "utf-8");
    } catch {
      continue;
    }

    let updated = content;
    const drifts: string[] = [];

    for (const rule of rules) {
      const matches = content.match(rule.pattern);
      if (matches) {
        for (const match of matches) {
          if (match !== rule.replacement) {
            drifts.push(
              `  "${match}" → "${rule.replacement}" (${rule.description})`,
            );
            updated = updated.replace(match, rule.replacement);
          }
        }
      }
    }

    if (drifts.length > 0) {
      allClean = false;
      console.log(`\n${relPath}:`);
      for (const d of drifts) {
        console.log(d);
      }
      if (FIX_MODE) {
        writeFileSync(fullPath, updated);
        console.log(`  ✓ Fixed`);
      }
    }
  }

  return allClean;
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

function main(): void {
  const stats = gatherStats();

  if (JSON_MODE) {
    process.stdout.write(JSON.stringify(stats, null, 2));
    process.stdout.write("\n");
    return;
  }

  console.log("Project Statistics (from source of truth):");
  console.log(`  Colors:           ${String(stats.colors)}`);
  console.log(
    `  Channels:         ${String(stats.channels)} → ${String(stats.windows)} windows`,
  );
  console.log(
    `  Profiles:         ${String(stats.profiles)} (${stats.profileNames.join(", ")})`,
  );
  console.log(`  Managed settings: ${String(stats.managedSettings)}`);
  console.log(`  Doctor checks:    ${String(stats.doctorChecks)}`);
  console.log(`  Required packages:${String(stats.requiredPackages)}`);
  console.log(`  CLI commands:     ${String(stats.cliCommands)}`);
  console.log(`  Make targets:     ${String(stats.makeTargets)}`);
  console.log(`  Layout templates: ${String(stats.layoutTemplates)}`);
  console.log(`  Bash scripts:     ${String(stats.scripts)}`);
  console.log(`  Test files:       ${String(stats.testFiles)}`);

  const clean = checkAndFix(stats);

  if (!clean && !FIX_MODE) {
    console.log("\n❌ Documentation has stale numbers.");
    console.log("Run: npx tsx scripts/generate-stats.ts --fix");
    process.exit(1);
  } else if (clean) {
    console.log("\n✓ All documentation numbers match source of truth.");
  } else {
    console.log("\n✓ Fixed all stale numbers.");
  }
}

main();
