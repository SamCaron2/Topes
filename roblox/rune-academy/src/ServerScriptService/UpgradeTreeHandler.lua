-- Server-authoritative ground upgrade tree: walk-over tiles on SecondIsland,
-- only reachable once WizardTierHandler reports Tier 3+ (per direct
-- request). Each tile is a ONE-TIME purchase (not a leveled upgrade like
-- everything else), paid in Arcane Dust, bought automatically by walking
-- over it - WorldBuilder's proximity loop calls buyTile1 every check tick,
-- which safely no-ops if not unlocked, already bought, or unaffordable.
--
-- Only Tile 1 is built so far ("lets just start with one tho") - the
-- planned layout is a 1-2-3-2-1 diamond of tiles, so TILES is a numbered
-- list from the start even with one entry, and every function here is
-- already tile-generic (keyed by index) so adding Tile 2+ later is just
-- appending to TILES and adding its own `dustTreeTileN` PlayerData field,
-- no reshaping needed.
--
-- Tile 1's cost is derived like the Wizard Tier costs: fully maxing the
-- entire 3-column Arcane Dust Upgrades board (More Arcane Dust to 100,
-- Grant Speed to 10, More Mana to 50) costs ~619,465 Dust total - Tile 1
-- prices well past that (a genuine next milestone, not something maxing
-- the board alone affords) at 1,000,000,000 Dust, also mirroring Tier 1's
-- own 1B Mana price for a clean, legible number.

local PlayerData = require(script.Parent.PlayerData)
local WizardTierHandler = require(script.Parent.WizardTierHandler)

local UNLOCK_MIN_TIER = 3

local TILES = {
	{ fieldName = "dustTreeTile1", cost = 1e9, dustMultiplier = 2 }, -- Arcane Dust
}

local UpgradeTreeHandler = {}

function UpgradeTreeHandler.isUnlocked(player: Player): boolean
	local data = PlayerData.get(player)
	local tier = data and data.wizardTier or 0
	return tier >= UNLOCK_MIN_TIER
end

-- Folds every bought tile's dustMultiplier together (just Tile 1's for now)
-- - read by ArcaneDustHandler alongside WizardTierHandler's own dust
-- multiplier, so they stack.
function UpgradeTreeHandler.getDustMultiplier(player: Player): number
	local data = PlayerData.get(player)
	if not data then
		return 1
	end

	local multiplier = 1
	for _, tile in TILES do
		if data[tile.fieldName] then
			multiplier *= tile.dustMultiplier
		end
	end
	return multiplier
end

function UpgradeTreeHandler.getState(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return nil
	end

	return {
		unlocked = UpgradeTreeHandler.isUnlocked(player),
		tile1Bought = data.dustTreeTile1 or false,
		tile1Cost = TILES[1].cost,
		arcaneDust = data.arcaneDust or 0,
	}
end

-- Called every WorldBuilder proximity-check tick for any player standing on
-- Tile 1 - returns true only on the tick it actually buys it (so the
-- caller knows to fire the Updated/Bought events), false on every no-op
-- tick (not unlocked yet, already bought, or can't afford).
function UpgradeTreeHandler.buyTile1(player: Player): boolean
	local data = PlayerData.get(player)
	if not data then
		return false
	end

	if not UpgradeTreeHandler.isUnlocked(player) then
		return false
	end

	if data.dustTreeTile1 then
		return false
	end

	local tile = TILES[1]
	if (data.arcaneDust or 0) < tile.cost then
		return false
	end

	data.arcaneDust -= tile.cost
	data.dustTreeTile1 = true
	return true
end

return UpgradeTreeHandler
