import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { writeFileSync, mkdirSync, rmSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import {
  createFileCheck,
  createGrepCheck,
  createCommandCheck,
  buildDefaultChecks,
  runChecks,
  formatJson,
  formatText,
  type Check,
  type DoctorReport,
} from "../src/doctor.js";

describe("createFileCheck", () => {
  let tempDir: string;

  beforeEach(() => {
    tempDir = join(tmpdir(), `nn-doctor-test-${Date.now()}`);
    mkdirSync(tempDir, { recursive: true });
  });

  afterEach(() => {
    rmSync(tempDir, { recursive: true, force: true });
  });

  it("creates a check with id, name, and check function", () => {
    const check = createFileCheck(
      "TEST_FILE",
      "Test file exists",
      join(tempDir, "somefile"),
      "create the file",
    );
    expect(check.id).toBe("TEST_FILE");
    expect(check.name).toBe("Test file exists");
    expect(typeof check.run).toBe("function");
  });

  it("passes for existing file", () => {
    const filePath = join(tempDir, "exists.txt");
    writeFileSync(filePath, "content");
    const check = createFileCheck(
      "EXISTS",
      "File exists",
      filePath,
      "create it",
    );
    const result = check.run();
    expect(result.status).toBe("pass");
    expect(result.id).toBe("EXISTS");
  });

  it("fails for missing file", () => {
    const check = createFileCheck(
      "MISSING",
      "File should exist",
      join(tempDir, "nope.txt"),
      "create the file",
    );
    const result = check.run();
    expect(result.status).toBe("fail");
    expect(result.fix).toBe("create the file");
  });
});

describe("createGrepCheck", () => {
  let tempDir: string;

  beforeEach(() => {
    tempDir = join(tmpdir(), `nn-doctor-grep-${Date.now()}`);
    mkdirSync(tempDir, { recursive: true });
  });

  afterEach(() => {
    rmSync(tempDir, { recursive: true, force: true });
  });

  it("passes when pattern matches file content", () => {
    const filePath = join(tempDir, "registry.reg");
    writeFileSync(filePath, '"d3d11"="native"\n"dxgi"="native"\n');
    const check = createGrepCheck(
      "GREP_MATCH",
      "Pattern found",
      filePath,
      '"d3d11"="native"',
      "run deploy",
    );
    const result = check.run();
    expect(result.status).toBe("pass");
  });

  it("fails when pattern does not match", () => {
    const filePath = join(tempDir, "registry.reg");
    writeFileSync(filePath, "some other content\n");
    const check = createGrepCheck(
      "GREP_MISS",
      "Pattern should exist",
      filePath,
      '"d3d11"="native"',
      "run deploy",
    );
    const result = check.run();
    expect(result.status).toBe("fail");
    expect(result.fix).toBe("run deploy");
  });

  it("fails when file does not exist", () => {
    const check = createGrepCheck(
      "GREP_NO_FILE",
      "File missing",
      join(tempDir, "nope.reg"),
      "pattern",
      "create file",
    );
    const result = check.run();
    expect(result.status).toBe("fail");
  });
});

describe("runChecks", () => {
  it("runs all checks and returns structured results", () => {
    const checks: Check[] = [
      {
        id: "A",
        name: "Check A",
        run: () => ({ id: "A", status: "pass", message: "A ok" }),
      },
      {
        id: "B",
        name: "Check B",
        run: () => ({
          id: "B",
          status: "warn",
          message: "B warn",
          fix: "fix B",
        }),
      },
      {
        id: "C",
        name: "Check C",
        run: () => ({
          id: "C",
          status: "fail",
          message: "C fail",
          fix: "fix C",
        }),
      },
    ];
    const report = runChecks(checks);
    expect(report.checks).toHaveLength(3);
  });

  it("counts pass/warn/fail correctly", () => {
    const checks: Check[] = [
      {
        id: "P1",
        name: "Pass 1",
        run: () => ({ id: "P1", status: "pass", message: "ok" }),
      },
      {
        id: "P2",
        name: "Pass 2",
        run: () => ({ id: "P2", status: "pass", message: "ok" }),
      },
      {
        id: "W1",
        name: "Warn 1",
        run: () => ({
          id: "W1",
          status: "warn",
          message: "w",
          fix: "f",
        }),
      },
      {
        id: "F1",
        name: "Fail 1",
        run: () => ({
          id: "F1",
          status: "fail",
          message: "f",
          fix: "f",
        }),
      },
    ];
    const report = runChecks(checks);
    expect(report.passed).toBe(2);
    expect(report.warnings).toBe(1);
    expect(report.failed).toBe(1);
  });

  it("check that returns pass is counted as passed", () => {
    const checks: Check[] = [
      {
        id: "PASS",
        name: "Pass",
        run: () => ({ id: "PASS", status: "pass", message: "ok" }),
      },
    ];
    const report = runChecks(checks);
    expect(report.passed).toBe(1);
    expect(report.warnings).toBe(0);
    expect(report.failed).toBe(0);
  });

  it("check that returns warn includes fix suggestion", () => {
    const checks: Check[] = [
      {
        id: "W",
        name: "Warn",
        run: () => ({
          id: "W",
          status: "warn",
          message: "warning",
          fix: "do this",
        }),
      },
    ];
    const report = runChecks(checks);
    expect(report.checks[0]?.fix).toBe("do this");
  });

  it("check that returns fail includes fix suggestion", () => {
    const checks: Check[] = [
      {
        id: "F",
        name: "Fail",
        run: () => ({
          id: "F",
          status: "fail",
          message: "failed",
          fix: "fix it",
        }),
      },
    ];
    const report = runChecks(checks);
    expect(report.checks[0]?.fix).toBe("fix it");
  });
});

describe("formatJson", () => {
  it("produces valid JSON with checks array", () => {
    const report: DoctorReport = {
      passed: 1,
      warnings: 0,
      failed: 0,
      checks: [{ id: "X", status: "pass", message: "ok" }],
    };
    const json = formatJson(report);
    const parsed = JSON.parse(json) as DoctorReport;
    expect(Array.isArray(parsed.checks)).toBe(true);
    expect(parsed.checks).toHaveLength(1);
  });

  it("includes passed/warnings/failed counts", () => {
    const report: DoctorReport = {
      passed: 3,
      warnings: 2,
      failed: 1,
      checks: [],
    };
    const json = formatJson(report);
    const parsed = JSON.parse(json) as DoctorReport;
    expect(parsed.passed).toBe(3);
    expect(parsed.warnings).toBe(2);
    expect(parsed.failed).toBe(1);
  });
});

describe("createCommandCheck", () => {
  it("passes when command succeeds", () => {
    const check = createCommandCheck("CMD_OK", "True runs", "true", "n/a");
    const result = check.run();
    expect(result.status).toBe("pass");
  });

  it("fails when command fails", () => {
    const check = createCommandCheck(
      "CMD_FAIL",
      "False fails",
      "false",
      "fix it",
    );
    const result = check.run();
    expect(result.status).toBe("fail");
    expect(result.fix).toBe("fix it");
  });

  it("fails on nonexistent command", () => {
    const check = createCommandCheck(
      "CMD_NOEXIST",
      "Bad cmd",
      "nonexistent_cmd_xyz",
      "fix",
    );
    const result = check.run();
    expect(result.status).toBe("fail");
  });

  it("captures stderr in failure message", () => {
    const check = createCommandCheck(
      "CMD_ERR",
      "Error output",
      "echo error_detail >&2 && false",
      "fix",
    );
    const result = check.run();
    expect(result.status).toBe("fail");
    expect(result.message).toContain("error_detail");
  });
});

describe("buildDefaultChecks", () => {
  it("returns an array of checks", () => {
    const checks = buildDefaultChecks("/tmp/fake-prefix");
    expect(Array.isArray(checks)).toBe(true);
    expect(checks.length).toBe(30);
  });

  it("all checks have id and name", () => {
    const checks = buildDefaultChecks("/tmp/fake-prefix");
    for (const check of checks) {
      expect(check.id).toBeTruthy();
      expect(check.name).toBeTruthy();
    }
  });

  it("all checks are runnable", () => {
    const checks = buildDefaultChecks("/tmp/fake-prefix");
    for (const check of checks) {
      const result = check.run();
      expect(result.id).toBe(check.id);
      expect(["pass", "warn", "fail"]).toContain(result.status);
    }
  });
});

describe("formatText", () => {
  it("produces ANSI text output", () => {
    const report: DoctorReport = {
      passed: 1,
      warnings: 0,
      failed: 0,
      checks: [{ id: "T", status: "pass", message: "ok" }],
    };
    const text = formatText(report);
    expect(text).toContain("pass");
    expect(text).toContain("ok");
  });

  it("shows detail in verbose mode", () => {
    const report: DoctorReport = {
      passed: 1,
      warnings: 0,
      failed: 0,
      checks: [
        { id: "T", status: "pass", message: "ok", detail: "/path/to/file" },
      ],
    };
    const text = formatText(report, true);
    expect(text).toContain("/path/to/file");
  });

  it("hides detail in non-verbose mode", () => {
    const report: DoctorReport = {
      passed: 1,
      warnings: 0,
      failed: 0,
      checks: [
        { id: "T", status: "pass", message: "ok", detail: "/path/to/file" },
      ],
    };
    const text = formatText(report, false);
    expect(text).not.toContain("/path/to/file");
  });
});
