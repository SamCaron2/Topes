# Rune Academy

Incremental/idle Roblox game. See `DESIGN.md` for the full system design
(resource chain, stats, Runes, Ascension, leaderboards, monetization plan).

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
6. Build in Studio as normal (terrain, the academy courtyard, node parts
   tagged `ManaNode` via CollectionService, UI) — code changes you make in
   your editor sync live; UI/building changes you make in Studio should be
   done in parts of the tree Rojo doesn't own (or synced back manually,
   since this is a code-first Rojo setup, not two-way).

## What's already scaffolded

- `GameConfig.lua` — every tunable number lives here (resource tiers, stat
  definitions, Rune rarity odds + boosts, Ascension tiers). Change balance
  here, not in the handler scripts.
- `NumberFormat.lua` — K/M/B/T/Qd/... suffix formatting for big numbers.
- `PlayerData.lua` — DataStore load/save/autosave, leaderstats.
- `CollectionHandler.lua` — server-authoritative Mana collection (distance +
  debounce checked server-side).
- `RuneHandler.lua` — server-authoritative gacha pull, Fortune-weighted odds.
- `ResetHandler.lua` — tier resets (Mana→Essence→Gold) and Ascension.
- `Main.server.lua` — wires up RemoteEvents/Functions between client and
  the handlers above.
- `CollectionClient.client.lua` — touches a `ManaNode`-tagged part → asks
  the server to collect it.
- `StoreHandler.lua` — the Power Store. Processes GamePass and Developer
  Product purchases server-side, grants stat multipliers/Gems/Scrolls/an
  instant Ascension, tracks Robux spent for the leaderboard, and guards
  against double-granting a retried purchase.

## One manual step required before the store works

`GameConfig.DevProducts` and `GameConfig.GamePasses` list every product
with a placeholder `id = 0`. In Studio: **Home → Monetize** (or the game's
page on the Creator Dashboard) → create each GamePass and Developer
Product listed there with matching prices, then paste the real asset ID
back into `GameConfig.lua`. Nothing will prompt a real purchase until
that's done — `StoreHandler.promptPurchase` silently no-ops on `id = 0` on
purpose, so a half-configured store can't accidentally prompt Studio's
test/placeholder asset IDs.

## Not yet built (next steps)

- Actual UI (rune pull screen, upgrade tree tiles, leaderboards, codes
  input, and a Store menu that fires `RequestPurchase`) — this is all
  backend/logic scaffolding right now, no GUI.
- The walkable upgrade tree layout + tile parts in the 3D world.
- OrderedDataStore-backed leaderboards (Gold / Runes Opened / Playtime /
  Robux Spent, Global + F2P split).
- Community codes module + redemption remote.
- Familiar auto-collect loop (currently just a stat number + an
  `AutoCollectPass` flag, no actual passive collection behavior yet).
