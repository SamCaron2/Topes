-- Card 3 of the wizard-material progression - Celestial Shard, unlocked
-- by EtherIsland's Tile 4 (LeyShardFloorTileHandler.isCelestialShardUnlocked,
-- 5,000,000 Astral Shard). Per direct request ("For the time being it
-- wont have any upgrades"), this is deliberately just a placeholder shell
-- for now - no collection mechanic, no upgrade columns, just the unlocked
-- flag and a currency field sitting at 0 - same "build the card, wire the
-- mechanic later" precedent as Card 2's own board when it first went up
-- ("3 empty 'Coming Soon' slots, no real upgrade logic wired up yet").

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
