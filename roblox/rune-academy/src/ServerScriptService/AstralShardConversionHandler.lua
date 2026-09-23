-- Server-authoritative conversion from Ley Shard into Astral Shard (Card
-- 2's own material) - per direct request ("a card next to that where you
-- can convert your ley shards into that... It cost 5k ley shards for this
-- one material. So there isnt a button or anything to get more of this
-- material" - Astral Shard has no collection mechanic of its own, purely
-- obtained by spending Ley Shard here). `convert` spends AS MANY as
-- currently affordable in one press rather than a fixed 1-per-click (my
-- own call for this first pass, not specified) - 5,000 Ley Shard per unit
-- would otherwise take many repeated clicks to spend down a large
-- balance.

local PlayerData = require(script.Parent.PlayerData)

local LEY_SHARD_COST_PER_ASTRAL_SHARD = 5000

local AstralShardConversionHandler = {}

function AstralShardConversionHandler.getState(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return nil
	end

	local leyShard = data.leyShard or 0
	return {
		leyShard = leyShard,
		astralShard = data.astralShard or 0,
		costPerAstralShard = LEY_SHARD_COST_PER_ASTRAL_SHARD,
		convertibleNow = math.floor(leyShard / LEY_SHARD_COST_PER_ASTRAL_SHARD),
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

	local convertible = math.floor((data.leyShard or 0) / LEY_SHARD_COST_PER_ASTRAL_SHARD)
	if convertible < 1 then
		return false, "Not enough Ley Shard"
	end

	data.leyShard -= convertible * LEY_SHARD_COST_PER_ASTRAL_SHARD
	data.astralShard = (data.astralShard or 0) + convertible

	return true, nil, AstralShardConversionHandler.getState(player)
end

return AstralShardConversionHandler
