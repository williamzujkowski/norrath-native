import { describe, it, expect } from "vitest";
import { gatherMetadata } from "../src/metadata.js";

describe("gatherMetadata", () => {
  const meta = gatherMetadata();

  it("returns color count matching COLOR_SCHEME", () => {
    expect(meta.colors.count).toBeGreaterThan(0);
    expect(meta.colors.count).toBe(91);
  });

  it("returns channel count matching CHANNEL_MAP", () => {
    expect(meta.channels.count).toBeGreaterThan(0);
    expect(meta.channels.windows).toBe(4);
  });

  it("returns 5 profiles", () => {
    expect(meta.profiles.count).toBe(5);
    expect(meta.profiles.names).toContain("raid");
    expect(meta.profiles.names).toContain("high");
    expect(meta.profiles.names).toContain("minimal");
  });

  it("returns managed settings count > 0", () => {
    expect(meta.managedSettings.count).toBeGreaterThan(30);
  });

  it("returns doctor checks count > 0", () => {
    expect(meta.doctorChecks.count).toBeGreaterThan(20);
  });

  it("returns required packages count > 0", () => {
    expect(meta.requiredPackages.count).toBeGreaterThan(5);
  });

  it("returns CLI commands including metadata", () => {
    expect(meta.cliCommands.count).toBeGreaterThan(10);
    expect(meta.cliCommands.names).toContain("metadata");
    expect(meta.cliCommands.names).toContain("help");
    expect(meta.cliCommands.names).toContain("doctor");
  });
});
