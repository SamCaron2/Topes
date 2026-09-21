-- Server-authoritative Rebirth Shop: permanent upgrades bought with
-- Rebirths, NOT reset when you rebirth (unlike the Mana-side upgrades,
-- which DO reset - see RebirthHandler.rebirth) - that's the whole point,
-- so each rebirth run collects Mana faster than the last. Three columns:
--
--  - "Mana Value Multiplier": level 1-100, LINEAR 1x -> 200x, cost
--    currentLevel Rebirths (unchanged from when it was the only column).
--  - "Rebirth Multiplier": level 1-100, NON-linear (quadratic) 1x -> 50x,
--    scales how many Rebirths a rebirth actually grants (RebirthHandler).
--  - "XP Multiplier": level 1-25, NON-linear (quadratic) 1x -> 50x, scales
--    XP per pickup (XPHandler). Cost also non-linear per direct request -
--    "periodically cost more," not a flat per-level increase.
--
-- Rebirth Multiplier and XP Multiplier are deliberately NOT linear, unlike
-- Mana Value Multiplier: both their multiplier curves and cost curves use
-- power functions, so the step between consecutive levels keeps changing
-- instead of growing by the same fixed amount or ratio every time.

local PlayerData = require(script.Parent.PlayerData)

-- Builds get/buy functions for one multiplier upgrade from its config, so
-- the three columns above don't each duplicate the same get-state/buy-with-
-- max-mode logic.
local function makeMultiplierUpgrade(config)
	local function multiplierFor(player: Player): number
		local data = PlayerData.get(player)
		local level = (data and data[config.fieldName]) or 1
		return config.multiplierForLevel(level)
	end

	local function getState(player: Player)
		local data = PlayerData.get(player)
		if not data then
			return nil
		end

		local level = data[config.fieldName] or 1
		local maxed = level >= config.maxLevel
		return {
			level = level,
			maxLevel = config.maxLevel,
			multiplier = config.multiplierForLevel(level),
			nextMultiplier = not maxed and config.multiplierForLevel(level + 1) or nil,
			nextLevelCost = not maxed and config.costForLevel(level) or nil,
			rebirths = data.rebirths or 0,
		}
	end

	local function buy(player: Player, mode: string?)
		local data = PlayerData.get(player)
		if not data then
			return false, "Not loaded"
		end

		local level = data[config.fieldName] or 1
		if level >= config.maxLevel then
			return false, "Already at max level"
		end

		local cost = config.costForLevel(level)
		if (data.rebirths or 0) < cost then
			return false, "Not enough Rebirths"
		end

		data.rebirths -= cost
		level += 1

		if mode == "max" then
			while level < config.maxLevel and data.rebirths >= config.costForLevel(level) do
				data.rebirths -= config.costForLevel(level)
				level += 1
			end
		end

		data[config.fieldName] = level

		return true, nil, getState(player)
	end

	return multiplierFor, getState, buy
end

local RebirthShopHandler = {}

RebirthShopHandler.getManaValueMultiplier, RebirthShopHandler.getManaValueMultiplierState, RebirthShopHandler.buyManaValueMultiplier =
	makeMultiplierUpgrade({
		fieldName = "manaValueMultiplierLevel",
		maxLevel = 100,
		multiplierForLevel = function(level)
			return 1 + (200 - 1) * (level - 1) / 99
		end,
		costForLevel = function(currentLevel)
			return currentLevel
		end,
	})

RebirthShopHandler.getRebirthMultiplier, RebirthShopHandler.getRebirthMultiplierState, RebirthShopHandler.buyRebirthMultiplier =
	makeMultiplierUpgrade({
		fieldName = "rebirthMultiplierLevel",
		maxLevel = 100,
		multiplierForLevel = function(level)
			return 1 + 49 * ((level - 1) / 99) ^ 2
		end,
		costForLevel = function(currentLevel)
			return math.ceil(currentLevel ^ 1.5)
		end,
	})

RebirthShopHandler.getXpMultiplier, RebirthShopHandler.getXpMultiplierState, RebirthShopHandler.buyXpMultiplier = makeMultiplierUpgrade({
	fieldName = "xpMultiplierLevel",
	maxLevel = 25,
	multiplierForLevel = function(level)
		return 1 + 49 * ((level - 1) / 24) ^ 2
	end,
	costForLevel = function(currentLevel)
		return math.ceil(currentLevel ^ 1.6)
	end,
})

return RebirthShopHandler
