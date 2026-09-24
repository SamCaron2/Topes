-- Server-authoritative conversion from Astral Shard into Celestial Shard
-- (Card 3's own material) - per direct request ("Okay time to do
-- celestial shard. It should cost 5 million astra shroud for 1
-- celestrial"). Celestial Shard has no collection mechanic of its own,
-- purely obtained by spending Astral Shard here - same shape as
-- AstralShardConversionHandler one tier down, just at a 5,000,000:1 base
-- rate instead of 1,000:1. `convert` spends AS MANY 5,000,000-Astral-Shard
-- units as currently affordable in one press (same "spend it all in one
-- press" call as the Ley->Astral conversion), each unit worth
-- CelestialConversionBoostHandler's own current multiplier's worth of
-- Celestial Shard (1x base, climbing with its own "More Celestial Shard"
-- upgrade).
--
-- Converting ALSO completely resets the Astral Shard board's own 2 real
-- upgrade levels back to 1 - per direct request ("hitting this converter
-- completely resets your astral shards") - the exact same "prestige"
-- trigger AstralShardConversionHandler.convert uses one tier down, just
-- applied to astralShardLeyBoostLevel/astralConversionBoostLevel instead
-- of the Ley Shard board's 3 levels. Card 3's own upgrades
-- (CelestialConversionBoostHandler/CelestialAstralBoostHandler/
-- CelestialManaBoostHandler, paid in Celestial Shard, NOT touched by this
-- reset) are what make every grind back up the Astral Shard board after
-- this point faster than the last, same "each layer's own upgrades speed
-- up the layer before it" philosophy. The Astral Shard balance itself is
-- zeroed outright too, not just docked the spent units - same "a total
-- reset shouldn't leave a leftover remainder" reasoning as the Ley->Astral
-- conversion.

local PlayerData = require(script.Parent.PlayerData)
local CelestialConversionBoostHandler = require(script.Parent.CelestialConversionBoostHandler)
local LeyShardFloorTileHandler = require(script.Parent.LeyShardFloorTileHandler)

local ASTRAL_SHARD_COST_PER_CELESTIAL_SHARD = 5000000

local CelestialShardConversionHandler = {}

function CelestialShardConversionHandler.getState(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return nil
	end

	local astralShard = data.astralShard or 0
	local units = math.floor(astralShard / ASTRAL_SHARD_COST_PER_CELESTIAL_SHARD)
	local celestialPerUnit = CelestialConversionBoostHandler.getMultiplier(player)
	return {
		astralShard = astralShard,
		celestialShard = data.celestialShard or 0,
		costPerCelestialShard = ASTRAL_SHARD_COST_PER_CELESTIAL_SHARD,
		celestialPerUnit = celestialPerUnit,
		convertibleNow = math.floor(units * celestialPerUnit),
	}
end

-- Lives physically on EtherIsland, right next to the Celestial Shard
-- board - gate on isCelestialShardUnlocked directly here too, same
-- defense-in-depth reasoning as every other gated handler.
function CelestialShardConversionHandler.convert(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return false, "Not loaded"
	end
	if not LeyShardFloorTileHandler.isCelestialShardUnlocked(player) then
		return false, "Celestial Shard not unlocked"
	end

	local units = math.floor((data.astralShard or 0) / ASTRAL_SHARD_COST_PER_CELESTIAL_SHARD)
	if units < 1 then
		return false, "Not enough Astral Shard"
	end

	local celestialGained = math.floor(units * CelestialConversionBoostHandler.getMultiplier(player))

	data.astralShard = 0
	data.celestialShard = (data.celestialShard or 0) + celestialGained

	-- The reset this whole system is built around - see the file header.
	data.astralShardLeyBoostLevel = 1
	data.astralConversionBoostLevel = 1

	return true, nil, CelestialShardConversionHandler.getState(player)
end

return CelestialShardConversionHandler
