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

import { resolveConfig, generateManagedSettings } from './config.js';
import {
  isUltrawide,
  clampTo16x9,
  calculateViewport,
  calculateTilePositions,
} from './resolution.js';

const args = process.argv.slice(2);
const command = args[0];

function printJson(data: unknown): void {
  process.stdout.write(JSON.stringify(data, null, 2));
  process.stdout.write('\n');
}

function commands(): Record<
  string,
  () => void
> {
  return {
    'config': cmdConfig,
    'config:resolve': cmdConfig,
    'config:settings': cmdConfigSettings,
    'resolution:detect': cmdResolutionDetect,
    'resolution:clamp': cmdResolutionClamp,
    'resolution:viewport': cmdResolutionViewport,
    'resolution:tiles': cmdResolutionTiles,
    'help': cmdHelp,
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

function cmdResolutionDetect(): void {
  const width = parseInt(args[1] ?? '1920', 10);
  const height = parseInt(args[2] ?? '1080', 10);

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
  const width = parseInt(args[1] ?? '1920', 10);
  const height = parseInt(args[2] ?? '1080', 10);
  const result = clampTo16x9(width, height);
  printJson(result);
}

function cmdResolutionViewport(): void {
  const width = parseInt(args[1] ?? '1920', 10);
  const height = parseInt(args[2] ?? '1080', 10);
  const result = calculateViewport(width, height);
  if (!result.ok) {
    process.stderr.write(`Error: ${result.error.message}\n`);
    process.exit(1);
  }
  printJson(result.value);
}

function cmdResolutionTiles(): void {
  const count = parseInt(args[1] ?? '1', 10);
  const width = parseInt(args[2] ?? '1920', 10);
  const height = parseInt(args[3] ?? '1080', 10);
  printJson(calculateTilePositions(count, width, height));
}

function cmdHelp(): void {
  process.stdout.write(`norrath-native CLI

Commands:
  config              Resolve full configuration (JSON)
  config:settings     Generate managed INI settings (JSON)
  resolution:detect W H    Detect ultrawide, clamp, viewport
  resolution:clamp W H     Clamp to 16:9
  resolution:viewport W H  Calculate viewport offsets
  resolution:tiles N W H   Calculate tile positions for N windows

Usage from bash:
  node dist/cli.js config | jq '.prefix'
  node dist/cli.js config:settings | jq -r 'to_entries[] | "\\(.key)=\\(.value)"'
  node dist/cli.js resolution:detect 3440 1440
`);
}

// Dispatch
const handler = commands()[command ?? 'help'];
if (handler) {
  handler();
} else {
  process.stderr.write(`Unknown command: ${command ?? '(none)'}\n`);
  cmdHelp();
  process.exit(1);
}
