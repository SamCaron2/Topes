-- Generic engine every currency in every Zone runs on. Adding, removing, or
-- rebalancing a currency is a GameConfig.Zones edit, never a code change -
-- keep it that way; if a new mechanic needs code here, it needs a config
-- field here too, not a one-off branch for a specific currency's key.
--
-- Layers per currency, all server-authoritative (a currency uses whichever
-- of these its config declares - none are required):
--   1. collect        - click/stand production, Power-scaled. An upgrade
--                        slot with kind = "tickInterval" controls how often
--                        this can fire (a real duration, not a multiplier);
--                        kind = "yield" (the default) instead multiplies
--                        the amount granted per collect.
--   2. upgrades        - N resettable slots per currency (see kinds above,
--                        plus "sellRate" which boosts sellInto's rate
--                        instead of this currency's own production).
--                        Each slot's cost is normally in the currency's own
--                        amount, but can be a DIFFERENT currency via
--                        costCurrency (e.g. Mana's upgrades cost Coins).
--   3. selfPrestige     - ordered {cost, multiplier} tiers, resets amount+upgrades, permanent multiplier
--   4. chainReset       - converts into the next currency once a THRESHOLD is hit, resets this currency's upgrades, permanent bonus to that next currency
--   5. sellInto         - converts into another currency at an upgradeable
--                        rate, ANY amount ANY time (no threshold, no
--                        upgrade reset) - a different mechanic from
--                        chainReset, for currencies you cash out of
--                        continuously rather than accumulate-then-reset.
-- Floor tiles are a separate, never-reset permanent multiplier per currency.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Modules.GameConfig)
local PlayerData = require(script.Parent.PlayerData)
local FriendBoostHandler = require(script.Parent.FriendBoostHandler)

local ResourceEngine = {}

local MAX_COLLECT_DISTANCE = 12
local COLLECT_DEBOUNCE_SECONDS = 0.2 -- fallback for currencies with no tickInterval-kind upgrade slot
local lastCollectAt = {} -- [player] = { [currencyKey] = os.clock() } - per-currency, since tick interval varies by currency now

-- ============================================================================
-- Config lookups
-- ============================================================================

function ResourceEngine.findZone(zoneKey: string)
	for _, zone in GameConfig.Zones do
		if zone.key == zoneKey then
			return zone
		end
	end
	return nil
end

function ResourceEngine.findCurrency(zone, currencyKey: string)
	for _, currency in zone.currencies do
		if currency.key == currencyKey then
			return currency
		end
	end
	return nil
end

local function findUpgradeSlot(currency, slotId: string)
	for _, slot in currency.upgrades do
		if slot.id == slotId then
			return slot
		end
	end
	return nil
end

local function findFloorTile(zone, tileKey: string)
	for _, tile in zone.floorTiles do
		if tile.key == tileKey then
			return tile
		end
	end
	return nil
end

function ResourceEngine.isZoneUnlocked(data, zone): boolean
	local requirement = zone.unlockRequirement
	if not requirement then
		return true
	end
	if requirement.type == "ascensionCount" then
		return (data.ascensionCount or 0) >= requirement.value
	end
	return false
end

-- ============================================================================
-- Player state lookups (built by PlayerData.defaultData from GameConfig.Zones)
-- ============================================================================

local function getCurrencyState(data, zoneKey: string, currencyKey: string)
	local zoneState = data.zones[zoneKey]
	return zoneState and zoneState.currencies[currencyKey]
end

-- ============================================================================
-- Rate math
-- ============================================================================

-- Only "yield" slots (the default) contribute to production - "tickInterval"
-- and "sellRate" slots affect other things (see getCollectDebounceSeconds
-- and sellCurrency) and are deliberately excluded here.
local function upgradeMultiplier(currency, state)
	local multiplier = 1
	for _, slot in currency.upgrades do
		if (slot.kind or "yield") == "yield" then
			local level = state.upgradeLevels[slot.id] or 0
			multiplier *= slot.multiplierPerLevel ^ level
		end
	end
	return multiplier
end

-- A "tickInterval" slot reduces how often collect() can grant this currency
-- by a flat step per level (not multiplicative, since it's a real duration)
-- - e.g. 1.0s at level 0 down to 0.1s at max level. Currencies without one
-- just use the flat COLLECT_DEBOUNCE_SECONDS anti-spam floor.
local function getCollectDebounceSeconds(currency, state): number
	for _, slot in currency.upgrades do
		if slot.kind == "tickInterval" then
			local level = state.upgradeLevels[slot.id] or 0
			return slot.tickIntervalBase - (level * slot.tickIntervalStep)
		end
	end
	return COLLECT_DEBOUNCE_SECONDS
end

local function selfPrestigeMultiplier(currency, state)
	if not currency.selfPrestigeTiers then
		return 1
	end
	local multiplier = 1
	for i = 1, state.selfPrestigeTier do
		local tier = currency.selfPrestigeTiers[i]
		if tier then
			multiplier *= tier.multiplier
		end
	end
	return multiplier
end

local function floorTileMultiplier(zone, currencyKey: string, zoneState)
	local multiplier = 1
	for _, tile in zone.floorTiles do
		if tile.type == "boost" and tile.targetCurrency == currencyKey then
			local level = zoneState.floorTiles[tile.key] or 0
			multiplier *= tile.multiplierPerLevel ^ level
		end
	end
	return multiplier
end

-- +10%/friend currently in this server, only for currencies flagged
-- friendBoost = true (see GameConfig.FriendBoost).
local function friendMultiplier(player: Player, currency): number
	if not currency.friendBoost then
		return 1
	end
	local friendCount = math.min(FriendBoostHandler.getFriendCount(player), GameConfig.FriendBoost.maxFriends)
	return 1 + GameConfig.FriendBoost.perFriend * friendCount
end

-- source: "manual" (click/stand, player-initiated) uses Power; "auto"
-- (Familiar passive ticks) uses Focus. See GameConfig.Stats for why.
function ResourceEngine.getEffectiveRate(data, zoneKey: string, currencyKey: string, source: string): number
	local zone = ResourceEngine.findZone(zoneKey)
	local currency = zone and ResourceEngine.findCurrency(zone, currencyKey)
	local zoneState = data.zones[zoneKey]
	local state = zoneState and zoneState.currencies[currencyKey]
	if not currency or not state then
		return 0
	end

	local statMultiplier = if source == "auto" then (data.stats.Focus or 1) else (data.stats.Power or 1)

	return currency.baseRate
		* upgradeMultiplier(currency, state)
		* selfPrestigeMultiplier(currency, state)
		* (state.chainBonusMultiplier or 1)
		* floorTileMultiplier(zone, currencyKey, zoneState)
		* statMultiplier
end

-- ============================================================================
-- Collect (click/stand)
-- ============================================================================

function ResourceEngine.collect(player: Player, zoneKey: string, currencyKey: string, part: Instance)
	local data = PlayerData.get(player)
	local zone = ResourceEngine.findZone(zoneKey)
	local currency = zone and ResourceEngine.findCurrency(zone, currencyKey)
	if not data or not zone or not currency or not part or not part:IsA("BasePart") then
		return false
	end

	if currency.collectMode ~= "click" and currency.collectMode ~= "stand" then
		return false -- chainOnly currencies can't be collected directly
	end

	if not ResourceEngine.isZoneUnlocked(data, zone) then
		return false
	end

	local state = getCurrencyState(data, zoneKey, currencyKey)

	local now = os.clock()
	local requiredInterval = getCollectDebounceSeconds(currency, state)
	local playerDebounce = lastCollectAt[player]
	if playerDebounce and playerDebounce[currencyKey] and now - playerDebounce[currencyKey] < requiredInterval then
		return false
	end

	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return false
	end

	if (rootPart.Position - part.Position).Magnitude > MAX_COLLECT_DISTANCE then
		return false
	end

	playerDebounce = playerDebounce or {}
	playerDebounce[currencyKey] = now
	lastCollectAt[player] = playerDebounce

	local gained = ResourceEngine.getEffectiveRate(data, zoneKey, currencyKey, "manual") * friendMultiplier(player, currency)
	state.amount += gained

	return true, gained
end

game:GetService("Players").PlayerRemoving:Connect(function(player)
	lastCollectAt[player] = nil
end)

-- ============================================================================
-- Upgrades
-- ============================================================================

local function upgradeCost(slot, level: number): number
	return slot.baseCost * (slot.costGrowth ^ level)
end

-- mode: "one" buys a single level if affordable; "max" buys as many as
-- affordable up to maxLevel. Returns success, levelsBought, totalSpent.
function ResourceEngine.buyUpgrade(player: Player, zoneKey: string, currencyKey: string, slotId: string, mode: string)
	local data = PlayerData.get(player)
	local zone = ResourceEngine.findZone(zoneKey)
	local currency = zone and ResourceEngine.findCurrency(zone, currencyKey)
	local slot = currency and findUpgradeSlot(currency, slotId)
	if not data or not zone or not currency or not slot then
		return false, "Unknown upgrade"
	end
	if not ResourceEngine.isZoneUnlocked(data, zone) then
		return false, "Zone locked"
	end

	local state = getCurrencyState(data, zoneKey, currencyKey)
	local costState = getCurrencyState(data, zoneKey, slot.costCurrency or currencyKey)
	local level = state.upgradeLevels[slotId] or 0
	local spent = 0
	local levelsBought = 0

	while level < slot.maxLevel do
		local cost = upgradeCost(slot, level)
		if costState.amount < cost then
			break
		end
		costState.amount -= cost
		spent += cost
		level += 1
		levelsBought += 1
		if mode ~= "max" then
			break
		end
	end

	if levelsBought == 0 then
		return false, "Can't afford or maxed"
	end

	state.upgradeLevels[slotId] = level
	return true, levelsBought, spent
end

-- ============================================================================
-- Self-prestige (reset this currency into itself for a permanent multiplier)
-- ============================================================================

function ResourceEngine.selfPrestige(player: Player, zoneKey: string, currencyKey: string)
	local data = PlayerData.get(player)
	local zone = ResourceEngine.findZone(zoneKey)
	local currency = zone and ResourceEngine.findCurrency(zone, currencyKey)
	if not data or not zone or not currency or not currency.selfPrestigeTiers then
		return false, "Not available"
	end
	if not ResourceEngine.isZoneUnlocked(data, zone) then
		return false, "Zone locked"
	end

	local state = getCurrencyState(data, zoneKey, currencyKey)
	local nextTier = currency.selfPrestigeTiers[state.selfPrestigeTier + 1]
	if not nextTier then
		return false, "No further prestige tiers"
	end
	if state.amount < nextTier.cost then
		return false, "Requirement not met"
	end

	state.amount = 0
	for _, slot in currency.upgrades do
		state.upgradeLevels[slot.id] = 0
	end
	state.selfPrestigeTier += 1

	return true, nextTier
end

-- ============================================================================
-- Chain reset (convert into the next currency in the zone's chain)
-- ============================================================================

function ResourceEngine.chainReset(player: Player, zoneKey: string, currencyKey: string)
	local data = PlayerData.get(player)
	local zone = ResourceEngine.findZone(zoneKey)
	local currency = zone and ResourceEngine.findCurrency(zone, currencyKey)
	if not data or not zone or not currency or not currency.chainReset then
		return false, "Not available"
	end
	if not ResourceEngine.isZoneUnlocked(data, zone) then
		return false, "Zone locked"
	end

	local state = getCurrencyState(data, zoneKey, currencyKey)
	local requirement = currency.chainReset.requirement
	local conversions = math.floor(state.amount / requirement)
	if conversions < 1 then
		return false, "Requirement not met"
	end

	state.amount = 0
	for _, slot in currency.upgrades do
		state.upgradeLevels[slot.id] = 0
	end

	local intoKey = currency.chainReset.into
	local intoCurrency = ResourceEngine.findCurrency(zone, intoKey)
	local intoState = getCurrencyState(data, zoneKey, intoKey)
	local grantedAmount = conversions * friendMultiplier(player, intoCurrency)
	intoState.amount += grantedAmount
	intoState.chainBonusMultiplier = (intoState.chainBonusMultiplier or 1) * currency.chainReset.intoStartMultiplier

	if currency.chainReset.grantsScrolls then
		data.scrolls = (data.scrolls or 0) + currency.chainReset.grantsScrolls
	end

	return true, grantedAmount, intoKey
end

-- ============================================================================
-- Sell (convert into another currency at an upgradeable rate, ANY amount,
-- ANY time - no threshold. Deliberately a separate mechanic from
-- chainReset: chainReset requires hitting a threshold and resets the
-- source currency's upgrades on cash-in; sellInto converts whatever you're
-- currently holding and never resets upgrades, since those are meant to be
-- a permanent collection investment, not something cashing out punishes.
-- ============================================================================

function ResourceEngine.sellCurrency(player: Player, zoneKey: string, currencyKey: string)
	local data = PlayerData.get(player)
	local zone = ResourceEngine.findZone(zoneKey)
	local currency = zone and ResourceEngine.findCurrency(zone, currencyKey)
	if not data or not zone or not currency or not currency.sellInto then
		return false, "Not available"
	end
	if not ResourceEngine.isZoneUnlocked(data, zone) then
		return false, "Zone locked"
	end

	local state = getCurrencyState(data, zoneKey, currencyKey)
	if state.amount <= 0 then
		return false, "Nothing to sell"
	end

	local sellInto = currency.sellInto
	local rateSlot = sellInto.rateSlotId and findUpgradeSlot(currency, sellInto.rateSlotId)
	local rateLevel = rateSlot and (state.upgradeLevels[rateSlot.id] or 0) or 0
	local rateMultiplier = rateSlot and (rateSlot.multiplierPerLevel ^ rateLevel) or 1
	local rate = sellInto.baseRate * rateMultiplier

	local sold = state.amount
	local intoKey = sellInto.into
	local intoCurrency = ResourceEngine.findCurrency(zone, intoKey)
	local gained = sold * rate * friendMultiplier(player, intoCurrency)

	state.amount = 0

	local intoState = getCurrencyState(data, zoneKey, intoKey)
	intoState.amount += gained

	if sellInto.grantsScrolls then
		data.scrolls = (data.scrolls or 0) + sellInto.grantsScrolls
	end

	return true, gained, intoKey
end

-- ============================================================================
-- Floor tiles (permanent, never reset)
-- ============================================================================

function ResourceEngine.buyFloorTile(player: Player, zoneKey: string, tileKey: string)
	local data = PlayerData.get(player)
	local zone = ResourceEngine.findZone(zoneKey)
	local tile = zone and findFloorTile(zone, tileKey)
	if not data or not zone or not tile then
		return false, "Unknown tile"
	end
	if not ResourceEngine.isZoneUnlocked(data, zone) then
		return false, "Zone locked"
	end

	local zoneState = data.zones[zoneKey]
	local level = zoneState.floorTiles[tileKey] or 0
	if level >= tile.maxLevel then
		return false, "Maxed"
	end

	if tile.requiresTile then
		local requiredTile = findFloorTile(zone, tile.requiresTile)
		local requiredLevel = zoneState.floorTiles[tile.requiresTile] or 0
		if not requiredTile or requiredLevel < requiredTile.maxLevel then
			return false, "Locked"
		end
	end

	local cost = tile.baseCost * (tile.costGrowth ^ level)
	local costState = getCurrencyState(data, zoneKey, tile.costCurrency)
	if costState.amount < cost then
		return false, "Requirement not met"
	end

	costState.amount -= cost
	zoneState.floorTiles[tileKey] = level + 1

	return true, level + 1
end

return ResourceEngine
