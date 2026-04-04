# Layout Templates

Layout templates define how EQ windows are arranged on screen and how
the in-game UI elements are positioned within each window.

## Two Layers of Layout

### Layer 1: Wine Desktop Tiling
Where each EQ instance window sits on your physical screen.
Managed by `window_manager.sh` (make tile, make pip).

### Layer 2: EQ Internal UI
Where chat windows, target frames, hotbars, etc. sit within each EQ instance.
Managed by `apply_layout.sh` and the layout templates here.

## Template Format

Templates are shell-parseable files defining percentage-based positions
that get calculated to pixel values for any screen resolution.

## Available Templates

- `multibox-bard-pull.conf` — Bard main (large), SK+BER (stacked right)
- `raid-solo.conf` — Main EQ left, utilities right
- `standard-solo.conf` — Single client, full screen
- `standard-multi.conf` — Equal tiling for 3+ clients

## Custom Templates

Copy any template and modify the percentages. Then:
```bash
make profile-load PROFILE=my-custom-layout
```
