---
title: Chat Window Setup Guide
description: Step-by-step in-game chat window configuration for raiding
source: EverQuest official documentation, community best practices
updated: 2026-04-05
---

# Chat Window Setup Guide

EverQuest's chat system supports up to 32 windows. This guide sets up
4 windows optimized for raiding with WCAG-compliant colors and timestamps.

## Quick Setup (5 minutes per character)

### Step 1: Create the windows

1. Right-click any chat tab → **"New Chat Window"**
2. A new empty window appears. Right-click its title → **"Rename"** → type **Combat**
3. Right-click the original chat tab → **"New Chat Window"** → rename to **Spam**
4. Right-click again → **"New Chat Window"** → rename to **Alerts**
5. Rename the original tab to **Social** (right-click → Rename)

You now have 4 tabs/windows: **Social | Combat | Spam | Alerts**

### Step 2: Set filters on each window

Right-click each tab → **"Filters"** to open the filter checkboxes.

#### Social (your main chat)

Enable ONLY:

- [x] Say, Tell, Group, Guild, Raid, OOC, Shout, Emote
- [x] Fellowship, Broadcast
- [x] Pet responses
- [ ] Uncheck everything else

#### Combat (your damage and healing)

Enable ONLY:

- [x] Melee (yours), Spells (yours), Skills
- [x] Your critical hits
- [x] Damage taken (incoming)
- [x] Your heals (self and others)
- [x] HoT (heal over time)
- [ ] Uncheck all "Others" categories

#### Spam (others' combat — dimmed)

Enable ONLY:

- [x] Others' melee, Others' spells
- [x] Others' heals, Others' crits
- [x] NPC dialogue
- [x] System messages
- [ ] Uncheck personal combat, social channels

#### Alerts (critical events — red text)

Enable ONLY:

- [x] Death messages
- [x] Loot
- [x] Experience gain
- [x] Achievement
- [x] Server messages
- [x] Faction changes
- [ ] Uncheck all combat, all social

### Step 3: Enable timestamps

Right-click each tab → **"Timestamp"** → select **HH:MM:SS**

Repeat for all 4 windows.

### Step 4: Save your filter set

In chat, type:

```
/fsave raid
```

This saves your current filter configuration. To restore it later:

```
/fload raid
```

### Step 5: Apply colors (automated)

Camp to character select, then:

```bash
make layout --force
make colors --force
```

Log back in. Your chat colors are now WCAG AA-compliant with
raid-optimized contrast.

## Color Reference

| Channel         | Color        | Hex     |
| --------------- | ------------ | ------- |
| Tell            | Bright pink  | #ff80ff |
| Guild           | Bright green | #00e600 |
| Group           | Soft blue    | #82b4ff |
| Raid            | Orange       | #ffa500 |
| Say             | Green        | #28f028 |
| Shout           | Salmon       | #ff6464 |
| Your melee      | Gold         | #f0c800 |
| Your heals      | Mint         | #64ffc8 |
| Incoming damage | Red          | #ff6464 |
| Others' combat  | Dimmed gray  | #6e8296 |
| Death           | BRIGHT RED   | #ff3232 |
| Loot            | Yellow       | #ffff64 |

## Tips

- **Drag tabs** between containers to reorganize
- **Resize** containers by dragging edges
- **Font size**: right-click → Font Size (3-5 recommended for raiding)
- **Scroll**: Shift+PageUp / Shift+PageDown
- **Quick channel**: right-click → "Always Chat Here" to set default
- `/chatfontsize N` changes font size (1-10)
- `/loadskin default` resets appearance if things break

## What `make layout` automates

After you create the windows in-game, `make layout` handles:

- Channel routing (107 channels → 4 windows)
- HH:MM:SS timestamps on all windows
- Tab names (Social, Combat, Spam, Alerts)
- Font styles and highlight settings

The window creation itself must be done in-game (EQ engine limitation).

## References

- [EverQuest Official Chat Guide](https://www.everquest.com/news/imported-eq-enus-50595)
- [EverQuest Chat Channels Guide](https://www.everquest.com/news/imported-eq-enus-50980)
- [Forum: Setting up Chat Windows & Filters](https://forums.everquest.com/index.php?threads/setting-up-chat-windows-filters.255719/)
