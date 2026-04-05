#!/usr/bin/env node
/**
 * norrath-native CLI — TypeScript logic entry point.
 *
 * Bash scripts call this for all calculation, configuration,
 * and data manipulation. Bash handles only system interaction
 * (wine, apt, wmctrl, xdotool).
 *
 * Usage: node dist/cli.js <command> [args]
 *
 * @module cli
 */

import { resolveConfig, generateManagedSettings } from "./config.js";
import {
  isUltrawide,
  clampTo16x9,
  calculateViewport,
  calculateTilePositions,
} from "./resolution.js";
import {
  buildDefaultChecks,
  runChecks,
  formatJson,
  formatText,
} from "./doctor.js";
import {
  COLOR_SCHEME,
  generateColorIniEntries,
  validateSchemeContrast,
} from "./colors.js";
import {
  CHANNEL_MAP,
  CHANNEL_NAMES,
  generateChannelMapEntries,
} from "./layout.js";

const args = process.argv.slice(2);
const command = args[0];

function printJson(data: unknown): void {
  process.stdout.write(JSON.stringify(data, null, 2));
  process.stdout.write("\n");
}

function commands(): Record<string, () => void> {
  return {
    config: cmdConfig,
    "config:resolve": cmdConfig,
    "config:settings": cmdConfigSettings,
    "config:settings:ini": cmdConfigSettingsIni,
    "resolution:detect": cmdResolutionDetect,
    "resolution:clamp": cmdResolutionClamp,
    "resolution:viewport": cmdResolutionViewport,
    "resolution:tiles": cmdResolutionTiles,
    "colors:scheme": cmdColorsScheme,
    "colors:ini": cmdColorsIni,
    "colors:data": cmdColorsData,
    "colors:validate": cmdColorsValidate,
    "layout:channels": cmdLayoutChannels,
    "layout:ini": cmdLayoutIni,
    "layout:data": cmdLayoutData,
    doctor: cmdDoctor,
    "doctor:json": cmdDoctorJson,
    help: cmdHelp,
  };
}

function cmdConfig(): void {
  const result = resolveConfig();
  if (!result.ok) {
    process.stderr.write(`Error: ${result.error.message}\n`);
    process.exit(1);
  }
  printJson(result.value);
}

function cmdConfigSettings(): void {
  const result = resolveConfig();
  if (!result.ok) {
    process.stderr.write(`Error: ${result.error.message}\n`);
    process.exit(1);
  }
  const settings = generateManagedSettings(result.value);
  printJson(settings);
}

function cmdConfigSettingsIni(): void {
  const result = resolveConfig();
  if (!result.ok) {
    process.stderr.write(`Error: ${result.error.message}\n`);
    process.exit(1);
  }
  const settings = generateManagedSettings(result.value);
  for (const [key, value] of Object.entries(settings)) {
    process.stdout.write(`${key}=${value}\n`);
  }
}

function cmdResolutionDetect(): void {
  const width = parseInt(args[1] ?? "1920", 10);
  const height = parseInt(args[2] ?? "1080", 10);

  printJson({
    monitor: `${String(width)}x${String(height)}`,
    isUltrawide: isUltrawide(width, height),
    clamped: clampTo16x9(width, height),
    viewport: (() => {
      const r = calculateViewport(width, height);
      return r.ok ? r.value : null;
    })(),
  });
}

function cmdResolutionClamp(): void {
  const width = parseInt(args[1] ?? "1920", 10);
  const height = parseInt(args[2] ?? "1080", 10);
  const result = clampTo16x9(width, height);
  printJson(result);
}

function cmdResolutionViewport(): void {
  const width = parseInt(args[1] ?? "1920", 10);
  const height = parseInt(args[2] ?? "1080", 10);
  const result = calculateViewport(width, height);
  if (!result.ok) {
    process.stderr.write(`Error: ${result.error.message}\n`);
    process.exit(1);
  }
  printJson(result.value);
}

function cmdResolutionTiles(): void {
  const count = parseInt(args[1] ?? "1", 10);
  const width = parseInt(args[2] ?? "1920", 10);
  const height = parseInt(args[3] ?? "1080", 10);
  printJson(calculateTilePositions(count, width, height));
}

function cmdColorsScheme(): void {
  printJson(COLOR_SCHEME);
}

function cmdColorsIni(): void {
  const entries = generateColorIniEntries();
  for (const [key, value] of Object.entries(entries)) {
    process.stdout.write(`${key}=${value}\n`);
  }
}

function cmdColorsData(): void {
  for (const [id, color] of Object.entries(COLOR_SCHEME)) {
    process.stdout.write(
      `${id} ${String(color.r)} ${String(color.g)} ${String(color.b)}\n`,
    );
  }
}

function cmdColorsValidate(): void {
  const bgR = parseInt(args[1] ?? "13", 10);
  const bgG = parseInt(args[2] ?? "13", 10);
  const bgB = parseInt(args[3] ?? "26", 10);
  const results = validateSchemeContrast({ r: bgR, g: bgG, b: bgB });
  const failing = results.filter((r) => !r.passes);
  if (failing.length > 0) {
    process.stderr.write(`${String(failing.length)} colors fail WCAG AA:\n`);
    for (const f of failing) {
      process.stderr.write(
        `  ${String(f.id)} ${f.name}: ${String(f.ratio)}:1\n`,
      );
    }
    process.exit(1);
  }
  process.stdout.write(`All ${String(results.length)} colors pass WCAG AA\n`);
}

function cmdLayoutChannels(): void {
  const channels: Record<string, { window: number; name: string }> = {};
  for (const [id, windowIndex] of Object.entries(CHANNEL_MAP)) {
    channels[id] = {
      window: windowIndex,
      name: CHANNEL_NAMES[Number(id)] ?? `Channel${id}`,
    };
  }
  printJson(channels);
}

function cmdLayoutIni(): void {
  const entries = generateChannelMapEntries();
  for (const [key, value] of Object.entries(entries)) {
    process.stdout.write(`${key}=${value}\n`);
  }
}

function cmdLayoutData(): void {
  for (const [id, windowIndex] of Object.entries(CHANNEL_MAP)) {
    process.stdout.write(`${id} ${String(windowIndex)}\n`);
  }
}

function getDoctorPrefix(): string {
  // --prefix flag takes precedence, then config, then default
  const prefixIdx = args.indexOf("--prefix");
  if (prefixIdx !== -1 && args[prefixIdx + 1]) {
    return args[prefixIdx + 1] ?? "";
  }
  const result = resolveConfig();
  if (result.ok) {
    return result.value.prefix;
  }
  const home = process.env["HOME"] ?? "/tmp";
  return `${home}/.wine-eq`;
}

function cmdDoctor(): void {
  const prefix = getDoctorPrefix();
  const checks = buildDefaultChecks(prefix);
  const report = runChecks(checks);
  process.stdout.write(formatText(report));
  if (report.failed > 0) {
    process.exit(1);
  }
}

function cmdDoctorJson(): void {
  const prefix = getDoctorPrefix();
  const checks = buildDefaultChecks(prefix);
  const report = runChecks(checks);
  process.stdout.write(formatJson(report));
  process.stdout.write("\n");
  if (report.failed > 0) {
    process.exit(1);
  }
}

function cmdHelp(): void {
  process.stdout.write(`norrath-native CLI

Commands:
  config              Resolve full configuration (JSON)
  config:settings     Generate managed INI settings (JSON)
  config:settings:ini Generate managed INI settings (key=value lines, no JSON)
  resolution:detect W H    Detect ultrawide, clamp, viewport
  resolution:clamp W H     Clamp to 16:9
  resolution:viewport W H  Calculate viewport offsets
  resolution:tiles N W H   Calculate tile positions for N windows
  colors:scheme            Output color scheme as JSON
  colors:ini               Output INI key=value entries for TextColors
  colors:data              Output color data as "ID R G B" lines (bash-friendly)
  colors:validate [R G B]  Validate WCAG contrast (default bg: 13,13,26)
  layout:channels          Output channel routing as JSON
  layout:ini               Output ChannelMap INI entries
  layout:data              Output channel map as "FILTER_ID WINDOW_ID" lines (bash-friendly)
  doctor                   Run health checks (ANSI text output)
  doctor:json              Run health checks (JSON output)
  doctor --prefix PATH     Override WINEPREFIX to check

Usage from bash:
  node dist/cli.js config | jq '.prefix'
  node dist/cli.js config:settings:ini               # key=value, no jq needed
  node dist/cli.js resolution:detect 3440 1440
  node dist/cli.js colors:data                       # "ID R G B" per line
  node dist/cli.js colors:ini >> eqclient.ini
  node dist/cli.js layout:data                       # "FILTER_ID WINDOW_ID" per line
  node dist/cli.js layout:ini >> UI_charname_server.ini
  node dist/cli.js doctor
  node dist/cli.js doctor:json | jq '.failed'
`);
}

// Dispatch
const handler = commands()[command ?? "help"];
if (handler) {
  handler();
} else {
  process.stderr.write(`Unknown command: ${command ?? "(none)"}\n`);
  cmdHelp();
  process.exit(1);
}
