# Rune Academy

Incremental/idle Roblox game. See `DESIGN.md` for the full system design
(multi-currency zone system, stats, Runes, Ascension, leaderboards,
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
6. You shouldn't need to manually build resource nodes or floor tiles at
   all — `WorldBuilder.server.lua` generates them automatically from
   `GameConfig.Zones` every time the server starts (including every Play
   session in Studio). Any terrain/art/decoration you want beyond that is
   normal Studio building, done in parts of the tree Rojo doesn't own.

## What's already scaffolded

- `GameConfig.lua` — every tunable number lives here: the multi-currency
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
- `FriendBoostHandler.lua` — tracks how many of a player's Roblox friends
  are in the same server (live, never saved); `ResourceEngine` applies
  `GameConfig.FriendBoost` on top of any currency flagged
  `friendBoost = true` (currently just Coins).
- `WorldBuilder.server.lua` — generates every resource node, floor tile,
  upgrade kiosk, and the Rune Altar in the world directly from
  `GameConfig.Zones` on server start (plain grid layout, one zone per
  column). Nothing about adding a currency or floor tile needs manual
  Studio building anymore — it's a config change.
- `FloorTileClient.client.lua` — walking onto a `FloorTile`-tagged part
  (WorldBuilder-generated) buys/levels it up (tiles are leveled, up to
  `maxLevel`, cost scaling like upgrade cards) or, for an "Expand Map"
  tile, unlocks whatever other tiles have it as their `requiresTile`.
  Renders live level/cost/locked state on each tile's label, polling once
  per zone rather than per tile.
- `UpgradeKioskClient.client.lua` — builds the actual **3D-world upgrade
  boards**: a `BillboardGui` mounted on each `UpgradeKiosk` part
  WorldBuilder creates (one per currency), sized in studs so it reads as a
  physical sign rather than a screen overlay. Shows upgrade cards
  (Buy/Max), a self-prestige button where configured, and a chain-reset
  button where configured — generic across every currency, not just Mana.
- `RuneAltarClient.client.lua` — standing on the `RuneAltar` part
  continuously pulls Runes once per second for as long as Scrolls last
  (matches the reference game's stand-on-a-platform pull mechanic, not a
  menu button), with two floating boards: the rank ladder + your total
  pulls, and your current stat boosts with the latest pull result.
- `CurrencyHUDClient.client.lua` — the only persistent on-screen UI: a
  small stat list (Mana/Coins/Scrolls/Gems) in the top-right
  corner, matching the reference game's minimal always-visible column.
- `SideMenuClient.client.lua` — the left-side icon column (Shop, Runes,
  Profile, Settings). Clicking an icon opens a shared popup panel built
  from a module in `Panels/` (`Profile`/`Settings` are stub "Coming soon"
  panels for now).
- `Panels/StorePanel.lua` — the Shop popup's content (module script
  `SideMenuClient` builds into its shared panel frame). Buying currently
  no-ops for every entry until real ids replace the `id = 0` placeholders
  (see Manual Steps below) — that's expected.
- `Panels/RunePanel.lua` — the Runes popup's content: your collection
  (count per rank owned) and the live server-wide pull feed. Not a pull
  button — that's the physical altar's job now.

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

## One-time cleanup if you manually placed a test crystal earlier

If you built a `ManaCrystal1` part by hand in Workspace before
`WorldBuilder.server.lua` existed, delete it — WorldBuilder now generates
its own `Node_Mana` automatically on every Play session, so the manual one
is a leftover duplicate (both would grant Mana, doubling your rate).

## Not yet built (next steps)

- Real Profile and Settings panels (currently "Coming soon" stubs in the
  side menu) — Profile should call `GetProfile` and a title-picker calling
  `EquipTitle`; Settings is undecided scope.
- Leaderboards and a codes-redemption input — still no UI or 3D placement
  decided for either.
- Real level design/terrain/art — `WorldBuilder` currently lays out a
  plain grid of colored balls, blocks, and kiosk boards per zone, purely
  functional. Making the kiosks/nodes/tiles actually look like a wizard
  academy (custom meshes, particle effects, terrain, lighting) is real,
  separate work from here.
- The kiosk boards' `GetCurrencyState` refresh polls the server once per
  second per open kiosk (~16 RPCs/sec with every kiosk visible at once,
  though `MaxDistance` limits how many actually render/matter at a time).
  Fine for solo testing; worth batching into one call if this becomes a
  real bottleneck with many players.
- OrderedDataStore-backed leaderboards (Coins / Runes Opened / Playtime /
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
- **Save migration**: `PlayerData.load` uses whatever `zones` shape was
  saved for a returning player as-is. That's fine pre-launch since nothing
  is saved yet, but the moment real players exist, adding a 17th currency
  (or renaming/removing one) will leave existing saves missing that
  currency's state, and any code touching it will error on a nil index.
  Before adding content post-launch, `PlayerData.load` needs a migration
  step that fills in any zone/currency present in `GameConfig.Zones` but
  missing from a loaded save (same shape `defaultZoneState()` already
  builds, just merged onto existing data instead of replacing it).
