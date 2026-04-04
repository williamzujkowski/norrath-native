/**
 * DXVK release resolver — reference implementation.
 * The actual DXVK resolution in production is done by deploy_eq_env.sh
 * via the GitHub API. This module serves as a typed reference and
 * is tested to validate the resolution logic.
 *
 * Queries the GitHub Releases API for doitsujin/dxvk and returns metadata
 * for the latest stable release that meets the minimum version floor.
 *
 * HTTP is injected via a fetch function parameter so the module is fully
 * testable without network access.
 */

import type { DxvkRelease, Result } from './types/interfaces.js';
import { MIN_DXVK_VERSION } from './types/interfaces.js';

// ---------------------------------------------------------------------------
// Public constants
// ---------------------------------------------------------------------------

export const DXVK_RELEASES_URL =
  'https://api.github.com/repos/doitsujin/dxvk/releases';

// ---------------------------------------------------------------------------
// Internal types for the GitHub Releases API response subset we need
// ---------------------------------------------------------------------------

interface GitHubAsset {
  name: string;
  browser_download_url: string;
}

interface GitHubRelease {
  tag_name: string;
  draft: boolean;
  prerelease: boolean;
  assets: GitHubAsset[];
}

// ---------------------------------------------------------------------------
// Version helpers
// ---------------------------------------------------------------------------

/** Parse a version tag like "v2.5.3" or "2.5.3" into [major, minor, patch]. */
export function parseVersion(tag: string): [number, number, number] | null {
  const match = /^v?(\d+)\.(\d+)(?:\.(\d+))?$/.exec(tag);
  if (!match) return null;
  return [
    Number(match[1]),
    Number(match[2]),
    Number(match[3] ?? '0'),
  ];
}

/** Returns true when `version` >= `minimum` (both as dotted strings). */
export function meetsMinimumVersion(version: string, minimum: string): boolean {
  const v = parseVersion(version);
  const m = parseVersion(minimum);
  if (!v || !m) return false;

  for (let i = 0; i < 3; i++) {
    if (v[i] > m[i]) return true;
    if (v[i] < m[i]) return false;
  }
  return true; // equal
}

// ---------------------------------------------------------------------------
// Fetch type accepted by the resolver (subset of global fetch)
// ---------------------------------------------------------------------------

export type FetchFn = (
  url: string,
  init?: { headers?: Record<string, string> },
) => Promise<{ ok: boolean; status: number; json(): Promise<unknown> }>;

// ---------------------------------------------------------------------------
// Release filtering
// ---------------------------------------------------------------------------

/** Find the tarball asset in a release's asset list. */
function findTarball(assets: GitHubAsset[]): GitHubAsset | undefined {
  return assets.find(
    (a) => a.name.endsWith('.tar.gz') && a.name.startsWith('dxvk-'),
  );
}

/** Filter releases to stable-only and above the version floor. */
export function filterStableReleases(
  releases: GitHubRelease[],
): GitHubRelease[] {
  return releases.filter((r) => {
    if (r.draft || r.prerelease) return false;
    // Exclude tags containing pre-release identifiers
    if (/alpha|beta|rc/i.test(r.tag_name)) return false;
    return meetsMinimumVersion(r.tag_name, MIN_DXVK_VERSION);
  });
}

// ---------------------------------------------------------------------------
// Public resolver
// ---------------------------------------------------------------------------

/**
 * Resolve the latest stable DXVK release from the GitHub API.
 *
 * @param fetchFn - Injected fetch implementation (for testability).
 * @returns A Result containing the resolved DxvkRelease or an Error.
 */
export async function resolveLatestDxvk(
  fetchFn: FetchFn,
): Promise<Result<DxvkRelease, Error>> {
  const response = await fetchFn(DXVK_RELEASES_URL, {
    headers: { Accept: 'application/vnd.github.v3+json' },
  });

  if (!response.ok) {
    return {
      ok: false,
      error: new Error(
        `GitHub API returned HTTP ${String(response.status)}`,
      ),
    };
  }

  const body: unknown = await response.json();
  if (!Array.isArray(body)) {
    return { ok: false, error: new Error('Unexpected API response shape') };
  }

  const stable = filterStableReleases(body as GitHubRelease[]);
  if (stable.length === 0) {
    return {
      ok: false,
      error: new Error(
        `No stable DXVK release found >= ${MIN_DXVK_VERSION}`,
      ),
    };
  }

  // GitHub returns releases newest-first; take the first stable match.
  const latest = stable[0];
  const tarball = findTarball(latest.assets);
  if (!tarball) {
    return {
      ok: false,
      error: new Error(
        `Release ${latest.tag_name} has no .tar.gz asset`,
      ),
    };
  }

  const version = latest.tag_name.replace(/^v/, '');
  return {
    ok: true,
    value: {
      version,
      downloadUrl: tarball.browser_download_url,
      tarballName: tarball.name,
    },
  };
}
