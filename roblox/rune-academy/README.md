# Rune Academy

Incremental/idle Roblox game. See `DESIGN.md` for the full system design
(16-currency zone system, stats, Runes, Ascension, leaderboards,
monetization plan).

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
6. Build in Studio as normal (terrain, each zone's area, node parts tagged
   `ResourceNode` via CollectionService with `ZoneKey`/`CurrencyKey`
   attributes set to match `GameConfig.Zones`, UI) — code changes you make
   in your editor sync live; UI/building changes you make in Studio should
   be done in parts of the tree Rojo doesn't own (or synced back manually,
   since this is a code-first Rojo setup, not two-way).

## What's already scaffolded

- `GameConfig.lua` — every tunable number lives here: the 16-currency
  `Zones` config (upgrades, self-prestige tiers, chain resets, floor
  tiles), stat definitions, Rune rarity odds + boosts, Ascension tiers.
  Change balance here, not in the handler scripts.
- `NumberFormat.lua` — K/M/B/T/Qd/... suffix formatting for big numbers.
- `PlayerData.lua` — DataStore load/save/autosave, leaderstats, and
  `defaultData()` builds every zone/currency's save-data shape straight
  from `GameConfig.Zones` (add a currency to config, its save slot exists
  automatically — no separate PlayerData change needed).
- `ResourceEngine.lua` — the generic engine every currency runs on:
  server-authoritative collect (click/stand, distance + debounce checked),
  buy upgrade (one/max), self-prestige, chain reset, and floor tile
  purchases. All 16 currencies go through this one module.
- `RuneHandler.lua` — server-authoritative gacha pull, Fortune-weighted odds.
- `ResetHandler.lua` — Ascension only (per-currency resets live in
  ResourceEngine now).
- `Main.server.lua` — wires up RemoteEvents/Functions between client and
  the handlers above.
- `ResourceCollectionClient.client.lua` — touches a `ResourceNode`-tagged
  part → asks the server to collect it, reading which zone/currency off
  the part's attributes (works for every currency, not just Mana).
- `StoreHandler.lua` — the Power Store. Processes GamePass and Developer
  Product purchases server-side, grants stat multipliers/Gems/Scrolls/an
  instant Ascension, tracks Robux spent for the leaderboard, and guards
  against double-granting a retried purchase.
- `TitleHandler.lua` — unlocks and equips Titles (`GameConfig.Titles`),
  mirrors the equipped one onto Player attributes.
- `TitleDisplayClient.client.lua` — draws the equipped title above every
  player's head, including the animated rainbow for Rich.

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

## Not yet built (next steps)

- Actual UI (per-currency upgrade panel with Buy/Max buttons, self-prestige
  + chain-reset buttons, rune pull screen, floor tile tree, leaderboards,
  codes input, a Store menu that fires `RequestPurchase`, a "Main" profile
  screen that calls `GetProfile`, a title-picker that calls `EquipTitle`)
  — this is all backend/logic scaffolding right now, no GUI.
- The actual 3D zones: 5 areas, each with its resource node parts (tagged
  `ResourceNode` with `ZoneKey`/`CurrencyKey` attributes) and a walkable
  floor tile layout.
- OrderedDataStore-backed leaderboards (Gold / Runes Opened / Playtime /
  Robux Spent, Global + F2P split).
- Community codes module + redemption remote.
- Familiar auto-collect loop (currently just a stat number + an
  `AutoCollectPass` flag, no actual passive collection behavior yet) — once
  built, it should call `ResourceEngine.getEffectiveRate(data, zone,
  currency, "auto")` per nearby node on a tick, same engine as manual
  collect just with the Focus stat instead of Power.
- An in-game admin command to grant Tester/Admin manually instead of only
  via the `GameConfig` UserId allowlists.
- Balance pass on `GameConfig.Zones`' numbers against the ~2 week
  completion target (see DESIGN.md's Pacing section) — current numbers are
  a reasonable first pass, not simulated/tuned.
- `leaderstats.Gold` is set once on join and doesn't live-update as Gold
  changes — needs a periodic sync from `data.zones.Academy.currencies.Gold.amount`.
- **Save migration**: `PlayerData.load` uses whatever `zones` shape was
  saved for a returning player as-is. That's fine pre-launch since nothing
  is saved yet, but the moment real players exist, adding a 17th currency
  (or renaming/removing one) will leave existing saves missing that
  currency's state, and any code touching it will error on a nil index.
  Before adding content post-launch, `PlayerData.load` needs a migration
  step that fills in any zone/currency present in `GameConfig.Zones` but
  missing from a loaded save (same shape `defaultZoneState()` already
  builds, just merged onto existing data instead of replacing it).
