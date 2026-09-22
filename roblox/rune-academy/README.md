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
- `RuneHandler.lua` — server-authoritative gacha pull, Fortune-weighted odds
  (`pull`, the older Scroll-costed manual pull - no UI wired to it). Also
  `collectAtAltar`: the Rune Altar's own tick logic (stand on
  `RuinRuneCircle`, called once per tick by `WorldBuilder`'s proximity
  loop) - spends `RuinRuneHandler.getManaCostPerTick` Mana, then rolls
  `1 + RuinRuneHandler.getExtraRolls` independent Runes via the same
  `weightedPick` odds table, Fortune boosted by `RuinRuneHandler
  .getLuckMultiplier` and bulk boosted by `UpgradeTreeHandler
  .getRuneBulkMultiplier * RuinRuneHandler.getBulkMultiplier`; returns nil
  (no-op) if not unlocked or Mana is too low. Kept separate from `pull` so
  the Altar's own upgrades never leak into the unrelated Scroll pull.
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
  auto-unlocks for free" design.
  BUG FIX: this poll used to check X only within `BRIDGE_WIDTH / 2` (6
  studs) of center, meaning it only enforced the lock on the narrow bridge
  itself - once a not-yet-unlocked player made it across onto the much
  wider island (120 studs) and drifted off that corridor, the check
  silently stopped matching and never caught them again, letting them use
  every board/pad on the island without ever unlocking it (reported
  directly: "I was able to purchase upgrades from behind the locked
  door"). Now checks the FULL island width, so it keeps enforcing anywhere
  on SecondIsland, not just the bridge crossing. As defense in depth on
  top of that physical fix, every handler that actually lives on
  SecondIsland (`ArcaneDustHandler`, `ArcaneDustSpawnHandler`,
  `ManaBoostHandler`, `WizardTierHandler`, `UpgradeTreeHandler`, all three
  Ether handlers, `EtherIslandHandler`) now also checks
  `secondIslandUnlocked` directly before collecting/buying anything, so a
  future containment bug can't reopen the same hole. `ArcaneDustPad` and
  both upgrade boards below are also now hidden/no-collide by default
  (same `RevealTransparency`/`RevealCanCollide` attribute pattern as the
  Fantasy Ruin/Ether Area) and only revealed LOCALLY by
  `SecondIslandGateClient` once a player is actually unlocked - per direct
  request, "make all the cards and everything look locked until they open
  that first door" - and `ArcaneDustUpgradeBoardClient`/
  `WizardTierBoardClient` each wait on `GetSecondIslandState().unlocked`
  before building their `SurfaceGui` at all, since a `SurfaceGui` renders
  independent of its host Part's own Transparency and so wouldn't have
  been hidden by that alone. `ArcaneDustUpgradeBoard` sits near the island's -X edge
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
  reports true for them. The orb (`RuinOrb`) stays purely decorative - the
  rune circle underneath it (`RuinRuneCircle`) is the actual Rune Altar:
  stand within its radius (no clicking - per direct correction, "There is
  no clicking on a ruin you just sit and it collects") and a proximity
  loop periodically spends Mana for a chance-based Rune via
  `RuneHandler.collectAtAltar`, gated on `RuinRuneHandler.isUnlocked`
  (= `hasUnlockedRuin`) server-side, same defense-in-depth reasoning as
  every other SecondIsland collector. Checked every `RUNE_ALTAR_CHECK_
  INTERVAL` (0.25s, finer than the tick itself) with each player's own
  next-allowed-tick tracked separately (`RuinRuneHandler
  .getTickIntervalSeconds` can differ per player once the Rune Speed tier
  is bought), same per-player timer shape as `ArcaneDustPad`'s own loop.
  On a successful tick, fires `ManaUpdated` (the new balance) and
  `RuneAltarCollected` (one `{name, amount}` per roll that tick - more
  than one once the Familiar tier is bought) at that player -
  `RuneAltarClient` turns the latter into floating "+N RankName" popups.
  Just past the pillar ring on the +Z side sits `RuneAltarBoard`, the
  Altar's own 5-tier upgrade board (`RuinRuneHandler`/
  `RuneAltarBoardClient`) - hidden/no-collide by default like every other
  board, but NOT a child of `FantasyRuin` (it needs the "clear glass"
  0.7-transparency reveal every other board gets, not the ruin's own
  full-opacity reveal), so `WizardRuinClient` reveals it explicitly via its
  own `RevealTransparency`/`RevealCanCollide` attributes. Positioned right
  where the perimeter tree ring comes closest to the ruin and rotated 90°
  around Y, per direct request ("rotate the card to face towards center of
  island and move it to where the trees are") - it was originally further
  +X outside the ring facing west back at the Altar, which read as facing
  the wrong way and sitting away from the trees. Its `SurfaceGui.Face` in
  `RuneAltarBoardClient` moved from `Left` to `Right` to match the
  rotation - still a guess like every other board face here.
  In the open grass between the Fantasy Ruin and `ArcaneDustPad` (Tile 1's
  spot is the midpoint between the two - a best guess from a circled
  screenshot, same as every other placement here) sits `UpgradeTreeTiles`,
  the full 9-tile ground upgrade tree - each a 9x6 stud paving-stone tile,
  walked over instead of clicked like every other upgrade, per direct
  request, laid out in the 1-2-3-2-1 diamond chain asked for (Tile 1 at
  one end, extending outward along +X into the open grass beyond, Tile 9 -
  Ether's unlock - at the opposite end). See `UpgradeTreeHandler`/
  `UpgradeTreeClient` below for what each tile does.
  Further out past Tile 9 (per a circled screenshot showing where to put
  it, same best-guess treatment) sits `EtherArea`: the Ether Shroud (a
  glowing purple `Neon` sphere core carrying a `ClickDetector`, ringed by
  5 translucent `ForceField` "mist" spheres bobbing at different heights,
  sitting on a round marble platform) and its own `EtherUpgradeBoard`
  right behind it. Every part here starts hidden/no-collide - shared
  world geometry, but players can be at different Upgrade Tree progress -
  and gets revealed LOCALLY per-player by `EtherAreaClient` once
  `UpgradeTreeHandler.isEtherUnlocked` reports true for them, same
  pattern as the Fantasy Ruin - each part's revealed look comes from its
  own `RevealTransparency`/`RevealCanCollide` attributes rather than a
  flat opaque/solid for everything, so the board ends up "clear" (0.7
  transparency, glass, matching every other board) per direct request,
  and the mist stays translucent (0.55) and non-collide instead of
  becoming a solid ball. Themed purple throughout, per direct request, in
  a deeper/more violet shade than the Wizard Tier board's own purple so
  the two read as distinct. See `EtherHandler`/`EtherClickSpeedHandler`/
  `EtherDustBoostHandler`/`EtherAreaClient`/`EtherUpgradeBoardClient`
  below.
  Further out past that, bridged straight off SecondIsland's own +X edge
  (continuing the same direction the tree/Shroud already extend in) sits
  `EtherIsland` - gated behind an Ether threshold instead of
  Mana/Rebirths/Level, per direct request. Same rope-bridge look and
  locked-gate mechanic as SecondIsland's own bridge, just running along X
  instead of Z (`EtherIslandBridge`'s deck/rails/posts are built the same
  way, just swapping which axis is the long one) since it leaves from an
  X edge rather than a Z edge. Its gate-check loop had the same
  bridge-width-only bug SecondIsland's did (fixed alongside it) - now
  checks the full island width instead of just `BRIDGE_WIDTH`. Nothing
  built on the island itself yet beyond grass and a decor ring - purely
  the gate/bridge/island for now. See
  `EtherIslandHandler`/`EtherIslandGateClient` below.
  Also a ring of procedurally placed decor pieces (`SecondIslandDecor`)
  around its edge, inset from the border, skipping the bridge's landing
  spot, and each given a small random `DECOR_JITTER` offset so the ring
  reads as staggered rather than a perfectly straight line. Each piece is
  also built from several overlapping/stacked parts instead of one plain
  shape, for a fuller look than a single sphere or dot. This scattering
  logic lives in `WorldDecor.lua`'s `WorldDecor.scatter(folder, centerX,
  centerZ, size, nearEdgeSign, groundY, bridgeWidth, useWizardTheme?)` -
  `nearEdgeSign` just flips which edge is the one to skip, so the same
  function rings SecondIsland, EtherIsland, and LeaderboardIsland despite
  their bridges approaching from different directions; `useWizardTheme` is
  what lets SecondIsland alone use its own themed pieces below.
  SecondIsland's own ring is a "purple wizardy nature" theme instead of the
  plain green one, per direct request ("this island can we do purple
  wizardy nature theme for decorations make it look good") -
  `SECOND_ISLAND_DECOR_KINDS` cycles 4 new pieces: `makeWizardTree` (the
  same 3-clump trunk-and-canopy shape as the plain tree, just a
  purple-barked trunk under a glowing violet Neon canopy with a small
  brighter magenta accent clump tucked in), `makeCrystalCluster` (4
  translucent purple/lilac shards - elongated `Ball`s rather than
  `WedgePart`s, so the spike look doesn't depend on getting wedge
  orientation exactly right - at different heights/tilts/shades, `Glass`
  material with a little `Reflectance` for shine), `makeGlowMushroom` (a
  pale stem under a glowing magenta Neon cap with 3 small white spots and
  its own soft `PointLight`, so it actually lights up its surroundings a
  little), and `makeGlowFlower` (the same stem+bloom shape as the plain
  flower, just a deeper teal stem and blooms drawn only from a
  purple/lilac palette). EtherIsland and LeaderboardIsland keep the
  original green theme - only SecondIsland was asked for the reskin.
- `WorldDecor.lua` — every piece-maker function above
  (`makeTree`/`makeBush`/`makeFlower`/`makeWizardTree`/
  `makeCrystalCluster`/`makeGlowMushroom`/`makeGlowFlower`) plus
  `WorldDecor.scatter` itself used to live directly in
  `WorldBuilder.server.lua`, until adding the purple-wizard theme pushed
  that script's own top-level locals over Luau's 200-local-register-per-
  chunk limit - Studio's actual error was `Out of local registers when
  trying to allocate index: exceeded limit 200` at the point the whole
  script's top-level code stopped running, which is why EVERYTHING
  disappeared (not just SecondIsland's decor) - nothing past that point in
  the file, including the starting island itself, ever got built. Confirmed
  and fixed by installing the real `luau-compile` and reproducing the exact
  error with `luau-compile -O0` (Roblox Studio appears to compile scripts
  at that optimization level, where dead locals aren't reused/retired as
  aggressively as `-O1`/`-O2` do) - every ModuleScript compiles as its own
  separate chunk with its own fresh budget, so moving this self-contained
  piece out into its own file is the actual fix, not just a workaround.
  `groundY`/`bridgeWidth` are now explicit parameters (`ISLAND_TOP_Y`/
  `BRIDGE_WIDTH` from `WorldBuilder`) instead of closed-over globals, and
  `useWizardTheme: boolean?` replaces the old `decorKinds` table parameter
  now that both theme tables live inside this same module. Every `.lua`
  file in the project was then compile-checked the same way (`luau-compile
  -O0` on each) to confirm nothing else is anywhere close to this limit.
  The exact direction/size
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
  (1x-6x, paid in Arcane Dust), `WizardTierHandler`'s flat tier
  multiplier (1x until Tier 1, then 20x), and the Upgrade Tree's own Mana
  tiles (x2 each, x4 combined once both are bought) -
  `amountPerPickup`/`nextAmountPerPickup` in the returned state already
  include all four, so the board always shows
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
  multiplier (1x until Tier 1, then 5x), `UpgradeTreeHandler`'s Dust tiles
  (x2 each), and `EtherDustBoostHandler`'s "More Dust" upgrade (1x-6x,
  paid in Ether).
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
- `RuinRuneHandler.lua` — 5 upgrade tiers for the Rune Altar
  (`RuinRuneCircle`, the Fantasy Ruin's rune circle - stand on it, no
  clicking), bought via the nearby `RuneAltarBoard`, only reachable once
  `WizardTierHandler.hasUnlockedRuin` is true. Per direct request ("for
  this rune we made on island 2 lets do 5 tiers you can name them. Each
  one boosts a specific tribute times a certain amount... each tier gets
  harder to unlock"), corrected after an initial miss where I'd built this
  as a click-to-open tier shop instead ("There is no clicking on a ruin
  you just sit and it collects... it cost mana to sit on the rune").
  Strictly linear like Wizard Tiers themselves - a single
  `data.ruinRuneTier` count (0-5), not a per-tile boolean set like the
  Upgrade Tree, since tier N+1 is only ever buyable after tier N. Paid in
  Mana, cost climbing 10x per tier (1e9 → 1e10 → 1e11 → 1e12 → 1e13), each
  a permanent, one-time boost to the Altar itself (a flat x2, or +1 for
  Familiar, same "cost scales, effect stays flat" convention as the
  Upgrade Tree) - names and targets are my call (per direct request, "this
  is all the info I will give you"), matching the reference screenshots'
  own "Rune Speed/Rune Luck/Rune Bulk" language plus two more of my own:
  Rune Speed (halves the tick interval), Rune Luck (x2 effective Fortune
  for the Altar's own rolls), Rune Bulk (x2 Runes per successful roll,
  folded together with `UpgradeTreeHandler.getRuneBulkMultiplier`),
  Familiar (+1 free extra roll per tick), Mana Efficiency (halves the Mana
  cost per tick). `getTickIntervalSeconds`/`getLuckMultiplier`/
  `getBulkMultiplier`/`getExtraRolls`/`getManaCostPerTick` are each read
  every tick by `RuneHandler.collectAtAltar`. `buyNextTier` checks
  `isUnlocked` (= `hasUnlockedRuin`) directly, not just physical/client
  reachability, same defense-in-depth reasoning as every other SecondIsland
  handler.
- `UpgradeTreeHandler.lua` — the full 9-tile ground upgrade tree:
  walk-over tiles, only reachable once `WizardTierHandler` reports Tier
  3+, each a ONE-TIME purchase (not a leveled upgrade like everything
  else) paid in Arcane Dust. `TILES` is a single data-driven list (id,
  `PlayerData` field name, cost, `kind`, multiplier, display label) that
  every function here reads generically - `foldMultiplier(player, kind)`
  multiplies together every bought tile of that `kind`, so
  `getDustMultiplier`/`getManaMultiplier`/`getXpMultiplier`/
  `getRebirthMultiplier`/`getRuneBulkMultiplier` are all one-line wrappers
  around it, and `buyTile(player, tileId)` looks up any tile by id instead
  of needing a separate `buyTileN` function each - adding a 10th tile
  later is just one more `TILES` entry and `PlayerData` field, no code
  changes. Tile 1's cost is derived the same way as the Wizard Tier costs:
  fully maxing the whole 3-column Arcane Dust Upgrades board costs
  ~619,465 Dust total, so Tile 1 prices past that at 1,000,000,000 Dust
  (also mirroring Tier 1's own 1B Mana price) for a genuine next
  milestone. The other 8 tiles' costs double per ring outward from Tile 1
  (2e9 → 4e9 → 8e9 → 16e9) while every tile's EFFECT stays a flat x2 - so
  cost is the only thing that scales with distance, keeping the whole tree
  easy to read at a glance: Tiles 2/7 (Mana x2, 2 layers), Tile 3 (XP x2),
  Tiles 4/8 (Rebirths x2, 2 layers), Tile 5 (Rune Bulk x2 - the widest
  row's center tile, per direct request "one of the cards in the middle"),
  Tile 6 (Dust x2, a 2nd layer stacking with Tile 1's), and Tile 9 (the
  final tile at the opposite end of the chain from Tile 1, per direct
  request - unlocks Ether, a brand new wizard resource named now but with
  no collection mechanic built yet, `isEtherUnlocked` for whenever that's
  ready). `getXpMultiplier`/`getRuneBulkMultiplier` are read by
  `XPHandler`/`RuneHandler` the same way the other three are read by
  `ManaHandler`/`RebirthHandler`/`ArcaneDustHandler` - Rune Bulk multiplies
  how many Runes a single pull grants even though no pull UI exists yet
  ("we can do that another time I just want it on the tile"), so it's
  already live for whenever that screen gets built. Per direct request
  ("have the cards only appear once you buy the ones before it"), every
  tile also lists a `requires` array of tile ids that must ALL be bought
  first - Tiles 2-3 need Tile 1, Tiles 4-6 need both of Tiles 2-3, Tiles
  7-8 need all of Tiles 4-6, and Tile 9 needs both of Tiles 7-8.
  `isTileReachable` checks this (on top of the Tier 3 unlock) and gates
  BOTH what `buyTile` allows purchasing and what `getState` reports as
  `reachable` per tile, so a tile with unmet requirements can't be bought
  even by walking onto it early, and its sign never appears client-side
  either.
- `EtherHandler.lua` — Ether, the third wizard resource, unlocked only
  once Tile 9 is bought (`UpgradeTreeHandler.isEtherUnlocked`).
  Click-collected instead of auto-collected/walked-over, per direct
  request - a `ClickDetector` on the Ether Shroud (`WorldBuilder`) fires
  `collect` server-side. Mirrors `ArcaneDustHandler`'s exact shape and
  yield curve for its own "More Ether" upgrade (level 1-100, paid in
  Ether).
- `EtherClickSpeedHandler.lua` — the Ether board's "Click Speed" column
  (level 1-10): how long you have to wait between clicks before the
  Shroud pays out again, 1.1s at level 1 down to 0.1s at level 10, exact
  values per direct request. Shaped like `ArcaneDustSpawnHandler` (same
  lerp curve, same API), costed on its own curve (`currentLevel * 10`,
  paid in Ether). `getCooldownSeconds` is read by `WorldBuilder`'s
  `ClickDetector.MouseClick` handler, which tracks each player's next
  allowed click time and silently ignores clicks before it.
- `EtherDustBoostHandler.lua` — the Ether board's "More Dust" column
  (level 1-50, 1x-6x): mirrors `ManaBoostHandler` exactly, just one link
  further down the resource chain - Ether (the newest, deepest resource)
  boosting Arcane Dust, the same way Arcane Dust's own "More Mana"
  column boosts Mana. Read by `ArcaneDustHandler` alongside
  `WizardTierHandler`'s and `UpgradeTreeHandler`'s own dust multipliers.
- `EtherIslandHandler.lua` — owns EtherIsland's unlock: `meetsRequirement`/
  `getState`/`unlock`, exact same shape as `SecondIslandHandler` (an
  explicit Unlock button that actually SPENDS the requirement, not a
  passive threshold check), just gated on Ether alone instead of
  Mana/Rebirths/Level, per direct request ("locked until you have what
  you think is good to progress in terms of ether"). The requirement
  (1,000,000,000 Ether) is derived the same way as every other milestone
  cost here: fully maxing the whole 3-column Ether board costs ~619,465
  Ether total (identical to Arcane Dust's own board total, since both
  boards' column curves are the same), so 1B prices past that while also
  matching Tier 1's 1B Mana and Upgrade Tree Tile 1's 1B Dust - every
  resource's first big gate lands on the same recognizable scale. `unlock`
  also checks `secondIslandUnlocked` directly (its own gate is physically
  on SecondIsland, past the Ether Shroud) - same defense-in-depth reasoning
  as every other SecondIsland-hosted handler, after the bridge
  containment bug (see `WorldBuilder`) let players reach content before
  unlocking the door it was behind.
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
  below that, a Rebirths counter below that, then an Ether counter below
  that. Styled after a typical incremental-game HUD, not the original dark
  rounded pill: no background at all, just the icon sitting a small fixed
  gap (`ICON_TEXT_GAP`) from a bold, left-aligned number - no
  "Mana"/"Arcane Dust"/"Rebirths"/"Ether" word, the icon says it - colored
  to echo the icon's own palette (violet for Mana, matching the Mana
  nodes' own glow; blue for Arcane Dust, matching its own uploaded icon,
  per direct request - was a gold placeholder glyph before; pink-red for
  Rebirths, matching the Rebirth board's red theme; purple for Ether,
  matching the Shroud's own color). The Rebirths and Ether icons keep a
  small round white circle behind them for contrast (Ether has no
  uploaded image yet, so it falls back to a placeholder glyph the same
  way Arcane Dust once did); the Mana and Arcane Dust icons have none,
  since both already read fine boxed on their own. The Arcane Dust,
  Rebirths, and Ether rows are all visible only while their amount is
  actually above 0, not just "ever shown once" - Arcane Dust the first
  time you actually stand on `ArcaneDustPad`, Rebirths only once you've
  actually rebirthed, Ether only once you've actually clicked the Shroud -
  and hide again if a Wizard Tier purchase resets any of them back to 0,
  so no counter shows up before it's relevant. `reflowLayout` re-stacks
  whichever rows are currently visible with no gap in between, since these
  three collapsible rows aren't always all present.
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
  into the label) to show what's highlighted. Only Profile is wired to a
  panel so far - clicking it fires an `OpenProfileRequested`
  `BindableEvent` (parented under this script's own `SideMenuHUD`
  `ScreenGui` so `ProfileClient` can find it reliably regardless of which
  script runs first) instead of building the panel itself, keeping the
  icon grid and the panel it opens as separate concerns. Store/Runes/
  Settings still just need to exist on screen for now.
- `ProfileClient.client.lua` — the Profile panel opened by that event: a
  dark modal card (dimmed background `Frame` with `Active = true` so
  clicks don't pass through to the side menu underneath) with two pages.
  The "Profile" page - what was originally asked for, per DESIGN.md's
  "Main profile screen" - shows the player's own avatar/name up top, then
  the 4 stats specifically requested: Time Played, Total Mana (now
  exposed by `GetProfile` as `totalManaEarned`, the same lifetime figure
  the leaderboard uses - not the live spendable `mana` balance also in
  that payload), Runes Opened, and Robux Spent. A "Titles ➜" button
  switches to the "Titles" page: every `GameConfig.Titles` entry (all 14),
  colored by its own title color when unlocked or grayed out when not,
  each locked one showing `describeCondition` - a plain-English rendering
  of its `condition` (none of the config entries carry a human-readable
  string, so this builds one: "Play for 7 days", "Spend R$1,000 total",
  "Join the group", "Own the ElitePass gamepass", "Join during launch
  week", "Granted manually") - and each unlocked one getting an
  Equip/Equipped button that calls the already-existing (but previously
  uncalled from any client) `EquipTitle` remote. A "⬅ Back" button
  returns to the Profile page. Both pages re-fetch fresh from `GetProfile`
  every time the panel opens rather than staying subscribed to live
  updates, since a modal stat/title screen doesn't need to track changes
  while it's closed.
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
  resets all of them. Waits in a blocking loop on `GetSecondIslandState()
  .unlocked` before building anything at all - per direct request that
  everything "look locked until they open that first door" - since a
  `SurfaceGui` renders independent of its host Part's Transparency, so
  hiding the physical board alone wouldn't stop this UI from showing
  through on top of it.
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
  "No further tiers yet" once there's nothing left to buy). Waits in a
  blocking loop on `GetSecondIslandState().unlocked` before building
  anything, same reasoning and same fix as `ArcaneDustUpgradeBoardClient`.
- `WizardRuinClient.client.lua` — reveals `Workspace.FantasyRuin` (Tier
  3's unlock) LOCALLY for whichever players have actually reached it: every
  part starts hidden/no-collide server-side since it's shared world
  geometry and different players can be at different tiers at once, so
  this checks `GetWizardTierState().unlockedRuin` (retrying a few times if
  `PlayerData` isn't loaded yet, same guard as `SecondIslandGateClient`)
  and flips `Transparency`/`CanCollide` back on for that client only if
  it's true. Also re-checks on every `PlayerWizardTiered` event, so
  reaching Tier 3 reveals the ruin immediately without needing to rejoin.
  Also reveals `RuneAltarBoard` (parented under `Kiosks`, not
  `FantasyRuin`, so the `Transparency`/`CanCollide` loop above doesn't
  touch it) via its own `RevealTransparency`/`RevealCanCollide`
  attributes, same "clear glass" treatment as every other board.
- `RuneAltarBoardClient.client.lua` — `RuneAltarBoard`'s SurfaceGui: a
  "Rune Altar" title, a subtitle stating the current Mana cost/tick
  interval (`RuinRuneHandler.getState`'s `manaCostPerTick`/
  `tickIntervalSeconds`, so it updates once Mana Efficiency/Rune Speed are
  bought), and the 5 tiers laid out in an explicit 2-column grid (not a
  `UIGridLayout`, so the odd 5th card lands predictably on its own row) -
  the overall "card per tier" look is from references given directly.
  Each card shows one of 3 states: locked (name shown, but "🔒 Discover
  the rune" in place of cost/boost - same progressive-reveal idea as the
  Upgrade Tree tiles), reachable (cost + a Buy/afford-colored button,
  live-updated off `ManaUpdated` same as every other Mana-spending board),
  or bought (its boost line + a "[MAX]" tag, no button). Waits in a
  blocking loop on `GetSecondIslandState().unlocked` before building
  anything, same reasoning as every other SecondIsland board.
- `RuneAltarClient.client.lua` — floating feedback for actually standing
  on the Rune Altar: listens for `RuneAltarCollected` (one `{name, amount}`
  per roll that tick) and pops a small rising, fading "+N RankName"
  `BillboardGui` above the player's head per entry (`TweenService`,
  `POPUP_DURATION_SECONDS` = 1.2s), colored by a rarity ramp
  (`RANK_COLORS`, my own call - `GameConfig.RuneRanks` itself carries no
  colors) so "sit there and it collects by chance" is actually visible
  happening in real time. Multiple entries (once the Familiar tier grants
  extra rolls) stack a bit higher each so they don't overlap.
- `UpgradeTreeClient.client.lua` — the info sign for whichever of
  `UpgradeTreeTile1`-`UpgradeTreeTile9` are currently reachable, styled
  like the reference upgrade cards (colored background, title, cost) but
  painted flat onto each tile's own Top face with a `SurfaceGui`, per
  direct request ("no 3D dynamic text just stuck to the ground like a sign
  laying down") - NOT a `BillboardGui`, which would float above the tile
  and always turn to face the camera. A tile's sign only exists once
  `GetUpgradeTreeState()` reports it `reachable` (Tier 3 AND every tile it
  requires already bought, per direct request "have the cards only appear
  once you buy the ones before it") - every tile is always solid ground,
  so no sign paints onto an unreached one, and each one's title comes
  straight from `UpgradeTreeHandler`'s own `label` for that tile. Colored
  per the exact rule given: red (not enough Dust), yellow (affordable -
  walk over it to buy), green (bought) - tracked live off
  `ArcaneDustUpdated` (afford check, re-evaluated against every unbought
  tile's own cost at once) and the `UpgradeTreeTileBought` event, which now
  triggers a full state re-fetch rather than just flipping one sign green,
  since buying a tile can make other tiles newly reachable (e.g. Tile 1
  revealing Tiles 2-3) and their signs need building too, not just the
  bought one's color updating.
  Re-checks on every `PlayerWizardTiered` event too, so reaching Tier 3
  builds every sign immediately without a rejoin.
- `EtherAreaClient.client.lua` — reveals `Workspace.EtherArea` (the Ether
  Shroud, its mist, platform, and upgrade board) LOCALLY for whichever
  players have actually unlocked Ether: every part starts hidden/no-collide
  server-side since it's shared world geometry and different players can
  be at different Upgrade Tree progress, so this checks `GetEtherUnlocked`
  (retrying a few times if `PlayerData` isn't loaded yet, same guard as
  `SecondIslandGateClient`/`WizardRuinClient`) and flips
  `Transparency`/`CanCollide` back on for that client only if it's true,
  also enabling the Shroud's "Click to Collect Ether" label. Re-checks on
  every `UpgradeTreeTileBought` event, so buying Tile 9 reveals the area
  immediately without a rejoin.
- `EtherUpgradeBoardClient.client.lua` — the Ether board's 3-column UI
  ("More Ether", "Click Speed", "More Dust"), same `createUpgradeColumn`
  pattern and purple theme as every other board, just costed in Ether.
  Unlike every other board, it doesn't build AT ALL until
  `GetEtherUnlocked` reports true - the physical board Part is already
  hidden per-player by `EtherAreaClient`, but that alone wouldn't stop a
  `SurfaceGui` from still rendering on top of it, so the UI itself also
  waits on the same unlock check before it's ever created. Also rechecks
  on `UpgradeTreeTileBought`, building the board immediately once Tile 9
  is bought.
- `EtherIslandGateClient.client.lua` — builds `EtherIslandGate`'s "LOCKED"
  sign and Unlock button, exact same shape as `SecondIslandGateClient`
  just with a single Ether requirement instead of Mana/Rebirths/Level.
  Fetches `GetEtherIslandState` on load (retrying a few times if
  `PlayerData` isn't loaded yet); if already unlocked, sets the gate's
  `Transparency` to 1 for this player only and stops there. Otherwise
  tracks the Unlock button's afford state live off `EtherUpdated`, and
  pressing it while affordable calls `UnlockEtherIsland`; on success,
  hides the gate and disables its `SurfaceGui` locally.
- `RebirthBoardClient.client.lua` — a separate, narrower board
  (`Workspace.Kiosks.RebirthBoard`) just past the Mana Upgrades board's
  edge, styled in red instead of the Mana board's blue. Its title banner
  carries the uploaded Rebirths icon to the left of the "Rebirths" text.
  Explains the mechanic, shows "Your Rebirths: <NumberFormat>" (kept live
  via `RebirthsUpdated` even when Rebirths are spent elsewhere, e.g. the
  Rebirth Shop board), a live "Rebirth now for +<NumberFormat> Rebirths"
  preview that updates off the same `ManaUpdated` event the HUD uses, and
  a Rebirth button (bright red when you have the required 1,000+ Mana,
  gray otherwise). Rebirths went through the shared `NumberFormat` (same
  "10.00T" style as Mana/Arcane Dust) instead of a plain `%.1f`, per direct
  request - with the Rebirth Shop/Wizard Tier/Upgrade Tree multipliers all
  stacking, a raw `%.1f` was rendering as one long unreadable number
  instead of an abbreviated one. Same SurfaceGui-on-a-face approach as the
  Mana board.
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
  Also reveals `ArcaneDustPad`, its label, and both upgrade boards
  LOCALLY the moment this player is actually unlocked (in both the
  already-unlocked and just-clicked-Unlock paths) - per direct request,
  "make all the cards and everything look locked until they open that
  first door" - reading each part's `RevealTransparency`/
  `RevealCanCollide` attributes, same mechanism `WizardRuinClient`/
  `EtherAreaClient` use.

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
`EtherArea`, `EtherIsland`, `EtherIslandBridge`, `EtherIslandGate`,
`EtherIslandDecor`, `LeaderboardIsland`,
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
