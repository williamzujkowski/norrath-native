/**
 * Color scheme module — 91-entry optimized chat color scheme for EQ raiding.
 *
 * Extracted from scripts/apply_colors.sh. Designed for dark backgrounds:
 *   Communication: each channel is instantly distinguishable
 *   Your combat:   warm tones (yellow/gold)
 *   Your healing:  cool tones (mint/blue)
 *   Incoming:      alert colors (red/salmon)
 *   Others:        dimmed gray-blue (reduces raid spam)
 *   Alerts:        high-contrast red (death, low HP)
 *
 * @module colors
 */

interface RgbColor {
  r: number;
  g: number;
  b: number;
}

interface ColorEntry extends RgbColor {
  name: string;
}

/**
 * Full 91-entry color scheme. Keys are EQ TextColor IDs (User_N).
 * Values are RGB + human-readable name.
 */
export const COLOR_SCHEME: Record<number, ColorEntry> = {
  1: { r: 255, g: 255, b: 255, name: 'Default' },
  2: { r: 255, g: 50, b: 50, name: 'DamageShield' },
  3: { r: 0, g: 255, b: 255, name: 'Auction' },
  4: { r: 40, g: 240, b: 40, name: 'Say' },
  5: { r: 255, g: 100, b: 100, name: 'Shout' },
  6: { r: 255, g: 200, b: 100, name: 'Emote' },
  7: { r: 255, g: 0, b: 0, name: 'ServerMsg' },
  8: { r: 200, g: 200, b: 255, name: 'PetResponse' },
  9: { r: 130, g: 180, b: 255, name: 'Group' },
  10: { r: 255, g: 165, b: 0, name: 'Raid' },
  11: { r: 0, g: 230, b: 0, name: 'Guild' },
  12: { r: 255, g: 128, b: 255, name: 'Tell' },
  13: { r: 0, g: 200, b: 200, name: 'OOC' },
  14: { r: 255, g: 255, b: 0, name: 'Broadcast' },
  15: { r: 255, g: 255, b: 100, name: 'Faction' },
  16: { r: 255, g: 50, b: 50, name: 'Death' },
  17: { r: 180, g: 130, b: 255, name: 'Spell' },
  18: { r: 200, g: 200, b: 255, name: 'SystemMsg' },
  20: { r: 240, g: 200, b: 0, name: 'YourMelee' },
  21: { r: 240, g: 240, b: 80, name: 'YourNonMelee' },
  22: { r: 255, g: 255, b: 200, name: 'YourSpellDmg' },
  23: { r: 255, g: 150, b: 50, name: 'YourCritMelee' },
  24: { r: 100, g: 255, b: 200, name: 'YourHealSelf' },
  25: { r: 150, g: 200, b: 255, name: 'YourHealOther' },
  26: { r: 100, g: 255, b: 150, name: 'YourHoT' },
  28: { r: 255, g: 150, b: 150, name: 'IncomingMelee' },
  29: { r: 255, g: 200, b: 80, name: 'IncomingNonMelee' },
  30: { r: 255, g: 100, b: 100, name: 'DamageTaken' },
  31: { r: 150, g: 200, b: 150, name: 'IncomingHeal' },
  34: { r: 100, g: 255, b: 200, name: 'IncomingHoT' },
  36: { r: 110, g: 130, b: 150, name: 'OthersMelee' },
  37: { r: 110, g: 130, b: 150, name: 'OthersNonMelee' },
  38: { r: 130, g: 150, b: 170, name: 'OthersSpellDmg' },
  39: { r: 115, g: 135, b: 155, name: 'OthersCritMelee' },
  40: { r: 110, g: 140, b: 130, name: 'OthersHealSelf' },
  41: { r: 110, g: 140, b: 130, name: 'OthersHealOther' },
  42: { r: 120, g: 150, b: 140, name: 'OthersHoT' },
  43: { r: 100, g: 130, b: 120, name: 'OthersDoT' },
  47: { r: 255, g: 255, b: 100, name: 'XPGain' },
  48: { r: 255, g: 200, b: 200, name: 'NPCDialogue' },
  49: { r: 160, g: 120, b: 200, name: 'SpellWornOff' },
  50: { r: 170, g: 130, b: 220, name: 'SpellFizzle' },
  52: { r: 180, g: 180, b: 220, name: 'Resist' },
  53: { r: 255, g: 220, b: 100, name: 'Loot' },
  54: { r: 200, g: 200, b: 255, name: 'MoneyLoot' },
  57: { r: 200, g: 180, b: 100, name: 'Skill' },
  58: { r: 100, g: 255, b: 200, name: 'TaskUpdate' },
  59: { r: 255, g: 200, b: 50, name: 'Achievement' },
  62: { r: 220, g: 160, b: 80, name: 'TradeskillSuccess' },
  63: { r: 180, g: 200, b: 100, name: 'TradeskillFail' },
  64: { r: 100, g: 180, b: 220, name: 'Fellowship' },
  65: { r: 200, g: 150, b: 200, name: 'Tribute' },
  66: { r: 220, g: 180, b: 140, name: 'AuraMsg' },
  67: { r: 140, g: 200, b: 180, name: 'MercMsg' },
  68: { r: 200, g: 170, b: 130, name: 'PetFlurry' },
  69: { r: 170, g: 170, b: 220, name: 'CombatAbility' },
  70: { r: 220, g: 200, b: 140, name: 'InspectMsg' },
  71: { r: 180, g: 220, b: 180, name: 'PvPMsg' },
  72: { r: 0, g: 200, b: 200, name: 'RaidSay' },
  73: { r: 255, g: 255, b: 0, name: 'AAGain' },
  76: { r: 255, g: 100, b: 100, name: 'PetCrit' },
  77: { r: 255, g: 200, b: 50, name: 'PetNonMelee' },
  86: { r: 200, g: 150, b: 150, name: 'OthersCrit' },
  87: { r: 150, g: 200, b: 150, name: 'OthersRiposte' },
  90: { r: 130, g: 200, b: 255, name: 'GuildChat' },
  91: { r: 255, g: 200, b: 50, name: 'CritHeal' },
  92: { r: 255, g: 165, b: 50, name: 'RaidInvite' },
  96: { r: 0, g: 255, b: 128, name: 'YourHealCrit' },
  98: { r: 240, g: 240, b: 80, name: 'YourDotDmg' },
  99: { r: 200, g: 150, b: 255, name: 'SpellInterrupt' },
  100: { r: 100, g: 220, b: 255, name: 'SpellRecovery' },
  101: { r: 255, g: 80, b: 80, name: 'DeathAlert' },
  104: { r: 255, g: 180, b: 80, name: 'YourCritNonMelee' },
  109: { r: 255, g: 200, b: 50, name: 'AltCurrency' },
  111: { r: 255, g: 220, b: 80, name: 'RareLoot' },
  113: { r: 200, g: 220, b: 180, name: 'Forage' },
  116: { r: 200, g: 130, b: 80, name: 'Fishing' },
  119: { r: 100, g: 255, b: 160, name: 'RegenTick' },
  129: { r: 100, g: 255, b: 100, name: 'EnvironMsg' },
  130: { r: 255, g: 150, b: 50, name: 'IncomingCrit' },
  131: { r: 200, g: 255, b: 150, name: 'ItemLink' },
  138: { r: 100, g: 150, b: 255, name: 'Leadership' },
  140: { r: 0, g: 200, b: 0, name: 'GuildMotd' },
  142: { r: 180, g: 140, b: 100, name: 'RandomRoll' },
  144: { r: 200, g: 150, b: 255, name: 'SpellDuration' },
  146: { r: 150, g: 200, b: 255, name: 'OtherHealCrit' },
  147: { r: 100, g: 255, b: 200, name: 'OtherHealSelfCrit' },
  148: { r: 150, g: 255, b: 150, name: 'OtherHoTCrit' },
  149: { r: 100, g: 220, b: 150, name: 'OtherDoTCrit' },
  150: { r: 150, g: 180, b: 255, name: 'FocusEffect' },
  151: { r: 255, g: 0, b: 0, name: 'LowHealth' },
};

/**
 * Convert sRGB channel (0-255) to linear luminance component.
 * Per WCAG 2.x relative luminance formula.
 */
function srgbToLinear(channel: number): number {
  const s = channel / 255;
  return s <= 0.04045 ? s / 12.92 : Math.pow((s + 0.055) / 1.055, 2.4);
}

/**
 * Calculate relative luminance of an RGB color per WCAG 2.x.
 */
function relativeLuminance(color: RgbColor): number {
  return (
    0.2126 * srgbToLinear(color.r) +
    0.7152 * srgbToLinear(color.g) +
    0.0722 * srgbToLinear(color.b)
  );
}

/**
 * Calculate WCAG contrast ratio between two colors.
 * Returns a value between 1 (identical) and 21 (black/white).
 */
export function getContrastRatio(fg: RgbColor, bg: RgbColor): number {
  const l1 = relativeLuminance(fg);
  const l2 = relativeLuminance(bg);
  const lighter = Math.max(l1, l2);
  const darker = Math.min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

/**
 * Generate INI key-value pairs for the [TextColors] section.
 * Produces User_N_Red, User_N_Green, User_N_Blue for each color.
 */
export function generateColorIniEntries(): Record<string, string> {
  const entries: Record<string, string> = {};
  for (const [id, color] of Object.entries(COLOR_SCHEME)) {
    entries[`User_${id}_Red`] = String(color.r);
    entries[`User_${id}_Green`] = String(color.g);
    entries[`User_${id}_Blue`] = String(color.b);
  }
  return entries;
}

/** WCAG AA minimum contrast ratio for normal text. */
const WCAG_AA_RATIO = 4.5;

/**
 * Validate all scheme colors against a background for WCAG AA compliance.
 * Returns one result per color with contrast ratio and pass/fail.
 */
export function validateSchemeContrast(
  bgColor: RgbColor,
): { id: number; name: string; ratio: number; passes: boolean }[] {
  return Object.entries(COLOR_SCHEME).map(([idStr, color]) => {
    const ratio = getContrastRatio(color, bgColor);
    return {
      id: Number(idStr),
      name: color.name,
      ratio: Math.round(ratio * 100) / 100,
      passes: ratio >= WCAG_AA_RATIO,
    };
  });
}
