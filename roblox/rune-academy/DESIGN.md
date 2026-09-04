# Rune Academy — Design Doc

Working title. Incremental/idle game, reskinned from the "Resource Incremental"
loop (mana chain → gacha runes → ascension prestige → leaderboards) into a
wizard academy theme. Everything below is our own numbers/names/art — only
the *system* is borrowed.

## 1. Core fantasy

You're a student at a floating wizard academy. You gather **Mana** from
crystal nodes scattered around the courtyard, convert it up a chain of
increasingly valuable resources, spend resources pulling **Runes** that
permanently boost your stats, and periodically **Ascend** to reset your
progress for a permanent multiplier and access to new content. Compete on
leaderboards, chase rare rune pulls, redeem community codes for boosts.

## 2. Zones & the 16-currency system

16 currencies total, split across 5 zones plus the global premium currency
(Gems). Every currency runs on the same generic engine
(`ResourceEngine.lua`) rather than being hand-built per currency — adding,
renaming, or rebalancing one is a `GameConfig.Zones` edit, never new code.
This is the actual depth driver behind the "keep people playing for a
while" goal: each currency you unlock is a fresh on-ramp with its own fast
early progress, which is what makes this genre addictive (see section on
pacing below).

**Four independent layers, per currency:**

1. **Collect** — click a node or stand on a plate. Only the first currency
   in each zone's chain is collected this way; everything above it is
   `chainOnly` (only obtained by resetting the tier below).
2. **Upgrades** — 3 resettable multiplier slots per currency ("More X /
   More X II / Faster X"), each with its own level cap and cost curve.
   Mirrors the reference game's Shells Upgrades panel exactly.
3. **Self-Prestige** — an ordered list of one-time tiers *within the same
   currency*: spend enough of it, and it resets to 0 (upgrades too) but
   permanently multiplies its own base rate forever after. This is the
   "Prestige 1 costs 10k Shells → resets Shells, starts back at x5"
   mechanic — distinct from converting to the next tier, and the layer
   that makes early grinding on a currency feel like it's compounding
   before you've even moved on.
4. **Chain Reset** — once a currency crosses its threshold, convert it into
   the next currency in the chain (Bronze→Iron style). Grants
   `floor(amount / requirement)` of the next currency, and permanently
   bumps that next currency's base rate a little more every time you reset
   into it — so a chain you've cycled through many times starts you off
   faster the next time you reach it.

**Floor tiles** are a fifth, separate layer: a walkable, permanent
production-multiplier tree per zone (e.g. "500k Bronze → x1.5 Bronze
production"). Never reset by anything — the permanent investment layer,
same category as Runes and Ascension count.

**The 16 currencies, by zone:**

| Zone | Currencies | Unlocks at |
|---|---|---|
| Rune Academy (start) | Mana → Essence → Gold | Always open |
| Familiar Grounds | Whispers | Always open (side-grind, no chain reset) |
| The Foundry | Copper → Tin → Steel → Mithril | Ascension I |
| Tidal Grotto | Pearls → Coral → Driftglass → Abyssal Salt | Ascension II |
| Starfall Peak | Stardust → Comet Shards → Celestium | Ascension III |
| *(global)* | Gems | Always open, premium |

Zones gating on Ascension count is what paces the whole game — you can't
rush to Starfall Peak on day one, you have to actually build up the
Academy chain enough to Ascend three times first. **Gold** (top of the
Academy chain) is our equivalent of the reference game's "Cash used for
rebirths" — it's what `AscensionTiers` requirements are measured in.
**Celestium** (top of Starfall Peak, no further chain reset) is the final
currency — maxing its self-prestige tiers is "100% completion."

Each currency's effective production rate is:

```
baseRate
  × (product of that currency's 3 upgrade slot multipliers)
  × (self-prestige cumulative multiplier)
  × (chain-reset "started faster" bonus, stacks per reset into it)
  × (floor tile multipliers targeting it)
  × global Power stat (manual collect) or Focus stat (Familiar auto-collect)
```

Number formatting: standard suffix notation (K, M, B, T, Qd, Qt, Sx, Sp, Oc,
No, Dc...) via a shared `NumberFormat` module — required once numbers exceed
~1e6, which happens fast in this genre.

### Pacing target: ~2 weeks casual F2P to 100%

The numbers currently in `GameConfig.Zones` are a first-pass scaffold, not
tuned balance — getting 16 currencies × 3 upgrade slots × self-prestige
tiers × chain thresholds to actually sum to "~2 weeks of casual play, a
little less with spending" needs simulation or real playtest data, not
guesswork. The method once there's something playable:

1. Instrument a debug command that fast-forwards a simulated "optimal
   player" through the whole game (buy the best-value upgrade each tick,
   chain-reset/self-prestige the moment it's worth it) and logs how long
   each currency and each zone takes.
2. Tune each zone's cost-growth rates and thresholds until the simulated
   total lands in the ~2 week range, biasing early zones (Academy) toward
   faster completion than late ones (Starfall Peak) — front-loaded
   momentum is what hooks new players.
3. Re-run after every balance change. Because everything is config-driven,
   this is editing numbers in `GameConfig.lua`, never rewriting logic.

## 3. Stats (multiply everything)

Reskin of Strength/Luck/Bulk/Speed/Clone:

| Stat | Effect |
|---|---|
| **Power** | Multiplies every manual collect (click/stand), on every currency in every zone |
| **Fortune** | Improves Rune pull odds toward rarer tiers |
| **Focus** | Multiplies every Familiar auto-collect tick, on every currency in every zone |
| **Haste** | Increases walkspeed + auto-collect tick rate |
| **Familiar** | Spawns spectral duplicates that auto-collect nearby nodes (stacks) |

Unlike the per-currency upgrades/self-prestige/chain-reset layers (section
2), these five Stats are global — raised via the walkable upgrade tree
(see below), Ascension, and Rune pulls, and they apply on top of every
single currency's own production math at once. They're the account-wide
multiplier layer that makes progress in one zone carry over as a boost to
every other zone.

## 4. Walkable upgrade tree

Physically laid out as a grid of tiles across the academy courtyard the
player walks onto — not just a UI menu (matches the source game's tile path
with "Expand Map & Unlock Strength" nodes). Each tile shows:

- Stat name + current level
- Next boost value (e.g. `x3.05 Power`)
- Cost in the relevant resource
- `MAXED` state once capped for the current Ascension tier

Walking further out unlocks new tiles ("Expand Academy" tiles cost Gold and
extend the path, gating late-game stats behind exploration + spend).

## 5. Runes (gacha pull system)

- Currency: **Scrolls** (reskin of "Steak") — earned as a byproduct of
  hitting Mana/Essence milestones, or bought with Gems.
- Pulling opens a rune chest animation, landing on a rarity tier with
  published odds (transparency matters for Roblox ToS + trust):

| Rank | Odds (baseline, before Fortune) |
|---|---|
| Apprentice | 1/1 |
| Novice | 1/5 |
| Adept | 1/5 |
| Skilled | 1/7 |
| Expert | 1/260 |
| Master | 1/5,200 |
| Archmage | 1/104,000 |
| Mythic | 1/125,000,000 |
| Ascendant | 1/750,000,000,000 |

- Each rune grants a small permanent multiplier to one of the five stats.
  Higher ranks grant bigger multipliers and can boost multiple stats at
  once (mirrors the source's "x960 Luck / x68.5T Bulk / x6k Speed / x1
  Clone" combo runes).
- Fortune stat shifts the odds table toward rarer tiers — gives Fortune
  investment a clear payoff.
- Live feed (bottom-right of screen) ticks server-wide rune pulls in
  real time — pure social proof / FOMO, no gameplay effect.

## 6. Ascension (prestige)

Multi-tier prestige, each tier permanent once reached:

- **Ascension I** — Requires X Gold. Grants: x2 all previous stats,
  +Familiar collection range, unlocks the Novice+ rune pool.
- **Ascension II** — Requires higher Gold + Ascension I. Grants: passive
  auto-collect (Familiars work without you present), +Haste baseline,
  unlocks a second upgrade tree.
- **Ascension III** — unlocks Tidal Grotto, escalating Gold requirement,
  new rune tiers, flat stat multipliers.
- **Ascension IV+** — further zones and content as they're designed;
  Starfall Peak's unlock (Ascension III) is currently the last zone gate,
  Ascension IV is a flat stat-multiplier-only tier beyond it.

Ascending resets every currency's amount and upgrade levels, across every
zone, but **never** resets Runes, Ascension count, Gems, floor tiles,
self-prestige tiers, or chain-reset bonuses — those are the "permanent
progress" layers that keep players from feeling like ascension is a
punishment (see section 2's four-layer breakdown for why those specific
things survive a reset).

## 7. Leaderboards

Four boards, each with a **Global** and **F2P** (free-to-play, i.e.
Robux-spent filtered to ~0) toggle, refreshed periodically via
`DataStoreService` + `OrderedDataStore`:

- Total Gold
- Total Runes Opened
- Playtime
- Robux Spent

The Robux Spent board turns spending into visible status — a proven
Roblox monetization lever (whale recognition). F2P split lets grindy
players compete without feeling priced out, which keeps retention up for
the players who'll never spend but do bring friends/engagement.

## 8. Community codes

A text-entry field under Settings. Redeeming a valid code (checked against
a `ModuleScript` allowlist updated via game update, not live-edited) grants
one-time or timed effects: bonus Scrolls, a temporary 2x Mana multiplier,
a free Rune pull. Standard marketing lever — codes get posted on the game's
Discord/social to drive spikes in DAU around updates.

## 9. Monetization plan — the Power Store

The stated goal for this project is Robux spend, not just engagement, so the
store isn't cosmetic-first — it's a direct, uncapped power lever. Two kinds
of product, each doing a different job:

**GamePasses (one-time, permanent)** — the "get invested" purchases. Cheap
(~150-350 Robux) so the first purchase is an easy yes:

| Pass | Effect |
|---|---|
| Archmage Pass | Permanent x3 Power |
| Fortune Pass | Permanent x3 Fortune (much better Rune odds) |
| Auto-Collect Pass | Familiars collect passively before you'd normally unlock it at Ascension II |
| VIP Familiar | +2 flat Familiars, cosmetic aura, chat tag |

**Developer Products (repeatable) — the real spend driver.** Unlike a
gamepass, these have no ceiling: a committed player can buy them over and
over, and each purchase visibly moves their numbers. This is the standard
whale-monetization pattern for the genre (mirrors the source game's Diamond
purchases) and is the main reason `statMultiplierAll` exists as a grant type
distinct from the one-time gamepass `statMultiplier`:

| Product | Effect | Price idea |
|---|---|---|
| Power Surge (S/M/L) | Instantly multiplies **every current stat** by 1.25x/1.6x/2.5x, stacks with every purchase | 99 / 299 / 999 Robux |
| Gem Pack (S/M/L) | Direct Gems, spent on extra Rune pulls | 99 / 399 / 999 Robux |
| Scroll Bundle | 10 Rune pulls worth of Scrolls | 249 Robux |
| Instant Ascend | Skips the current tier's Gold requirement and forces the next Ascension immediately | 199 Robux |

Because Power Surge multiplies *current* stats rather than adding a flat
bonus, it compounds with everything else a player has (Rune pulls,
Ascension multipliers) — the more invested a player already is, the more
a single Power Surge is worth, which is exactly the dynamic that gets
high-spenders to keep buying rather than stopping at one purchase.

The **Robux Spent leaderboard** (section 7) is what makes this visible and
socially competitive — spend converts directly into a public rank, which
is a proven driver of repeat purchases in this genre.

Implementation: `GameConfig.DevProducts` / `GameConfig.GamePasses` define
every product's grant; `StoreHandler.lua` processes purchases
server-side via `MarketplaceService.ProcessReceipt` (dev products) and
`PromptGamePassPurchaseFinished` (gamepasses), with purchase-history
tracking so a retried receipt is never double-granted. See the README for
the one manual step left: creating the real GamePass/Dev Product assets in
Studio and pasting their IDs into `GameConfig.lua` (they're all placeholder
`id = 0` right now).

## 10. Profile & Titles

**"Main" profile screen** (not yet built as a UI, but the server side is —
`GetProfile` RemoteFunction returns everything it needs): account name +
avatar picture (drawn client-side from the `Player` instance / Roblox's
thumbnail API, not stored by us), current Gold + Gems totals, playtime, and
Robux spent. Same numbers driving the leaderboards, just scoped to you.

**Titles** — one equipped at a time, shown as a colored label floating
above the player's head (matches the reference screenshot). Unlocking and
equipping are separate: earning a title just makes it selectable, players
choose which one to actually display. This is a status/collection layer
independent of the resource-chain — someone can be un-equipped and grinding
quietly, or decked out in "Rich" showing off.

| Title | Unlocks when | Color |
|---|---|---|
| OG | Joined within 24h of release | Gold |
| Fan | Member of the game's Roblox group | Pink |
| Newbie | 1 hour playtime | Gray |
| Regular | 1 day playtime | Green |
| VIP | 7 days playtime | Blue |
| No Life | 30 days playtime | Purple |
| Supporter | 100+ Robux spent | Teal |
| Boss | 1,000+ Robux spent | Orange |
| **Rich** | 10,000+ Robux spent | **Animated rainbow** |
| Ultimate Spender | 100,000+ Robux spent | Red |
| EliteGP | Owns the Elite gamepass | Cyan |
| Tester | Manually granted | Mint |
| Admin | Manually granted | Red |
| Owner | Manually granted | Gold |

The spend-gated titles (Supporter → Ultimate Spender) do double duty with
the Power Store: they're free status rewards for the same spending that's
already buying Power Surges, so a whale gets both mechanical power *and*
visible rank from one purchase — reinforces the same loop rather than
competing with it.

Implementation: `GameConfig.Titles` defines the list + unlock conditions;
`TitleHandler.lua` checks conditions (on join, after any purchase, and on
a periodic sweep for playtime-based ones), persists unlocks + the equipped
title in `PlayerData`, and mirrors the equipped title onto `Player`
attributes so it replicates to every client automatically.
`TitleDisplayClient.client.lua` reads those attributes and draws the
`BillboardGui` above each player's head, including the rainbow animation
for Rich. Tester/Admin/Owner are granted via UserId allowlists in
`GameConfig` (`OwnerUserIds`/`AdminUserIds`/`TesterUserIds`) until an
in-game admin command exists to grant them live.

Three things need real values before these work as intended (see README):
`GameConfig.ReleaseTimestampUnix` (for OG), `GameConfig.FanGroupId` (for
Fan), and the UserId allowlists (for Tester/Admin/Owner) — all placeholder
`nil`/`0`/`{}` right now.

## 11. Tech plan

- **Rojo**-based project (`default.project.json`) so this folder stays the
  source of truth and syncs into Roblox Studio — install the Rojo plugin
  in Studio, run `rojo serve` from this folder, connect from the plugin.
- Server-authoritative resource collection and rune pulls (never trust the
  client for currency math — trivially exploited otherwise).
- `ProfileService`-style pattern for `DataStore` saves (session-locking,
  autosave, retry-on-fail) — start simple, harden before launch.
- `NumberFormat` module shared client/server for suffix notation.

## 12. Open questions for you

- Final game name (placeholder: "Rune Academy")
- Visual style: low-poly fantasy (matches source game's blocky look) vs.
  something more stylized
- Whether Ascension resets Runes too at some far endgame tier ("True
  Ascension") for long-term replay depth — common in this genre once
  players hit late Ascension counts
