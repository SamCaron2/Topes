-- Bootstraps RemoteEvents and wires client requests to the server-authoritative
-- handlers. Keep all currency/stat mutation behind these handlers - scripts
-- should never let a RemoteEvent write directly into PlayerData.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local PlayerData = require(script.Parent.PlayerData)
local ManaHandler = require(script.Parent.ManaHandler)
local ManaSpawnHandler = require(script.Parent.ManaSpawnHandler)
local WalkSpeedHandler = require(script.Parent.WalkSpeedHandler)
local CollectionRangeHandler = require(script.Parent.CollectionRangeHandler)
local RebirthHandler = require(script.Parent.RebirthHandler)
local RebirthShopHandler = require(script.Parent.RebirthShopHandler)
local XPHandler = require(script.Parent.XPHandler)
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
local getManaSpawnStateFunction = newRemoteFunction("GetManaSpawnState")
local buyManaSpawnUpgradeFunction = newRemoteFunction("BuyManaSpawnUpgrade")
local getWalkSpeedStateFunction = newRemoteFunction("GetWalkSpeedState")
local buyWalkSpeedUpgradeFunction = newRemoteFunction("BuyWalkSpeedUpgrade")
local getCollectionRangeStateFunction = newRemoteFunction("GetCollectionRangeState")
local buyCollectionRangeUpgradeFunction = newRemoteFunction("BuyCollectionRangeUpgrade")
local collectionRangeUpdatedEvent = newRemoteEvent("CollectionRangeUpdated") -- server -> client, fired on join and on every purchase
local getRebirthStateFunction = newRemoteFunction("GetRebirthState")
local performRebirthFunction = newRemoteFunction("PerformRebirth")
local rebirthsUpdatedEvent = newRemoteEvent("RebirthsUpdated") -- server -> client, fired on join and whenever Rebirths changes
local getManaValueMultiplierStateFunction = newRemoteFunction("GetManaValueMultiplierState")
local buyManaValueMultiplierFunction = newRemoteFunction("BuyManaValueMultiplier")
local getRebirthMultiplierStateFunction = newRemoteFunction("GetRebirthMultiplierState")
local buyRebirthMultiplierFunction = newRemoteFunction("BuyRebirthMultiplier")
local getXpMultiplierStateFunction = newRemoteFunction("GetXpMultiplierState")
local buyXpMultiplierFunction = newRemoteFunction("BuyXpMultiplier")
local playerRebirthedEvent = newRemoteEvent("PlayerRebirthed") -- server -> client, tells the Mana Upgrades board to re-fetch every column (levels reset)
local getXPStateFunction = newRemoteFunction("GetXPState")
local xpUpdatedEvent = newRemoteEvent("XPUpdated") -- server -> client, fired on join and every Mana pickup (XP/level bar)

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

buyManaYieldUpgradeFunction.OnServerInvoke = function(player, mode)
	if mode ~= nil and mode ~= "one" and mode ~= "max" then
		return false, "Invalid request"
	end
	local success, err, newState = ManaHandler.buyYieldUpgrade(player, mode)
	if success then
		manaUpdatedEvent:FireClient(player, newState.mana)
	end
	return success, err, newState
end

getManaSpawnStateFunction.OnServerInvoke = function(player)
	return ManaSpawnHandler.getUpgradeState(player)
end

buyManaSpawnUpgradeFunction.OnServerInvoke = function(player, mode)
	if mode ~= nil and mode ~= "one" and mode ~= "max" then
		return false, "Invalid request"
	end
	local success, err, newState = ManaSpawnHandler.buyUpgrade(player, mode)
	if success then
		manaUpdatedEvent:FireClient(player, newState.mana)
	end
	return success, err, newState
end

getWalkSpeedStateFunction.OnServerInvoke = function(player)
	return WalkSpeedHandler.getUpgradeState(player)
end

buyWalkSpeedUpgradeFunction.OnServerInvoke = function(player, mode)
	if mode ~= nil and mode ~= "one" and mode ~= "max" then
		return false, "Invalid request"
	end
	local success, err, newState = WalkSpeedHandler.buyUpgrade(player, mode)
	if success then
		manaUpdatedEvent:FireClient(player, newState.mana)
	end
	return success, err, newState
end

getCollectionRangeStateFunction.OnServerInvoke = function(player)
	return CollectionRangeHandler.getUpgradeState(player)
end

buyCollectionRangeUpgradeFunction.OnServerInvoke = function(player, mode)
	if mode ~= nil and mode ~= "one" and mode ~= "max" then
		return false, "Invalid request"
	end
	local success, err, newState = CollectionRangeHandler.buyUpgrade(player, mode)
	if success then
		manaUpdatedEvent:FireClient(player, newState.mana)
		collectionRangeUpdatedEvent:FireClient(player, newState.radius)
	end
	return success, err, newState
end

getRebirthStateFunction.OnServerInvoke = function(player)
	return RebirthHandler.getState(player)
end

performRebirthFunction.OnServerInvoke = function(player)
	local success, err, newState = RebirthHandler.rebirth(player)
	if success then
		manaUpdatedEvent:FireClient(player, newState.mana)
		rebirthsUpdatedEvent:FireClient(player, newState.rebirths)
		collectionRangeUpdatedEvent:FireClient(player, CollectionRangeHandler.getRadius(player))
		playerRebirthedEvent:FireClient(player)
	end
	return success, err, newState
end

getManaValueMultiplierStateFunction.OnServerInvoke = function(player)
	return RebirthShopHandler.getManaValueMultiplierState(player)
end

buyManaValueMultiplierFunction.OnServerInvoke = function(player, mode)
	if mode ~= nil and mode ~= "one" and mode ~= "max" then
		return false, "Invalid request"
	end
	local success, err, newState = RebirthShopHandler.buyManaValueMultiplier(player, mode)
	if success then
		rebirthsUpdatedEvent:FireClient(player, newState.rebirths)
	end
	return success, err, newState
end

getRebirthMultiplierStateFunction.OnServerInvoke = function(player)
	return RebirthShopHandler.getRebirthMultiplierState(player)
end

buyRebirthMultiplierFunction.OnServerInvoke = function(player, mode)
	if mode ~= nil and mode ~= "one" and mode ~= "max" then
		return false, "Invalid request"
	end
	local success, err, newState = RebirthShopHandler.buyRebirthMultiplier(player, mode)
	if success then
		rebirthsUpdatedEvent:FireClient(player, newState.rebirths)
	end
	return success, err, newState
end

getXpMultiplierStateFunction.OnServerInvoke = function(player)
	return RebirthShopHandler.getXpMultiplierState(player)
end

buyXpMultiplierFunction.OnServerInvoke = function(player, mode)
	if mode ~= nil and mode ~= "one" and mode ~= "max" then
		return false, "Invalid request"
	end
	local success, err, newState = RebirthShopHandler.buyXpMultiplier(player, mode)
	if success then
		rebirthsUpdatedEvent:FireClient(player, newState.rebirths)
	end
	return success, err, newState
end

getXPStateFunction.OnServerInvoke = function(player)
	return XPHandler.getState(player)
end

-- Touch PlayerData once so its PlayerAdded listener is guaranteed registered
-- before any player join events fire from this point on.
local _ = PlayerData

-- Sends the Mana HUD, feet-ring, and Rebirths HUD their starting values on
-- join (every pickup/purchase/rebirth after that comes from the same
-- events firing again). Rebirths only fires when the player already has
-- some - ManaHUDClient keeps that counter hidden until it sees a value
-- above 0, matching "only show it once Rebirths are unlocked."
Players.PlayerAdded:Connect(function(player)
	local data = PlayerData.waitForLoad(player)
	if data then
		manaUpdatedEvent:FireClient(player, data.mana or 0)
		collectionRangeUpdatedEvent:FireClient(player, CollectionRangeHandler.getRadius(player))
		xpUpdatedEvent:FireClient(player, XPHandler.getState(player))
		if (data.rebirths or 0) > 0 then
			rebirthsUpdatedEvent:FireClient(player, data.rebirths)
		end
	end
end)
