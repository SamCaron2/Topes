-- Reveals the Fantasy Ruin (Tier 3's unlock) for players who've actually
-- reached Tier 3 - every part in `Workspace.FantasyRuin` starts hidden and
-- non-collide server-side (shared world geometry, but different players can
-- be at different Wizard Tiers at once), so this flips Transparency/
-- CanCollide back on LOCALLY, same per-player pattern as
-- SecondIslandGateClient uses for the SecondIsland gate - other players who
-- haven't reached Tier 3 still see/walk through empty space where the ruin
-- sits. Also reveals RuneAltarBoard (the Rune Altar's own upgrade board,
-- parented under Kiosks rather than FantasyRuin) via its own
-- RevealTransparency/RevealCanCollide attributes, same "clear glass"
-- treatment as every other board - it's gated on the same
-- hasUnlockedRuin check but isn't a child of `ruinFolder`, so the loop
-- below doesn't touch it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local getWizardTierStateFunction = remotes:WaitForChild("GetWizardTierState")
local playerWizardTieredEvent = remotes:WaitForChild("PlayerWizardTiered")

local ruinFolder = Workspace:WaitForChild("FantasyRuin")
local runeAltarBoard = Workspace:WaitForChild("Kiosks"):WaitForChild("RuneAltarBoard")

local function revealRuin()
	for _, part in ruinFolder:GetChildren() do
		if part:IsA("BasePart") then
			part.Transparency = 0
			part.CanCollide = true
		end
	end

	runeAltarBoard.Transparency = runeAltarBoard:GetAttribute("RevealTransparency") or 0
	runeAltarBoard.CanCollide = runeAltarBoard:GetAttribute("RevealCanCollide") or false
end

-- PlayerData might not be loaded yet the instant this script runs - retry a
-- few times rather than assuming "not unlocked" from an empty state, same
-- guard SecondIslandGateClient uses.
local RETRY_ATTEMPTS = 10
local RETRY_DELAY_SECONDS = 0.5

local function checkAndReveal()
	for _ = 1, RETRY_ATTEMPTS do
		local state = getWizardTierStateFunction:InvokeServer()
		if state then
			if state.unlockedRuin then
				revealRuin()
			end
			return
		end
		task.wait(RETRY_DELAY_SECONDS)
	end
end

checkAndReveal()

-- Fires on every Wizard Tier purchase (not just Tier 3's) - re-checking is
-- cheap and means reaching Tier 3 reveals the ruin immediately, no rejoin
-- needed.
playerWizardTieredEvent.OnClientEvent:Connect(checkAndReveal)
