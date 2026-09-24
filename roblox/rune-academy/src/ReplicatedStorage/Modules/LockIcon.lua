-- Shared "🔒" padlock overlay for board/kiosk cards that are locked until
-- some later unlock condition - per direct request ("Make sure all cards
-- are locked with a locked emoji on them until you unlock them"). Every
-- gated board's own client used to just build nothing at all while
-- locked (leaving a bare, blank Part with no explanation - the precedent
-- comment behind that was "keep the cards so people see there is stuff
-- on the island but the text on them does not appear until you unlock").
-- Now each of those boards shows THIS immediately, on the same face its
-- real content will use, then destroys it and builds the real board once
-- its own unlock check passes - so a locked card now reads as "locked",
-- not "broken/empty".

local LockIcon = {}

function LockIcon.show(board: BasePart, face: Enum.NormalId): SurfaceGui
	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Name = "LockedIconGui"
	surfaceGui.Face = face
	surfaceGui.Adornee = board
	surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surfaceGui.PixelsPerStud = 36
	surfaceGui.Parent = board

	local background = Instance.new("Frame")
	background.Size = UDim2.new(1, 0, 1, 0)
	background.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
	background.BackgroundTransparency = 0.35
	background.BorderSizePixel = 0
	background.Parent = surfaceGui

	local lockLabel = Instance.new("TextLabel")
	lockLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	lockLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
	lockLabel.Size = UDim2.new(0.4, 0, 0.4, 0)
	lockLabel.BackgroundTransparency = 1
	lockLabel.Font = Enum.Font.GothamBold
	lockLabel.TextScaled = true
	lockLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	lockLabel.Text = "🔒"
	lockLabel.Parent = background

	return surfaceGui
end

return LockIcon
