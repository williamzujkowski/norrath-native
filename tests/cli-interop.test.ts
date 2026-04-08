/**
 * Bash-TypeScript interop tests.
 *
 * Verifies that each CLI subcommand returns valid JSON with the
 * expected shape. These tests catch schema drift between bash
 * scripts (which parse CLI JSON output) and TypeScript (which
 * produces it).
 */

import { describe, it, expect } from "vitest";
import { execSync } from "node:child_process";
import { join } from "node:path";

const CLI = join(import.meta.dirname, "..", "dist", "cli.js");

/** Run a CLI command and parse its JSON output. */
function runCli(command: string): unknown {
  const stdout = execSync(`node ${CLI} ${command}`, {
    encoding: "utf-8",
    timeout: 10_000,
  });
  return JSON.parse(stdout);
}

/** Run a CLI command and return raw stdout. */
function runCliRaw(command: string): string {
  return execSync(`node ${CLI} ${command}`, {
    encoding: "utf-8",
    timeout: 10_000,
  });
}

// ---------------------------------------------------------------------------
// Config commands
// ---------------------------------------------------------------------------

describe("cli interop: config", () => {
  it("config returns JSON with required fields", () => {
    const result = runCli("config") as Record<string, unknown>;
    expect(result).toHaveProperty("prefix");
    expect(result).toHaveProperty("resolution");
    expect(result).toHaveProperty("display");
    expect(result).toHaveProperty("instances");
    expect(result).toHaveProperty("profile");
    expect(result).toHaveProperty("eqSettings");
    expect(typeof result["prefix"]).toBe("string");
    expect(typeof result["instances"]).toBe("number");
  });

  it("config:settings returns JSON object", () => {
    const result = runCli("config:settings") as Record<string, unknown>;
    expect(typeof result).toBe("object");
    expect(result).toHaveProperty("WindowedMode");
    expect(result).toHaveProperty("MaxBGFPS");
    expect(result).toHaveProperty("Log");
  });

  it("config:settings:ini returns key=value lines", () => {
    const raw = runCliRaw("config:settings:ini");
    const lines = raw.trim().split("\n");
    expect(lines.length).toBeGreaterThan(10);
    for (const line of lines) {
      expect(line).toMatch(/^[A-Za-z]\w*=.+$/);
    }
  });
});

// ---------------------------------------------------------------------------
// Resolution commands
// ---------------------------------------------------------------------------

describe("cli interop: resolution", () => {
  it("resolution:detect returns JSON with monitor info", () => {
    const result = runCli("resolution:detect 1920 1080") as Record<
      string,
      unknown
    >;
    expect(result).toHaveProperty("monitor");
    expect(result).toHaveProperty("isUltrawide");
    expect(result).toHaveProperty("clamped");
    expect(result["isUltrawide"]).toBe(false);
  });

  it("resolution:detect identifies ultrawide", () => {
    const result = runCli("resolution:detect 3440 1440") as Record<
      string,
      unknown
    >;
    expect(result["isUltrawide"]).toBe(true);
  });

  it("resolution:clamp returns width and height", () => {
    const result = runCli("resolution:clamp 3440 1440") as Record<
      string,
      unknown
    >;
    expect(result).toHaveProperty("width");
    expect(result).toHaveProperty("height");
    expect(typeof result["width"]).toBe("number");
  });

  it("resolution:tiles returns array of positions", () => {
    const result = runCli("resolution:tiles 3 1920 1080") as unknown[];
    expect(Array.isArray(result)).toBe(true);
    expect(result).toHaveLength(3);
    const tile = result[0] as Record<string, unknown>;
    expect(tile).toHaveProperty("x");
    expect(tile).toHaveProperty("y");
    expect(tile).toHaveProperty("width");
    expect(tile).toHaveProperty("height");
  });
});

// ---------------------------------------------------------------------------
// Colors commands
// ---------------------------------------------------------------------------

describe("cli interop: colors", () => {
  it("colors:scheme returns JSON with 91 entries", () => {
    const result = runCli("colors:scheme") as Record<string, unknown>;
    expect(Object.keys(result).length).toBe(91);
  });

  it("colors:ini returns key=value lines for TextColors", () => {
    const raw = runCliRaw("colors:ini");
    const lines = raw.trim().split("\n");
    expect(lines.length).toBeGreaterThan(200); // 91 colors * 3 channels
    expect(lines[0]).toMatch(/^User_\d+_\w+=\d+$/);
  });

  it("colors:data returns 'ID R G B' lines", () => {
    const raw = runCliRaw("colors:data");
    const lines = raw.trim().split("\n");
    expect(lines).toHaveLength(91);
    expect(lines[0]).toMatch(/^\d+ \d+ \d+ \d+$/);
  });
});

// ---------------------------------------------------------------------------
// Layout commands
// ---------------------------------------------------------------------------

describe("cli interop: layout", () => {
  it("layout:channels returns JSON with channel map", () => {
    const result = runCli("layout:channels") as Record<string, unknown>;
    expect(Object.keys(result).length).toBeGreaterThan(100);
  });

  it("layout:data returns 'FILTER_ID WINDOW_ID' lines", () => {
    const raw = runCliRaw("layout:data");
    const lines = raw.trim().split("\n");
    expect(lines.length).toBeGreaterThan(100);
    expect(lines[0]).toMatch(/^\d+ \d+$/);
  });
});

// ---------------------------------------------------------------------------
// Doctor commands
// ---------------------------------------------------------------------------

describe("cli interop: doctor", () => {
  it("doctor:json returns valid JSON with check results", () => {
    const result = runCli("doctor:json") as Record<string, unknown>;
    expect(result).toHaveProperty("passed");
    expect(result).toHaveProperty("warnings");
    expect(result).toHaveProperty("failed");
    expect(result).toHaveProperty("checks");
    expect(Array.isArray(result["checks"])).toBe(true);
  });
});

// ---------------------------------------------------------------------------
// Status and metadata
// ---------------------------------------------------------------------------

describe("cli interop: status and metadata", () => {
  it("status:versions returns JSON with version fields", () => {
    const result = runCli("status:versions") as Record<string, unknown>;
    expect(result).toHaveProperty("deployed_at");
    expect(result).toHaveProperty("wine_version");
    expect(result).toHaveProperty("dxvk_version");
    expect(result).toHaveProperty("config_profile");
  });

  it("metadata returns JSON with project stats", () => {
    const result = runCli("metadata") as Record<string, unknown>;
    expect(result).toHaveProperty("colors");
    expect(result).toHaveProperty("channels");
    expect(result).toHaveProperty("profiles");
    expect(result).toHaveProperty("managedSettings");
    expect(result).toHaveProperty("doctorChecks");
    expect(result).toHaveProperty("cliCommands");
  });
});

// ---------------------------------------------------------------------------
// Error handling
// ---------------------------------------------------------------------------

describe("cli interop: error handling", () => {
  it("unknown command exits non-zero", () => {
    expect(() => {
      execSync(`node ${CLI} nonexistent:command`, {
        encoding: "utf-8",
        timeout: 5000,
      });
    }).toThrow();
  });

  it("help command exits zero", () => {
    const raw = runCliRaw("help");
    expect(raw).toContain("Commands:");
    expect(raw).toContain("config");
    expect(raw).toContain("doctor");
  });
});
