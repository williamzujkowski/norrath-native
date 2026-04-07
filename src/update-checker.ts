/**
 * Update checker — compares installed versions against latest available.
 *
 * Checks DXVK (via GitHub API) and Wine (via version string comparison)
 * against deployed state. Non-intrusive: returns status only, never
 * auto-updates.
 *
 * @module update-checker
 */

import { existsSync, readFileSync } from "node:fs";
import {
  filterStableReleases,
  DXVK_RELEASES_URL,
  meetsMinimumVersion,
  type FetchFn,
} from "./dxvk-resolver.js";
import { MIN_WINE_VERSION } from "./types/interfaces.js";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface UpdateStatus {
  component: "dxvk" | "wine";
  status: "up-to-date" | "update-available" | "unknown" | "error";
  installed?: string;
  latest?: string;
  message: string;
}

// ---------------------------------------------------------------------------
// GitHub release shape (minimal subset)
// ---------------------------------------------------------------------------

interface GitHubRelease {
  tag_name: string;
  draft: boolean;
  prerelease: boolean;
  assets: { name: string; browser_download_url: string }[];
}

// ---------------------------------------------------------------------------
// DXVK update check
// ---------------------------------------------------------------------------

/** Fetch the latest stable DXVK version string from GitHub. */
async function fetchLatestDxvkVersion(
  fetchFn: FetchFn,
): Promise<{ version: string } | { error: string }> {
  const response = await fetchFn(DXVK_RELEASES_URL, {
    headers: { Accept: "application/vnd.github.v3+json" },
  });
  if (!response.ok) {
    return { error: `GitHub API returned HTTP ${String(response.status)}` };
  }
  const body: unknown = await response.json();
  if (!Array.isArray(body)) {
    return { error: "Unexpected API response shape" };
  }
  const stable = filterStableReleases(body as GitHubRelease[]);
  const latestRelease = stable[0];
  if (latestRelease === undefined) {
    return { error: "No stable DXVK releases found" };
  }
  return { version: latestRelease.tag_name.replace(/^v/, "") };
}

/** Compare installed vs latest DXVK version. */
function compareDxvkVersions(installed: string, latest: string): UpdateStatus {
  if (meetsMinimumVersion(installed, latest)) {
    return {
      component: "dxvk",
      status: "up-to-date",
      installed,
      latest,
      message: `DXVK ${installed} is current`,
    };
  }
  return {
    component: "dxvk",
    status: "update-available",
    installed,
    latest,
    message: `DXVK ${latest} available (installed: ${installed})`,
  };
}

/**
 * Check if DXVK has a newer stable release than what's deployed.
 *
 * Reads the installed version from state.json, queries GitHub for latest.
 */
export async function checkDxvkUpdate(
  stateFilePath: string,
  fetchFn: FetchFn,
): Promise<UpdateStatus> {
  const installed = readDxvkVersion(stateFilePath);
  if (installed === undefined) {
    return {
      component: "dxvk",
      status: "unknown",
      message: "No deployed DXVK version found in state file",
    };
  }

  try {
    const result = await fetchLatestDxvkVersion(fetchFn);
    if ("error" in result) {
      return {
        component: "dxvk",
        status: "error",
        installed,
        message: result.error,
      };
    }
    return compareDxvkVersions(installed, result.version);
  } catch {
    return {
      component: "dxvk",
      status: "error",
      installed,
      message: "Failed to check DXVK updates",
    };
  }
}

// ---------------------------------------------------------------------------
// Wine update check (local only, no network)
// ---------------------------------------------------------------------------

/**
 * Check if installed Wine version meets the minimum requirement.
 *
 * @param versionString - Output of `wine64 --version`, e.g. "wine-11.5"
 */
export function checkWineUpdate(versionString: string): UpdateStatus {
  const match = /wine-(\d+\.\d+)/.exec(versionString);
  if (!match || match[1] === undefined) {
    return {
      component: "wine",
      status: "unknown",
      message: "Could not parse Wine version",
    };
  }

  const installed = match[1];
  if (meetsMinimumVersion(installed, MIN_WINE_VERSION)) {
    return {
      component: "wine",
      status: "up-to-date",
      installed,
      latest: MIN_WINE_VERSION,
      message: `Wine ${installed} meets minimum (${MIN_WINE_VERSION})`,
    };
  }

  return {
    component: "wine",
    status: "update-available",
    installed,
    latest: MIN_WINE_VERSION,
    message: `Wine ${installed} is below minimum ${MIN_WINE_VERSION}`,
  };
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

function readDxvkVersion(stateFilePath: string): string | undefined {
  if (!existsSync(stateFilePath)) return undefined;
  try {
    const state = JSON.parse(readFileSync(stateFilePath, "utf-8")) as Record<
      string,
      unknown
    >;
    const version = state["dxvk_version"];
    return typeof version === "string" ? version : undefined;
  } catch {
    return undefined;
  }
}
