-- Generic engine every currency in every Zone runs on. Adding, removing, or
-- rebalancing a currency is a GameConfig.Zones edit, never a code change -
-- keep it that way; if a new mechanic needs code here, it needs a config
-- field here too, not a one-off branch for a specific currency's key.
--
-- Four layers per currency, all server-authoritative:
--   1. collect        - manual (click/stand) production, Power-scaled
--   2. upgrades        - 3 resettable multiplier slots
--   3. selfPrestige     - ordered {cost, multiplier} tiers, resets amount+upgrades, permanent multiplier
--   4. chainReset       - converts into the next currency once a threshold is hit, permanent bonus to that currency
-- Floor tiles are a separate, never-reset permanent multiplier per currency.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Modules.GameConfig)
local PlayerData = require(script.Parent.PlayerData)

local ResourceEngine = {}

local MAX_COLLECT_DISTANCE = 12
local COLLECT_DEBOUNCE_SECONDS = 0.2
local lastCollectAt = {} -- [player] = os.clock()

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

local function upgradeMultiplier(currency, state)
	local multiplier = 1
	for _, slot in currency.upgrades do
		local level = state.upgradeLevels[slot.id] or 0
		multiplier *= slot.multiplierPerLevel ^ level
	end
	return multiplier
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
		if tile.targetCurrency == currencyKey and zoneState.floorTiles[tile.key] then
			multiplier *= tile.multiplier
		end
	end
	return multiplier
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

	local now = os.clock()
	if lastCollectAt[player] and now - lastCollectAt[player] < COLLECT_DEBOUNCE_SECONDS then
		return false
	end
	lastCollectAt[player] = now

	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return false
	end

	if (rootPart.Position - part.Position).Magnitude > MAX_COLLECT_DISTANCE then
		return false
	end

	local state = getCurrencyState(data, zoneKey, currencyKey)
	local gained = ResourceEngine.getEffectiveRate(data, zoneKey, currencyKey, "manual")
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
	local level = state.upgradeLevels[slotId] or 0
	local spent = 0
	local levelsBought = 0

	while level < slot.maxLevel do
		local cost = upgradeCost(slot, level)
		if state.amount < cost then
			break
		end
		state.amount -= cost
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
	local intoState = getCurrencyState(data, zoneKey, intoKey)
	intoState.amount += conversions
	intoState.chainBonusMultiplier = (intoState.chainBonusMultiplier or 1) * currency.chainReset.intoStartMultiplier

	return true, conversions, intoKey
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
	if zoneState.floorTiles[tileKey] then
		return false, "Already purchased"
	end

	local costState = getCurrencyState(data, zoneKey, tile.costCurrency)
	if costState.amount < tile.cost then
		return false, "Requirement not met"
	end

	costState.amount -= tile.cost
	zoneState.floorTiles[tileKey] = true

	return true
end

return ResourceEngine
