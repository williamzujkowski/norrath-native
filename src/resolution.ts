/**
 * Resolution calculation utilities.
 *
 * Pure functions for resolution management — 16:9 clamping, ultrawide
 * detection, viewport calculation, and percentage-to-pixel conversion.
 * Used as the source of truth; bash scripts mirror this logic.
 *
 * @module resolution
 */

import { type Result, ok, err } from './types/interfaces.js';

/** Check if a resolution is ultrawide (wider than 16:9) */
export function isUltrawide(width: number, height: number): boolean {
  return width / height > 16 / 9 + 0.01; // small epsilon for float comparison
}

/** Clamp a resolution to 16:9 aspect ratio (EQ's max supported) */
export function clampTo16x9(
  width: number,
  height: number
): { width: number; height: number } {
  if (isUltrawide(width, height)) {
    return { width: Math.floor((height * 16) / 9), height };
  }
  return { width, height };
}

/** Calculate centered viewport offset for ultrawide monitors */
export function calculateViewport(
  monitorWidth: number,
  monitorHeight: number
): Result<
  { x: number; y: number; width: number; height: number },
  Error
> {
  if (monitorWidth <= 0 || monitorHeight <= 0) {
    return err(new Error('Invalid monitor dimensions'));
  }

  const clamped = clampTo16x9(monitorWidth, monitorHeight);

  if (clamped.width === monitorWidth) {
    // Not ultrawide, no viewport adjustment needed
    return ok({
      x: 0,
      y: 0,
      width: monitorWidth,
      height: monitorHeight,
    });
  }

  const offset = Math.floor(
    (monitorWidth - clamped.width) / 2
  );
  return ok({
    x: offset,
    y: 0,
    width: clamped.width,
    height: clamped.height,
  });
}

/** Convert percentage position to pixel position */
export function percentToPixel(
  percent: number,
  totalPixels: number
): number {
  return Math.floor((percent * totalPixels) / 100);
}

/** Calculate tile positions for N windows on a screen */
export function calculateTilePositions(
  count: number,
  screenWidth: number,
  screenHeight: number
): Array<{
  x: number;
  y: number;
  width: number;
  height: number;
}> {
  if (count <= 0) return [];

  if (count === 1) {
    return [
      { x: 0, y: 0, width: screenWidth, height: screenHeight },
    ];
  }

  if (count === 2) {
    const halfW = Math.floor(screenWidth / 2);
    return [
      { x: 0, y: 0, width: halfW, height: screenHeight },
      { x: halfW, y: 0, width: halfW, height: screenHeight },
    ];
  }

  // 3-4: 2x2 grid
  if (count <= 4) {
    const halfW = Math.floor(screenWidth / 2);
    const halfH = Math.floor(screenHeight / 2);
    const positions = [
      { x: 0, y: 0 },
      { x: halfW, y: 0 },
      { x: 0, y: halfH },
      { x: halfW, y: halfH },
    ];
    return positions.slice(0, count).map((p) => ({
      ...p,
      width: halfW,
      height: halfH,
    }));
  }

  // 5-6: 3x2 grid
  const thirdW = Math.floor(screenWidth / 3);
  const halfH = Math.floor(screenHeight / 2);
  const result: Array<{
    x: number;
    y: number;
    width: number;
    height: number;
  }> = [];
  for (let i = 0; i < count && i < 6; i++) {
    result.push({
      x: (i % 3) * thirdW,
      y: Math.floor(i / 3) * halfH,
      width: thirdW,
      height: halfH,
    });
  }
  return result;
}
