/**
 * Integration tests — validate make targets and CLI commands
 * work end-to-end as a subprocess.
 *
 * These tests run actual commands and verify output/exit codes.
 * They don't require Wine or EQ to be installed.
 */

import { describe, it, expect } from "vitest";
import { execSync } from "node:child_process";
import { join } from "node:path";

const ROOT = join(import.meta.dirname ?? "", "..");

function run(cmd: string): { stdout: string; exitCode: number } {
  try {
    const stdout = execSync(cmd, {
      cwd: ROOT,
      encoding: "utf-8",
      timeout: 30_000,
      stdio: ["pipe", "pipe", "pipe"],
    });
    return { stdout, exitCode: 0 };
  } catch (e: unknown) {
    const err = e as { stdout?: string; status?: number };
    return { stdout: err.stdout ?? "", exitCode: err.status ?? 1 };
  }
}

describe("make targets (smoke tests)", () => {
  it("make help exits 0 and lists commands", () => {
    const { stdout, exitCode } = run("make help");
    expect(exitCode).toBe(0);
    expect(stdout).toContain("fix");
    expect(stdout).toContain("doctor");
    expect(stdout).toContain("launch");
  });

  it("make build exits 0", () => {
    const { exitCode } = run("make build");
    expect(exitCode).toBe(0);
  });

  it("make typecheck exits 0", () => {
    const { exitCode } = run("make typecheck");
    expect(exitCode).toBe(0);
  });

  it("make lint exits 0", () => {
    const { exitCode } = run("make lint");
    expect(exitCode).toBe(0);
  });

  it("make format-check exits 0", () => {
    const { exitCode } = run("make format-check");
    expect(exitCode).toBe(0);
  });

  it("make stats exits 0 (docs match source)", () => {
    const { exitCode } = run("make stats");
    expect(exitCode).toBe(0);
  });
});

describe("CLI metadata consistency", () => {
  const CLI = join(ROOT, "dist", "cli.js");

  it("metadata colors count matches colors:scheme output", () => {
    const meta = JSON.parse(
      execSync(`node ${CLI} metadata`, { encoding: "utf-8" }),
    ) as { colors: { count: number } };
    const scheme = JSON.parse(
      execSync(`node ${CLI} colors:scheme`, { encoding: "utf-8" }),
    ) as Record<string, unknown>;
    expect(meta.colors.count).toBe(Object.keys(scheme).length);
  });

  it("metadata channels count matches layout:channels output", () => {
    const meta = JSON.parse(
      execSync(`node ${CLI} metadata`, { encoding: "utf-8" }),
    ) as { channels: { count: number } };
    const channels = JSON.parse(
      execSync(`node ${CLI} layout:channels`, { encoding: "utf-8" }),
    ) as Record<string, unknown>;
    expect(meta.channels.count).toBe(Object.keys(channels).length);
  });

  it("metadata settings count matches config:settings output", () => {
    const meta = JSON.parse(
      execSync(`node ${CLI} metadata`, { encoding: "utf-8" }),
    ) as { managedSettings: { count: number } };
    const settings = JSON.parse(
      execSync(`node ${CLI} config:settings`, { encoding: "utf-8" }),
    ) as Record<string, unknown>;
    expect(meta.managedSettings.count).toBe(Object.keys(settings).length);
  });

  it("config:settings includes resolution keys", () => {
    const settings = JSON.parse(
      execSync(`node ${CLI} config:settings`, { encoding: "utf-8" }),
    ) as Record<string, string>;
    expect(settings).toHaveProperty("Width");
    expect(settings).toHaveProperty("Height");
    expect(settings).toHaveProperty("WindowedWidth");
    expect(settings).toHaveProperty("WindowedHeight");
  });
});

describe("shellcheck compliance", () => {
  it("all bash scripts pass shellcheck", () => {
    const { exitCode } = run("shellcheck --exclude=SC1091 scripts/*.sh 2>&1");
    expect(exitCode).toBe(0);
  });
});
