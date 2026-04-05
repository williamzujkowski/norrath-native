import { describe, it, expect, beforeEach, afterEach } from "vitest";
import * as fs from "node:fs";
import * as path from "node:path";
import * as os from "node:os";
import { injectConfig, injectSettings } from "../src/config-injector.js";
import { MANAGED_INI_SETTINGS } from "../src/types/interfaces.js";

let tmpDir: string;

beforeEach(() => {
  tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "norrath-test-"));
});

afterEach(() => {
  fs.rmSync(tmpDir, { recursive: true, force: true });
});

// ---------------------------------------------------------------------------
// Test 1: Creation — generates a valid baseline file from scratch
// ---------------------------------------------------------------------------
describe("creation from scratch", () => {
  it("generates a file with all managed settings when none exists", () => {
    const iniPath = path.join(tmpDir, "eqclient.ini");
    const result = injectConfig(iniPath, tmpDir);

    expect(result.ok).toBe(true);
    expect(fs.existsSync(iniPath)).toBe(true);

    const content = fs.readFileSync(iniPath, "utf-8");
    expect(content).toContain("WindowedMode=TRUE");
    expect(content).toContain("UpdateInBackground=1");
    expect(content).toContain("MaxBGFPS=30");

    for (let i = 0; i <= 11; i++) {
      expect(content).toContain(`ClientCore${i}=-1`);
    }
  });

  it("creates parent directories if they do not exist", () => {
    const nested = path.join(tmpDir, "sub", "dir", "eqclient.ini");
    const result = injectConfig(nested, tmpDir);

    expect(result.ok).toBe(true);
    expect(fs.existsSync(nested)).toBe(true);
  });
});

// ---------------------------------------------------------------------------
// Test 2: Idempotent update — fixes managed keys, preserves user keys
// ---------------------------------------------------------------------------
describe("idempotent update", () => {
  it("updates managed keys without destroying user settings", () => {
    const iniPath = path.join(tmpDir, "eqclient.ini");
    const existing = [
      "[Defaults]",
      "MaxBGFPS=60",
      "CustomSetting=MyValue",
      "WindowedMode=FALSE",
      "",
    ].join("\n");

    fs.writeFileSync(iniPath, existing, "utf-8");
    const result = injectConfig(iniPath, tmpDir);

    expect(result.ok).toBe(true);
    const content = fs.readFileSync(iniPath, "utf-8");

    expect(content).toContain("MaxBGFPS=30");
    expect(content).toContain("WindowedMode=TRUE");
    expect(content).toContain("CustomSetting=MyValue");
    expect(content).not.toContain("MaxBGFPS=60");
    expect(content).not.toContain("WindowedMode=FALSE");
  });

  it("preserves section headers", () => {
    const iniPath = path.join(tmpDir, "eqclient.ini");
    fs.writeFileSync(iniPath, "[Defaults]\nCustom=1\n", "utf-8");

    injectConfig(iniPath, tmpDir);
    const content = fs.readFileSync(iniPath, "utf-8");

    expect(content).toContain("[Defaults]");
  });
});

// ---------------------------------------------------------------------------
// Test 3: Duplicate prevention — byte-identical on second run
// ---------------------------------------------------------------------------
describe("duplicate prevention", () => {
  it("produces byte-identical output on consecutive runs", () => {
    const iniPath = path.join(tmpDir, "eqclient.ini");

    injectConfig(iniPath, tmpDir);
    const first = fs.readFileSync(iniPath);

    injectConfig(iniPath, tmpDir);
    const second = fs.readFileSync(iniPath);

    expect(Buffer.compare(first, second)).toBe(0);
  });

  it("is byte-identical even with pre-existing user settings", () => {
    const iniPath = path.join(tmpDir, "eqclient.ini");
    fs.writeFileSync(iniPath, "UserKey=Hello\n", "utf-8");

    injectConfig(iniPath, tmpDir);
    const first = fs.readFileSync(iniPath);

    injectConfig(iniPath, tmpDir);
    const second = fs.readFileSync(iniPath);

    expect(Buffer.compare(first, second)).toBe(0);
  });
});

// ---------------------------------------------------------------------------
// Test 4: Path traversal — rejects escape attempts
// ---------------------------------------------------------------------------
describe("path traversal protection", () => {
  it("rejects relative traversal outside prefix", () => {
    const result = injectConfig(
      path.join(tmpDir, "..", "..", "etc", "passwd"),
      tmpDir,
    );

    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.error.message).toMatch(/path traversal/i);
    }
  });

  it("rejects absolute paths outside prefix", () => {
    const result = injectConfig("/etc/passwd", tmpDir);

    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.error.message).toMatch(/path traversal/i);
    }
  });

  it("accepts paths within the prefix boundary", () => {
    const iniPath = path.join(tmpDir, "game", "eqclient.ini");
    const result = injectConfig(iniPath, tmpDir);

    expect(result.ok).toBe(true);
  });
});

// ---------------------------------------------------------------------------
// Test 5a: Malformed input — basic formats
// ---------------------------------------------------------------------------
describe("malformed input basics", () => {
  it("handles file with no section headers", () => {
    const iniPath = path.join(tmpDir, "eqclient.ini");
    fs.writeFileSync(iniPath, "SomeKey=SomeValue\n", "utf-8");

    const result = injectConfig(iniPath, tmpDir);
    expect(result.ok).toBe(true);

    const content = fs.readFileSync(iniPath, "utf-8");
    expect(content).toContain("SomeKey=SomeValue");
    expect(content).toContain("WindowedMode=TRUE");
  });

  it("preserves blank lines and comments", () => {
    const iniPath = path.join(tmpDir, "eqclient.ini");
    const existing = [
      "; This is a comment",
      "# Another comment",
      "",
      "UserSetting=1",
      "",
    ].join("\n");
    fs.writeFileSync(iniPath, existing, "utf-8");

    const result = injectConfig(iniPath, tmpDir);
    expect(result.ok).toBe(true);

    const content = fs.readFileSync(iniPath, "utf-8");
    expect(content).toContain("; This is a comment");
    expect(content).toContain("# Another comment");
  });
});

// ---------------------------------------------------------------------------
// Test 5b: Malformed input — line endings and duplicates
// ---------------------------------------------------------------------------
describe("malformed input line endings and duplicates", () => {
  it("normalizes CRLF line endings to LF", () => {
    const iniPath = path.join(tmpDir, "eqclient.ini");
    fs.writeFileSync(iniPath, "Key1=A\r\nKey2=B\r\n", "utf-8");

    const result = injectConfig(iniPath, tmpDir);
    expect(result.ok).toBe(true);

    const raw = fs.readFileSync(iniPath, "utf-8");
    expect(raw).not.toContain("\r");
    expect(raw).toContain("Key1=A\n");
  });

  it("deduplicates keys keeping last value then applies managed", () => {
    const iniPath = path.join(tmpDir, "eqclient.ini");
    const existing = [
      "UserDup=First",
      "UserDup=Second",
      "MaxBGFPS=99",
      "MaxBGFPS=100",
    ].join("\n");
    fs.writeFileSync(iniPath, existing, "utf-8");

    const result = injectConfig(iniPath, tmpDir);
    expect(result.ok).toBe(true);

    const content = fs.readFileSync(iniPath, "utf-8");
    expect(content).toContain("UserDup=Second");

    const dupCount = content
      .split("\n")
      .filter((l: string) => l.startsWith("UserDup=")).length;
    expect(dupCount).toBe(1);

    expect(content).toContain("MaxBGFPS=30");
    expect(content).not.toContain("MaxBGFPS=99");
    expect(content).not.toContain("MaxBGFPS=100");
  });
});

// ---------------------------------------------------------------------------
// Sanity: all managed keys present in MANAGED_INI_SETTINGS
// ---------------------------------------------------------------------------
describe("managed settings completeness", () => {
  it("MANAGED_INI_SETTINGS includes all expected keys", () => {
    const keys = Object.keys(MANAGED_INI_SETTINGS);

    expect(keys).toContain("WindowedMode");
    expect(keys).toContain("UpdateInBackground");
    expect(keys).toContain("MaxBGFPS");

    for (let i = 0; i <= 11; i++) {
      expect(keys).toContain(`ClientCore${i}`);
    }

    expect(keys).toContain("Log");
    expect(keys).toHaveLength(16);
  });
});

// ---------------------------------------------------------------------------
// injectSettings — generic section-aware key injection
// ---------------------------------------------------------------------------
describe("injectSettings", () => {
  it("updates existing keys in a section", () => {
    const iniPath = path.join(tmpDir, "test.ini");
    fs.writeFileSync(iniPath, "[TextColors]\nUser_1_Red=255\nUser_1_Green=0\n");

    const result = injectSettings(
      iniPath,
      { User_1_Red: "128", User_1_Green: "64" },
      "TextColors",
    );
    expect(result.ok).toBe(true);
    if (result.ok) expect(result.value.changed).toBe(2);

    const content = fs.readFileSync(iniPath, "utf-8");
    expect(content).toContain("User_1_Red=128");
    expect(content).toContain("User_1_Green=64");
  });

  it("appends missing keys to existing section", () => {
    const iniPath = path.join(tmpDir, "test.ini");
    fs.writeFileSync(iniPath, "[ChatManager]\nNumWindows=2\n");

    const result = injectSettings(
      iniPath,
      { ChannelMap0: "0", ChannelMap1: "1" },
      "ChatManager",
    );
    expect(result.ok).toBe(true);
    if (result.ok) expect(result.value.changed).toBe(2);

    const content = fs.readFileSync(iniPath, "utf-8");
    expect(content).toContain("ChannelMap0=0");
    expect(content).toContain("ChannelMap1=1");
    expect(content).toContain("NumWindows=2");
  });

  it("creates section if not found", () => {
    const iniPath = path.join(tmpDir, "test.ini");
    fs.writeFileSync(iniPath, "[OtherSection]\nFoo=bar\n");

    const result = injectSettings(iniPath, { Key1: "val1" }, "NewSection");
    expect(result.ok).toBe(true);
    if (result.ok) expect(result.value.changed).toBe(1);

    const content = fs.readFileSync(iniPath, "utf-8");
    expect(content).toContain("[NewSection]");
    expect(content).toContain("Key1=val1");
    expect(content).toContain("[OtherSection]");
  });

  it("returns 0 changes when all values match", () => {
    const iniPath = path.join(tmpDir, "test.ini");
    fs.writeFileSync(iniPath, "[TextColors]\nUser_1_Red=128\n");

    const result = injectSettings(iniPath, { User_1_Red: "128" }, "TextColors");
    expect(result.ok).toBe(true);
    if (result.ok) expect(result.value.changed).toBe(0);
  });

  it("handles empty file", () => {
    const iniPath = path.join(tmpDir, "test.ini");
    fs.writeFileSync(iniPath, "");

    const result = injectSettings(iniPath, { Key1: "val1" }, "MySection");
    expect(result.ok).toBe(true);
    if (result.ok) expect(result.value.changed).toBe(1);

    const content = fs.readFileSync(iniPath, "utf-8");
    expect(content).toContain("[MySection]");
    expect(content).toContain("Key1=val1");
  });

  it("preserves keys in other sections", () => {
    const iniPath = path.join(tmpDir, "test.ini");
    fs.writeFileSync(iniPath, "[Section1]\nA=1\n[Section2]\nB=2\n");

    const result = injectSettings(iniPath, { A: "99" }, "Section1");
    expect(result.ok).toBe(true);

    const content = fs.readFileSync(iniPath, "utf-8");
    expect(content).toContain("A=99");
    expect(content).toContain("B=2");
  });
});
