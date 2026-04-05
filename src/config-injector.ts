/**
 * INI config injector for eqclient.ini.
 *
 * Enforces managed settings while preserving user-defined keys.
 * No third-party INI libraries — hand-rolled parser for EQ's format.
 */

import * as fs from "node:fs";
import * as path from "node:path";
import {
  type Result,
  ok,
  err,
  MANAGED_INI_SETTINGS,
} from "./types/interfaces.js";

/** A parsed line: either a section header, a key-value pair, or a verbatim line (comment/blank). */
type IniLine =
  | { kind: "section"; raw: string }
  | { kind: "kv"; key: string; value: string }
  | { kind: "verbatim"; raw: string };

/** Parse raw INI text into structured lines, deduplicating keys (last wins). */
function parseIni(text: string): IniLine[] {
  const normalized = text.replace(/\r\n/g, "\n").replace(/\r/g, "\n");
  const rawLines = normalized.split("\n");
  const seen = new Map<string, number>();
  const lines: IniLine[] = [];

  for (const raw of rawLines) {
    const trimmed = raw.trim();

    if (trimmed.startsWith("[") && trimmed.endsWith("]")) {
      lines.push({ kind: "section", raw: trimmed });
    } else if (
      trimmed === "" ||
      trimmed.startsWith(";") ||
      trimmed.startsWith("#")
    ) {
      lines.push({ kind: "verbatim", raw });
    } else {
      const eqIdx = trimmed.indexOf("=");
      if (eqIdx === -1) {
        lines.push({ kind: "verbatim", raw });
        continue;
      }
      const key = trimmed.substring(0, eqIdx);
      const value = trimmed.substring(eqIdx + 1);
      const prevIdx = seen.get(key);
      if (prevIdx !== undefined) {
        lines[prevIdx] = { kind: "verbatim", raw: "" };
      }
      seen.set(key, lines.length);
      lines.push({ kind: "kv", key, value });
    }
  }

  return lines;
}

/** Serialize parsed lines back to INI text (LF endings, no trailing blank duplication). */
function serializeIni(lines: IniLine[]): string {
  const out: string[] = [];

  for (const line of lines) {
    if (line.kind === "section") {
      out.push(line.raw);
    } else if (line.kind === "kv") {
      out.push(`${line.key}=${line.value}`);
    } else {
      out.push(line.raw);
    }
  }

  // Ensure single trailing newline
  const joined = out.join("\n");
  return joined.endsWith("\n") ? joined : joined + "\n";
}

/** Validate that filePath resolves within prefixPath (path traversal guard). */
function validatePath(
  filePath: string,
  prefixPath: string,
): Result<string, Error> {
  const resolved = path.resolve(filePath);
  const resolvedPrefix = path.resolve(prefixPath);

  if (
    !resolved.startsWith(resolvedPrefix + path.sep) &&
    resolved !== resolvedPrefix
  ) {
    return err(
      new Error(
        `Path traversal rejected: ${filePath} is outside ${prefixPath}`,
      ),
    );
  }

  return ok(resolved);
}

/**
 * Inject managed settings into an eqclient.ini file.
 *
 * - Creates the file with baseline settings if it does not exist.
 * - Updates managed keys in-place, preserving all user-defined keys.
 * - Deduplicates keys (last value wins), then enforces managed values.
 * - Normalizes line endings to LF.
 * - Returns Result<void, Error> — never throws for expected failures.
 */
export function injectConfig(
  filePath: string,
  prefixPath: string,
): Result<void, Error> {
  const pathCheck = validatePath(filePath, prefixPath);
  if (!pathCheck.ok) {
    return pathCheck;
  }

  const resolvedPath = pathCheck.value;
  const existing = readExistingFile(resolvedPath);
  const lines = parseIni(existing);
  const merged = applyManagedSettings(lines);
  const output = serializeIni(merged);

  return writeFile(resolvedPath, output);
}

/** Read file content or return empty string if it does not exist. */
function readExistingFile(filePath: string): string {
  try {
    return fs.readFileSync(filePath, "utf-8");
  } catch {
    return "";
  }
}

/** Apply managed settings: update existing keys or append missing ones. */
function applyManagedSettings(lines: IniLine[]): IniLine[] {
  const result = [...lines];
  const applied = new Set<string>();

  for (let i = 0; i < result.length; i++) {
    const line = result[i];
    if (line === undefined) continue;
    if (line.kind === "kv" && line.key in MANAGED_INI_SETTINGS) {
      result[i] = {
        kind: "kv",
        key: line.key,
        value: MANAGED_INI_SETTINGS[line.key] ?? "",
      };
      applied.add(line.key);
    }
  }

  for (const [key, value] of Object.entries(MANAGED_INI_SETTINGS)) {
    if (!applied.has(key)) {
      result.push({ kind: "kv", key, value });
    }
  }

  return result;
}

/** Write content to file, creating parent directories as needed. */
function writeFile(filePath: string, content: string): Result<void, Error> {
  try {
    const dir = path.dirname(filePath);
    fs.mkdirSync(dir, { recursive: true });
    fs.writeFileSync(filePath, content, "utf-8");
    return ok(undefined);
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : String(e);
    return err(new Error(`Failed to write ${filePath}: ${msg}`));
  }
}
