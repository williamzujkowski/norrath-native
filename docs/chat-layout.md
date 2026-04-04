# Recommended Chat Window Layout

*This guide explains the norrath-native recommended chat window setup for raiding.*

## Design Principles

1. **Social messages stay visible** — You never want to miss a tell, guild message, or raid instruction
2. **Your combat is separated** — So you can monitor DPS and healing without social noise
3. **Others' spam is contained** — Raid combat spam goes to a dedicated window you can ignore
4. **Loot and alerts catch your eye** — Deaths, aggro warnings, and loot in their own space

## The 4-Window Layout

### Window 0: "Social" (keep visible at all times)

Everything you'd want to read and respond to:

| Channel | Color | Why Here |
|---|---|---|
| Tell | Pink `#ff80ff` | Never miss a /tell |
| Guild | Green `#00e600` | Guild chat |
| Group | Blue `#82b4ff` | Group coordination |
| Raid | Orange `#ffa500` | Raid instructions |
| RaidSay | Gold `#ffc832` | Raid leader commands |
| Say | Green `#28f028` | Nearby chat |
| OOC | Teal `#00c8c8` | Zone chat |
| Emote | Orange `#ffc864` | Player emotes |
| Fellowship | Mint `#64ffc8` | Fellowship chat |
| MOTD | Cyan `#00ffff` | Message of the day |
| Auction | Yellow `#ffff00` | Trade |

### Window 1: "Combat" (your personal combat log)

Everything about YOUR character's actions:

| Channel | Color | Why Here |
|---|---|---|
| Your damage dealt | Cream `#ffffc8` | Your melee/spell hits |
| Your spell casts | Yellow `#f0f050` | Casting confirmations |
| Your crits (melee) | Salmon `#ff6464` | Critical melee strikes |
| Your crits (spell) | Gold `#ffc832` | Critical spell damage |
| DoT damage | Purple `#c896ff` | Your damage over time |
| Spell damage | Yellow `#f0f050` | Direct spell damage |
| Your heals | Mint `#64ffc8` | Heals you cast |
| Crit heals | Green `#00ff80` | Critical heals |
| HoT ticks | Blue `#96c8ff` | Heal over time |
| Incoming damage | Salmon `#ff6464` | Damage you take |
| Mob casts on you | Gold `#ffc850` | Incoming spells |
| Pet combat | Purple `#a078c8` | Pet damage/actions |

### Window 2: "Spam" (others' combat — glance occasionally)

Raid combat spam from other players. Dimmed colors so it doesn't distract:

| Channel | Color | Why Here |
|---|---|---|
| Others' damage | Gray-blue `#8296aa` | Other players hitting |
| Others' heals | Gray-green `#78968c` | Other players healing |
| Others' misses | Dim gray `#64788c` | Misses, fizzles |
| NPC says | Periwinkle `#c8c8ff` | NPC dialogue |
| NPC rampage/flurry | Blue `#5a5aff` | Mob special attacks |
| Faction changes | Muted gold `#b4a064` | Faction hits |
| System messages | Pink-white `#ffc8c8` | Misc system output |

### Window 3: "Alerts & Loot" (important notifications)

Things you want to notice but don't need constant visibility:

| Channel | Color | Why Here |
|---|---|---|
| Death messages | Red `#ff3232` | Someone died |
| Low health | BRIGHT RED `#ff0000` | You're dying |
| Aggro messages | Alert red `#ff5050` | Aggro warnings |
| XP/AA gains | Light yellow `#ffff64` | Experience rewards |
| Loot/money | Gold `#ffdc64` | Loot drops |
| Advanced loot | Yellow-gold `#ffdc50` | Loot system |
| Achievements | Gold `#ffc832` | Achievement unlocks |
| Task updates | Orange `#ffa532` | Quest progress |
| Skill changes | Light blue `#c8c8ff` | Skill-ups |
| Random rolls | Light blue `#c8c8ff` | /random results |

## Applying the Layout

```bash
# Preview what would change
make layout --dry-run

# Apply the 4-window layout
make layout

# In-game, type /loadskin to reload the UI
```

## Resolution-Specific Tips

### 1920x1080 (most common)

```
┌─────────────────────────────────────────────┐
│                  Game View                    │
│                                              │
│                                              │
├──────────────┬───────────────┬───────────────┤
│  Social      │  Combat       │ Alerts & Loot │
│  (tells,     │  (your dmg,   │ (death, XP,   │
│   guild,     │   heals,      │  loot, tasks) │
│   group)     │   incoming)   │               │
├──────────────┴───────────────┴───────────────┤
│                    Spam (others' combat)       │
└───────────────────────────────────────────────┘
```

- Social: bottom-left, ~400px wide, ~200px tall
- Combat: bottom-center, ~500px wide, ~200px tall
- Alerts: bottom-right, ~400px wide, ~200px tall
- Spam: very bottom strip, full width, ~100px tall (collapsed)

### 2560x1440

Same layout, scaled proportionally. More room for wider windows.

### 800x600 (multibox background client)

Use 2 windows only:
- Window 0 "Social": tells, guild, group, raid (essential comms)
- Window 1 "Combat": everything else (compact, scrollback when needed)

## Customizing

The layout is applied to the character's `UI_charname_server.ini` file in the `[ChatManager]` section. Each `ChannelMapN` entry maps a filter ID to a window index (0-3).

You can adjust which channels go to which window by editing the layout in the config or using the in-game right-click menu on each chat window tab.

## Sources

- [RedGuides: What are your windows and chat filters?](https://www.redguides.com/community/threads/what-are-your-windows-and-chat-filters.89674/)
- [Bonzz's EQ Communication Guide](https://www.bonzz.com/channels.htm)
- [ZAM: Chat Window Guide](https://everquest.allakhazam.com/story.html?story=9921)
- [RedGuides: Chat Window Filters](https://www.redguides.com/community/threads/chat-window-filters.89542/)
