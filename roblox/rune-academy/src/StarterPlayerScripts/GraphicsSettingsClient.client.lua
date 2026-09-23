-- Applies the "Reduce Effects" setting (SettingsClient) by turning every
-- decor PointLight on/off - currently just the glow mushrooms' caps
-- (WorldDecor.makeGlowMushroom), the only real-time lights this game has.
-- Purely a local rendering toggle (Enabled on an existing Instance), same
-- kind of per-player-only change already used throughout this game (gate
-- reveals, board transparency) - other players' games are unaffected.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClientSettings = require(ReplicatedStorage.Modules.ClientSettings)

-- Every folder WorldDecor.scatter can populate - checked by name rather
-- than required to exist, since EtherIsland/LeaderboardIsland build later
-- in WorldBuilder and might not have finished (or even started) yet.
local DECOR_FOLDER_NAMES = { "SecondIslandDecor", "EtherIslandDecor", "LeaderboardDecor" }

local function setDecorLightsEnabled(enabled: boolean)
	for _, folderName in DECOR_FOLDER_NAMES do
		local folder = Workspace:FindFirstChild(folderName)
		if folder then
			for _, light in folder:GetDescendants() do
				if light:IsA("PointLight") then
					light.Enabled = enabled
				end
			end
		end
	end
end

-- Decor folders are built once at server start and don't get torn down
-- and rebuilt afterward, so a plain "apply now" is enough - no need to
-- keep watching for new lights showing up later.
local function applyCurrentSetting()
	setDecorLightsEnabled(not ClientSettings.reducedEffects)
end

applyCurrentSetting()
ClientSettings.ReducedEffectsChanged.Event:Connect(applyCurrentSetting)
