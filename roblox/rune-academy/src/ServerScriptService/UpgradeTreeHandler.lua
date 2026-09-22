-- Server-authoritative ground upgrade tree: walk-over tiles on SecondIsland,
-- only reachable once WizardTierHandler reports Tier 3+ (per direct
-- request). Each tile is a ONE-TIME purchase (not a leveled upgrade like
-- everything else), paid in Arcane Dust, bought automatically by walking
-- over it - WorldBuilder's proximity loop calls buyTile every check tick
-- for whichever tile a player is standing on, which safely no-ops if not
-- unlocked, already bought, or unaffordable.
--
-- The full 1-2-3-2-1 diamond chain (9 tiles total, extending outward from
-- Tile 1 - see WorldBuilder for the actual positions):
--   Tile 1            : Dust x2      (built first, on its own)
--   Tiles 2-3         : Mana x2, XP x2
--   Tiles 4-6         : Rebirths x2, Rune Bulk x2 ("one of the cards in
--                        the middle"), Dust x2
--   Tiles 7-8         : Mana x2, Rebirths x2 (2nd layer of each - stacks
--                        multiplicatively with Tiles 2/4)
--   Tile 9 (final, "the very last tile on the opposite side"): unlocks
--                        Ether, the next wizard resource - name only for
--                        now, per direct request ("Just choose the name
--                        for right now"); no collection mechanic built yet.
--
-- Cost doubles per ring outward from Tile 1 (1e9 -> 2e9 -> 4e9 -> 8e9 ->
-- 16e9) - every tile's EFFECT is a flat x2, so cost is the only thing that
-- scales with distance, which keeps the whole tree easy to read at a
-- glance instead of needing a different multiplier value memorized per
-- tile.

local PlayerData = require(script.Parent.PlayerData)
local WizardTierHandler = require(script.Parent.WizardTierHandler)

local UNLOCK_MIN_TIER = 3

local TILES = {
	{ id = 1, fieldName = "dustTreeTile1", cost = 1e9, kind = "dust", multiplier = 2, label = "Dust x2" },
	{ id = 2, fieldName = "dustTreeTile2", cost = 2e9, kind = "mana", multiplier = 2, label = "Mana x2" },
	{ id = 3, fieldName = "dustTreeTile3", cost = 2e9, kind = "xp", multiplier = 2, label = "XP x2" },
	{ id = 4, fieldName = "dustTreeTile4", cost = 4e9, kind = "rebirth", multiplier = 2, label = "Rebirths x2" },
	{ id = 5, fieldName = "dustTreeTile5", cost = 4e9, kind = "runeBulk", multiplier = 2, label = "Rune Bulk x2" },
	{ id = 6, fieldName = "dustTreeTile6", cost = 4e9, kind = "dust", multiplier = 2, label = "Dust x2" },
	{ id = 7, fieldName = "dustTreeTile7", cost = 8e9, kind = "mana", multiplier = 2, label = "Mana x2" },
	{ id = 8, fieldName = "dustTreeTile8", cost = 8e9, kind = "rebirth", multiplier = 2, label = "Rebirths x2" },
	{ id = 9, fieldName = "dustTreeTile9", cost = 16e9, kind = "unlock", label = "Unlocks Ether" },
}

local UpgradeTreeHandler = {}
UpgradeTreeHandler.TILES = TILES

function UpgradeTreeHandler.isUnlocked(player: Player): boolean
	local data = PlayerData.get(player)
	local tier = data and data.wizardTier or 0
	return tier >= UNLOCK_MIN_TIER
end

-- Folds every bought tile of a given `kind` together (multiplicatively) -
-- shared by all the get*Multiplier functions below so adding another tile
-- of an existing kind never needs a code change, just a new TILES entry.
local function foldMultiplier(player: Player, kind: string): number
	local data = PlayerData.get(player)
	if not data then
		return 1
	end

	local multiplier = 1
	for _, tile in TILES do
		if tile.kind == kind and data[tile.fieldName] then
			multiplier *= tile.multiplier
		end
	end
	return multiplier
end

function UpgradeTreeHandler.getDustMultiplier(player: Player): number
	return foldMultiplier(player, "dust")
end

function UpgradeTreeHandler.getManaMultiplier(player: Player): number
	return foldMultiplier(player, "mana")
end

function UpgradeTreeHandler.getXpMultiplier(player: Player): number
	return foldMultiplier(player, "xp")
end

function UpgradeTreeHandler.getRebirthMultiplier(player: Player): number
	return foldMultiplier(player, "rebirth")
end

function UpgradeTreeHandler.getRuneBulkMultiplier(player: Player): number
	return foldMultiplier(player, "runeBulk")
end

-- Tile 9's "kind" is special - it's a one-time unlock flag, not a folded
-- multiplier - read by whatever eventually builds Ether's own collection
-- mechanic.
function UpgradeTreeHandler.isEtherUnlocked(player: Player): boolean
	local data = PlayerData.get(player)
	return data ~= nil and data.dustTreeTile9 == true
end

function UpgradeTreeHandler.getState(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return nil
	end

	local tiles = {}
	for _, tile in TILES do
		tiles[tile.id] = {
			bought = data[tile.fieldName] or false,
			cost = tile.cost,
			label = tile.label,
		}
	end

	return {
		unlocked = UpgradeTreeHandler.isUnlocked(player),
		arcaneDust = data.arcaneDust or 0,
		tiles = tiles,
	}
end

-- Called every WorldBuilder proximity-check tick for any player standing on
-- tile `tileId` - returns true only on the tick it actually buys it (so
-- the caller knows to fire the Updated/Bought events), false on every
-- no-op tick (not unlocked yet, already bought, or can't afford).
function UpgradeTreeHandler.buyTile(player: Player, tileId: number): boolean
	local data = PlayerData.get(player)
	if not data then
		return false
	end

	if not UpgradeTreeHandler.isUnlocked(player) then
		return false
	end

	local tile = TILES[tileId]
	if not tile then
		return false
	end

	if data[tile.fieldName] then
		return false
	end

	if (data.arcaneDust or 0) < tile.cost then
		return false
	end

	data.arcaneDust -= tile.cost
	data[tile.fieldName] = true
	return true
end

return UpgradeTreeHandler
