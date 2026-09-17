-- Bootstraps RemoteEvents and wires client requests to the server-authoritative
-- handlers. Keep all currency/stat mutation behind these handlers - scripts
-- should never let a RemoteEvent write directly into PlayerData.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local PlayerData = require(script.Parent.PlayerData)
local ManaHandler = require(script.Parent.ManaHandler)
local ResourceEngine = require(script.Parent.ResourceEngine)
local RuneHandler = require(script.Parent.RuneHandler)
local ResetHandler = require(script.Parent.ResetHandler)
local StoreHandler = require(script.Parent.StoreHandler) -- self-wires MarketplaceService on require
local TitleHandler = require(script.Parent.TitleHandler)

local remotesFolder = Instance.new("Folder")
remotesFolder.Name = "Remotes"
remotesFolder.Parent = ReplicatedStorage

local function newRemoteEvent(name: string): RemoteEvent
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotesFolder
	return remote
end

local function newRemoteFunction(name: string): RemoteFunction
	local remote = Instance.new("RemoteFunction")
	remote.Name = name
	remote.Parent = remotesFolder
	return remote
end

local collectNodeEvent = newRemoteEvent("CollectNode") -- args: zoneKey, currencyKey, part
local buyUpgradeFunction = newRemoteFunction("BuyUpgrade") -- args: zoneKey, currencyKey, slotId, mode ("one"|"max")
local selfPrestigeFunction = newRemoteFunction("SelfPrestige") -- args: zoneKey, currencyKey
local chainResetFunction = newRemoteFunction("ChainReset") -- args: zoneKey, currencyKey
local sellCurrencyFunction = newRemoteFunction("SellCurrency") -- args: zoneKey, currencyKey
local buyFloorTileFunction = newRemoteFunction("BuyFloorTile") -- args: zoneKey, tileKey
local pullRuneFunction = newRemoteFunction("PullRune")
local ascendFunction = newRemoteFunction("Ascend")
local runePulledEvent = newRemoteEvent("RunePulledBroadcast") -- feeds the live-feed UI
local requestPurchaseEvent = newRemoteEvent("RequestPurchase")
local getProfileFunction = newRemoteFunction("GetProfile")
local equipTitleFunction = newRemoteFunction("EquipTitle")
local getCurrencyStateFunction = newRemoteFunction("GetCurrencyState") -- args: zoneKey, currencyKey
local getFloorTilesFunction = newRemoteFunction("GetFloorTiles") -- args: zoneKey
local manaUpdatedEvent = newRemoteEvent("ManaUpdated") -- server -> client, fired on join and every pickup/purchase
local getManaYieldStateFunction = newRemoteFunction("GetManaYieldState")
local buyManaYieldUpgradeFunction = newRemoteFunction("BuyManaYieldUpgrade")

collectNodeEvent.OnServerEvent:Connect(function(player, zoneKey, currencyKey, part)
	if type(zoneKey) == "string" and type(currencyKey) == "string" then
		ResourceEngine.collect(player, zoneKey, currencyKey, part)
	end
end)

buyUpgradeFunction.OnServerInvoke = function(player, zoneKey, currencyKey, slotId, mode)
	if type(zoneKey) ~= "string" or type(currencyKey) ~= "string" or type(slotId) ~= "string" then
		return false, "Invalid request"
	end
	return ResourceEngine.buyUpgrade(player, zoneKey, currencyKey, slotId, mode)
end

selfPrestigeFunction.OnServerInvoke = function(player, zoneKey, currencyKey)
	if type(zoneKey) ~= "string" or type(currencyKey) ~= "string" then
		return false, "Invalid request"
	end
	return ResourceEngine.selfPrestige(player, zoneKey, currencyKey)
end

chainResetFunction.OnServerInvoke = function(player, zoneKey, currencyKey)
	if type(zoneKey) ~= "string" or type(currencyKey) ~= "string" then
		return false, "Invalid request"
	end
	return ResourceEngine.chainReset(player, zoneKey, currencyKey)
end

sellCurrencyFunction.OnServerInvoke = function(player, zoneKey, currencyKey)
	if type(zoneKey) ~= "string" or type(currencyKey) ~= "string" then
		return false, "Invalid request"
	end
	return ResourceEngine.sellCurrency(player, zoneKey, currencyKey)
end

buyFloorTileFunction.OnServerInvoke = function(player, zoneKey, tileKey)
	if type(zoneKey) ~= "string" or type(tileKey) ~= "string" then
		return false, "Invalid request"
	end
	return ResourceEngine.buyFloorTile(player, zoneKey, tileKey)
end

pullRuneFunction.OnServerInvoke = function(player)
	local rank, err = RuneHandler.pull(player)
	if rank then
		runePulledEvent:FireAllClients(player.Name, rank.name)
	end
	return rank, err
end

ascendFunction.OnServerInvoke = function(player)
	return ResetHandler.ascend(player)
end

requestPurchaseEvent.OnServerEvent:Connect(function(player, kind, key)
	if type(kind) == "string" and type(key) == "string" then
		StoreHandler.promptPurchase(player, kind, key)
	end
end)

-- Feeds the "Main" profile screen: account name/picture are drawn client-side
-- from the Player instance itself, everything else comes from here.
getProfileFunction.OnServerInvoke = function(player)
	local data = PlayerData.get(player)
	if not data then
		return nil
	end

	return {
		mana = data.mana or 0,
		gems = data.gems or 0,
		playtimeSeconds = data.playtimeSeconds or 0,
		robuxSpent = data.robuxSpent or 0,
		unlockedTitles = data.unlockedTitles,
		equippedTitle = data.equippedTitle,
		stats = data.stats, -- for the Rune Altar's "Your Boosts" board
		scrolls = data.scrolls,
		runesOpened = data.runesOpened,
		runesOwned = data.runesOwned,
	}
end

equipTitleFunction.OnServerInvoke = function(player, key)
	if key ~= nil and type(key) ~= "string" then
		return false, "Invalid title key"
	end
	return TitleHandler.equipTitle(player, key)
end

-- Read-only snapshot of one currency's state for the UI to render upgrade
-- levels/costs against. The live amount itself comes from the leaderstat
-- PlayerData already syncs - this is just what leaderstats doesn't cover.
getCurrencyStateFunction.OnServerInvoke = function(player, zoneKey, currencyKey)
	if type(zoneKey) ~= "string" or type(currencyKey) ~= "string" then
		return nil
	end

	local data = PlayerData.get(player)
	local zoneState = data and data.zones[zoneKey]
	local state = zoneState and zoneState.currencies[currencyKey]
	if not state then
		return nil
	end

	return {
		upgradeLevels = state.upgradeLevels,
		selfPrestigeTier = state.selfPrestigeTier,
	}
end

-- Read-only snapshot of a zone's floor tile levels, for the tiles' floating
-- labels to render level/cost/locked state against.
getFloorTilesFunction.OnServerInvoke = function(player, zoneKey)
	if type(zoneKey) ~= "string" then
		return nil
	end

	local data = PlayerData.get(player)
	local zoneState = data and data.zones[zoneKey]
	if not zoneState then
		return nil
	end

	return zoneState.floorTiles
end

getManaYieldStateFunction.OnServerInvoke = function(player)
	return ManaHandler.getYieldUpgradeState(player)
end

buyManaYieldUpgradeFunction.OnServerInvoke = function(player)
	local success, err, newState = ManaHandler.buyYieldUpgrade(player)
	if success then
		manaUpdatedEvent:FireClient(player, newState.mana)
	end
	return success, err, newState
end

-- Touch PlayerData once so its PlayerAdded listener is guaranteed registered
-- before any player join events fire from this point on.
local _ = PlayerData

-- Sends the Mana HUD its starting value on join (every pickup after that
-- comes from WorldBuilder's ManaNode Touched handler firing this same event).
Players.PlayerAdded:Connect(function(player)
	local data = PlayerData.waitForLoad(player)
	if data then
		manaUpdatedEvent:FireClient(player, data.mana or 0)
	end
end)
