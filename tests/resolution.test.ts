import { describe, it, expect } from "vitest";
import {
  isUltrawide,
  clampTo16x9,
  calculateViewport,
  percentToPixel,
  calculateTilePositions,
} from "../src/resolution.js";

describe("isUltrawide", () => {
  it("detects 21:9 as ultrawide", () => {
    expect(isUltrawide(3440, 1440)).toBe(true);
  });

  it("detects 32:9 as ultrawide", () => {
    expect(isUltrawide(5120, 1440)).toBe(true);
  });

  it("detects 16:9 as NOT ultrawide", () => {
    expect(isUltrawide(1920, 1080)).toBe(false);
    expect(isUltrawide(2560, 1440)).toBe(false);
    expect(isUltrawide(3840, 2160)).toBe(false);
  });

  it("detects 4:3 as NOT ultrawide", () => {
    expect(isUltrawide(1024, 768)).toBe(false);
  });
});

describe("clampTo16x9", () => {
  it("clamps 3440x1440 to 2560x1440", () => {
    const result = clampTo16x9(3440, 1440);
    expect(result.width).toBe(2560);
    expect(result.height).toBe(1440);
  });

  it("clamps 5120x1440 to 2560x1440", () => {
    const result = clampTo16x9(5120, 1440);
    expect(result.width).toBe(2560);
    expect(result.height).toBe(1440);
  });

  it("preserves 1920x1080 (already 16:9)", () => {
    const result = clampTo16x9(1920, 1080);
    expect(result.width).toBe(1920);
    expect(result.height).toBe(1080);
  });

  it("preserves 2560x1440 (already 16:9)", () => {
    const result = clampTo16x9(2560, 1440);
    expect(result.width).toBe(2560);
    expect(result.height).toBe(1440);
  });

  it("preserves 4:3 resolutions", () => {
    const result = clampTo16x9(1024, 768);
    expect(result.width).toBe(1024);
    expect(result.height).toBe(768);
  });
});

describe("calculateViewport", () => {
  it("calculates centered viewport for 3440x1440 ultrawide", () => {
    const result = calculateViewport(3440, 1440);
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.value.x).toBe(440);
      expect(result.value.y).toBe(0);
      expect(result.value.width).toBe(2560);
      expect(result.value.height).toBe(1440);
    }
  });

  it("returns full screen for 16:9 monitors", () => {
    const result = calculateViewport(1920, 1080);
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.value.x).toBe(0);
      expect(result.value.y).toBe(0);
      expect(result.value.width).toBe(1920);
      expect(result.value.height).toBe(1080);
    }
  });

  it("rejects invalid dimensions", () => {
    expect(calculateViewport(0, 0).ok).toBe(false);
    expect(calculateViewport(-1, 1080).ok).toBe(false);
  });

  it("calculates viewport for 5120x1440 super-ultrawide", () => {
    const result = calculateViewport(5120, 1440);
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.value.x).toBe(1280);
      expect(result.value.width).toBe(2560);
    }
  });
});

describe("percentToPixel", () => {
  it("converts 50% of 1920 to 960", () => {
    expect(percentToPixel(50, 1920)).toBe(960);
  });

  it("converts 65% of 3440 to 2236", () => {
    expect(percentToPixel(65, 3440)).toBe(2236);
  });

  it("converts 0% to 0", () => {
    expect(percentToPixel(0, 1920)).toBe(0);
  });

  it("converts 100% to full value", () => {
    expect(percentToPixel(100, 1440)).toBe(1440);
  });

  it("handles rounding down", () => {
    expect(percentToPixel(33, 100)).toBe(33);
    expect(percentToPixel(33, 1920)).toBe(633);
  });
});

describe("calculateTilePositions", () => {
  it("returns empty array for 0 windows", () => {
    expect(calculateTilePositions(0, 1920, 1080)).toEqual([]);
  });

  it("maximizes single window", () => {
    const tiles = calculateTilePositions(1, 1920, 1080);
    expect(tiles).toHaveLength(1);
    expect(tiles[0]).toEqual({ x: 0, y: 0, width: 1920, height: 1080 });
  });

  it("splits 2 windows side-by-side", () => {
    const tiles = calculateTilePositions(2, 1920, 1080);
    expect(tiles).toHaveLength(2);
    expect(tiles[0]).toEqual({ x: 0, y: 0, width: 960, height: 1080 });
    expect(tiles[1]).toEqual({ x: 960, y: 0, width: 960, height: 1080 });
  });

  it("tiles 3 windows in 2x2 grid", () => {
    const tiles = calculateTilePositions(3, 1920, 1080);
    expect(tiles).toHaveLength(3);
    expect(tiles[0]).toEqual({ x: 0, y: 0, width: 960, height: 540 });
    expect(tiles[1]).toEqual({ x: 960, y: 0, width: 960, height: 540 });
    expect(tiles[2]).toEqual({ x: 0, y: 540, width: 960, height: 540 });
  });

  it("tiles 4 windows in 2x2 grid", () => {
    const tiles = calculateTilePositions(4, 3440, 1440);
    expect(tiles).toHaveLength(4);
    expect(tiles[0]).toEqual({ x: 0, y: 0, width: 1720, height: 720 });
    expect(tiles[3]).toEqual({ x: 1720, y: 720, width: 1720, height: 720 });
  });

  it("tiles 6 windows in 3x2 grid", () => {
    const tiles = calculateTilePositions(6, 1920, 1080);
    expect(tiles).toHaveLength(6);
    expect(tiles[0]).toEqual({ x: 0, y: 0, width: 640, height: 540 });
    expect(tiles[5]).toEqual({ x: 1280, y: 540, width: 640, height: 540 });
  });

  it("tiles 5 windows (incomplete 3-col grid)", () => {
    const tiles = calculateTilePositions(5, 1920, 1080);
    expect(tiles).toHaveLength(5);
    // First row: 3 columns
    expect(tiles[0]?.width).toBe(640);
    // Second row: 2 of 3 filled
    expect(tiles[3]?.y).toBe(540);
  });

  it("tiles 7 windows (incomplete third row)", () => {
    const tiles = calculateTilePositions(7, 1920, 1080);
    expect(tiles).toHaveLength(7);
  });
});

describe("percentToPixel edge cases", () => {
  it("handles negative percent", () => {
    const result = percentToPixel(-10, 1920);
    expect(result).toBeLessThan(0);
  });

  it("handles percent above 100", () => {
    const result = percentToPixel(150, 1920);
    expect(result).toBeGreaterThan(1920);
  });
});

describe("calculateViewport edge cases", () => {
  it("rejects zero height with non-zero width", () => {
    const result = calculateViewport(1920, 0);
    expect(result.ok).toBe(false);
  });

  it("rejects zero width with non-zero height", () => {
    const result = calculateViewport(0, 1080);
    expect(result.ok).toBe(false);
  });
});
