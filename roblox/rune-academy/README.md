# Rune Academy

Incremental/idle Roblox game.

> **Full reset in progress.** The Mana/Coins economy and its world
> (kiosks, floor tiles, the Rune Altar) were scrapped on request — the
> world is back to just a baseplate, `GameConfig.Zones` and
> `AscensionTiers` are empty, and every `StarterPlayerScripts` file was
> removed. Everything below `## What's still here` describes the reusable
> backend infrastructure that survived the reset (Runes, Titles, Power
> Store, the generic ResourceEngine); the sections after that describe
> the OLD scrapped design and are kept only as reference for mechanics
> that may come back, not as a description of the current game. A new
> vision is being defined from scratch, one piece at a time.

See `DESIGN.md` for the full (mostly historical, pending rewrite) system
design notes.

## Setup (do this on your gaming PC Monday)

1. Install [Roblox Studio](https://create.roblox.com/) if you haven't.
2. Install [Rojo](https://rojo.space/) — either the VS Code extension +
   the `rojo` CLI (`cargo install rojo` or download from GitHub releases),
   or just the Studio plugin from the Roblox plugin marketplace ("Rojo").
3. Create a new blank Studio place, save it inside this `rune-academy/`
   folder (e.g. `rune-academy/RuneAcademy.rbxl`).
4. From this folder, run:
   ```
   rojo serve
   ```
5. In Studio, open the Rojo plugin panel and click **Connect**. Everything
   in `src/` will sync into the place.
6. Studio should now show just the baseplate — nothing auto-generates a
   world right now (see the reset note above). Building starts fresh once
   the new vision is specified.

## What's still here (survived the reset)

- `GameConfig.lua` — every tunable number lives here: the multi-currency
  `Zones` config (upgrades, self-prestige tiers, chain resets, floor
  tiles), stat definitions, Rune rarity odds + boosts, Ascension tiers.
  Change balance here, not in the handler scripts.
- `NumberFormat.lua` — plain comma-separated whole numbers below a
  million ("999,000"), then a 2-decimal suffix from a million up
  ("5.32B" for 5,324,222,143) - suffix ladder M, B, T, Qd, Qt, St, SEt,
  Oc, No, Dc. Used by every client-side Mana display so far
  (`ManaHUDClient`, `ManaUpgradeBoardClient`'s readout/costs/yield
  preview) - use it for any other currency display that could reach
  seven figures too.
- `PlayerData.lua` — DataStore load/save/autosave, leaderstats, and
  `defaultData()` builds every zone/currency's save-data shape straight
  from `GameConfig.Zones` (add a currency to config, its save slot exists
  automatically — no separate PlayerData change needed).
- `ResourceEngine.lua` — the generic engine every currency runs on:
  server-authoritative collect (click/stand, distance + debounce checked),
  buy upgrade (one/max), self-prestige, chain reset, sell (see below), and
  floor tile purchases. All currencies go through this one module. An
  upgrade slot's `kind` changes what its levels do: `"yield"` (default)
  multiplies that currency's own production; `"tickInterval"` instead
  controls how often `collect()` can fire (a real duration, e.g. Mana's
  1.0s → 0.1s Scrap Respawn upgrade), read via
  `getCollectDebounceSeconds`; `"sellRate"` boosts a `sellInto` conversion
  rate instead of production. A slot's `costCurrency` (optional, defaults
  to the currency it's on) lets it be bought with a DIFFERENT currency —
  e.g. all of Mana's upgrades cost Coins, matching the reference game.
  `sellInto` is a separate mechanic from `chainReset`: it converts ANY
  amount of a currency into another at an upgradeable rate, at ANY time
  (no threshold, no upgrade reset) — Mana → Coins uses this, not a
  chain reset, since you can cash out partial Mana whenever you want.
- `RuneHandler.lua` — server-authoritative gacha pull, Fortune-weighted odds.
- `ResetHandler.lua` — Ascension only (per-currency resets live in
  ResourceEngine now). `GameConfig.AscensionTiers` is empty right now, so
  `ascend()` just returns "No further Ascension tiers" — safe no-op, not
  a bug.
- `Main.server.lua` — wires up RemoteEvents/Functions between client and
  the handlers above.
- `StoreHandler.lua` — the Power Store. Processes GamePass and Developer
  Product purchases server-side, grants stat multipliers/Gems/Scrolls/an
  instant Ascension, tracks Robux spent for the leaderboard, and guards
  against double-granting a retried purchase.
- `TitleHandler.lua` — unlocks and equips Titles (`GameConfig.Titles`),
  mirrors the equipped one onto Player attributes.
- `LeaderboardHandler.lua` — the 4 global leaderboards (Playtime, Robux
  Spent, Total Mana, Runes Opened) shown on the Leaderboard island's sign
  boards, backed by one `OrderedDataStore` per stat so rankings persist
  across restarts and cover every player who's ever played, not just who's
  online - same "DataStores might be unavailable in Studio" defensive
  `pcall` pattern as `PlayerData`, so a missing store just returns an empty
  list instead of crashing. A `task.spawn` loop pushes every online
  player's current stats into the stores every 60s; `PlayerData.onBeforeRelease`
  (not `Players.PlayerRemoving` directly - listener order across separate
  scripts isn't guaranteed, and `PlayerData.release` clearing the session
  could easily run first) does one more sync on the way out so a leaving
  player's final numbers aren't lost to the interval's timing.
  `getTop(statKey, limit)` resolves each entry's player name live via
  `Players:GetNameFromUserIdAsync` and returns `{name, value}` pairs,
  highest first. "Total Mana" reads a new `totalManaEarned` PlayerData
  field (incremented by `ManaHandler.collect` alongside the live `mana`
  balance) rather than the live balance itself, since rebirthing resets
  that to 0 - a lifetime counter is what actually makes sense on a
  leaderboard.
- `SecondIslandHandler.lua` — owns the SecondIsland unlock: `meetsRequirement`
  (40,000,000 Mana / 40,000 Rebirths / Level 25, read straight off
  `PlayerData`), `getState` (for the gate's client UI to show the
  requirement and enable/disable its Unlock button live), and `unlock` -
  which actually SPENDS the exact Mana/Rebirths requirement and sets the
  permanent `secondIslandUnlocked` flag, rather than just checking a
  threshold and leaving the balance untouched. Calling `unlock` on an
  already-unlocked player is a harmless no-op success, so a stale/retried
  client call can't double-charge them.
- `FriendBoostHandler.lua` — tracks how many of a player's Roblox friends
  are in the same server (live, never saved); `ResourceEngine` applies
  `GameConfig.FriendBoost` on top of any currency flagged
  `friendBoost = true`, once a currency has that flag again.

- `WorldBuilder.server.lua` — generates world content on server start.
  Builds a 120x120 floating grass island (`StartingIsland`, Roblox's
  built-in Grass material, no image asset needed) 60 studs up, and lifts
  `SpawnLocation` onto its surface — everything else (platform, Mana
  nodes, kiosk board) is positioned relative to `SpawnLocation`, so it
  all rides up with it. Walk off the edge and you fall into the void; a
  poll every 0.5s (`FALL_CHECK_INTERVAL`) kills any player who's fallen
  30 studs below the island surface, and Roblox respawns them at
  `SpawnLocation` automatically, same as any other death. This is a
  manual poll rather than the simpler `Workspace.FallenPartsDestroyHeight`
  because writing that property from a normal server Script is blocked
  ("lacking capability Plugin") - Roblox restricts it to Studio/plugin
  contexts. Contains the 60x60 Mana collection platform (a hollow square outline,
  4 thin Neon parts, non-collide) plus Mana cubes spawned inside it.
  Collection is range-based, not touch-based: a `COLLECT_CHECK_INTERVAL`
  (0.15s) poll collects any live node within a player's current
  "Collection Range" upgrade radius (`CollectionRangeHandler`) — the
  same radius `ManaRingClient` draws as a ring around their feet. Every
  pickup also grants XP through `XPHandler.grantXpForPickup`, firing
  `XPUpdated` for the bottom-middle XP bar. A
  replacement node spawns elsewhere after a delay set by the collecting
  player's own "Mana Spawn Speed" level. That same level also sets how
  many nodes exist at once (3 at level 1, up to 10 at level 10, taking
  the max across everyone online) — a `TOP_UP_INTERVAL` poll spawns more
  as needed, not just on pickup, so a purchase (or another player's
  higher level) adds nodes right away.
  Also places physical kiosk boards past the platform's edge, each just
  outside the previous one's far edge - `ManaUpgradeBoard` (42 studs wide,
  the 4-column Mana upgrades board), `RebirthBoard` (20 studs wide, the
  reset-for-Rebirths action board), `RebirthShopBoard` (32 studs
  wide, fitting its 3 columns edge-to-edge; rotated -90 degrees from the other
  two since it's the last board at the end of the row, so it faces back
  along the row instead of straight ahead - that rotation also swaps
  which of its dimensions runs along the row, so its offset uses half
  its thickness there instead of half its width, to sit flush against
  the Rebirth board's edge) - each just a bare Part
  (Glass material, 0.7 transparency, for a see-through card look - still
  solid, `CanCollide` stays true); `ManaUpgradeBoardClient`,
  `RebirthBoardClient`, and `RebirthShopBoardClient` build their actual UI (their SurfaceGui
  backgrounds are also transparent, so the glass shows through behind the
  UI, not just around its edges). Grows
  one piece at a time as the new vision gets specified — rerunning it
  (every server start) rebuilds the `StartingIsland`, `ManaZone`, and
  `Kiosks` from scratch, so editing this file and reconnecting Rojo is
  how you iterate on world layout.
  The first of those future areas is now built too: a `SecondIsland` (same
  120x120 footprint as the starting island) straight out along +Z from it -
  the direction the kiosk row reads as being on your left when facing it -
  shifted `SECOND_ISLAND_OFFSET_X` (-25 studs, i.e. right, away from
  `RebirthShopBoard`) so it doesn't crowd that board. `IslandBridge` is a
  small folder of parts instead of one flat slab - a thin `BridgeDeck`
  (WoodPlanks) with two `BridgeRail` cylinders along its edges and
  `BridgePost` supports every `BRIDGE_POST_SPACING` studs, for a rope-bridge
  look. A translucent red `SecondIslandGate` sits at the bridge's near end
  (`ForceField` material, `CanCollide` false - purely visual, built bare
  here; its "LOCKED" sign and Unlock button are built client-side by
  `SecondIslandGateClient` instead of as a static server sign, since they
  need to be interactive and to disappear locally once that specific
  player unlocks it). The physical block is enforced by a
  `GATE_CHECK_INTERVAL` (0.25s) poll, same pattern as the fall-kill check:
  anyone without the permanent `secondIslandUnlocked` flag set gets
  teleported back onto the starting island the moment they step onto the
  bridge - meeting the 40,000,000 Mana / 40,000 Rebirths / Level 25
  requirement is no longer enough by itself. Only pressing the gate's
  Unlock button (`SecondIslandHandler.unlock`) sets that flag, and doing
  so actually SPENDS the Mana/Rebirths requirement (Level is checked but
  never spent - there's nothing to take from a level) rather than just
  checking it, per direct correction to the original "walk up and it
  auto-unlocks for free" design. Restricted to the bridge's own width so
  it never touches someone just walking near the starting island's edge
  elsewhere. `ArcaneDustUpgradeBoard` sits near the island's -X edge
  (`ARCANE_DUST_AREA_X`, 15 studs in from the edge), un-rotated - thin
  along X, wide along Z, running parallel to the edge like the starting
  island's kiosk row - facing inward toward the island's center, "Right"
  instead of the row's "Left". `ArcaneDustPad` - a flat cylinder (Neon
  material, rotated flat, colored blue to match the Arcane Dust icon's own
  palette, per direct request - was gold before) with a small floating
  "Stand for Arcane Dust" `BillboardGui` label, kept small and given a
  `MaxDistance` (20 studs) so it only shows up close instead of being
  readable from across the map - sits `ARCANE_DUST_PAD_FRONT_OFFSET` (12)
  studs in front of the board, along its +X facing direction, at the same
  Z - directly facing the board, not off to the side along the edge like
  an earlier layout had it. The second wizard resource, entirely separate
  from Mana (no Rebirth Shop interaction, not reset by rebirthing - though
  a Wizard Tier purchase, below, DOES reset it). No pickup nodes to
  walk past, per direct request - standing on the pad's radius grants
  Arcane Dust immediately, then again every `ArcaneDustSpawnHandler`
  interval for as long as you stay; step off and the timer
  (`arcaneDustNextGrant`, keyed per player) resets, so it's "stand here to
  farm," not "walk past to collect once." The board's own 3-column UI
  (`ArcaneDustUpgradeBoardClient`), widened from 24 to 30 studs to fit the
  3rd column, has "More Arcane Dust", "Grant Speed" (how often the pad pays
  out), and "More Mana" (boosts Mana Per Pickup, costed in Arcane Dust -
  see `ManaBoostHandler` below). Themed blue throughout (title, column
  names, background tint) to match the Arcane Dust icon, per direct
  request - was gold before.
  Right next to it (same X, offset along +Z where the island has 80+ studs
  of open room, unlike the ~10 left on the -Z/bridge side) sits
  `WizardTierBoard` (36 studs wide, bigger than the Arcane Dust board per
  direct request) - see `WizardTierHandler`/`WizardTierBoardClient` below.
  Further along +Z past that (Tier 3's unlock, "a Fantasy ruin to the left
  of the Tier card") sits `FantasyRuin` - a 26x26 stud decorative plaza:
  a glowing purple rune circle (same flat-cylinder trick as
  `ArcaneDustPad`, just bigger) under a floating gold orb, 6 broken stone
  pillars of varying height/tilt in a ring around it, a crumbling 2-pillar
  archway with a lintel that stops short of the far pillar instead of
  spanning the whole gap, and 8 scattered rubble blocks. Every part starts
  hidden (`Transparency = 1`, `CanCollide = false`) - it's shared world
  geometry, but players can be at different Wizard Tiers simultaneously,
  so `WizardRuinClient` reveals it LOCALLY per-player (same pattern as
  `SecondIslandGateClient`) once `WizardTierHandler.hasUnlockedRuin`
  reports true for them.
  In the open grass between `ArcaneDustPad` and the tree line (a best
  guess from a screenshot showing where to place it, same as every other
  placement here) sits `UpgradeTreeTiles`, the start of a ground upgrade
  tree - `UpgradeTreeTile1`, a 6x6 stud paving-stone tile, is walked over
  instead of clicked like every other upgrade, per direct request. See
  `UpgradeTreeHandler`/`UpgradeTreeClient` below; only Tile 1 exists so
  far, with a planned 1-2-3-2-1 diamond of tiles to come.
  Also a ring of procedurally placed trees/bushes/flowers
  (`SecondIslandDecor`) around its
  edge, inset from the border, skipping the bridge's landing spot, and each
  given a small random `DECOR_JITTER` offset so the ring reads as staggered
  rather than a perfectly straight line. Each piece is also built from
  several overlapping/stacked parts (three canopy clumps per tree, three
  bumps per bush, a stem + bloom per flower) instead of one plain shape, for
  a fuller look than a single sphere or dot. This scattering logic lives in
  a shared `scatterIslandDecor(folder, centerX, centerZ, size, nearEdgeSign)`
  function - `nearEdgeSign` just flips which edge is the one to skip, so
  the same function rings both SecondIsland and LeaderboardIsland despite
  their bridges approaching from opposite directions. The exact direction/size
  (`BRIDGE_LENGTH`/`BRIDGE_WIDTH`/`SECOND_ISLAND_SIZE`/
  `SECOND_ISLAND_OFFSET_X`) is a best guess from a screenshot, same "nudge
  the numbers after testing" situation as the kiosk board offsets above if
  it's not quite lined up.
  A third island - `LeaderboardIsland` (80x80, smaller than the other two -
  it's just holding sign boards) - goes the opposite direction, straight
  out along -Z, the side that reads as "to the left" of the Mana Upgrades
  board when facing it (the kiosk row itself grows in +Z, `SecondIsland`
  in +Z from the starting island's far edge - this is the one direction
  left unused). `LeaderboardBridge` reuses the exact same deck/rail/post
  look and the same `BRIDGE_*` constants as `IslandBridge`, just with no
  gate - this one is never locked, per direct request. 4 sign boards
  (`LeaderboardPlaytimeBoard`/`LeaderboardRobuxBoard`/
  `LeaderboardManaBoard`/`LeaderboardRunesBoard`) sit in a row set well
  back from the island's near edge (not just past the entrance), same
  Glass-card physical style as the main kiosks but thin along Z instead of
  X so their wide face points back at a player crossing the bridge from
  +Z; `LeaderboardBoardClient` builds each one's UI with a clear/see-through
  background (matching every other board's look, not an opaque sign),
  pulling its top-5 list from the new `GetLeaderboard` remote
  (`LeaderboardHandler`). Ringed with the same tree/bush/flower decoration
  as `SecondIsland` (see `scatterIslandDecor` below), inset from its own
  edge and skipping the bridge's landing spot on its near (+Z) side instead
  of the -Z side `SecondIsland` skips.
- `UpgradeCost.lua` — the one shared cost curve every Mana upgrade costs
  its levels through (`costForLevel(currentLevel) = currentLevel * 10`),
  so the very first purchase (from level 1) always costs 10 Mana no
  matter which upgrade it is — keeps every upgrade "in line" with the
  others as more get added, instead of each handler inventing its own curve.
- `ManaHandler.lua` — server-authoritative Mana collection and its "Mana
  Per Pickup" upgrade (level 1-100). The yield itself is a mildly convex
  curve, not flat +1/level - `amountForLevel(level) = floor(level *
  (level + 5) / 6)` - so later levels pay off faster than early ones
  (level 1 gives 1, level 15 gives 50). Cost is NOT the shared
  `UpgradeCost` curve anymore - it tracks the yield curve itself
  (`amountForLevel(currentLevel) * 10`), so cost scales with the payoff
  instead of a flat level*10 making high levels feel cheap relative to
  what they gave (level 1 still costs 10, but level 9 - to reach level
  10's +25/pickup - now costs 210 instead of 90). Every pickup is also
  scaled by `RebirthShopHandler`'s permanent "Mana Value Multiplier"
  (1x-200x, survives rebirthing), `ManaBoostHandler`'s "More Mana" upgrade
  (1x-6x, paid in Arcane Dust), and `WizardTierHandler`'s flat tier
  multiplier (1x until Tier 1, then 20x) -
  `amountPerPickup`/`nextAmountPerPickup` in the returned state already
  include all three, so the board always shows
  the real effective yield. `buyYieldUpgrade` takes an optional `"max"`
  mode that buys as many levels in a row as currently affordable.
  Deliberately kept separate from `ResourceEngine`/`GameConfig.Zones`
  for now — a fresh, much simpler mechanic until the new vision needs more.
- `ManaSpawnHandler.lua` — the "Mana Spawn Speed" upgrade (level 1-10,
  same `UpgradeCost` curve as every other Mana upgrade). Two effects per
  level, both linear: respawn delay 2.0s → 0.2s, and live node count 3 →
  10. `getRespawnSeconds`/`getNodeCount` are read by `WorldBuilder` (the
  latter maxed across everyone online) — the upgrade is per-player even
  though the nodes themselves are shared world objects, same as how
  "Mana Per Pickup" already works.
- `ArcaneDustHandler.lua` — the second wizard resource, entirely separate
  from Mana (no Rebirth Shop multiplier, doesn't interact with Rebirths at
  all, not reset by rebirthing). Mirrors `ManaHandler`'s exact shape and
  yield curve for consistency - its own "More Arcane Dust" upgrade (level
  1-100), its own `arcaneDust` currency and `arcaneDustYieldLevel` field.
  Every collect is also scaled by `WizardTierHandler`'s flat dust
  multiplier (1x until Tier 1, then 5x).
- `ArcaneDustSpawnHandler.lua` — the "Grant Speed" upgrade for
  `ArcaneDustPad` (level 1-10, its grant interval going 1.5s → 0.5s while
  you stand on the pad - lowered from an original 2.0s → 0.2s per direct
  request, 2.0s felt too slow to start) - shaped like `ManaSpawnHandler` (same lerp curve,
  same `getRespawnSeconds`/`getUpgradeState`/`buyUpgrade` API), even though
  there's no node count to raise here since Arcane Dust has no pickup
  nodes, just the one pad. Costed on its own curve (`currentLevel * 10`,
  paid in Arcane Dust - not Mana's shared `UpgradeCost`, a different
  currency entirely).
- `ManaBoostHandler.lua` — the Arcane Dust Upgrades board's 3rd column,
  "More Mana" (per direct request, "another upgrade for mana, 50 total
  upgrades, make them cost dust"). 50 levels, a flat multiplier on Mana Per
  Pickup climbing linearly from 1x at level 1 to 6x at level 50 (+0.1x per
  level - a reasonable default since no exact curve was specified; easy to
  retune via `MULTIPLIER_PER_LEVEL`). Costed on its own curve
  (`currentLevel * 25`, paid in Arcane Dust). `ManaHandler` reads
  `getMultiplier` to fold it into effective Mana yield.
- `WizardTierHandler.lua` — Wizard Tiers, a deeper prestige layer than
  Rebirths: spend a flat Mana cost to wipe every "lobby" currency/upgrade
  earned so far (Mana, Rebirths, Level/XP, and every Mana/Rebirth
  Shop/Arcane Dust upgrade level, including `ManaBoostHandler`'s) back to
  default, in exchange for a permanent flat multiplier on Mana, Rebirths,
  and Arcane Dust that applies from the very next pickup onward. Per direct
  request, `secondIslandUnlocked` is deliberately left untouched by the
  reset ("the entire lobby thus far resets except for the locked door that
  stays open"), and lifetime stats (`totalManaEarned`, `wizardTier` itself)
  never reset either. `data.wizardTier` starts at 0; the `TIERS` table is
  built to hold more tiers later without any logic changes.
  Tier 1 costs 1,000,000,000 Mana, grants x20 Mana, x20 Rebirths, x5
  Arcane Dust. Tier 2's cost and rewards are DERIVED, not guessed
  (per direct request, "you decide based on how much everything cost
  mana wise, you do the calculations"): the total Mana needed to fully
  max every Mana-side upgrade (Mana Per Pickup to 100, Mana Spawn
  Speed/Walking Speed/Collection Range each to their cap) comes out to
  ~600,390 Mana - Tier 1's 1e9 cost was already ~1,666x that total, since
  it was always meant as a grind target well past simply maxing upgrades.
  Since Tier 1 grants a flat 20x Mana multiplier, the same grind now
  produces 20x the raw Mana per hour of play - scaling Tier 2's cost by
  that same 20x (1e9 × 20 = 20,000,000,000 Mana) keeps the actual TIME to
  reach Tier 2 comparable to what Tier 1 took, despite the much bigger
  number. Its rewards are "everything else again" per direct request -
  20x Tier 1's own multipliers, stored as final absolute values (20×20=x400
  Mana, 20×20=x400 Rebirths, 5×5=x25 Arcane Dust) - plus a brand new
  reward, Auto Mana (`autoMana = true` on its `TIERS` entry): once
  `WizardTierHandler.hasAutoMana` reports true (permanent from Tier 2
  onward, checked by scanning every tier up to the player's current one,
  not just the current tier's own flag), a background loop in
  `Main.server.lua` calls `ManaHandler.collect` for that player every
  `AUTO_MANA_INTERVAL` (1s) - the same effective yield/multipliers a
  manual pickup gets, just automatic, no walking onto a node required.
  Tier 3 follows the same two rules again, per direct request ("Add
  upgrade everything else more again"): cost scales by another 20x
  (20e9 × 20 = 400,000,000,000 Mana, matching Tier 2's own 20x Mana
  multiplier), and its multipliers are Tier 2's × 20x/20x/5x again
  (400×20=x8000 Mana, 400×20=x8000 Rebirths, 25×5=x125 Arcane Dust). Its
  reward is physical instead of another passive system: `unlockName =
  "Fantasy Ruin"` on its `TIERS` entry, checked permanently (same scan
  pattern as `hasAutoMana`) by `hasUnlockedRuin`, which
  `WizardRuinClient` reads to reveal `Workspace.FantasyRuin` - see
  `WorldBuilder` and `WizardRuinClient` below.
  `getManaMultiplier`/`getRebirthMultiplier`/
  `getDustMultiplier` are read by `ManaHandler`/`RebirthHandler`/
  `ArcaneDustHandler` respectively.
- `UpgradeTreeHandler.lua` — the ground upgrade tree: walk-over tiles,
  only reachable once `WizardTierHandler` reports Tier 3+, each a
  ONE-TIME purchase (not a leveled upgrade like everything else) paid in
  Arcane Dust. `TILES` is a numbered list from the start (even with just
  one entry) so the planned 1-2-3-2-1 diamond layout can append more tiles
  later without reshaping anything - each tile just needs its own
  `dustTreeTileN` `PlayerData` field. Tile 1's cost is derived the same
  way as the Wizard Tier costs: fully maxing the whole 3-column Arcane
  Dust Upgrades board costs ~619,465 Dust total, so Tile 1 prices past
  that at 1,000,000,000 Dust (also mirroring Tier 1's own 1B Mana price)
  for a genuine next milestone, not something maxing the board alone
  affords. Grants a permanent x2 Arcane Dust multiplier once bought -
  `getDustMultiplier` folds every bought tile's multiplier together
  (multiplicatively, ready for more tiles), read by `ArcaneDustHandler`
  alongside `WizardTierHandler`'s own dust multiplier. `buyTile1` is
  called every tick by `WorldBuilder`'s proximity loop for any player
  standing on the tile - it silently no-ops (returns false) if not
  unlocked, already bought, or unaffordable, so it's safe to call on
  every check without a separate "can I buy this" query first.
- `WalkSpeedHandler.lua` — the "Walking Speed" upgrade (level 1-10,
  linear 1x → 1.5x `Humanoid.WalkSpeed` - halved from the original 3x
  max, which felt too strong, applied on every spawn and
  instantly on purchase). Costed steeply on purpose, NOT through the
  shared `UpgradeCost` curve — only 10 levels, but each should feel like
  real progress rather than a quick fill-in upgrade, so the first
  purchase alone costs as much as reaching level 20 on "More Mana"
  (`UpgradeCost.costForLevel(19)` = 190 Mana right now), climbing by
  that same amount every level after.
- `CollectionRangeHandler.lua` — the "Collection Range" upgrade (level
  1-12, radius linear 3 studs → 9 studs - halved from 18, which felt
  too strong). Also on its own cost curve
  per direct request — the first purchase costs 50 Mana, climbing
  linearly to 495 for the last purchase. `getRadius(player)` is read by
  `WorldBuilder`'s collection loop (see below) and by `ManaRingClient`,
  so the visible ring always matches the real pickup radius.
- `RebirthHandler.lua` — Rebirths, a second currency: resetting your
  Mana grants Rebirths at 1,000 Mana = 1 Rebirth, fractional (5,400
  Mana gives exactly 5.4 Rebirths, not floored). Requires at least 1,000
  Mana to rebirth at all. Also resets all 4 Mana-side upgrade levels
  (Mana Per Pickup, Mana Spawn Speed, Walking Speed, Collection Range)
  back to 1 - re-applies `Humanoid.WalkSpeed` immediately via
  `WalkSpeedHandler.applyCurrentSpeed` since changing `PlayerData` alone
  doesn't touch the live Humanoid. Rebirth Shop upgrades
  (`RebirthShopHandler`) are deliberately NOT reset - they're the whole
  point of rebirthing, so each run collects Mana faster than the last.
- `RebirthShopHandler.lua` — permanent upgrades bought with Rebirths
  instead of Mana, that survive rebirthing. Three columns, built through
  a shared `makeMultiplierUpgrade(config)` factory so they don't each
  duplicate the same get-state/buy-with-max-mode logic: "Mana Value
  Multiplier" (level 1-100, linear 1x → 200x, cost = currentLevel
  Rebirths - read by `ManaHandler` to scale every pickup), "Rebirth
  Multiplier" (level 1-100, non-linear/quadratic 1x → 50x, cost =
  `ceil(level^1.5)` Rebirths - read by `RebirthHandler` to scale how many
  Rebirths a rebirth actually grants), and "XP Multiplier" (level 1-25,
  non-linear/quadratic 1x → 50x, cost = `ceil(level^1.6)` Rebirths - read
  by `XPHandler` to scale XP per pickup). Rebirth Multiplier and XP
  Multiplier are deliberately non-linear on both their multiplier and
  cost curves per direct request, unlike Mana Value Multiplier's linear
  curve — the step between consecutive levels keeps changing instead of
  growing by the same fixed amount every time.
- `XPHandler.lua` — a separate XP/Level progression track, NOT reset by
  rebirthing. 50 levels; every Mana pickup grants 10 XP scaled by the
  Rebirth Shop's "XP Multiplier". The level-up cost curve is non-linear
  (`floor(100 * currentLevel^1.4)`), landing exactly on 100 XP for the
  first level-up as specified. `grantXpForPickup` is called once per
  successful pickup from `WorldBuilder`'s collection loop and returns the
  resulting state so it can be pushed to the client via `XPUpdated`.
- `ManaHUDClient.client.lua` — a Mana counter, middle-left of the screen,
  updated live off the `ManaUpdated` RemoteEvent, an Arcane Dust counter
  below that, then a Rebirths counter below that. Styled after a typical
  incremental-game HUD, not the original dark rounded pill: no background
  at all, just the icon sitting a small fixed gap (`ICON_TEXT_GAP`) from a
  bold, left-aligned number - no "Mana"/"Arcane Dust"/"Rebirths" word, the
  icon says it - colored to echo the icon's own palette (violet for Mana,
  matching the Mana nodes' own glow; blue for Arcane Dust, matching its
  own uploaded icon, per direct request - was a gold placeholder glyph
  before; pink-red for Rebirths, matching the Rebirth board's red theme).
  The Rebirths icon keeps a small round white circle behind it for
  contrast; the Mana and Arcane Dust icons have none, since both already
  read fine boxed on their own. Both the Arcane Dust and Rebirths rows
  are visible only while their amount is actually above 0, not just "ever
  shown once" - Arcane Dust the first time you actually stand on
  `ArcaneDustPad`, Rebirths only once you've actually rebirthed - and hide
  again if a Wizard Tier purchase resets either back to 0, so neither
  counter shows up before it's relevant. `reflowLayout` re-stacks
  whichever rows are currently visible with no gap in between, since the
  two collapsible rows aren't always both present.
- `SideMenuClient.client.lua` — the right-side icon menu, mirroring the
  Mana counter's placement, laid out 2x2 on a high-opacity dark
  `SideMenuPanel` (not just a transparent background) behind the whole
  grid, so the icons read as one solid unit: Store/Runes/Profile/Settings.
  Store, Settings, and Runes all show their uploaded icon image directly
  (background transparent, no colored circle behind it - the art reads
  fine on its own); Profile shows the PLAYER'S OWN live avatar headshot
  instead, via
  `Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)`
  - no uploaded asset needed since Roblox already renders and hosts a
  thumbnail per-player - swapped in after the fact (starts as the usual
  placeholder circle+glyph, since the fetch yields on a
  network call) with the colored circle dropped once the real image
  lands, same as Store/Settings/Runes. Each item also gets a
  bold `FredokaOne`
  name label with a heavy stroke underneath for a "cool logo" look. A
  small round `SideMenuToggle` tab sits fixed just above the panel and
  tweens it fully off-screen to the right (and back) on click, so the
  whole menu can be collapsed/hidden - the tab itself never moves, so it
  stays reachable even while the panel's hidden.
  Hovering tweens the icon up to 1.15x size (centered growth, not
  top-anchored, so it doesn't push
  into the label) to show what's highlighted. Not wired to any panel yet -
  it only needed to exist on screen for now.
- `ManaRingClient.client.lua` — a small dashed ring under the player's
  feet, visible only while standing inside the `ManaZone` platform
  bounds (read off attributes `WorldBuilder` sets on that folder:
  `CenterX`/`CenterZ`/`Size`/`GroundY`). Its radius IS the "Collection
  Range" upgrade's real pickup radius, kept live via the
  `CollectionRangeUpdated` event, so the ring always shows exactly how
  far away a Mana node will still get auto-collected. (Arcane Dust has no
  ring of its own - it's a stand-on pad, not a pickup-range mechanic.)
- `ManaUpgradeBoardClient.client.lua` — the 3D upgrade board standing
  just outside the platform (`Workspace.Kiosks.ManaUpgradeBoard`).
  Styled like a typical incremental-game upgrades board: a small clear
  readout pill (white, ~75% transparent, live off `ManaUpdated`) showing
  just the Mana icon and the amount - no "Mana" word - above a "Mana
  Upgrades" title banner - this readout is the template to reuse on every
  future currency board - then 4 columns filling the board
  edge-to-edge, built through one shared `createUpgradeColumn` helper
  so every upgrade looks and behaves alike — "More Mana", "Mana Spawn
  Speed", "Walking Speed", and "Collection Range", each with a
  placeholder icon, level `(x/max)`, a value preview (`+N > +N`,
  `Ns > Ns`, `Nx > Nx`, or plain `N > N` studs), cost, and Buy/Max
  buttons (white text, padded so labels don't stretch edge-to-edge, all
  text with a subtle stroke for a slight 3D look). Its UI is a
  `SurfaceGui` painted onto the board's face (not a `BillboardGui` - a
  Billboard always turns to face the camera, so it visibly slides
  around as you walk past; a SurfaceGui is flat against the physical
  face, unreadable from behind, exactly like a real sign). Buy/Max turn
  green/yellow when affordable and red when they aren't, tracked live
  off the same `ManaUpdated` event the HUD counter uses. Once a column
  hits its max level, Max is hidden and Buy expands to a single
  full-width gray "Maxed" button instead of showing two redundant
  maxed-out buttons. Each `createUpgradeColumn` call returns a
  `refresh()` function; all 4 are re-run whenever `PlayerRebirthed`
  fires, so the board never keeps showing stale pre-rebirth
  levels/costs after a rebirth resets them server-side.
- `ArcaneDustUpgradeBoardClient.client.lua` — the Arcane Dust upgrade
  board on SecondIsland (`Workspace.Kiosks.ArcaneDustUpgradeBoard`), a
  blue-themed version of `ManaUpgradeBoardClient` (was gold before, per
  direct request to match the Arcane Dust icon's own palette) with 3
  columns instead of 4 - "More Arcane Dust", "Grant Speed", and "More
  Mana" (`ManaBoostHandler`) - same
  `createUpgradeColumn` pattern, clear readout (now with the real uploaded
  dust icon overlapping its left edge, same as Mana's own readout), and
  Buy/Max → "Maxed" behavior, just costed and gated in Arcane Dust instead
  of Mana - and its
  Buy/Max buttons sit at Y=0.7 instead of the Mana board's 0.82, since
  this board's bottom edge sits right at ground level (its height puts
  the bottom of the Part at `ISLAND_TOP_Y`), so 0.82 read as the buttons
  touching the floor. Sits near SecondIsland's -X edge facing inward -
  "Right" instead of the starting island kiosk row's "Left" - since it's
  positioned off to the side near an edge rather than in the middle of
  the island. No `PlayerRebirthed` hookup - a plain Rebirth never resets
  Arcane Dust - but it does listen for the new `PlayerWizardTiered` event
  and re-fetches all 3 columns when it fires, since a Wizard Tier purchase
  resets all of them.
- `WizardTierBoardClient.client.lua` — the bigger `WizardTierBoard` right
  next to the Arcane Dust Upgrades board: a "Wizard Tiers" title banner, a
  line naming the current tier and its bonuses (or "No Tier Entered Yet"),
  a description box explaining the next tier's cost/reset/reward in plain
  English, and a big red "Enter" button - styled after a reference "Summer
  Tiers" board's layout (title → tier name → description → buy button),
  minus its prev/next tier arrows since only Tiers 1-3 exist so far -
  `formatBonuses` appends "+ Auto Mana (collects Mana passively, no
  pickups needed)" whenever a tier's `autoMana` flag is set (Tier 2), and
  "+ unlocks the <unlockName>" whenever one is set (Tier 3's Fantasy
  Ruin). Because
  buying a tier wipes almost everything (Mana, Rebirths, Level, every
  upgrade), the button requires two clicks - the first turns it orange
  with "Click again to confirm!" for a few seconds (`CONFIRM_WINDOW_SECONDS`),
  the second actually calls `BuyWizardTier` - a safeguard not asked for
  outright, but reasonable given how destructive a misclick here would be.
  On success, re-renders from the server's returned state (which reports
  "No further tiers yet" once there's nothing left to buy).
- `WizardRuinClient.client.lua` — reveals `Workspace.FantasyRuin` (Tier
  3's unlock) LOCALLY for whichever players have actually reached it: every
  part starts hidden/no-collide server-side since it's shared world
  geometry and different players can be at different tiers at once, so
  this checks `GetWizardTierState().unlockedRuin` (retrying a few times if
  `PlayerData` isn't loaded yet, same guard as `SecondIslandGateClient`)
  and flips `Transparency`/`CanCollide` back on for that client only if
  it's true. Also re-checks on every `PlayerWizardTiered` event, so
  reaching Tier 3 reveals the ruin immediately without needing to rejoin.
- `UpgradeTreeClient.client.lua` — the floating card above
  `UpgradeTreeTile1`, styled like the reference upgrade cards (colored
  background, title, cost) but only exists at all once
  `GetUpgradeTreeState().unlocked` is true - the tile itself is always
  solid ground, so nothing floats there before Tier 3 rather than
  spoiling what's coming. Colored per the exact rule given: red (not
  enough Dust), yellow (affordable - walk over it to buy), green (bought) -
  tracked live off `ArcaneDustUpdated` (afford check) and the new
  `UpgradeTreeTileBought` event (flips to green the instant `WorldBuilder`'s
  proximity loop actually buys it, no need to wait for the next Dust tick).
  Re-checks on every `PlayerWizardTiered` event too, so reaching Tier 3
  builds the card immediately without a rejoin.
- `RebirthBoardClient.client.lua` — a separate, narrower board
  (`Workspace.Kiosks.RebirthBoard`) just past the Mana Upgrades board's
  edge, styled in red instead of the Mana board's blue. Its title banner
  carries the uploaded Rebirths icon to the left of the "Rebirths" text.
  Explains the mechanic, shows "Your Rebirths: X.X" (kept live via
  `RebirthsUpdated` even when Rebirths are spent elsewhere, e.g. the
  Rebirth Shop board), a live "Rebirth now for +X.X Rebirths" preview that
  updates off the same `ManaUpdated` event the HUD uses, and a Rebirth
  button (bright red when you have the required 1,000+ Mana, gray
  otherwise). Same SurfaceGui-on-a-face approach as the Mana board.
- `RebirthShopBoardClient.client.lua` — the Rebirth Shop board
  (`Workspace.Kiosks.RebirthShopBoard`), styled in the same red as the
  Rebirths board (not the Mana board's blue - both are Rebirth-themed).
  Same clear readout (with the same uploaded Rebirths icon badge as the
  corner HUD, just the icon and the amount - no "Rebirths" word) + title
  banner template as the Mana Upgrades board, then 3 columns filling the
  board edge-to-edge through the same
  `createUpgradeColumn` pattern as the Mana Upgrades board, just
  costed and gated in Rebirths instead of Mana: "Mana Value Multiplier"
  (`(x/100)`), "Rebirth Multiplier" (`(x/100)`), and "XP Multiplier"
  (`(x/25)`), each with a `%.1fx > %.1fx` preview, cost in Rebirths, and
  the same Buy/Max → single "Maxed" button behavior as the Mana board's
  columns.
- `XPBarClient.client.lua` — a small bottom-middle HUD: "Level <N>" above
  a progress bar that fills as XP approaches the next level, with
  "<xp> / <xpToNextLevel> XP" over the bar itself (or "MAX LEVEL" once
  `xpToNextLevel` comes back nil at level 50). Fetches its initial state
  via `GetXPState` on load, then just renders whatever `XPUpdated` sends
  after that — all the leveling logic lives server-side in `XPHandler`.
- `LeaderboardBoardClient.client.lua` — builds the 4 sign boards on
  `LeaderboardIsland` (Playtime/Robux Spent/Total Mana/Runes Opened), each
  just a title banner over a top-5 list ("N. Name - value") on a clear,
  ~55% transparent background (matching every other board's glass look,
  not a solid opaque sign) with white stroked text for legibility against
  it, no Buy/Max buttons or anything interactive. Each stat gets its own
  value formatter - Playtime as "Xh Ym", Robux as "R$<amount>", Mana/Runes
  through the shared `NumberFormat`. Pulls its list from the
  `GetLeaderboard` remote on load and every `REFRESH_INTERVAL` (20s) after
  that; empty rows show "-" until that stat's `OrderedDataStore` actually
  has entries (e.g. in Studio without API access enabled). Same
  SurfaceGui-on-a-face approach as every other board here.
- `SecondIslandGateClient.client.lua` — builds `SecondIslandGate`'s
  "🔒 LOCKED" sign and Unlock button. Fetches `GetSecondIslandState` on
  load (retrying a few times if `PlayerData` isn't loaded yet rather than
  building the sign with placeholder numbers); if already unlocked from a
  previous visit, just sets the gate's `Transparency` to 1 for this
  player and stops there - a purely local visual change, so the gate
  stays solid-looking for anyone who hasn't unlocked it. Otherwise builds
  the sign (same title-banner-plus-clean-lines look as the kiosk boards)
  plus an Unlock button, tracking current Mana/Rebirths/Level locally off
  the same `ManaUpdated`/`RebirthsUpdated`/`XPUpdated` events the HUD
  uses (seeded from real starting values via `GetRebirthState`/
  `GetXPState`, not 0s, so the button's enabled state doesn't glitch on
  the first live update) so the button enables/disables in real time
  without hitting the server on every Mana pickup. Clicking it while
  affordable calls `UnlockSecondIsland`; on success, hides the gate and
  its sign locally, same as the already-unlocked case.

## Manual steps required before everything works

1. **Power Store**: `GameConfig.DevProducts` and `GameConfig.GamePasses`
   list every product with a placeholder `id = 0`. In Studio: **Home →
   Monetize** (or the game's page on the Creator Dashboard) → create each
   GamePass and Developer Product listed there with matching prices, then
   paste the real asset ID back into `GameConfig.lua`. Nothing will prompt
   a real purchase until that's done — `StoreHandler.promptPurchase`
   silently no-ops on `id = 0` on purpose, so a half-configured store can't
   accidentally prompt Studio's test/placeholder asset IDs.
2. **Titles**: three `GameConfig` values are placeholders until you fill
   them in —
   - `ReleaseTimestampUnix` (nil right now): set to the real launch time so
     the OG title means something. The OG condition never unlocks while
     this is nil.
   - `FanGroupId` (0 right now): your Roblox group's id, for the Fan title.
   - `OwnerUserIds` / `AdminUserIds` / `TesterUserIds` (all empty): add your
     own UserId to `OwnerUserIds` so you get the Owner title on join.

## One-time cleanup if Studio still shows old world parts

Nothing server-side generates or removes world parts anymore except what
`WorldBuilder` explicitly manages (`StartingIsland`, `ManaZone`,
`Kiosks`, `SecondIsland`, `IslandBridge`, `ArcaneDustPad`,
`SecondIslandGate`, `SecondIslandDecor`, `FantasyRuin`, `UpgradeTreeTiles`,
`LeaderboardIsland`,
`LeaderboardBridge`, `LeaderboardDecor`, all rebuilt from scratch on every
server start). If your saved `.rbxl`
still has leftover parts from before the reset (e.g. a
saved-while-in-Play-mode `GeneratedWorld` folder or similar), delete them
by hand in Workspace — they're just leftover geometry, nothing references
them.

The original `Baseplate` from Studio's blank template is still down at
its original spot (around y=0), well below where the fall check now
kills a falling character — so it's harmless but also never actually
reachable anymore. It's left in place rather than auto-deleted since
it's Studio-authored content, not something `WorldBuilder` created;
delete it by hand in Workspace if you want it gone for good.

## Not yet built (next steps)

Everything client-facing and every currency/zone. `GameConfig.Zones` and
`GameConfig.AscensionTiers` are empty, `StarterPlayerScripts` is empty,
and there's no world content at all beyond the baseplate. The plan is to
rebuild one piece at a time as the new vision is specified — nothing
speculative gets added ahead of that.

An in-game admin command to grant Tester/Admin manually (instead of only
via the `GameConfig` UserId allowlists), OrderedDataStore-backed
leaderboards, and a community-codes module are still open ideas from the
old design and may or may not carry over — see DESIGN.md for the
(historical) detail.
