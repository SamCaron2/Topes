-- Reveals the Ether Shroud, its mist decoration, platform, and upgrade
-- board LOCALLY for whichever players have actually unlocked Ether
-- (bought Tile 9) - every part in `Workspace.EtherArea` starts hidden and
-- non-collide server-side (shared world geometry, but different players
-- can be at different Upgrade Tree progress at once), so this flips
-- Transparency/CanCollide back on for that client only, same per-player
-- pattern as WizardRuinClient uses for the Fantasy Ruin. Each part's
-- revealed Transparency/CanCollide come from its own RevealTransparency/
-- RevealCanCollide attributes (set in WorldBuilder) instead of a flat 0/
-- true for everything - the board needs to end up "clear" like every
-- other board (0.7, glass), not fully opaque, and the mist needs to stay
-- translucent (0.55) and non-collide, not become a solid ball.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local getEtherUnlockedFunction = remotes:WaitForChild("GetEtherUnlocked")
local upgradeTreeTileBoughtEvent = remotes:WaitForChild("UpgradeTreeTileBought")

local etherAreaFolder = Workspace:WaitForChild("EtherArea")

local function revealEtherArea()
	for _, part in etherAreaFolder:GetChildren() do
		if part:IsA("BasePart") then
			part.Transparency = part:GetAttribute("RevealTransparency") or 0
			part.CanCollide = part:GetAttribute("RevealCanCollide") or false

			local label = part:FindFirstChild("EtherShroudLabel")
			if label then
				label.Enabled = true
			end
		end
	end
end

-- PlayerData might not be loaded yet the instant this script runs - retry
-- a few times rather than assuming "not unlocked," same guard
-- SecondIslandGateClient/WizardRuinClient use.
local RETRY_ATTEMPTS = 10
local RETRY_DELAY_SECONDS = 0.5

local function checkAndReveal()
	for _ = 1, RETRY_ATTEMPTS do
		local success, unlocked = pcall(function()
			return getEtherUnlockedFunction:InvokeServer()
		end)
		if success then
			if unlocked then
				revealEtherArea()
			end
			return
		end
		task.wait(RETRY_DELAY_SECONDS)
	end
end

checkAndReveal()

-- Fires on every Upgrade Tree tile purchase (Tile 9 included) - re-checking
-- is cheap and means buying Tile 9 reveals the Ether area immediately, no
-- rejoin needed.
upgradeTreeTileBoughtEvent.OnClientEvent:Connect(checkAndReveal)
