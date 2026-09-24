-- Server-authoritative conversion from Ley Shard into Astral Shard (Card
-- 2's own material) - per direct request ("a card next to that where you
-- can convert your ley shards into that"). Astral Shard has no collection
-- mechanic of its own, purely obtained by spending Ley Shard here.
-- `convert` spends AS MANY 1,000-Ley-Shard units as currently affordable
-- in one press (my own call for this first pass, not specified), each
-- unit worth AstralShardConversionBoostHandler's own current multiplier's
-- worth of Astral Shard (1x base, climbing with its own "More Astral
-- Shards" upgrade) - per direct request ("Lets make it actually 1k ley
-- shards for astral"), lowered from an original 5,000.
--
-- Converting ALSO totally resets the Ley Shard board's own 3 levels back
-- to 1 - per direct request ("when you exchange them it totally resets
-- your ley shard upgrades all 3"). This is the deliberate "prestige"
-- trigger this whole 2-card system is built around: Card 2's own
-- upgrades (AstralShardLeyBoostHandler/AstralShardConversionBoostHandler,
-- paid in Astral Shard, NOT touched by this reset) are what make every
-- grind back up the Ley Shard board after this point faster than the
-- last - per direct request, "So to max out ley shards it takes a bit
-- but when you exchange for astral shards and buy more ley shards it
-- goes by quicker the second time." The Ley Shard balance itself is
-- zeroed outright too, not just docked the spent units, per a direct
-- follow-up report ("I noticed I have some left over") - a "total reset"
-- shouldn't leave a leftover sub-1,000 remainder sitting around.
--
-- Also folds in LeyShardFloorTileHandler's own "Astral Shard x2" floor
-- tile (Tile 3 on EtherIsland - a one-time purchase, not a level, so it's
-- permanent and separate from AstralShardConversionBoostHandler's own
-- leveled "More Astral Shards" upgrade), and Card 3's own "More Astral
-- Shard" upgrade (CelestialAstralBoostHandler, paid in Celestial Shard) -
-- per direct request, the whole point of Card 3's second upgrade column is
-- to make this exact conversion rate climb further, one prestige layer
-- deeper than AstralShardConversionBoostHandler's own leveled multiplier.

local PlayerData = require(script.Parent.PlayerData)
local AstralShardConversionBoostHandler = require(script.Parent.AstralShardConversionBoostHandler)
local LeyShardFloorTileHandler = require(script.Parent.LeyShardFloorTileHandler)
local CelestialAstralBoostHandler = require(script.Parent.CelestialAstralBoostHandler)

local LEY_SHARD_COST_PER_ASTRAL_SHARD = 1000

local AstralShardConversionHandler = {}

function AstralShardConversionHandler.getState(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return nil
	end

	local leyShard = data.leyShard or 0
	local units = math.floor(leyShard / LEY_SHARD_COST_PER_ASTRAL_SHARD)
	local astralPerUnit = AstralShardConversionBoostHandler.getMultiplier(player)
		* LeyShardFloorTileHandler.getAstralConversionMultiplier(player)
		* CelestialAstralBoostHandler.getMultiplier(player)
	return {
		leyShard = leyShard,
		astralShard = data.astralShard or 0,
		costPerAstralShard = LEY_SHARD_COST_PER_ASTRAL_SHARD,
		astralPerUnit = astralPerUnit,
		convertibleNow = math.floor(units * astralPerUnit),
	}
end

-- Lives physically on EtherIsland, right next to the Ley Shard board -
-- gate on etherIslandUnlocked directly here too, same defense-in-depth
-- reasoning as every other gated handler in this game.
function AstralShardConversionHandler.convert(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return false, "Not loaded"
	end
	if not data.etherIslandUnlocked then
		return false, "EtherIsland not unlocked"
	end

	local units = math.floor((data.leyShard or 0) / LEY_SHARD_COST_PER_ASTRAL_SHARD)
	if units < 1 then
		return false, "Not enough Ley Shard"
	end

	local astralGained = math.floor(
		units
			* AstralShardConversionBoostHandler.getMultiplier(player)
			* LeyShardFloorTileHandler.getAstralConversionMultiplier(player)
			* CelestialAstralBoostHandler.getMultiplier(player)
	)

	data.leyShard = 0
	data.astralShard = (data.astralShard or 0) + astralGained

	-- The reset this whole system is built around - see the file header.
	data.leyShardYieldLevel = 1
	data.leyShardSpeedLevel = 1
	data.leyShardManaBoostLevel = 1

	return true, nil, AstralShardConversionHandler.getState(player)
end

-- "Auto Ley Shard" (LeyShardFloorTileHandler.hasAutoLeyShard, Tile 5 on
-- EtherIsland's floor) - a periodic, no-cost version of `convert` above,
-- called by WorldBuilder's own background loop on its own timer rather
-- than a button press. Computes the SAME astralGained a manual convert
-- would (same units/multiplier math) but does NOT spend the Ley Shard
-- units OR reset the 3 Ley Shard board levels - per direct request ("that
-- will unlock Auto Ley shards where you auto collect instead of having to
-- levatate and also That in turn auto collects astra shards to while keep
-- the amount of ley shards you have... it auto collects and auto cashes
-- ley shards in for astra shards while keeping ley shards"). Since
-- nothing is ever spent, this is a straight ongoing bonus on top of
-- normal Ley Shard collection - WorldBuilder throttles how often this
-- fires (not every collect tick) so the free rate stays sane.
function AstralShardConversionHandler.autoConvertTick(player: Player): number?
	local data = PlayerData.get(player)
	if not data or not data.etherIslandUnlocked then
		return nil
	end

	local units = math.floor((data.leyShard or 0) / LEY_SHARD_COST_PER_ASTRAL_SHARD)
	if units < 1 then
		return nil
	end

	local astralGained = math.floor(
		units
			* AstralShardConversionBoostHandler.getMultiplier(player)
			* LeyShardFloorTileHandler.getAstralConversionMultiplier(player)
			* CelestialAstralBoostHandler.getMultiplier(player)
	)
	if astralGained < 1 then
		return nil
	end

	data.astralShard = (data.astralShard or 0) + astralGained
	return data.astralShard
end

return AstralShardConversionHandler
