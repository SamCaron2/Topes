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

## 2. Resource chain (the reset ladder)

Four tiers, each one "cashes in" the tier below it for a permanent boost.
This is the core session-length driver — you always have a next resource to
chase.

| Tier | Name | How you get it | What it resets |
|---|---|---|---|
| 1 | **Mana** | Walk to glowing crystal nodes / auto-collected by Familiars | — |
| 2 | **Essence** | Spend Mana at the Distillery once you hit the tier requirement | Resets Mana + Mana upgrades, grants permanent Essence/sec multiplier |
| 3 | **Gold** | Spend Essence at the Vault once you hit the tier requirement | Resets Essence + Essence upgrades, grants permanent Gold/sec multiplier |
| 4 | **Gems** (premium-feel) | Slow passive trickle from Gold milestones, or bought with Robux | Not resettable — spent on Rune pulls & instant boosts |

Each tier's "Buy Max" screen shows current rate, next-level rate, and cost —
mirrors the source game's Coins/Cash upgrade panel (More Coins / More Cash
side-by-side buttons, Buy vs Max).

Number formatting: standard suffix notation (K, M, B, T, Qd, Qt, Sx, Sp, Oc,
No, Dc...) via a shared `NumberFormat` module — required once numbers exceed
~1e6, which happens fast in this genre.

## 3. Stats (multiply everything)

Reskin of Strength/Luck/Bulk/Speed/Clone:

| Stat | Effect |
|---|---|
| **Power** | Multiplies Mana gained per node collected |
| **Fortune** | Improves Rune pull odds toward rarer tiers |
| **Focus** | Multiplies Mana gained per collection tick (bulk per action) |
| **Haste** | Increases walkspeed + auto-collect tick rate |
| **Familiar** | Spawns spectral duplicates that auto-collect nearby nodes (stacks) |

All five are raised via the walkable upgrade tree (see below) and via Rune
pulls. Total output = `baseRate * Power * Focus * (ascension multiplier)`.

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
- **Ascension III+** — Escalating requirements, each unlocking new upgrade
  trees, new rune tiers, and flat stat multipliers.

Ascending resets Mana/Essence/Gold and their upgrades but **never** resets
Runes, Ascension count, or Gems — those are the "permanent progress" that
keeps players from feeling like ascension is a punishment.

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

## 9. Monetization plan

| Product | Type | Price idea |
|---|---|---|
| Gem packs | Dev Product | Several tiers, e.g. 100/500/1500/5000 Gems |
| 2x Mana Gamepass | Gamepass | Permanent passive multiplier |
| 2x Rune Luck Gamepass | Gamepass | Permanent Fortune boost |
| Auto-Collect Gamepass | Gamepass | Unlocks Familiar auto-collect before Ascension II |
| VIP Familiar | Gamepass | Cosmetic + small stat perk, chat tag |
| Instant Ascend Dev Product | Dev Product | Skips the current tier's grind once |

Keep early gamepasses cheap (~50-99 Robux) to drive first-purchase
conversion; mid-game Gem packs are where the real revenue comes from once
players are invested (matches how the source game structures its Diamonds).

## 10. Tech plan

- **Rojo**-based project (`default.project.json`) so this folder stays the
  source of truth and syncs into Roblox Studio — install the Rojo plugin
  in Studio, run `rojo serve` from this folder, connect from the plugin.
- Server-authoritative resource collection and rune pulls (never trust the
  client for currency math — trivially exploited otherwise).
- `ProfileService`-style pattern for `DataStore` saves (session-locking,
  autosave, retry-on-fail) — start simple, harden before launch.
- `NumberFormat` module shared client/server for suffix notation.

## 11. Open questions for you

- Final game name (placeholder: "Rune Academy")
- Visual style: low-poly fantasy (matches source game's blocky look) vs.
  something more stylized
- Whether Ascension resets Runes too at some far endgame tier ("True
  Ascension") for long-term replay depth — common in this genre once
  players hit late Ascension counts
