/**
 * Channel routing module — 107-entry chat channel to window mapping.
 *
 * Extracted from scripts/apply_layout.sh. Routes EQ chat channels
 * into a 4-window layout:
 *   0 = Social (tells, guild, group, raid)
 *   1 = Combat (your damage, heals, incoming)
 *   2 = Spam   (others' combat, NPC, system)
 *   3 = Alerts (death, loot, XP, tasks)
 *
 * @module layout
 */

/** Window names in display order. */
export const WINDOW_NAMES: string[] = [
  "Social",
  "Combat",
  "Spam",
  "Alerts & Loot",
];

/**
 * Human-readable names for each filter ID.
 * Keys match CHANNEL_MAP keys.
 */
export const CHANNEL_NAMES: Record<number, string> = {
  0: "Default",
  1: "MeleeDmg",
  2: "SpellDmg",
  3: "EnvironDmg",
  4: "Say",
  5: "Shout",
  6: "Emote",
  7: "ServerMsg",
  8: "PetResponse",
  9: "Group",
  10: "Raid",
  11: "Guild",
  12: "Tell",
  13: "OOC",
  14: "Broadcast",
  15: "Faction",
  16: "Death",
  17: "Spell",
  18: "SystemMsg",
  19: "SpellCast",
  20: "YourMelee",
  21: "YourNonMelee",
  22: "YourSpellDmg",
  23: "YourCritMelee",
  24: "YourHealSelf",
  25: "YourHealOther",
  26: "YourHoT",
  27: "YourDoT",
  28: "IncomingMelee",
  29: "IncomingNonMelee",
  30: "DamageTaken",
  31: "IncomingHeal",
  32: "IncomingHoT",
  33: "IncomingDoT",
  34: "IncomingHealCrit",
  35: "OthersMeleeHit",
  36: "OthersMelee",
  37: "OthersNonMelee",
  38: "OthersSpellDmg",
  39: "OthersCritMelee",
  40: "OthersHealSelf",
  41: "OthersHealOther",
  42: "OthersHoT",
  43: "OthersDoT",
  44: "OthersMiss",
  45: "OthersBlock",
  46: "PetMelee",
  47: "XPGain",
  48: "NPCDialogue",
  49: "SpellWornOff",
  50: "SpellFizzle",
  51: "SpellMiss",
  52: "Resist",
  53: "Loot",
  54: "MoneyLoot",
  55: "GuildOfficer",
  56: "SystemError",
  57: "Skill",
  58: "TaskUpdate",
  59: "Achievement",
  60: "MonoMsg",
  61: "Petition",
  62: "Fellowship",
  63: "TradeskillSuccess",
  64: "TradeskillFail",
  65: "Tribute",
  66: "AuraMsg",
  67: "MercMsg",
  68: "PetFlurry",
  69: "CombatAbility",
  70: "InspectMsg",
  71: "PvPMsg",
  72: "RaidSay",
  73: "AAGain",
  74: "OthersDodge",
  75: "OthersParry",
  76: "PetCrit",
  77: "PetNonMelee",
  78: "OthersRiposte",
  79: "OthersBlock2",
  80: "OthersDmgShield",
  81: "OthersEnviron",
  82: "OthersPetMelee",
  83: "OthersPetCrit",
  84: "TaskComplete",
  85: "OthersPetNonMelee",
  86: "OthersCrit",
  87: "OthersHealCrit",
  88: "QuestReward",
  89: "OthersPetFlurry",
  90: "GuildChat",
  91: "CritHeal",
  92: "RaidInvite",
  93: "RaidLoot",
  94: "RaidMisc",
  95: "MerchantOffer",
  96: "YourHealCrit",
  97: "YourDotCrit",
  98: "YourDotDmg",
  99: "SpellInterrupt",
  100: "SpellRecovery",
  101: "DeathAlert",
  102: "TaskTimer",
  103: "OthersCombatAbility",
  104: "YourCritNonMelee",
  105: "YourFlurry",
  106: "YourRiposte",
};

/**
 * Channel routing map: filter ID -> window index.
 * 0=Social, 1=Combat, 2=Spam, 3=Alerts & Loot
 */
export const CHANNEL_MAP: Record<number, number> = {
  0: 0,
  1: 0,
  2: 0,
  3: 0,
  4: 0,
  5: 0,
  6: 0,
  7: 3,
  8: 0,
  9: 0,
  10: 0,
  11: 0,
  12: 0,
  13: 0,
  14: 0,
  15: 3,
  16: 3,
  17: 1,
  18: 3,
  19: 1,
  20: 1,
  21: 1,
  22: 1,
  23: 1,
  24: 1,
  25: 1,
  26: 1,
  27: 1,
  28: 1,
  29: 1,
  30: 1,
  31: 1,
  32: 1,
  33: 1,
  34: 1,
  35: 2,
  36: 2,
  37: 2,
  38: 2,
  39: 2,
  40: 2,
  41: 2,
  42: 2,
  43: 2,
  44: 2,
  45: 2,
  46: 1,
  47: 3,
  48: 2,
  49: 1,
  50: 1,
  51: 1,
  52: 1,
  53: 3,
  54: 3,
  55: 0,
  56: 2,
  57: 2,
  58: 0,
  59: 3,
  60: 2,
  61: 2,
  62: 0,
  63: 0,
  64: 0,
  65: 0,
  66: 0,
  67: 0,
  68: 0,
  69: 0,
  70: 0,
  71: 0,
  72: 0,
  73: 0,
  74: 2,
  75: 2,
  76: 1,
  77: 1,
  78: 2,
  79: 2,
  80: 2,
  81: 2,
  82: 2,
  83: 2,
  84: 3,
  85: 2,
  86: 1,
  87: 1,
  88: 3,
  89: 2,
  90: 0,
  91: 0,
  92: 3,
  93: 3,
  94: 3,
  95: 3,
  96: 1,
  97: 1,
  98: 1,
  99: 1,
  100: 1,
  101: 3,
  102: 3,
  103: 2,
  104: 1,
  105: 1,
  106: 1,
};

/**
 * Generate INI key-value pairs for the [ChatManager] section.
 * Produces ChannelMapN=X for each channel routing.
 */
export function generateChannelMapEntries(): Record<string, string> {
  const entries: Record<string, string> = {};
  for (const [id, windowIndex] of Object.entries(CHANNEL_MAP)) {
    entries[`ChannelMap${id}`] = String(windowIndex);
  }

  // Configure each chat window as a tab in the Main Chat container.
  // EQ requires ContainerIndex + ContainerTabIndex for windows to
  // actually appear. Without these, NumWindows=4 creates the windows
  // but they're invisible (no container placement).
  for (let w = 0; w < WINDOW_NAMES.length; w++) {
    const prefix = `ChatWindow${String(w)}`;
    const name = WINDOW_NAMES[w];
    if (name !== undefined) {
      entries[`${prefix}_Name`] = name;
    }
    // Place all windows as tabs in container 0 (Main Chat)
    entries[`${prefix}_ContainerIndex`] = "0";
    entries[`${prefix}_ContainerTabIndex`] = String(w);
    // HH:MM:SS timestamps (essential for log parsing and raid timing)
    entries[`${prefix}_TimestampFormat`] = "1";
    entries[`${prefix}_TimestampMatchChatColor`] = "1";
    entries[`${prefix}_TimestampColor.red`] = "255";
    entries[`${prefix}_TimestampColor.green`] = "255";
    entries[`${prefix}_TimestampColor.blue`] = "255";
    // Defaults
    entries[`${prefix}_ChatChannel`] = w === 0 ? "0" : "-1";
    entries[`${prefix}_DefaultChannel`] = "8";
    entries[`${prefix}_FontStyle`] = w === 0 ? "5" : "3";
    entries[`${prefix}_Scrollbar`] = "1";
    entries[`${prefix}_Highlight`] = "1";
    entries[`${prefix}_HighlightColor`] = "-65536";
    entries[`${prefix}_LanguageId`] = "0";
  }

  // Set NumWindows
  entries["NumWindows"] = String(WINDOW_NAMES.length);

  return entries;
}

/**
 * Get all channels routed to a given window.
 * Returns channel ID and human-readable name for each.
 */
export function getWindowChannels(
  windowIndex: number,
): { id: number; name: string }[] {
  return Object.entries(CHANNEL_MAP)
    .filter(([, wi]) => wi === windowIndex)
    .map(([idStr]) => {
      const id = Number(idStr);
      return { id, name: CHANNEL_NAMES[id] ?? `Channel${id}` };
    });
}
