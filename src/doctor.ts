/**
 * Doctor module — health check system for norrath-native.
 *
 * Provides a structured check framework that validates system
 * dependencies, Wine prefix configuration, DXVK, EverQuest
 * installation, and deploy state.
 *
 * @module doctor
 */

import { existsSync, readFileSync } from "node:fs";
import { execSync } from "node:child_process";
import { join } from "node:path";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface CheckResult {
  id: string;
  status: "pass" | "warn" | "fail";
  message: string;
  fix?: string;
}

export interface DoctorReport {
  passed: number;
  warnings: number;
  failed: number;
  checks: CheckResult[];
}

export interface Check {
  id: string;
  name: string;
  run: () => CheckResult;
}

// ---------------------------------------------------------------------------
// Check factories
// ---------------------------------------------------------------------------

/**
 * Create a check that verifies a file exists.
 */
export function createFileCheck(
  id: string,
  description: string,
  filePath: string,
  fix: string,
): Check {
  return {
    id,
    name: description,
    run(): CheckResult {
      if (existsSync(filePath)) {
        return { id, status: "pass", message: description };
      }
      return { id, status: "fail", message: `${description}: not found`, fix };
    },
  };
}

/**
 * Create a check that greps a file for a pattern (substring match).
 */
export function createGrepCheck(
  id: string,
  description: string,
  filePath: string,
  pattern: string,
  fix: string,
): Check {
  return {
    id,
    name: description,
    run(): CheckResult {
      if (!existsSync(filePath)) {
        return {
          id,
          status: "fail",
          message: `${description}: file not found`,
          fix,
        };
      }
      const content = readFileSync(filePath, "utf-8");
      if (content.includes(pattern)) {
        return { id, status: "pass", message: description };
      }
      return {
        id,
        status: "fail",
        message: `${description}: pattern not found`,
        fix,
      };
    },
  };
}

/**
 * Create a check that runs a shell command and checks exit code.
 */
export function createCommandCheck(
  id: string,
  description: string,
  command: string,
  fix: string,
): Check {
  return {
    id,
    name: description,
    run(): CheckResult {
      try {
        execSync(command, { stdio: "pipe", timeout: 10_000 });
        return { id, status: "pass", message: description };
      } catch {
        return {
          id,
          status: "fail",
          message: `${description}: command failed`,
          fix,
        };
      }
    },
  };
}

// ---------------------------------------------------------------------------
// Runner
// ---------------------------------------------------------------------------

/**
 * Run all checks and return a structured report.
 */
export function runChecks(checks: readonly Check[]): DoctorReport {
  let passed = 0;
  let warnings = 0;
  let failed = 0;
  const results: CheckResult[] = [];

  for (const check of checks) {
    const result = check.run();
    results.push(result);
    switch (result.status) {
      case "pass":
        passed++;
        break;
      case "warn":
        warnings++;
        break;
      case "fail":
        failed++;
        break;
    }
  }

  return { passed, warnings, failed, checks: results };
}

// ---------------------------------------------------------------------------
// Formatters
// ---------------------------------------------------------------------------

/**
 * Format a report as a JSON string.
 */
export function formatJson(report: DoctorReport): string {
  return JSON.stringify(report, null, 2);
}

/**
 * Format a report with ANSI colors for terminal output.
 */
export function formatText(report: DoctorReport): string {
  const lines: string[] = [];

  lines.push("");
  lines.push("\x1b[1m=== Norrath-Native Health Check ===\x1b[0m");
  lines.push("");

  for (const check of report.checks) {
    switch (check.status) {
      case "pass":
        lines.push(`  \x1b[32m\u2713\x1b[0m ${check.message}`);
        break;
      case "warn":
        lines.push(`  \x1b[33m\u26a0\x1b[0m ${check.message}`);
        if (check.fix) {
          lines.push(`    \x1b[33mfix: ${check.fix}\x1b[0m`);
        }
        break;
      case "fail":
        lines.push(`  \x1b[31m\u2717\x1b[0m ${check.message}`);
        if (check.fix) {
          lines.push(`    \x1b[31mfix: ${check.fix}\x1b[0m`);
        }
        break;
    }
  }

  lines.push("");
  lines.push(
    `\x1b[1mSummary:\x1b[0m ` +
      `\x1b[32m${String(report.passed)} passed\x1b[0m, ` +
      `\x1b[33m${String(report.warnings)} warnings\x1b[0m, ` +
      `\x1b[31m${String(report.failed)} failed\x1b[0m`,
  );

  if (report.failed > 0) {
    lines.push("");
    lines.push("Run \x1b[36mmake deploy\x1b[0m to fix failed checks.");
  } else if (report.warnings > 0) {
    lines.push("");
    lines.push("System is functional but has warnings.");
  } else {
    lines.push("");
    lines.push("All checks passed. Ready to launch!");
  }

  lines.push("");
  return lines.join("\n");
}

// ---------------------------------------------------------------------------
// Default checks
// ---------------------------------------------------------------------------

/**
 * Build the full set of doctor checks for a given Wine prefix.
 */
function systemChecks(): Check[] {
  return [
    createCommandCheck(
      "SYS_WINE",
      "Wine installed",
      "wine64 --version || wine --version",
      "run: make prereqs",
    ),
    createCommandCheck(
      "SYS_VULKAN",
      "Vulkan tools installed",
      "vulkaninfo --summary",
      "run: make prereqs",
    ),
    createCommandCheck(
      "SYS_NTLM",
      "ntlm_auth (winbind) available",
      "command -v ntlm_auth",
      "sudo apt install winbind",
    ),
    createCommandCheck(
      "SYS_NODE",
      "Node.js installed",
      "node --version",
      "run: make prereqs",
    ),
  ];
}

function prefixChecks(prefix: string): Check[] {
  const userReg = join(prefix, "user.reg");
  const systemReg = join(prefix, "system.reg");
  return [
    createFileCheck(
      "PREFIX_EXISTS",
      "WINEPREFIX exists",
      prefix,
      "run: make deploy",
    ),
    createGrepCheck(
      "PREFIX_ARCH",
      "Prefix architecture is win64",
      systemReg,
      "#arch=win64",
      "run: make deploy",
    ),
    createFileCheck(
      "PREFIX_COREFONTS",
      "Microsoft core fonts installed",
      join(prefix, "drive_c/windows/Fonts/arial.ttf"),
      "run: make deploy",
    ),
    createGrepCheck(
      "PREFIX_MOUSE_CAPTURE",
      "Mouse capture configured",
      userReg,
      "MouseWarpOverride",
      "run: make deploy",
    ),
  ];
}

function dxvkChecks(prefix: string): Check[] {
  const sys32 = join(prefix, "drive_c/windows/system32");
  const wow64 = join(prefix, "drive_c/windows/syswow64");
  const userReg = join(prefix, "user.reg");
  return [
    createFileCheck(
      "DXVK_SYS32_D3D11",
      "d3d11.dll in system32 (x64)",
      join(sys32, "d3d11.dll"),
      "run: make deploy",
    ),
    createFileCheck(
      "DXVK_WOW64_D3D11",
      "d3d11.dll in syswow64 (x32)",
      join(wow64, "d3d11.dll"),
      "run: make deploy",
    ),
    createFileCheck(
      "DXVK_SYS32_DXGI",
      "dxgi.dll in system32 (x64)",
      join(sys32, "dxgi.dll"),
      "run: make deploy",
    ),
    createFileCheck(
      "DXVK_WOW64_DXGI",
      "dxgi.dll in syswow64 (x32)",
      join(wow64, "dxgi.dll"),
      "run: make deploy",
    ),
    createGrepCheck(
      "DXVK_OVERRIDE_D3D11",
      "DLL override: d3d11=native",
      userReg,
      '"d3d11"="native"',
      "run: make deploy",
    ),
    createGrepCheck(
      "DXVK_OVERRIDE_DXGI",
      "DLL override: dxgi=native",
      userReg,
      '"dxgi"="native"',
      "run: make deploy",
    ),
  ];
}

function eqCoreChecks(eqDir: string): Check[] {
  return [
    createFileCheck(
      "EQ_DIR",
      "EverQuest directory exists",
      eqDir,
      "run: make deploy",
    ),
    createFileCheck(
      "EQ_LAUNCHER",
      "LaunchPad.exe present",
      join(eqDir, "LaunchPad.exe"),
      "run: make deploy",
    ),
    createFileCheck(
      "EQ_INI",
      "eqclient.ini exists",
      join(eqDir, "eqclient.ini"),
      "run: make configure",
    ),
    createGrepCheck(
      "EQ_LOGGING",
      "EQ logging enabled (Log=TRUE)",
      join(eqDir, "eqclient.ini"),
      "Log=TRUE",
      "run: make configure",
    ),
  ];
}

function eqExtrasChecks(prefix: string, eqDir: string): Check[] {
  return [
    createFileCheck(
      "EQ_PATCHED",
      "Game binary present (eqgame.exe)",
      join(eqDir, "eqgame.exe"),
      "run make launch and let patcher finish",
    ),
    createFileCheck(
      "EQ_REMEMBER_ME",
      "Remember Me cookie database exists",
      join(eqDir, "LaunchPad.libs/LaunchPad.Cache/Cookies"),
      "check the box on next login",
    ),
    createFileCheck(
      "EQ_MAPS",
      "Good's maps installed",
      join(eqDir, "maps"),
      "make maps",
    ),
    createFileCheck(
      "EQ_DXVK_CONF",
      "DXVK config present (async shaders)",
      join(eqDir, "dxvk.conf"),
      "run: make deploy",
    ),
    createFileCheck(
      "EQ_PARSER",
      "EQLogParser installed",
      join(prefix, "drive_c/Program Files/EQLogParser/EQLogParser.exe"),
      "run: make parser",
    ),
  ];
}

function eqChecks(prefix: string): Check[] {
  const eqDir = join(prefix, "drive_c/EverQuest");
  return [...eqCoreChecks(eqDir), ...eqExtrasChecks(prefix, eqDir)];
}

function stateChecks(): Check[] {
  const home = process.env["HOME"] ?? "/tmp";
  const stateFile = join(home, ".local/share/norrath-native/state.json");
  const logDir = join(home, ".local/share/norrath-native");
  return [
    createFileCheck(
      "STATE_FILE",
      "Deploy state file exists",
      stateFile,
      "run: make deploy",
    ),
    createGrepCheck(
      "STATE_DEPLOYED_AT",
      "Deploy timestamp recorded",
      stateFile,
      '"deployed_at"',
      "run: make deploy",
    ),
    createGrepCheck(
      "STATE_WINE_VERSION",
      "Wine version recorded in state",
      stateFile,
      '"wine_version"',
      "run: make deploy",
    ),
    createGrepCheck(
      "STATE_DXVK_VERSION",
      "DXVK version recorded in state",
      stateFile,
      '"dxvk_version"',
      "run: make deploy",
    ),
    createFileCheck(
      "LOG_DIR",
      "Log directory exists",
      logDir,
      "run: make deploy",
    ),
    createFileCheck(
      "LOG_LAST_DEPLOY",
      "Deploy log exists",
      join(logDir, "deploy.log"),
      "run: make deploy",
    ),
  ];
}

export function buildDefaultChecks(prefix: string): Check[] {
  return [
    ...systemChecks(),
    ...prefixChecks(prefix),
    ...dxvkChecks(prefix),
    ...eqChecks(prefix),
    ...stateChecks(),
  ];
}
