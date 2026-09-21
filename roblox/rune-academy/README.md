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
  higher level) adds nodes right away. Also places three separate
  physical kiosk boards past the platform's edge, each just outside the
  previous one's far edge - `ManaUpgradeBoard` (42 studs wide, the
  4-column Mana upgrades board), `RebirthBoard` (20 studs wide, the
  reset-for-Rebirths action board), and `RebirthShopBoard` (32 studs
  wide, fitting its 3 columns edge-to-edge; rotated -90 degrees from the other
  two since it's the last board at the end of the row, so it faces back
  along the row instead of straight ahead - that rotation also swaps
  which of its dimensions runs along the row, so its offset uses half
  its thickness there instead of half its width, to sit flush against
  the Rebirth board's edge) - each just a bare Part
  (Glass material, 0.7 transparency, for a see-through card look - still
  solid, `CanCollide` stays true); `ManaUpgradeBoardClient`,
  `RebirthBoardClient`, and `RebirthShopBoardClient` build their actual
  UI (their SurfaceGui backgrounds are also 0.55 transparent, so the
  glass shows through behind the UI, not just around its edges). Grows
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
  (`ForceField` material, `CanCollide` false - purely visual) with a static
  SurfaceGui: a "🔒 LOCKED" title banner (same look as the kiosk boards'
  banners) plus one clean line per requirement instead of one cramped
  multi-line label. The lock is enforced (and "unlocked") by a
  `GATE_CHECK_INTERVAL` (0.25s) poll, same pattern as the fall-kill check:
  reaching the gate without the permanent `secondIslandUnlocked` flag set
  checks 40,000,000 Mana, 40,000 Rebirths, and Level 25 straight off
  `PlayerData` - meeting it flips that flag permanently (never touches
  Mana/Rebirths, it's a one-time threshold check, not a toll) so the player
  only has to walk up to the gate once; falling short teleports them back
  onto the starting island instead. Restricted to the bridge's own width so
  it never touches someone just walking near the starting island's edge
  elsewhere. No upgrade kiosks on `SecondIsland` yet, just a ring of
  procedurally placed trees/bushes/flowers (`SecondIslandDecor`) around its
  edge, inset from the border, skipping the bridge's landing spot, and each
  given a small random `DECOR_JITTER` offset so the ring reads as staggered
  rather than a perfectly straight line. Each piece is also built from
  several overlapping/stacked parts (three canopy clumps per tree, three
  bumps per bush, a stem + bloom per flower) instead of one plain shape, for
  a fuller look than a single sphere or dot. The exact direction/size
  (`BRIDGE_LENGTH`/`BRIDGE_WIDTH`/`SECOND_ISLAND_SIZE`/
  `SECOND_ISLAND_OFFSET_X`) is a best guess from a screenshot, same "nudge
  the numbers after testing" situation as the kiosk board offsets above if
  it's not quite lined up.
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
  (1x-200x, survives rebirthing) - `amountPerPickup`/`nextAmountPerPickup`
  in the returned state already include it, so the board always shows
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
  updated live off the `ManaUpdated` RemoteEvent, plus a Rebirths counter
  right below it. Styled after a typical incremental-game HUD, not the
  original dark rounded pill: no background at all, just the icon sitting
  a small fixed gap (`ICON_TEXT_GAP`) from a bold, left-aligned number -
  no "Mana"/"Rebirths" word, the icon says it - colored to echo the icon's
  own palette (violet for Mana, matching the Mana nodes' own glow; pink-red
  for Rebirths, matching the Rebirth board's red theme). The Rebirths icon
  keeps a small round white circle behind it for contrast; the Mana icon
  has none, per direct request, since its sparkles poke outside a round
  silhouette and looked bad boxed into one. The Rebirths row starts hidden
  and only appears once the `RebirthsUpdated` event fires with a value
  above 0 - the server only ever fires it once a player has actually
  rebirthed, so it stays hidden until Rebirths are unlocked.
- `SideMenuClient.client.lua` — the right-side icon menu, mirroring the
  Mana counter's placement, laid out 2x2: Store/Runes/Profile/Settings.
  Store and Settings show their uploaded icon image directly (background
  transparent, no colored circle behind it - the art reads fine on its
  own); Runes/Profile don't have real art yet, so they keep the original
  colored-circle-plus-placeholder-symbol look (safe basic Unicode glyphs -
  ★/☺ - not emoji) until they do. Each item also gets a bold `FredokaOne`
  name label with a heavy stroke underneath for a "cool logo" look.
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
  far away a Mana node will still get auto-collected.
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
`WorldBuilder` explicitly manages (`StartingIsland`, `ManaZone`, `Kiosks`,
`SecondIsland`, `IslandBridge`, `SecondIslandGate`, `SecondIslandDecor`,
all rebuilt from scratch on every server start). If your saved `.rbxl`
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
