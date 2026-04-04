import { describe, it, expect } from 'vitest';
import {
  COLOR_SCHEME,
  generateColorIniEntries,
  getContrastRatio,
  validateSchemeContrast,
} from '../src/colors.js';

describe('COLOR_SCHEME', () => {
  it('has 91 entries', () => {
    expect(Object.keys(COLOR_SCHEME).length).toBe(91);
  });

  it('Tell color is pink (255,128,255)', () => {
    expect(COLOR_SCHEME[12]).toEqual(
      expect.objectContaining({ r: 255, g: 128, b: 255 }),
    );
    expect(COLOR_SCHEME[12].name).toBe('Tell');
  });

  it('Guild color is green (0,230,0)', () => {
    expect(COLOR_SCHEME[11]).toEqual(
      expect.objectContaining({ r: 0, g: 230, b: 0 }),
    );
    expect(COLOR_SCHEME[11].name).toBe('Guild');
  });

  it('Default color is white (255,255,255)', () => {
    expect(COLOR_SCHEME[1]).toEqual(
      expect.objectContaining({ r: 255, g: 255, b: 255 }),
    );
    expect(COLOR_SCHEME[1].name).toBe('Default');
  });

  it('Say color is green (40,240,40)', () => {
    expect(COLOR_SCHEME[4]).toEqual(
      expect.objectContaining({ r: 40, g: 240, b: 40 }),
    );
  });

  it('Group color is soft blue (130,180,255)', () => {
    expect(COLOR_SCHEME[9]).toEqual(
      expect.objectContaining({ r: 130, g: 180, b: 255 }),
    );
  });

  it('Raid color is orange (255,165,0)', () => {
    expect(COLOR_SCHEME[10]).toEqual(
      expect.objectContaining({ r: 255, g: 165, b: 0 }),
    );
  });

  it('OOC color is cyan (0,200,200)', () => {
    expect(COLOR_SCHEME[13]).toEqual(
      expect.objectContaining({ r: 0, g: 200, b: 200 }),
    );
  });

  it('DamageTaken color is red (255,100,100)', () => {
    expect(COLOR_SCHEME[30]).toEqual(
      expect.objectContaining({ r: 255, g: 100, b: 100 }),
    );
  });

  it('LowHealth color is bright red (255,0,0)', () => {
    expect(COLOR_SCHEME[151]).toEqual(
      expect.objectContaining({ r: 255, g: 0, b: 0 }),
    );
  });

  it('all RGB values are 0-255 integers', () => {
    for (const [, color] of Object.entries(COLOR_SCHEME)) {
      expect(color.r).toBeGreaterThanOrEqual(0);
      expect(color.r).toBeLessThanOrEqual(255);
      expect(color.g).toBeGreaterThanOrEqual(0);
      expect(color.g).toBeLessThanOrEqual(255);
      expect(color.b).toBeGreaterThanOrEqual(0);
      expect(color.b).toBeLessThanOrEqual(255);
      expect(Number.isInteger(color.r)).toBe(true);
      expect(Number.isInteger(color.g)).toBe(true);
      expect(Number.isInteger(color.b)).toBe(true);
    }
  });

  it('all entries have non-empty names', () => {
    for (const [, color] of Object.entries(COLOR_SCHEME)) {
      expect(color.name.length).toBeGreaterThan(0);
    }
  });
});

describe('generateColorIniEntries', () => {
  it('produces 273 entries (91 colors * 3 RGB components)', () => {
    const entries = generateColorIniEntries();
    expect(Object.keys(entries).length).toBe(273);
  });

  it('generates correct key format User_N_Color', () => {
    const entries = generateColorIniEntries();
    expect(entries['User_12_Red']).toBe('255');
    expect(entries['User_12_Green']).toBe('128');
    expect(entries['User_12_Blue']).toBe('255');
  });

  it('generates correct values for Guild color', () => {
    const entries = generateColorIniEntries();
    expect(entries['User_11_Red']).toBe('0');
    expect(entries['User_11_Green']).toBe('230');
    expect(entries['User_11_Blue']).toBe('0');
  });

  it('all values are string representations of integers', () => {
    const entries = generateColorIniEntries();
    for (const [, value] of Object.entries(entries)) {
      expect(value).toMatch(/^\d{1,3}$/);
    }
  });
});

describe('getContrastRatio', () => {
  it('returns 21:1 for white on black', () => {
    const ratio = getContrastRatio(
      { r: 255, g: 255, b: 255 },
      { r: 0, g: 0, b: 0 },
    );
    expect(ratio).toBeCloseTo(21, 0);
  });

  it('returns 1:1 for same colors', () => {
    const ratio = getContrastRatio(
      { r: 128, g: 128, b: 128 },
      { r: 128, g: 128, b: 128 },
    );
    expect(ratio).toBe(1);
  });

  it('is symmetric (fg/bg order does not matter)', () => {
    const a = { r: 255, g: 100, b: 100 };
    const b = { r: 0, g: 0, b: 50 };
    expect(getContrastRatio(a, b)).toBeCloseTo(getContrastRatio(b, a), 5);
  });

  it('returns correct ratio for known WCAG example', () => {
    // Pure white on pure black = 21:1
    const ratio = getContrastRatio(
      { r: 255, g: 255, b: 255 },
      { r: 0, g: 0, b: 0 },
    );
    expect(ratio).toBeCloseTo(21, 0);
  });
});

describe('validateSchemeContrast', () => {
  const DARK_BG = { r: 13, g: 13, b: 26 };

  it('returns one result per color in the scheme', () => {
    const results = validateSchemeContrast(DARK_BG);
    expect(results.length).toBe(91);
  });

  it('all colors pass WCAG AA (4.5:1) against dark background', () => {
    const results = validateSchemeContrast(DARK_BG);
    const failing = results.filter((r) => !r.passes);
    expect(failing).toEqual([]);
  });

  it('each result has id, name, ratio, and passes fields', () => {
    const results = validateSchemeContrast(DARK_BG);
    for (const result of results) {
      expect(typeof result.id).toBe('number');
      expect(typeof result.name).toBe('string');
      expect(typeof result.ratio).toBe('number');
      expect(typeof result.passes).toBe('boolean');
    }
  });

  it('white on dark background has high contrast', () => {
    const results = validateSchemeContrast(DARK_BG);
    const white = results.find((r) => r.id === 1);
    expect(white).toBeDefined();
    expect(white!.ratio).toBeGreaterThan(15);
    expect(white!.passes).toBe(true);
  });
});
