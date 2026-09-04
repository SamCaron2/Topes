-- Bootstraps RemoteEvents and wires client requests to the server-authoritative
-- handlers. Keep all currency/stat mutation behind these handlers - scripts
-- should never let a RemoteEvent write directly into PlayerData.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerData = require(script.Parent.PlayerData)
local CollectionHandler = require(script.Parent.CollectionHandler)
local RuneHandler = require(script.Parent.RuneHandler)
local ResetHandler = require(script.Parent.ResetHandler)

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

local collectNodeEvent = newRemoteEvent("CollectNode")
local pullRuneFunction = newRemoteFunction("PullRune")
local resetTierFunction = newRemoteFunction("ResetTier")
local ascendFunction = newRemoteFunction("Ascend")
local runePulledEvent = newRemoteEvent("RunePulledBroadcast") -- feeds the live-feed UI

collectNodeEvent.OnServerEvent:Connect(function(player, node)
	CollectionHandler.collectNode(player, node)
end)

pullRuneFunction.OnServerInvoke = function(player)
	local rank, err = RuneHandler.pull(player)
	if rank then
		runePulledEvent:FireAllClients(player.Name, rank.name)
	end
	return rank, err
end

resetTierFunction.OnServerInvoke = function(player, tierName)
	return ResetHandler.resetTier(player, tierName)
end

ascendFunction.OnServerInvoke = function(player)
	return ResetHandler.ascend(player)
end

-- Touch PlayerData once so its PlayerAdded listener is guaranteed registered
-- before any player join events fire from this point on.
local _ = PlayerData
