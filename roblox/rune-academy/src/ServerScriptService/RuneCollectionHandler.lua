-- Server-authoritative permanent bonus from OWNING Rune ranks, on top of
-- and separate from the existing per-pull Stat boosts in
-- GameConfig.RuneRanks - per direct request ("everytime you get something
-- like for example everytime you get apprentice you get .2x mana until
-- it gets to 5x and it tells you that too"). Each of the 9 ranks grants
-- its OWN +0.2x per copy currently owned (data.runesOwned[rankName],
-- already tracked by RuneHandler for every pull/collect), capped at a
-- flat x5 contribution from that one rank alone; every rank's own
-- multiplier then combines multiplicatively with every other rank's, same
-- "multiply every source together" convention as every other multiplier
-- chain in this game (WizardTier * UpgradeTree * RebirthShop * ManaBoost *
-- ...). Originally Mana-only; per direct follow-up request ("have it
-- multiply other stuff too like rebirths, ether and dust please") this one
-- combined multiplier (`getMultiplier`) is now also folded into
-- RebirthHandler, EtherHandler, and ArcaneDustHandler.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Modules.GameConfig)
local PlayerData = require(script.Parent.PlayerData)
local GamePassBoostHandler = require(script.Parent.GamePassBoostHandler)

local PER_COPY_BONUS = 0.2
local RANK_CAP_MULTIPLIER = 5

local RuneCollectionHandler = {}

-- Owning 0 of a rank contributes a plain 1x (no bonus, no penalty) -
-- everything scales up from there as copies come in, same idea as every
-- other "level 1 = base rate" curve in this game.
function RuneCollectionHandler.getRankMultiplier(player: Player, rankName: string): number
	local data = PlayerData.get(player)
	if not data or not data.runesOwned then
		return 1
	end

	local owned = data.runesOwned[rankName] or 0
	return math.min(1 + owned * PER_COPY_BONUS, RANK_CAP_MULTIPLIER)
end

-- Combined bonus from every rank owned - applied to Mana (ManaHandler),
-- Rebirths (RebirthHandler), Ether (EtherHandler), Arcane Dust
-- (ArcaneDustHandler), and Ley Shard (LeyShardHandler) alike, per direct
-- request. Also folds in GamePassBoostHandler's own Rune-focused gamepass
-- bonus (FortunesFavorPass) - since this one combined multiplier already
-- cascades into 5 different currencies, that pass's payoff compounds
-- across the whole economy, same reasoning as everything else it grants.
function RuneCollectionHandler.getMultiplier(player: Player): number
	local multiplier = GamePassBoostHandler.getRuneCollectionMultiplier(player)
	for _, rank in GameConfig.RuneRanks do
		multiplier *= RuneCollectionHandler.getRankMultiplier(player, rank.name)
	end
	return multiplier
end

-- For the info card floating above the Rune Altar (RuneOddsCardClient):
-- every rank's name, odds, how many are currently owned, and its
-- current/max multiplier, in GameConfig.RuneRanks' own order - "and it
-- tells you that too."
function RuneCollectionHandler.getState(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return nil
	end

	local ranks = {}
	for i, rank in GameConfig.RuneRanks do
		ranks[i] = {
			name = rank.name,
			oddsOneIn = rank.oddsOneIn,
			owned = (data.runesOwned and data.runesOwned[rank.name]) or 0,
			multiplier = RuneCollectionHandler.getRankMultiplier(player, rank.name),
			maxMultiplier = RANK_CAP_MULTIPLIER,
		}
	end

	return {
		ranks = ranks,
		totalMultiplier = RuneCollectionHandler.getMultiplier(player),
	}
end

return RuneCollectionHandler
