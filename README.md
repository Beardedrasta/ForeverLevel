# Forever Level

**A compact, customizable leveling companion for World of Warcraft: Forever.**

Forever Level combines an unobtrusive, Blizzard-inspired gold tracker with a detailed leveling journal. Keep an eye on your progress while you play, then open the journal when you want to examine your session, leveling pace, and history.

## Features

- **Four compact panels:** estimated kills to level, quests to level, level progress, and time to level.
- **Adaptive dock:** hiding a panel automatically closes the gap and resizes the tracker and vertical XP strip.
- **Flexible arrangement:** dock panels together or detach and move them independently; lock to prevent accidental dragging.
- **Blizzard-inspired UI:** textured borders with Antique, Royal, and Bright gold presets, plus adjustable scale and opacity.
- **Vertical XP strip:** Current XP or Current + Rested XP modes.
- **Leveling projections:** full-session, recent 5-minute, and estimated active XP/hour; recent 20-kill estimates.
- **Leveling Journal:** Session, Lifetime, Sources, Efficiency, Zones, and History views.
- **Persistent per-character settings and totals**, including level history and online level-time tracking.

The numbers are based on game events and observable changes in XP. Source attribution and activity estimates can be incomplete, especially when XP is awarded in unusual ways or the client reports rewards asynchronously.

## Compatibility

- **Game:** World of Warcraft: Forever
- **Target game version:** 1.60.1
- **Interface number:** `16001`
- **Dependencies:** none intended
- **Other flavors:** Retail, Classic Era, and other clients are **not** supported by this release.

## Installation

1. Exit WoW Forever.
2. Download the release ZIP and extract it.
3. Copy the contained **`ForeverLevel`** folder directly into the Forever client's `Interface/AddOns` folder (typically `World of Warcraft/_forever_/Interface/AddOns/`).
4. Verify the layout: `Interface/AddOns/ForeverLevel/ForeverLevel.toc`. Do not leave an extra nested folder.
5. Start the game and enable **Forever Level** in the AddOns list if necessary.
6. Type `/fl config` to customize or `/fl journal` to open statistics.

## Main commands

| Command                               | Action                                                                |
| ------------------------------------- | --------------------------------------------------------------------- |
| `/fl config`                          | Open configuration                                                    |
| `/fl journal`                         | Open journal                                                          |
| `/fl sources`                         | Show XP source breakdown                                              |
| `/fl efficiency`                      | Show leveling efficiency                                              |
| `/fl zones`                           | Show zone performance                                                 |
| `/fl history`                         | Show level-up history                                                 |
| `/fl timing`                          | Report current level's recorded online time                           |
| `/fl dock` / `/fl detach`             | Switch docked/detached mode                                           |
| `/fl lock` / `/fl unlock`             | Lock/unlock movement                                                  |
| `/fl hide quests` / `/fl show quests` | Hide/show an individual panel (also: `kills`, `level`, `time`, `all`) |
| `/fl rate session\|recent\|active`    | Choose time projection                                                |
| `/fl kills session\|recent`           | Choose kill projection                                                |
| `/fl xpbar current\|both`             | Choose vertical XP strip display                                      |
| `/fl border antique\|royal\|bright`   | Change Blizzard-border gold tint                                      |
| `/fl activity 60\|90\|120`            | Change estimated active-time window                                   |
| `/fl stats`                           | Print session summary                                                 |
| `/fl reset`                           | Reset session only; preserve lifetime stats                           |
| `/fl pos`                             | Print position diagnostics                                            |
| `/fl layout`                          | Reset tracker positions                                               |

## Understanding the statistics

- **Full-session XP/hour** uses all online time since session start, including downtime.
- **Recent XP/hour** estimates gains over the rolling five-minute period.
- **Active XP/hour** uses a configurable post-XP activity window; it is a heuristic, not a measurement of combat time.
- **Zone XP/hour** divides XP observed within a zone by recorded online time there. A zone with the highest measured rate may not be the best location in general.
- **History time** records time observed while online. Offline time is excluded; incomplete level observations are marked accordingly.
- **Kill / quest / other XP** are approximate categories based on reported rewards; the addon may not identify every XP source.

## Screenshots

## Troubleshooting

- **Addon missing:** confirm folder nesting and restart the game after installing new files.
- **No estimates yet:** earn some XP; rates need sufficient samples or elapsed time.
- **No rested blue bar:** the character may have no rested XP; try the `both` option.
- **Unexpected UI error:** run `/console scriptErrors 1`, reproduce it, and include the entire error and Forever client version in a report.
- **Settings unexpectedly reset:** back up your character-specific `WTF` SavedVariables before troubleshooting. Do not delete them as a routine update step.

## Project

Maintainer: [Beardedrasta](https://github.com/Beardedrasta)

Source repository: `https://github.com/Beardedrasta/ForeverLevel` **(planned; create before publishing)**.

For release notes see [CHANGELOG.md](CHANGELOG.md). To report a bug, include your addon version, client version, steps to reproduce, and any Lua error text.

## License
