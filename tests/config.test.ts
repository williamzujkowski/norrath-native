import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { writeFileSync, mkdirSync, rmSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import {
  resolveConfig,
  generateManagedSettings,
} from '../src/config.js';

describe('resolveConfig', () => {
  let tempDir: string;

  beforeEach(() => {
    tempDir = join(tmpdir(), `nn-config-test-${Date.now()}`);
    mkdirSync(tempDir, { recursive: true });
  });

  afterEach(() => {
    rmSync(tempDir, { recursive: true, force: true });
  });

  it('returns defaults when no config file exists', () => {
    const result = resolveConfig(join(tempDir, 'nonexistent.yaml'));
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.value.instances).toBe(1);
      expect(result.value.multiboxInstances).toBe(3);
      expect(result.value.profile).toBe('high');
      expect(result.value.display).toBe('x11');
    }
  });

  it('reads instances from YAML', () => {
    const configPath = join(tempDir, 'config.yaml');
    writeFileSync(configPath, 'instances: 4\n');
    const result = resolveConfig(configPath);
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.value.instances).toBe(4);
    }
  });

  it('reads multibox_instances from YAML', () => {
    const configPath = join(tempDir, 'config.yaml');
    writeFileSync(configPath, 'multibox_instances: 6\n');
    const result = resolveConfig(configPath);
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.value.multiboxInstances).toBe(6);
    }
  });

  it('applies balanced profile', () => {
    const configPath = join(tempDir, 'config.yaml');
    writeFileSync(configPath, 'profile: balanced\n');
    const result = resolveConfig(configPath);
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.value.eqSettings.maxFps).toBe(45);
      expect(result.value.eqSettings.maxBgFps).toBe(15);
      expect(result.value.eqSettings.clipPlane).toBe(10);
      expect(result.value.eqSettings.spellParticles).toBe(0.5);
    }
  });

  it('applies minimal profile', () => {
    const configPath = join(tempDir, 'config.yaml');
    writeFileSync(configPath, 'profile: minimal\n');
    const result = resolveConfig(configPath);
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.value.eqSettings.maxFps).toBe(15);
      expect(result.value.eqSettings.sound).toBe(false);
      expect(result.value.eqSettings.spellParticles).toBe(0);
    }
  });

  it('reads resolution from YAML', () => {
    const configPath = join(tempDir, 'config.yaml');
    writeFileSync(configPath, 'resolution: 2560x1440\n');
    const result = resolveConfig(configPath);
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.value.resolution).toBe('2560x1440');
    }
  });

  it('reads display backend from YAML', () => {
    const configPath = join(tempDir, 'config.yaml');
    writeFileSync(configPath, 'display: wayland\n');
    const result = resolveConfig(configPath);
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.value.display).toBe('wayland');
    }
  });

  it('ignores comments in YAML values', () => {
    const configPath = join(tempDir, 'config.yaml');
    writeFileSync(
      configPath,
      'instances: 2 # two clients\nprofile: low # save power\n'
    );
    const result = resolveConfig(configPath);
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.value.instances).toBe(2);
      expect(result.value.profile).toBe('low');
    }
  });

  it('expands ~ in prefix path', () => {
    const configPath = join(tempDir, 'config.yaml');
    writeFileSync(configPath, 'prefix: ~/.wine-test\n');
    const result = resolveConfig(configPath);
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.value.prefix).not.toContain('~');
      expect(result.value.prefix).toContain('.wine-test');
    }
  });
});

describe('generateManagedSettings', () => {
  it('generates all required keys', () => {
    const result = resolveConfig();
    expect(result.ok).toBe(true);
    if (!result.ok) return;

    const settings = generateManagedSettings(result.value);

    // Core keys
    expect(settings['WindowedMode']).toBe('TRUE');
    expect(settings['UpdateInBackground']).toBe('1');
    expect(settings['Log']).toBe('TRUE');
    expect(settings['AllowResize']).toBe('1');

    // CPU affinity (12 cores)
    for (let i = 0; i < 12; i++) {
      expect(settings[`ClientCore${String(i)}`]).toBe('-1');
    }

    // Profile-dependent
    expect(settings['PostEffects']).toBe('FALSE');
    expect(settings['MultiPassLighting']).toBe('FALSE');
  });

  it('generates 35 total managed settings (high profile)', () => {
    const result = resolveConfig();
    expect(result.ok).toBe(true);
    if (!result.ok) return;

    const settings = generateManagedSettings(result.value);
    expect(Object.keys(settings).length).toBe(35);
  });

  it('reflects profile in FPS values', () => {
    const configPath = join(
      tmpdir(),
      `nn-test-${Date.now()}.yaml`
    );
    writeFileSync(configPath, 'profile: minimal\n');
    const result = resolveConfig(configPath);
    expect(result.ok).toBe(true);
    if (!result.ok) return;

    const settings = generateManagedSettings(result.value);
    expect(settings['MaxBGFPS']).toBe('5');
    expect(settings['Sound']).toBe('0');
    rmSync(configPath);
  });
});
