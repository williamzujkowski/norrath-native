/**
 * CLI command integration tests.
 *
 * Tests the three data-output commands added for bash script integration:
 *   config:settings:ini — key=value lines for configure_eq.sh
 *   colors:data         — "ID R G B" lines for apply_colors.sh
 *   layout:data         — "FILTER_ID WINDOW_ID" lines for apply_layout.sh
 */

import { describe, it, expect } from 'vitest';
import { execFileSync } from 'node:child_process';
import { join } from 'node:path';

// Path to compiled CLI
const CLI = join(import.meta.dirname ?? '', '..', 'dist', 'cli.js');

function runCli(command: string, extraArgs: string[] = []): string {
  return execFileSync('node', [CLI, command, ...extraArgs], {
    encoding: 'utf-8',
  });
}

describe('config:settings:ini', () => {
  it('outputs key=value lines (no JSON braces)', () => {
    const output = runCli('config:settings:ini');
    expect(output).not.toContain('{');
    expect(output).not.toContain('}');
  });

  it('every non-empty line is KEY=value format', () => {
    const output = runCli('config:settings:ini');
    const lines = output.split('\n').filter((l) => l.trim().length > 0);
    for (const line of lines) {
      expect(line).toMatch(/^[A-Za-z_][A-Za-z0-9_]+=.+$/);
    }
  });

  it('includes WindowedMode=TRUE', () => {
    const output = runCli('config:settings:ini');
    expect(output).toContain('WindowedMode=TRUE');
  });

  it('includes MaxBGFPS entry', () => {
    const output = runCli('config:settings:ini');
    expect(output).toContain('MaxBGFPS=');
  });

  it('includes all 12 ClientCoreN entries', () => {
    const output = runCli('config:settings:ini');
    for (let i = 0; i < 12; i++) {
      expect(output).toContain(`ClientCore${String(i)}=-1`);
    }
  });

  it('includes particle opacity settings', () => {
    const output = runCli('config:settings:ini');
    expect(output).toContain('SpellParticleOpacity=');
    expect(output).toContain('EnvironmentParticleOpacity=');
    expect(output).toContain('ActorParticleOpacity=');
  });
});

describe('colors:data', () => {
  it('outputs "ID R G B" lines (no JSON)', () => {
    const output = runCli('colors:data');
    expect(output).not.toContain('{');
    expect(output).not.toContain('"');
  });

  it('every non-empty line has exactly 4 space-separated integers', () => {
    const output = runCli('colors:data');
    const lines = output.split('\n').filter((l) => l.trim().length > 0);
    expect(lines.length).toBeGreaterThan(0);
    for (const line of lines) {
      const parts = line.trim().split(/\s+/);
      expect(parts.length).toBe(4);
      for (const part of parts) {
        expect(Number.isInteger(Number(part))).toBe(true);
      }
    }
  });

  it('produces one line per color in the scheme (91 entries)', () => {
    const output = runCli('colors:data');
    const lines = output.split('\n').filter((l) => l.trim().length > 0);
    expect(lines.length).toBe(91);
  });

  it('RGB values are in range 0-255', () => {
    const output = runCli('colors:data');
    const lines = output.split('\n').filter((l) => l.trim().length > 0);
    for (const line of lines) {
      const [, r, g, b] = line.trim().split(/\s+/).map(Number);
      expect(r).toBeGreaterThanOrEqual(0);
      expect(r).toBeLessThanOrEqual(255);
      expect(g).toBeGreaterThanOrEqual(0);
      expect(g).toBeLessThanOrEqual(255);
      expect(b).toBeGreaterThanOrEqual(0);
      expect(b).toBeLessThanOrEqual(255);
    }
  });

  it('Tell color (ID 12) is 255 128 255', () => {
    const output = runCli('colors:data');
    const lines = output.split('\n').filter((l) => l.trim().length > 0);
    const tell = lines.find((l) => l.startsWith('12 '));
    expect(tell).toBe('12 255 128 255');
  });
});

describe('layout:data', () => {
  it('outputs "FILTER_ID WINDOW_ID" lines (no JSON)', () => {
    const output = runCli('layout:data');
    expect(output).not.toContain('{');
    expect(output).not.toContain('"');
  });

  it('every non-empty line has exactly 2 space-separated integers', () => {
    const output = runCli('layout:data');
    const lines = output.split('\n').filter((l) => l.trim().length > 0);
    expect(lines.length).toBeGreaterThan(0);
    for (const line of lines) {
      const parts = line.trim().split(/\s+/);
      expect(parts.length).toBe(2);
      for (const part of parts) {
        expect(Number.isInteger(Number(part))).toBe(true);
      }
    }
  });

  it('produces one line per channel in the map (107 entries)', () => {
    const output = runCli('layout:data');
    const lines = output.split('\n').filter((l) => l.trim().length > 0);
    expect(lines.length).toBe(107);
  });

  it('window IDs are valid (0-3)', () => {
    const output = runCli('layout:data');
    const lines = output.split('\n').filter((l) => l.trim().length > 0);
    for (const line of lines) {
      const [, windowId] = line.trim().split(/\s+/).map(Number);
      expect(windowId).toBeGreaterThanOrEqual(0);
      expect(windowId).toBeLessThanOrEqual(3);
    }
  });

  it('Tell channel (ID 12) routes to window 0 (Social)', () => {
    const output = runCli('layout:data');
    const lines = output.split('\n').filter((l) => l.trim().length > 0);
    const tell = lines.find((l) => l.startsWith('12 '));
    expect(tell).toBe('12 0');
  });

  it('Death channel (ID 16) routes to window 3 (Alerts)', () => {
    const output = runCli('layout:data');
    const lines = output.split('\n').filter((l) => l.trim().length > 0);
    const death = lines.find((l) => l.startsWith('16 '));
    expect(death).toBe('16 3');
  });
});
