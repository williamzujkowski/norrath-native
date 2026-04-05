/**
 * Core type definitions for norrath-native deployment toolkit.
 */

// ---------------------------------------------------------------------------
// Result type for fallible operations
// ---------------------------------------------------------------------------

export type Result<T, E> = { ok: true; value: T } | { ok: false; error: E };

export function ok<T>(value: T): Result<T, never> {
  return { ok: true, value };
}

export function err<E>(error: E): Result<never, E> {
  return { ok: false, error };
}

// ---------------------------------------------------------------------------
// Wine environment
// ---------------------------------------------------------------------------

export interface IWineEnvironment {
  /** Absolute path to WINEPREFIX */
  prefixPath: string;
  /** Always 64-bit */
  architecture: "win64";
  /** Whether the prefix directory already exists (idempotency check) */
  prefixExists: boolean;
  /** Installed DXVK version string, e.g. "2.5.3" */
  dxvkVersion: string;
}

// ---------------------------------------------------------------------------
// Client configuration (eqclient.ini)
// ---------------------------------------------------------------------------

export interface IClientConfig {
  /** Path to eqclient.ini within the Wine prefix */
  filePath: string;
  /** Key-value pairs to inject into the INI file */
  settings: Record<string, string>;
  /** When true, never overwrite keys not present in `settings` */
  preserveUserSettings: boolean;
}

// ---------------------------------------------------------------------------
// Launch options
// ---------------------------------------------------------------------------

export interface ILaunchOptions {
  /** Number of EQ clients to launch (default: 1) */
  instances: number;
  /** Milliseconds to wait between launching successive instances */
  staggerDelayMs: number;
  /** Directory for per-instance log output */
  logDir: string;
  /** false = X11 (default), true = Wayland */
  waylandBackend: boolean;
}

// ---------------------------------------------------------------------------
// DXVK release metadata
// ---------------------------------------------------------------------------

export interface DxvkRelease {
  /** Semantic version string, e.g. "2.5.3" */
  version: string;
  /** Direct URL to the tarball asset */
  downloadUrl: string;
  /** Filename of the tarball, e.g. "dxvk-2.5.3.tar.gz" */
  tarballName: string;
}

// ---------------------------------------------------------------------------
// Version floors
// ---------------------------------------------------------------------------

/** Minimum Wine version required (major.minor) */
export const MIN_WINE_VERSION = "11.0";

/** Minimum DXVK version required (major.minor) */
export const MIN_DXVK_VERSION = "2.4";

// ---------------------------------------------------------------------------
// Required apt packages for 64-bit Wine + Vulkan on Ubuntu 24.04 LTS
// ---------------------------------------------------------------------------

export const REQUIRED_APT_PACKAGES: readonly string[] = [
  // Wine (WineHQ stable or distro wine)
  "wine64",
  "wine32",
  "wine",
  // Vulkan drivers and loader (amd64)
  "mesa-vulkan-drivers",
  "libvulkan1",
  "vulkan-tools",
  // Vulkan / Mesa 32-bit multiarch (required for 32-bit DXVK DLLs)
  "mesa-vulkan-drivers:i386",
  "libvulkan1:i386",
  // Wine authentication support (prevents ntlm_auth warnings)
  "winbind",
  // Download and extraction utilities
  "wget",
  "tar",
  "cabextract",
] as const;

// ---------------------------------------------------------------------------
// Managed INI settings injected into eqclient.ini
//
// These keys are owned by norrath-native and will be overwritten on every
// launch.  User-managed keys outside this set are never touched.
// ---------------------------------------------------------------------------

/** Reference only — canonical settings are in scripts/configure_eq.sh */
export const MANAGED_INI_SETTINGS: Readonly<Record<string, string>> = {
  WindowedMode: "TRUE",
  UpdateInBackground: "1",
  Log: "TRUE",
  MaxBGFPS: "30",
  ClientCore0: "-1",
  ClientCore1: "-1",
  ClientCore2: "-1",
  ClientCore3: "-1",
  ClientCore4: "-1",
  ClientCore5: "-1",
  ClientCore6: "-1",
  ClientCore7: "-1",
  ClientCore8: "-1",
  ClientCore9: "-1",
  ClientCore10: "-1",
  ClientCore11: "-1",
} as const;
