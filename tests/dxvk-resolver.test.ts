import { describe, it, expect } from "vitest";
import {
  resolveLatestDxvk,
  filterStableReleases,
  parseVersion,
  meetsMinimumVersion,
  DXVK_RELEASES_URL,
  type FetchFn,
} from "../src/dxvk-resolver.js";

// ---------------------------------------------------------------------------
// Helpers to build mock GitHub release objects
// ---------------------------------------------------------------------------

interface MockAsset {
  name: string;
  browser_download_url: string;
}

interface MockRelease {
  tag_name: string;
  prerelease: boolean;
  draft: boolean;
  assets: MockAsset[];
}

function makeRelease(
  tag: string,
  opts: Partial<{
    prerelease: boolean;
    draft: boolean;
    assets: MockAsset[];
  }> = {},
): MockRelease {
  return {
    tag_name: tag,
    prerelease: opts.prerelease ?? false,
    draft: opts.draft ?? false,
    assets: opts.assets ?? [
      {
        name: `dxvk-${tag.replace(/^v/, "")}.tar.gz`,
        browser_download_url: `https://github.com/doitsujin/dxvk/releases/download/${tag}/dxvk-${tag.replace(/^v/, "")}.tar.gz`,
      },
    ],
  };
}

function makeFetch(releases: MockRelease[]): FetchFn {
  return async (_url, _init) =>
    ({
      ok: true,
      status: 200,
      json: async () => releases,
    }) as Awaited<ReturnType<FetchFn>>;
}

function makeFailingFetch(status: number): FetchFn {
  return async (_url, _init) =>
    ({
      ok: false,
      status,
      json: async () => null,
    }) as Awaited<ReturnType<FetchFn>>;
}

// ---------------------------------------------------------------------------
// parseVersion
// ---------------------------------------------------------------------------

describe("parseVersion", () => {
  it("parses a full semver tag with v prefix", () => {
    expect(parseVersion("v2.7.1")).toEqual([2, 7, 1]);
  });

  it("parses a semver tag without v prefix", () => {
    expect(parseVersion("2.5.3")).toEqual([2, 5, 3]);
  });

  it("parses a major.minor tag (no patch) as patch 0", () => {
    expect(parseVersion("v2.4")).toEqual([2, 4, 0]);
  });

  it("returns null for an invalid tag", () => {
    expect(parseVersion("not-a-version")).toBeNull();
  });

  it("returns null for an empty string", () => {
    expect(parseVersion("")).toBeNull();
  });

  it('returns null for a partial string like "v2"', () => {
    expect(parseVersion("v2")).toBeNull();
  });
});

// ---------------------------------------------------------------------------
// meetsMinimumVersion
// ---------------------------------------------------------------------------

describe("meetsMinimumVersion", () => {
  it("returns true when version equals minimum", () => {
    expect(meetsMinimumVersion("2.4", "2.4")).toBe(true);
  });

  it("returns true when major version exceeds minimum", () => {
    expect(meetsMinimumVersion("3.0.0", "2.4")).toBe(true);
  });

  it("returns true when minor version exceeds minimum", () => {
    expect(meetsMinimumVersion("2.7.1", "2.4")).toBe(true);
  });

  it("returns true when patch version exceeds minimum", () => {
    expect(meetsMinimumVersion("2.4.1", "2.4.0")).toBe(true);
  });

  it("returns false when minor version is below minimum", () => {
    expect(meetsMinimumVersion("2.3.9", "2.4")).toBe(false);
  });

  it("returns false when major version is below minimum", () => {
    expect(meetsMinimumVersion("1.99.99", "2.4")).toBe(false);
  });

  it("returns false when either version string is invalid", () => {
    expect(meetsMinimumVersion("bad", "2.4")).toBe(false);
    expect(meetsMinimumVersion("2.4", "bad")).toBe(false);
  });
});

// ---------------------------------------------------------------------------
// filterStableReleases
// ---------------------------------------------------------------------------

describe("filterStableReleases", () => {
  it("passes through a stable release above the minimum", () => {
    const releases = [makeRelease("v2.7.1")];
    expect(filterStableReleases(releases)).toHaveLength(1);
  });

  it("filters out prerelease releases", () => {
    const releases = [makeRelease("v2.7.1", { prerelease: true })];
    expect(filterStableReleases(releases)).toHaveLength(0);
  });

  it("filters out draft releases", () => {
    const releases = [makeRelease("v2.7.1", { draft: true })];
    expect(filterStableReleases(releases)).toHaveLength(0);
  });

  it('filters out tags containing "beta"', () => {
    const releases = [makeRelease("v2.7.0-beta.1")];
    expect(filterStableReleases(releases)).toHaveLength(0);
  });

  it('filters out tags containing "alpha"', () => {
    const releases = [makeRelease("v2.7.0-alpha")];
    expect(filterStableReleases(releases)).toHaveLength(0);
  });

  it('filters out tags containing "rc"', () => {
    const releases = [makeRelease("v2.8.0-rc1")];
    expect(filterStableReleases(releases)).toHaveLength(0);
  });

  it("rejects versions below the minimum floor (2.4)", () => {
    const releases = [makeRelease("v2.3.0")];
    expect(filterStableReleases(releases)).toHaveLength(0);
  });

  it("accepts the exact minimum version (v2.4)", () => {
    const releases = [makeRelease("v2.4.0")];
    expect(filterStableReleases(releases)).toHaveLength(1);
  });

  it("returns only stable releases from a mixed list", () => {
    const releases = [
      makeRelease("v2.7.1"),
      makeRelease("v2.7.0-beta.1", { prerelease: true }),
      makeRelease("v2.6.2", { draft: true }),
      makeRelease("v2.6.1"),
      makeRelease("v2.3.0"),
    ];
    const stable = filterStableReleases(releases);
    expect(stable).toHaveLength(2);
    expect(stable.map((r) => r.tag_name)).toEqual(["v2.7.1", "v2.6.1"]);
  });

  it("returns an empty array when given an empty list", () => {
    expect(filterStableReleases([])).toEqual([]);
  });
});

// ---------------------------------------------------------------------------
// resolveLatestDxvk — integration-style with mocked fetch
// ---------------------------------------------------------------------------

describe("resolveLatestDxvk", () => {
  it("resolves the latest stable release from a typical API response", async () => {
    const fetch = makeFetch([
      makeRelease("v2.7.1"),
      makeRelease("v2.7.0"),
      makeRelease("v2.6.2"),
    ]);

    const result = await resolveLatestDxvk(fetch);

    expect(result.ok).toBe(true);
    if (!result.ok) throw new Error("Expected ok result");

    expect(result.value.version).toBe("2.7.1");
    expect(result.value.tarballName).toBe("dxvk-2.7.1.tar.gz");
    expect(result.value.downloadUrl).toContain("dxvk-2.7.1.tar.gz");
  });

  it('strips the leading "v" from the resolved version string', async () => {
    const fetch = makeFetch([makeRelease("v2.5.3")]);
    const result = await resolveLatestDxvk(fetch);

    expect(result.ok).toBe(true);
    if (!result.ok) throw new Error("Expected ok result");
    expect(result.value.version).toBe("2.5.3");
    expect(result.value.version.startsWith("v")).toBe(false);
  });

  it("skips prerelease and draft entries and resolves next stable", async () => {
    const fetch = makeFetch([
      makeRelease("v2.8.0-beta.1", { prerelease: true }),
      makeRelease("v2.7.1", { draft: true }),
      makeRelease("v2.7.0"),
    ]);

    const result = await resolveLatestDxvk(fetch);

    expect(result.ok).toBe(true);
    if (!result.ok) throw new Error("Expected ok result");
    expect(result.value.version).toBe("2.7.0");
  });

  it("returns an error when HTTP response is not ok (404)", async () => {
    const fetch = makeFailingFetch(404);
    const result = await resolveLatestDxvk(fetch);

    expect(result.ok).toBe(false);
    if (result.ok) throw new Error("Expected error result");
    expect(result.error.message).toMatch(/404/);
  });

  it("returns an error when HTTP response is a server error (500)", async () => {
    const fetch = makeFailingFetch(500);
    const result = await resolveLatestDxvk(fetch);

    expect(result.ok).toBe(false);
    if (result.ok) throw new Error("Expected error result");
    expect(result.error.message).toMatch(/500/);
  });

  it("returns an error when the releases list is empty", async () => {
    const fetch = makeFetch([]);
    const result = await resolveLatestDxvk(fetch);

    expect(result.ok).toBe(false);
    if (result.ok) throw new Error("Expected error result");
    expect(result.error.message).toMatch(/no stable dxvk release/i);
  });

  it("returns an error when all releases are below the minimum version", async () => {
    const fetch = makeFetch([makeRelease("v2.3.0"), makeRelease("v2.2.1")]);
    const result = await resolveLatestDxvk(fetch);

    expect(result.ok).toBe(false);
    if (result.ok) throw new Error("Expected error result");
    expect(result.error.message).toMatch(/no stable dxvk release/i);
  });

  it("returns an error when the latest stable release has no tarball asset", async () => {
    const releaseWithoutTarball: MockRelease = {
      tag_name: "v2.7.1",
      prerelease: false,
      draft: false,
      assets: [
        {
          name: "dxvk-2.7.1-checksums.txt",
          browser_download_url:
            "https://github.com/doitsujin/dxvk/releases/download/v2.7.1/dxvk-2.7.1-checksums.txt",
        },
      ],
    };
    const fetch = makeFetch([releaseWithoutTarball]);
    const result = await resolveLatestDxvk(fetch);

    expect(result.ok).toBe(false);
    if (result.ok) throw new Error("Expected error result");
    expect(result.error.message).toMatch(/no .tar.gz asset/i);
  });

  it("returns an error when the API response is not an array", async () => {
    const fetch: FetchFn = async (_url, _init) =>
      ({
        ok: true,
        status: 200,
        json: async () => ({ error: "rate limited" }),
      }) as Awaited<ReturnType<FetchFn>>;

    const result = await resolveLatestDxvk(fetch);

    expect(result.ok).toBe(false);
    if (result.ok) throw new Error("Expected error result");
    expect(result.error.message).toMatch(/unexpected api response/i);
  });

  it("uses the correct GitHub API URL", async () => {
    let capturedUrl: string | null = null;
    const fetch: FetchFn = async (url, _init) => {
      capturedUrl = url;
      return {
        ok: true,
        status: 200,
        json: async () => [makeRelease("v2.7.1")],
      } as Awaited<ReturnType<FetchFn>>;
    };

    await resolveLatestDxvk(fetch);

    expect(capturedUrl).toBe(DXVK_RELEASES_URL);
  });

  it("sends the correct Accept header to the GitHub API", async () => {
    let capturedHeaders: Record<string, string> | undefined;
    const fetch: FetchFn = async (_url, init) => {
      capturedHeaders = init?.headers;
      return {
        ok: true,
        status: 200,
        json: async () => [makeRelease("v2.7.1")],
      } as Awaited<ReturnType<FetchFn>>;
    };

    await resolveLatestDxvk(fetch);

    expect(capturedHeaders).toBeDefined();
    expect(capturedHeaders?.["Accept"]).toBe("application/vnd.github.v3+json");
  });

  it("selects the tarball asset by name pattern (dxvk-*.tar.gz)", async () => {
    const releaseMultipleAssets: MockRelease = {
      tag_name: "v2.7.1",
      prerelease: false,
      draft: false,
      assets: [
        {
          name: "dxvk-2.7.1-checksums.txt",
          browser_download_url:
            "https://github.com/doitsujin/dxvk/releases/download/v2.7.1/dxvk-2.7.1-checksums.txt",
        },
        {
          name: "dxvk-2.7.1.tar.gz",
          browser_download_url:
            "https://github.com/doitsujin/dxvk/releases/download/v2.7.1/dxvk-2.7.1.tar.gz",
        },
        {
          name: "something-else.zip",
          browser_download_url:
            "https://github.com/doitsujin/dxvk/releases/download/v2.7.1/something-else.zip",
        },
      ],
    };
    const fetch = makeFetch([releaseMultipleAssets]);
    const result = await resolveLatestDxvk(fetch);

    expect(result.ok).toBe(true);
    if (!result.ok) throw new Error("Expected ok result");
    expect(result.value.tarballName).toBe("dxvk-2.7.1.tar.gz");
  });
});
