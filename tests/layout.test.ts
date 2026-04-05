import { describe, it, expect } from "vitest";
import {
  WINDOW_NAMES,
  CHANNEL_MAP,
  CHANNEL_NAMES,
  generateChannelMapEntries,
  getWindowChannels,
} from "../src/layout.js";

describe("WINDOW_NAMES", () => {
  it("has 4 entries", () => {
    expect(WINDOW_NAMES.length).toBe(4);
  });

  it("contains the correct window names in order", () => {
    expect(WINDOW_NAMES).toEqual(["Social", "Combat", "Spam", "Alerts & Loot"]);
  });
});

describe("CHANNEL_MAP", () => {
  it("has 107 entries", () => {
    expect(Object.keys(CHANNEL_MAP).length).toBe(107);
  });

  it("Tell (ID 12) routes to window 0 (Social)", () => {
    expect(CHANNEL_MAP[12]).toBe(0);
  });

  it("DamageTaken (ID 30) routes to window 1 (Combat)", () => {
    expect(CHANNEL_MAP[30]).toBe(1);
  });

  it("Others damage (ID 38) routes to window 2 (Spam)", () => {
    expect(CHANNEL_MAP[38]).toBe(2);
  });

  it("Death (ID 16) routes to window 3 (Alerts)", () => {
    expect(CHANNEL_MAP[16]).toBe(3);
  });

  it("all values are valid window indices (0-3)", () => {
    for (const [, windowIndex] of Object.entries(CHANNEL_MAP)) {
      expect(windowIndex).toBeGreaterThanOrEqual(0);
      expect(windowIndex).toBeLessThanOrEqual(3);
    }
  });

  it("Guild (ID 11) routes to window 0 (Social)", () => {
    expect(CHANNEL_MAP[11]).toBe(0);
  });

  it("Group (ID 9) routes to window 0 (Social)", () => {
    expect(CHANNEL_MAP[9]).toBe(0);
  });

  it("Raid (ID 10) routes to window 0 (Social)", () => {
    expect(CHANNEL_MAP[10]).toBe(0);
  });

  it("Loot (ID 53) routes to window 3 (Alerts)", () => {
    expect(CHANNEL_MAP[53]).toBe(3);
  });
});

describe("CHANNEL_NAMES", () => {
  it("has the same number of entries as CHANNEL_MAP", () => {
    expect(Object.keys(CHANNEL_NAMES).length).toBe(
      Object.keys(CHANNEL_MAP).length,
    );
  });

  it("all entries have non-empty names", () => {
    for (const [, name] of Object.entries(CHANNEL_NAMES)) {
      expect(name.length).toBeGreaterThan(0);
    }
  });
});

describe("generateChannelMapEntries", () => {
  it("produces ChannelMap0 through ChannelMap106", () => {
    const entries = generateChannelMapEntries();
    expect(entries["ChannelMap0"]).toBeDefined();
    expect(entries["ChannelMap106"]).toBeDefined();
  });

  it("produces 107 channel entries plus window config", () => {
    const entries = generateChannelMapEntries();
    const channelEntries = Object.keys(entries).filter((k) =>
      k.startsWith("ChannelMap"),
    );
    expect(channelEntries.length).toBe(107);
    // Also includes timestamps, window names, NumWindows
    expect(Object.keys(entries).length).toBeGreaterThan(107);
  });

  it("all channel keys follow ChannelMapN format", () => {
    const entries = generateChannelMapEntries();
    for (const key of Object.keys(entries)) {
      if (key.startsWith("ChannelMap")) {
        expect(key).toMatch(/^ChannelMap\d+$/);
      }
    }
  });

  it("channel values are string window indices", () => {
    const entries = generateChannelMapEntries();
    for (const [key, value] of Object.entries(entries)) {
      if (key.startsWith("ChannelMap")) {
        expect(value).toMatch(/^[0-3]$/);
      }
    }
  });

  it("enables HH:MM:SS timestamps on all windows", () => {
    const entries = generateChannelMapEntries();
    expect(entries["ChatWindow0_TimestampFormat"]).toBe("1");
    expect(entries["ChatWindow1_TimestampFormat"]).toBe("1");
    expect(entries["ChatWindow2_TimestampFormat"]).toBe("1");
    expect(entries["ChatWindow3_TimestampFormat"]).toBe("1");
  });

  it("sets window names", () => {
    const entries = generateChannelMapEntries();
    expect(entries["ChatWindow0_Name"]).toBe("Social");
    expect(entries["NumWindows"]).toBe("4");
  });

  it("Tell channel maps to Social window", () => {
    const entries = generateChannelMapEntries();
    expect(entries["ChannelMap12"]).toBe("0");
  });
});

describe("getWindowChannels", () => {
  it("Social (0) includes Tell and Guild", () => {
    const channels = getWindowChannels(0);
    const ids = channels.map((c) => c.id);
    expect(ids).toContain(12); // Tell
    expect(ids).toContain(11); // Guild
  });

  it("Combat (1) includes DamageTaken", () => {
    const channels = getWindowChannels(1);
    const ids = channels.map((c) => c.id);
    expect(ids).toContain(30);
  });

  it("Spam (2) includes Others damage", () => {
    const channels = getWindowChannels(2);
    const ids = channels.map((c) => c.id);
    expect(ids).toContain(38);
  });

  it("Alerts (3) includes Death", () => {
    const channels = getWindowChannels(3);
    const ids = channels.map((c) => c.id);
    expect(ids).toContain(16);
  });

  it("all channels are accounted for across all windows", () => {
    const allIds = [0, 1, 2, 3].flatMap((w) =>
      getWindowChannels(w).map((c) => c.id),
    );
    expect(allIds.length).toBe(107);
  });

  it("each channel result has id and name", () => {
    const channels = getWindowChannels(0);
    for (const ch of channels) {
      expect(typeof ch.id).toBe("number");
      expect(typeof ch.name).toBe("string");
      expect(ch.name.length).toBeGreaterThan(0);
    }
  });

  it("returns empty array for invalid window index", () => {
    expect(getWindowChannels(5)).toEqual([]);
  });
});
