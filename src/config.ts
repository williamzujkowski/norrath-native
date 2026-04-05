/**
 * Configuration system for norrath-native.
 *
 * Reads norrath-native.yaml, resolves profiles, provides defaults.
 * This is the single source of truth for all configuration —
 * bash scripts call this via the CLI to get resolved values.
 *
 * @module config
 */

import { readFileSync, existsSync } from "node:fs";
import { join } from "node:path";
import { type Result, ok } from "./types/interfaces.js";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface NorrathConfig {
  prefix: string;
  resolution: string;
  display: "x11" | "wayland";
  instances: number;
  multiboxInstances: number;
  staggerDelay: number;
  profile: Profile;
  eqSettings: EqSettings;
}

export type Profile = "high" | "balanced" | "low" | "minimal";

export interface EqSettings {
  maxFps: number;
  maxBgFps: number;
  clipPlane: number;
  lodBias: number;
  postEffects: boolean;
  multiPassLighting: boolean;
  vertexShaders: boolean;
  spellParticles: number;
  envParticles: number;
  actorParticles: number;
  sound: boolean;
  musicVolume: number;
  soundVolume: number;
  showNames: number;
  chatFontSize: number;
  trackPlayers: boolean;
  serverFilter: boolean;
  socialAnimations: boolean;
  combatMusic: boolean;
  textureQuality: number;
  stickFigures: boolean;
}

// ---------------------------------------------------------------------------
// Profile presets
// ---------------------------------------------------------------------------

const PROFILES: Record<Profile, Partial<EqSettings>> = {
  high: {
    maxFps: 60,
    maxBgFps: 30,
    clipPlane: 15,
    lodBias: 10,
    spellParticles: 1.0,
    envParticles: 1.0,
    actorParticles: 1.0,
    serverFilter: false,
    socialAnimations: true,
    combatMusic: false,
    textureQuality: 2,
    stickFigures: false,
  },
  balanced: {
    maxFps: 45,
    maxBgFps: 15,
    clipPlane: 10,
    lodBias: 7,
    spellParticles: 0.5,
    envParticles: 0.5,
    actorParticles: 0.5,
    serverFilter: true,
    socialAnimations: false,
    combatMusic: false,
    textureQuality: 1,
    stickFigures: false,
  },
  low: {
    maxFps: 30,
    maxBgFps: 10,
    clipPlane: 5,
    lodBias: 3,
    spellParticles: 0.25,
    envParticles: 0.0,
    actorParticles: 0.25,
    serverFilter: true,
    socialAnimations: false,
    combatMusic: false,
    textureQuality: 0,
    stickFigures: false,
  },
  minimal: {
    maxFps: 15,
    maxBgFps: 5,
    clipPlane: 2,
    lodBias: 1,
    spellParticles: 0.0,
    envParticles: 0.0,
    actorParticles: 0.0,
    sound: false,
    serverFilter: true,
    socialAnimations: false,
    combatMusic: false,
    textureQuality: 0,
    stickFigures: true,
  },
};

const DEFAULT_SETTINGS: EqSettings = {
  maxFps: 60,
  maxBgFps: 30,
  clipPlane: 15,
  lodBias: 10,
  postEffects: false,
  multiPassLighting: false,
  vertexShaders: true,
  spellParticles: 1.0,
  envParticles: 1.0,
  actorParticles: 1.0,
  sound: true,
  musicVolume: 10,
  soundVolume: 10,
  showNames: 4,
  chatFontSize: 3,
  trackPlayers: true,
  serverFilter: false,
  socialAnimations: true,
  combatMusic: false,
  textureQuality: 2,
  stickFigures: false,
};

// ---------------------------------------------------------------------------
// YAML reader (simple, no dependency)
// ---------------------------------------------------------------------------

function yamlGet(content: string, key: string): string | undefined {
  const match = content.match(new RegExp(`^${key}:\\s*(.+)$`, "m"));
  if (!match) return undefined;
  const captured = match[1];
  if (captured === undefined) return undefined;
  return captured
    .replace(/#.*$/, "")
    .replace(/^['"]|['"]$/g, "")
    .trim();
}

// ---------------------------------------------------------------------------
// Config resolution
// ---------------------------------------------------------------------------

function buildDefaults(): NorrathConfig {
  return {
    prefix: join(process.env["HOME"] ?? "/tmp", ".wine-eq"),
    resolution: "1920x1080",
    display: "x11",
    instances: 1,
    multiboxInstances: 3,
    staggerDelay: 5,
    profile: "high",
    eqSettings: { ...DEFAULT_SETTINGS },
  };
}

function findConfigFile(configPath?: string): string | undefined {
  const paths = configPath
    ? [configPath]
    : [
        join(process.cwd(), "norrath-native.yaml"),
        join(
          process.env["HOME"] ?? "/tmp",
          ".config/norrath-native/config.yaml",
        ),
      ];
  return paths.find((p) => existsSync(p));
}

function applyYamlOverrides(config: NorrathConfig, content: string): void {
  const home = process.env["HOME"] ?? "/tmp";
  const prefix = yamlGet(content, "prefix");
  if (prefix) config.prefix = prefix.replace(/^~/, home);

  const res = yamlGet(content, "resolution");
  if (res) config.resolution = res;

  const display = yamlGet(content, "display");
  if (display === "x11" || display === "wayland") {
    config.display = display;
  }

  const inst = yamlGet(content, "instances");
  if (inst) config.instances = parseInt(inst, 10);

  const multi = yamlGet(content, "multibox_instances");
  if (multi) config.multiboxInstances = parseInt(multi, 10);

  const stagger = yamlGet(content, "stagger_delay");
  if (stagger) config.staggerDelay = parseInt(stagger, 10);

  const profile = yamlGet(content, "profile");
  if (isProfile(profile)) config.profile = profile;
}

function isProfile(v: string | undefined): v is Profile {
  return v === "high" || v === "balanced" || v === "low" || v === "minimal";
}

export function resolveConfig(
  configPath?: string,
): Result<NorrathConfig, Error> {
  const config = buildDefaults();

  const path = findConfigFile(configPath);
  if (!path) return ok(config);

  const content = readFileSync(path, "utf-8");
  applyYamlOverrides(config, content);

  config.eqSettings = {
    ...DEFAULT_SETTINGS,
    ...PROFILES[config.profile],
  };

  return ok(config);
}

/** Boolean → INI string converters */
function boolTF(v: boolean): string {
  return v ? "TRUE" : "FALSE";
}
function bool10(v: boolean): string {
  return v ? "1" : "0";
}

/**
 * Generate the managed INI settings map from resolved config.
 * This is the canonical source of truth for what gets written
 * to eqclient.ini.
 */
export function generateManagedSettings(
  config: NorrathConfig,
): Record<string, string> {
  const s = config.eqSettings;
  const settings: Record<string, string> = {
    WindowedMode: "TRUE",
    UpdateInBackground: "1",
    GraphicsMemoryModeSwitch: "1",
    APVOptimizations: "TRUE",
    Log: "TRUE",
    AllowResize: "1",
    Maximized: "1",
    AlwaysOnTop: "0",
    MaxBGFPS: String(s.maxBgFps),
    PostEffects: boolTF(s.postEffects),
    MultiPassLighting: boolTF(s.multiPassLighting),
    VertexShaders: boolTF(s.vertexShaders),
    SpellParticleOpacity: s.spellParticles.toFixed(6),
    EnvironmentParticleOpacity: s.envParticles.toFixed(6),
    ActorParticleOpacity: s.actorParticles.toFixed(6),
    Sound: bool10(s.sound),
    Music: String(s.musicVolume),
    SoundVolume: String(s.soundVolume),
    ShowNamesLevel: String(s.showNames),
    ChatFontSize: String(s.chatFontSize),
    TrackPlayers: bool10(s.trackPlayers),
    ClipPlane: String(s.clipPlane),
    LODBias: String(s.lodBias),
    ServerFilter: bool10(s.serverFilter),
    LoadSocialAnimations: boolTF(s.socialAnimations),
    CombatMusic: bool10(s.combatMusic),
    TextureQuality: String(s.textureQuality),
    StickFigures: bool10(s.stickFigures),
  };

  // CPU affinity — always let Linux manage
  for (let i = 0; i < 12; i++) {
    settings[`ClientCore${String(i)}`] = "-1";
  }

  return settings;
}
