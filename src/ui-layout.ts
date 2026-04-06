/**
 * UI layout generator — computes optimal EQ window positions for any resolution.
 *
 * Based on MMO best practices (center-bottom focus):
 *   - Player/Target frames near center, above hotbars
 *   - Chat bottom-left, wide
 *   - Buffs top-right (glanceable)
 *   - Group window left side
 *   - Extended targets left side below group
 *   - Hotbar bottom-center
 *
 * Generates resolution-specific position keys (XPos1920x1080, etc.)
 * that EQ reads from UI_CharName_Server.ini.
 *
 * @module ui-layout
 */

export interface Rect {
  x: number;
  y: number;
  w: number;
  h: number;
}

export interface UILayout {
  resolution: string;
  components: Record<string, Rect>;
}

/** Standard resolutions to pre-compute positions for. */
const STANDARD_RESOLUTIONS: [number, number][] = [
  [1920, 1080],
  [2256, 1361],
  [2256, 1504],
  [2560, 1440],
  [3440, 1440],
  [1920, 1200],
  [1680, 1050],
  [1600, 900],
];

/** Layout dimensions computed from resolution. */
interface LayoutDimensions {
  pad: number;
  cx: number;
  chatTop: number;
  hotbarTop: number;
  frameTop: number;
  chatH: number;
  chatW: number;
  hotbarW: number;
  hotbarH: number;
}

function computeDimensions(w: number, h: number): LayoutDimensions {
  const pad = 4;
  const chatH = Math.round(h * 0.18);
  const hotbarH = 38;
  const chatTop = h - chatH - pad;
  const hotbarTop = chatTop - hotbarH - pad;
  const frameTop = hotbarTop - 110 - pad;
  return {
    pad,
    cx: Math.round(w / 2),
    chatTop,
    hotbarTop,
    frameTop,
    chatH,
    chatW: Math.round(w * 0.35),
    hotbarW: Math.round(w * 0.35),
    hotbarH,
  };
}

function computeCenterComponents(d: LayoutDimensions): Record<string, Rect> {
  return {
    PlayerWindow: { x: d.cx - 170, y: d.frameTop, w: 160, h: 110 },
    TargetWindow: { x: d.cx + 10, y: d.frameTop, w: 200, h: 100 },
    TargetOfTargetWindow: { x: d.cx + 220, y: d.frameTop + 20, w: 120, h: 60 },
    CastSpellWnd: { x: d.cx - 112, y: d.hotbarTop - 52, w: 225, h: 50 },
    HotButtonWnd: {
      x: d.cx - Math.round(d.hotbarW / 2),
      y: d.hotbarTop,
      w: d.hotbarW,
      h: d.hotbarH,
    },
    CombatAbilityWnd: {
      x: d.cx + Math.round(d.hotbarW / 2) + d.pad,
      y: d.hotbarTop,
      w: 200,
      h: d.hotbarH,
    },
    ActionsWindow: {
      x: d.cx - Math.round(d.hotbarW / 2) - 64,
      y: d.hotbarTop,
      w: 60,
      h: d.hotbarH,
    },
  };
}

function computeEdgeComponents(
  w: number,
  h: number,
  d: LayoutDimensions,
): Record<string, Rect> {
  return {
    MainChat: { x: d.pad, y: d.chatTop, w: d.chatW, h: d.chatH },
    GroupWindow: { x: d.pad, y: Math.round(h * 0.4), w: 160, h: 260 },
    ExtendedTargetWnd: {
      x: d.pad,
      y: Math.round(h * 0.4) + 264,
      w: 165,
      h: 260,
    },
    BuffWindow: { x: w - 304, y: d.pad, w: 300, h: 80 },
    ShortDurationBuffWindow: { x: w - 204, y: 88, w: 200, h: 80 },
    CompassWindow: { x: w - 129, y: 172, w: 125, h: 125 },
  };
}

/**
 * Compute optimal UI positions for a given resolution.
 */
export function computeLayout(w: number, h: number): UILayout {
  const d = computeDimensions(w, h);
  return {
    resolution: `${String(w)}x${String(h)}`,
    components: {
      ...computeCenterComponents(d),
      ...computeEdgeComponents(w, h, d),
    },
  };
}

/**
 * Generate INI entries for all standard resolutions.
 * Returns key-value pairs like XPos1920x1080=880.
 */
export function generateUILayoutEntries(): Record<string, string> {
  const entries: Record<string, string> = {};

  for (const [w, h] of STANDARD_RESOLUTIONS) {
    const layout = computeLayout(w, h);
    const res = layout.resolution;

    for (const [name, rect] of Object.entries(layout.components)) {
      entries[`[${name}]XPos${res}`] = String(rect.x);
      entries[`[${name}]YPos${res}`] = String(rect.y);
      entries[`[${name}]Width${res}`] = String(rect.w);
      entries[`[${name}]Height${res}`] = String(rect.h);
      entries[`[${name}]RestoreXPos${res}`] = String(rect.x);
      entries[`[${name}]RestoreYPos${res}`] = String(rect.y);
      entries[`[${name}]RestoreWidth${res}`] = String(rect.w);
      entries[`[${name}]RestoreHeight${res}`] = String(rect.h);
      entries[`[${name}]Show`] = "1";
    }
  }

  return entries;
}

/** Build the list of key-value pairs to inject for a component at a resolution. */
function buildPositionKeys(res: string, rect: Rect): [string, string][] {
  return [
    [`XPos${res}`, String(rect.x)],
    [`YPos${res}`, String(rect.y)],
    [`Width${res}`, String(rect.w)],
    [`Height${res}`, String(rect.h)],
    [`RestoreXPos${res}`, String(rect.x)],
    [`RestoreYPos${res}`, String(rect.y)],
    [`RestoreWidth${res}`, String(rect.w)],
    [`RestoreHeight${res}`, String(rect.h)],
    [`Minimized${res}`, "0"],
  ];
}

/** Inject a key=value into a section of INI content. */
function injectKey(
  content: string,
  section: string,
  key: string,
  val: string,
): string {
  const sectionIdx = content.indexOf(section);
  if (sectionIdx < 0) return content;

  const nextSection = content.indexOf("\n[", sectionIdx + 1);
  const sectionEnd = nextSection > 0 ? nextSection : content.length;
  const body = content.substring(sectionIdx, sectionEnd);
  const keyRegex = new RegExp(`^${key}=.*$`, "m");

  if (keyRegex.test(body)) {
    const updated = body.replace(keyRegex, `${key}=${val}`);
    return (
      content.substring(0, sectionIdx) + updated + content.substring(sectionEnd)
    );
  }
  const insertPos = content.indexOf("\n", sectionIdx) + 1;
  return (
    content.substring(0, insertPos) +
    `${key}=${val}\n` +
    content.substring(insertPos)
  );
}

/**
 * Generate a complete UI INI from baseline, injecting optimal positions.
 */
export function generateOptimalINI(
  baseline: string,
  width: number,
  height: number,
): string {
  const layout = computeLayout(width, height);
  let content = baseline;

  for (const [name, rect] of Object.entries(layout.components)) {
    const section = `[${name}]`;
    if (!content.includes(section)) {
      content += `\n${section}\nShow=1\nINIVersion=1\n`;
    }
    for (const [key, val] of buildPositionKeys(layout.resolution, rect)) {
      content = injectKey(content, section, key, val);
    }
  }
  return content;
}
