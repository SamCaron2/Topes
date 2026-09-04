-- Bootstraps RemoteEvents and wires client requests to the server-authoritative
-- handlers. Keep all currency/stat mutation behind these handlers - scripts
-- should never let a RemoteEvent write directly into PlayerData.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerData = require(script.Parent.PlayerData)
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
local buyFloorTileFunction = newRemoteFunction("BuyFloorTile") -- args: zoneKey, tileKey
local pullRuneFunction = newRemoteFunction("PullRune")
local ascendFunction = newRemoteFunction("Ascend")
local runePulledEvent = newRemoteEvent("RunePulledBroadcast") -- feeds the live-feed UI
local requestPurchaseEvent = newRemoteEvent("RequestPurchase")
local getProfileFunction = newRemoteFunction("GetProfile")
local equipTitleFunction = newRemoteFunction("EquipTitle")

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
		gold = data.zones.Academy.currencies.Gold.amount or 0,
		gems = data.gems or 0,
		playtimeSeconds = data.playtimeSeconds or 0,
		robuxSpent = data.robuxSpent or 0,
		unlockedTitles = data.unlockedTitles,
		equippedTitle = data.equippedTitle,
	}
end

equipTitleFunction.OnServerInvoke = function(player, key)
	if key ~= nil and type(key) ~= "string" then
		return false, "Invalid title key"
	end
	return TitleHandler.equipTitle(player, key)
end

-- Touch PlayerData once so its PlayerAdded listener is guaranteed registered
-- before any player join events fire from this point on.
local _ = PlayerData
