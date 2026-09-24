-- Server-authoritative floor tile upgrades on EtherIsland - same
-- walk-over-to-buy mechanic as the SecondIsland Upgrade Tree
-- (UpgradeTreeHandler), just its own EtherIsland-gated set instead of
-- Arcane-Dust-funded/Tier-3-gated. Tile 1 (1,000 Ley Shard, per direct
-- request "Lets do for 1k ley shards times your ley by 2") is a cheap
-- intro; Tiles 2-3 (per direct follow-up request, "Now two more floor
-- tiles above that is one for times 2 ley shrouds and 2x astra shrouds.
-- Make them cost a decent amount so the players cant just unlock those
-- tiles right when they get to this island") cost substantially more and
-- each require the previous tile bought first, same "each tile requires
-- the one before it" chaining as the SecondIsland tree. Tile 2 is 25,000
-- Ley Shard; Tile 3, since it boosts Astral Shard itself, is priced in
-- Astral Shard instead - 50 Astral Shard (per direct follow-up request,
-- "Make tile 3 cost a resonable amount of astral shard not ley shard" -
-- my own call for "reasonable," not specified: enough to need a couple of
-- conversions to save up, not a single one). A one-time purchase flag per
-- tile, not a level, so bought tiles survive
-- AstralShardConversionHandler.convert's reset just like every other
-- one-time-flag purchase in this game (only
-- leyShardYieldLevel/leyShardSpeedLevel/leyShardManaBoostLevel get wiped
-- by that - and that reset never touches astralShard either).
--
-- Each tile has a `kind` (same convention as UpgradeTreeHandler.TILES)
-- so its multiplier only folds into the ONE thing it actually boosts:
-- "leyShard" (Tiles 1-2, read by LeyShardHandler) or "astralConversion"
-- (Tile 3, read by AstralShardConversionHandler - Card 2's "2x Astral
-- Shard" tile, since Astral Shard itself has no yield of its own, only a
-- conversion rate). A separate `currency` field (independent of `kind`)
-- says what each tile is PAID in - "leyShard" for Tiles 1-2, "astralShard"
-- for Tile 3 - so buyTile/getState can debit/display the right balance.

local PlayerData = require(script.Parent.PlayerData)

local TILES = {
	{ id = 1, fieldName = "leyShardFloorTile1", cost = 1000, currency = "leyShard", kind = "leyShard", multiplier = 2, label = "Ley Shard x2", requires = {} },
	{ id = 2, fieldName = "leyShardFloorTile2", cost = 25000, currency = "leyShard", kind = "leyShard", multiplier = 2, label = "Ley Shard x2", requires = { 1 } },
	{ id = 3, fieldName = "leyShardFloorTile3", cost = 50, currency = "astralShard", kind = "astralConversion", multiplier = 2, label = "Astral Shard x2", requires = { 2 } },
}

local LeyShardFloorTileHandler = {}
LeyShardFloorTileHandler.TILES = TILES

function LeyShardFloorTileHandler.isUnlocked(player: Player): boolean
	local data = PlayerData.get(player)
	return data ~= nil and data.etherIslandUnlocked == true
end

-- True once the whole set is unlocked (EtherIsland) AND every tile this
-- one requires has already been bought - same shape as
-- UpgradeTreeHandler.isTileReachable.
function LeyShardFloorTileHandler.isTileReachable(player: Player, tileId: number): boolean
	if not LeyShardFloorTileHandler.isUnlocked(player) then
		return false
	end

	local data = PlayerData.get(player)
	local tile = TILES[tileId]
	if not data or not tile then
		return false
	end

	for _, requiredId in tile.requires do
		local requiredTile = TILES[requiredId]
		if not (requiredTile and data[requiredTile.fieldName]) then
			return false
		end
	end

	return true
end

-- Folds every bought tile of a given `kind` together (multiplicatively) -
-- shared by getLeyShardMultiplier/getAstralConversionMultiplier below,
-- same pattern as UpgradeTreeHandler's own foldMultiplier.
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

-- Read by LeyShardHandler as another factor in its own Ley Shard yield
-- multiplier chain (Tiles 1-2).
function LeyShardFloorTileHandler.getLeyShardMultiplier(player: Player): number
	return foldMultiplier(player, "leyShard")
end

-- Read by AstralShardConversionHandler as another factor in how many
-- Astral Shard each conversion grants (Tile 3).
function LeyShardFloorTileHandler.getAstralConversionMultiplier(player: Player): number
	return foldMultiplier(player, "astralConversion")
end

function LeyShardFloorTileHandler.getState(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return nil
	end

	local tiles = {}
	for _, tile in TILES do
		tiles[tile.id] = {
			bought = data[tile.fieldName] or false,
			cost = tile.cost,
			currency = tile.currency,
			label = tile.label,
			reachable = LeyShardFloorTileHandler.isTileReachable(player, tile.id),
		}
	end

	return {
		unlocked = LeyShardFloorTileHandler.isUnlocked(player),
		leyShard = data.leyShard or 0,
		astralShard = data.astralShard or 0,
		tiles = tiles,
	}
end

-- Called every WorldBuilder proximity-check tick for whichever player is
-- standing on tile `tileId` - returns true only on the tick it actually
-- buys it, false on every no-op tick (not unlocked, already bought, or
-- unaffordable), same convention as UpgradeTreeHandler.buyTile.
function LeyShardFloorTileHandler.buyTile(player: Player, tileId: number): boolean
	local data = PlayerData.get(player)
	if not data then
		return false
	end

	if not LeyShardFloorTileHandler.isTileReachable(player, tileId) then
		return false
	end

	local tile = TILES[tileId]
	if not tile then
		return false
	end

	if data[tile.fieldName] then
		return false
	end

	if (data[tile.currency] or 0) < tile.cost then
		return false
	end

	data[tile.currency] -= tile.cost
	data[tile.fieldName] = true
	return true
end

return LeyShardFloorTileHandler
