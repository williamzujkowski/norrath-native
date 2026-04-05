---
title: Chat Layout Profiles
description: Role-specific chat window configurations for raiding
source: src/layout.ts
updated: auto-generated
---

# Chat Layout Profiles

norrath-native includes optimized chat layouts for different roles.
All layouts use 4 windows with WCAG AA-compliant colors.

## Default (Raid DPS / General)

Best for: DPS classes, general play, multibox boxes

| Window   | Contents                                   |
| -------- | ------------------------------------------ |
| 0 Social | Tells, guild, group, raid, say, emote, OOC |
| 1 Combat | Your damage, heals, incoming, crits, pet   |
| 2 Spam   | Others' combat, NPC dialogue, system       |
| 3 Alerts | Death, loot, XP, achievements, server msgs |

## Healer Profile

Best for: Clerics, druids, shamans — healing spam is prominent

| Window    | Contents                                     |
| --------- | -------------------------------------------- |
| 0 Social  | Tells, guild, group, raid, say               |
| 1 Healing | Your heals, incoming heals, HoTs, pet heals  |
| 2 Combat  | Your damage, incoming damage, others' combat |
| 3 Alerts  | Death (critical!), loot, XP, low HP alerts   |

Key difference: Healing gets its own dedicated window instead of
being mixed with damage. Death alerts in the Alerts window flash
red for immediate visibility.

## Tank Profile

Best for: Warriors, shadowknights, paladins — incoming damage is prominent

| Window     | Contents                                                  |
| ---------- | --------------------------------------------------------- |
| 0 Social   | Tells, guild, group, raid, say                            |
| 1 Incoming | Incoming melee, incoming spells, damage taken, riposte    |
| 2 Outgoing | Your melee, your spells, your heals, others' heals on you |
| 3 Alerts   | Death, loot, raid invites, server msgs                    |

Key difference: Incoming damage has its own window. Tank sees
exactly what's hitting them and how hard.

## Box Profile (Minimal)

Best for: Multibox characters that you monitor but don't actively read

| Window            | Contents                              |
| ----------------- | ------------------------------------- |
| 0 All Chat        | Tells, guild, group, raid, say, emote |
| 1 Everything Else | All combat, all damage, all healing   |
| 2 (unused)        | —                                     |
| 3 Alerts          | Death only (bright red, unmissable)   |

Key difference: Minimal windows to reduce visual noise. Only 2 active
windows. Death alerts are the only critical filter.

## Applying a Profile

```bash
make layout              # Apply default (raid DPS) layout
# Future: make layout PROFILE=healer
# Future: make layout PROFILE=tank
# Future: make layout PROFILE=box
```

## Customizing

Edit `norrath-native.yaml`:

```yaml
# Chat layout profile (default, healer, tank, box)
chat_layout: default
```

Or manually adjust in-game: right-click any chat tab → Filters.
