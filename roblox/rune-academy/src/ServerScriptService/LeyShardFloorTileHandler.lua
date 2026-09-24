-- Server-authoritative floor tile upgrade(s) on EtherIsland, paid in Ley
-- Shard - same walk-over-to-buy mechanic as the SecondIsland Upgrade Tree
-- (UpgradeTreeHandler), just its own Ley-Shard-funded, EtherIsland-gated
-- set instead of Arcane-Dust-funded/Tier-3-gated. Per direct request
-- ("x107 z134 start a floor tile upgrade. Lets do for 1k ley shards
-- times your ley by 2") - Tile 1 costs 1,000 Ley Shard and permanently
-- doubles Ley Shard yield. A one-time purchase flag, not a level, so it
-- survives AstralShardConversionHandler.convert's reset just like every
-- other one-time-flag purchase in this game (only leyShardYieldLevel/
-- leyShardSpeedLevel/leyShardManaBoostLevel get wiped by that). Structured
-- as a TILES list (same shape as UpgradeTreeHandler.TILES, `requires`
-- included even though nothing needs it yet) so a second/third tile later
-- is just one more entry, no code changes.

local PlayerData = require(script.Parent.PlayerData)

local TILES = {
	{ id = 1, fieldName = "leyShardFloorTile1", cost = 1000, multiplier = 2, label = "Ley Shard x2", requires = {} },
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

-- Folds every bought tile's multiplier together (multiplicatively) - read
-- by LeyShardHandler as another factor in its own Ley Shard yield
-- multiplier chain.
function LeyShardFloorTileHandler.getMultiplier(player: Player): number
	local data = PlayerData.get(player)
	if not data then
		return 1
	end

	local multiplier = 1
	for _, tile in TILES do
		if data[tile.fieldName] then
			multiplier *= tile.multiplier
		end
	end
	return multiplier
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
			label = tile.label,
			reachable = LeyShardFloorTileHandler.isTileReachable(player, tile.id),
		}
	end

	return {
		unlocked = LeyShardFloorTileHandler.isUnlocked(player),
		leyShard = data.leyShard or 0,
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

	if (data.leyShard or 0) < tile.cost then
		return false
	end

	data.leyShard -= tile.cost
	data[tile.fieldName] = true
	return true
end

return LeyShardFloorTileHandler
