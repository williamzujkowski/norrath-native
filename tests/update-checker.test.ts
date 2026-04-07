import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { writeFileSync, mkdirSync, rmSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { checkDxvkUpdate, checkWineUpdate } from "../src/update-checker.js";

describe("checkDxvkUpdate", () => {
  let tempDir: string;

  beforeEach(() => {
    tempDir = join(tmpdir(), `nn-update-test-${Date.now()}`);
    mkdirSync(tempDir, { recursive: true });
  });

  afterEach(() => {
    rmSync(tempDir, { recursive: true, force: true });
  });

  it("returns up-to-date when installed matches latest", async () => {
    const stateFile = join(tempDir, "state.json");
    writeFileSync(stateFile, JSON.stringify({ dxvk_version: "2.5.3" }));
    const fakeFetch = makeFakeFetch([
      {
        tag_name: "v2.5.3",
        draft: false,
        prerelease: false,
        assets: [tarball("2.5.3")],
      },
    ]);
    const result = await checkDxvkUpdate(stateFile, fakeFetch);
    expect(result.status).toBe("up-to-date");
    expect(result.installed).toBe("2.5.3");
    expect(result.latest).toBe("2.5.3");
  });

  it("returns update-available when newer version exists", async () => {
    const stateFile = join(tempDir, "state.json");
    writeFileSync(stateFile, JSON.stringify({ dxvk_version: "2.4.0" }));
    const fakeFetch = makeFakeFetch([
      {
        tag_name: "v2.5.3",
        draft: false,
        prerelease: false,
        assets: [tarball("2.5.3")],
      },
      {
        tag_name: "v2.4.0",
        draft: false,
        prerelease: false,
        assets: [tarball("2.4.0")],
      },
    ]);
    const result = await checkDxvkUpdate(stateFile, fakeFetch);
    expect(result.status).toBe("update-available");
    expect(result.installed).toBe("2.4.0");
    expect(result.latest).toBe("2.5.3");
  });

  it("returns unknown when state file missing", async () => {
    const fakeFetch = makeFakeFetch([]);
    const result = await checkDxvkUpdate(
      join(tempDir, "nonexistent.json"),
      fakeFetch,
    );
    expect(result.status).toBe("unknown");
  });

  it("returns error when API fails", async () => {
    const stateFile = join(tempDir, "state.json");
    writeFileSync(stateFile, JSON.stringify({ dxvk_version: "2.4.0" }));
    const fakeFetch = makeFakeFetchError(500);
    const result = await checkDxvkUpdate(stateFile, fakeFetch);
    expect(result.status).toBe("error");
  });

  it("skips draft and prerelease versions", async () => {
    const stateFile = join(tempDir, "state.json");
    writeFileSync(stateFile, JSON.stringify({ dxvk_version: "2.4.0" }));
    const fakeFetch = makeFakeFetch([
      {
        tag_name: "v2.6.0-rc1",
        draft: false,
        prerelease: true,
        assets: [tarball("2.6.0-rc1")],
      },
      {
        tag_name: "v2.5.0",
        draft: true,
        prerelease: false,
        assets: [tarball("2.5.0")],
      },
      {
        tag_name: "v2.4.0",
        draft: false,
        prerelease: false,
        assets: [tarball("2.4.0")],
      },
    ]);
    const result = await checkDxvkUpdate(stateFile, fakeFetch);
    expect(result.status).toBe("up-to-date");
    expect(result.latest).toBe("2.4.0");
  });
});

describe("checkWineUpdate", () => {
  it("returns up-to-date when installed >= minimum", () => {
    const result = checkWineUpdate("wine-11.5");
    expect(result.status).toBe("up-to-date");
  });

  it("returns update-available when below minimum", () => {
    const result = checkWineUpdate("wine-9.0");
    expect(result.status).toBe("update-available");
    expect(result.installed).toBe("9.0");
  });

  it("handles wine64 version string", () => {
    const result = checkWineUpdate("wine-11.0 (Ubuntu 11.0~repack-4)");
    expect(result.status).toBe("up-to-date");
    expect(result.installed).toBe("11.0");
  });

  it("returns unknown for unparseable version", () => {
    const result = checkWineUpdate("");
    expect(result.status).toBe("unknown");
  });
});

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

function tarball(version: string) {
  return {
    name: `dxvk-${version}.tar.gz`,
    browser_download_url: `https://example.com/dxvk-${version}.tar.gz`,
  };
}

function makeFakeFetch(releases: unknown[]) {
  return async () => ({
    ok: true,
    status: 200,
    json: () => Promise.resolve(releases),
  });
}

function makeFakeFetchError(status: number) {
  return async () => ({
    ok: false,
    status,
    json: () => Promise.resolve({}),
  });
}
