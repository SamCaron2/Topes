-- Server-authoritative permanent-perk hooks for Robux gamepasses
-- (GameConfig.GamePasses) and the Starter Pack (GameConfig.StarterPack,
-- which is really just another one-time pass under the hood - see that
-- table's own comment). Same "one small handler per boost source, fold
-- every owner's contribution together" convention as every other
-- multiplier module in this game (UpgradeTreeHandler, WizardTierHandler,
-- RuneCollectionHandler, LeyShardFloorTileHandler, ...) - added per
-- direct request to implement a real Robux store ("can I have you
-- implement our store? ... I want a game pass, also smaller micro
-- transactions, a starter pack").
--
-- Reads each grant value straight out of GameConfig instead of
-- hardcoding multipliers here a second time, so tuning a pass's price or
-- effect in GameConfig.lua is the only place that ever needs to change.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Modules.GameConfig)
local PlayerData = require(script.Parent.PlayerData)

local GamePassBoostHandler = {}

-- Every one-time Robux grant in the game, gamepasses and the Starter Pack
-- alike - StoreHandler grants from this exact same list, so there's only
-- ever one place a pass's key/grants can be defined.
local ALL_PASSES = {}
for _, pass in GameConfig.GamePasses do
	table.insert(ALL_PASSES, pass)
end
table.insert(ALL_PASSES, GameConfig.StarterPack)

-- Multiplies together every owned pass's value for one named grant field
-- (e.g. "manaMultiplier") - a pass that doesn't grant that field simply
-- doesn't contribute, same shape as LeyShardFloorTileHandler's own
-- foldMultiplier.
local function foldMultiplierGrant(player: Player, fieldName: string): number
	local data = PlayerData.get(player)
	if not data then
		return 1
	end

	local multiplier = 1
	for _, pass in ALL_PASSES do
		if data.ownedPasses[pass.key] and pass.grants[fieldName] then
			multiplier *= pass.grants[fieldName]
		end
	end
	return multiplier
end

-- Read by ManaHandler as one more factor in its effective Mana yield -
-- VIPPass (1.25x), DoubleManaPass (2x), and the Starter Pack (1.1x) all
-- contribute here.
function GamePassBoostHandler.getManaMultiplier(player: Player): number
	return foldMultiplierGrant(player, "manaMultiplier")
end

-- Read by ArcaneDustHandler - VIPPass and the Starter Pack contribute.
function GamePassBoostHandler.getDustMultiplier(player: Player): number
	return foldMultiplierGrant(player, "dustMultiplier")
end

-- Read by EtherHandler - VIPPass and the Starter Pack contribute.
function GamePassBoostHandler.getEtherMultiplier(player: Player): number
	return foldMultiplierGrant(player, "etherMultiplier")
end

-- Read by LeyShardHandler - VIPPass and the Starter Pack contribute.
function GamePassBoostHandler.getLeyShardMultiplier(player: Player): number
	return foldMultiplierGrant(player, "leyShardMultiplier")
end

-- Read by RuneCollectionHandler as one more factor in its own combined
-- Rune-ownership multiplier - since that multiplier already cascades into
-- Mana/Rebirths/Arcane Dust/Ether/Ley Shard alike, FortunesFavorPass's 2x
-- here is deliberately the single most powerful (and correctly the most
-- expensive) grant in the whole store.
function GamePassBoostHandler.getRuneCollectionMultiplier(player: Player): number
	return foldMultiplierGrant(player, "runeCollectionMultiplier")
end

-- True once HeadStartPass or the Starter Pack is owned - read alongside
-- WizardTierHandler.hasAutoMana at the Main.server.lua auto-mana loop's
-- own call site, so either one (natural Tier 2 progress OR a Robux
-- purchase) turns passive Mana collection on.
function GamePassBoostHandler.hasEarlyAutoMana(player: Player): boolean
	local data = PlayerData.get(player)
	if not data then
		return false
	end

	for _, pass in ALL_PASSES do
		if data.ownedPasses[pass.key] and pass.grants.earlyAutoMana then
			return true
		end
	end
	return false
end

return GamePassBoostHandler
