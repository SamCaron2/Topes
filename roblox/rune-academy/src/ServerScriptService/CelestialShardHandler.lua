-- Card 3 of the wizard-material progression - Celestial Shard, unlocked
-- by EtherIsland's Tile 4 (LeyShardFloorTileHandler.isCelestialShardUnlocked,
-- 5,000,000 Astral Shard). Just the unlocked flag and a currency readout -
-- the actual conversion (CelestialShardConversionHandler) and the 3 real
-- upgrade columns (CelestialConversionBoostHandler/
-- CelestialAstralBoostHandler/CelestialManaBoostHandler) each live in
-- their own sibling handler files, same "one small module per column"
-- convention as every other board in this game.

local PlayerData = require(script.Parent.PlayerData)
local LeyShardFloorTileHandler = require(script.Parent.LeyShardFloorTileHandler)

local CelestialShardHandler = {}

function CelestialShardHandler.getState(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return nil
	end

	return {
		unlocked = LeyShardFloorTileHandler.isCelestialShardUnlocked(player),
		celestialShard = data.celestialShard or 0,
	}
end

return CelestialShardHandler
