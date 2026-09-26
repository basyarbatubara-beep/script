-- KickControl installer (single-file bundle).
-- HOW TO USE: paste this entire file into the Roblox Studio command bar and run it once.
-- It creates or updates both scripts:
--   ServerScriptService/KickAllPlayers   (Script)      - owner-only Start/Stop kicker + kick counter + kick history
--   StarterPlayerScripts/KickControlUI   (LocalScript) - control panel + IOCASO chip (owner sees it)
-- Re-running is safe: it updates in place and never duplicates.
-- Works in any game: open the place, paste, run.

local SERVER_SOURCE = [==[-- KickAllPlayers: controlled kicker with Start/Stop, a kick counter, and a kick history.
-- Control is owner-only. Control objects are created at runtime so this
-- script stays portable: drop it into any game's ServerScriptService.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local OWNER_USER_ID = 10954395796
local HISTORY_LIMIT = 5

local state = {
	enabled = false,
	count = 0,
	history = {},
}

local function ensure(parent, className, name)
	local existing = parent:FindFirstChild(name)
	if existing then
		return existing
	end
	local created = Instance.new(className)
	created.Name = name
	created.Parent = parent
	return created
end

local controlFolder = ensure(ReplicatedStorage, "Folder", "KickControl")
local toggleEvent = ensure(controlFolder, "RemoteEvent", "ToggleEvent")
local stateEvent = ensure(controlFolder, "RemoteEvent", "StateEvent")
local requestState = ensure(controlFolder, "RemoteEvent", "RequestState")
local adminFunction = ensure(ServerStorage, "BindableFunction", "KickControlAdmin")

local function broadcast()
	stateEvent:FireAllClients(state.enabled, state.count, state.history)
end

local function addHistory(player)
	table.insert(state.history, 1, {
		name = player.Name,
		userId = player.UserId,
		time = os.time(),
	})
	while #state.history > HISTORY_LIMIT do
		table.remove(state.history)
	end
end

local function kickIfEligible(player)
	if not state.enabled or player.UserId == OWNER_USER_ID then
		return false
	end
	state.count += 1
	player:Kick()
	addHistory(player)
	print("[KickAllPlayers] Kicked: " .. player.Name .. " (" .. player.UserId .. ") [total: " .. state.count .. "]")
	return true
end

local function applyAction(action)
	if action == "start" then
		state.enabled = true
	elseif action == "stop" then
		state.enabled = false
	elseif action == "clearhistory" then
		state.history = {}
		broadcast()
		return state.enabled, state.count
	elseif action == "status" then
		return state.enabled, state.count
	elseif action == "history" then
		return state.enabled, state.count, state.history
	else
		warn("[KickAllPlayers] Unknown action: " .. tostring(action))
		return state.enabled, state.count
	end

	if state.enabled then
		for _, player in Players:GetPlayers() do
			kickIfEligible(player)
		end
	end

	broadcast()
	print("[KickAllPlayers] Kicking " .. (state.enabled and "ON" or "OFF") .. " [total: " .. state.count .. "]")
	return state.enabled, state.count
end

toggleEvent.OnServerEvent:Connect(function(player, action)
	if player.UserId ~= OWNER_USER_ID then
		warn("[KickAllPlayers] Rejected toggle from " .. player.Name .. " (" .. player.UserId .. ")")
		return
	end
	applyAction(action)
end)

requestState.OnServerEvent:Connect(function(player)
	stateEvent:FireClient(player, state.enabled, state.count, state.history)
end)

adminFunction.OnInvoke = function(action)
	return applyAction(action)
end

Players.PlayerAdded:Connect(kickIfEligible)

for _, player in Players:GetPlayers() do
	kickIfEligible(player)
end
]==]

local CLIENT_SOURCE = [==[-- KickControlUI: Start/Stop panel with a kick counter and recent-kick history (owner-only).
-- Minimize and close collapse the panel to an IOCASO chip; click the chip to reopen.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local OWNER_USER_ID = 10954395796
local HISTORY_ROWS = 5

local player = Players.LocalPlayer

-- Published game: only the owner sees the panel. In Studio: shown on all clients for testing.
if player.UserId ~= OWNER_USER_ID and not RunService:IsStudio() then
	return
end

local controlFolder = ReplicatedStorage:WaitForChild("KickControl", 30)
if not controlFolder then
	return
end

local toggleEvent = controlFolder:WaitForChild("ToggleEvent", 30)
local stateEvent = controlFolder:WaitForChild("StateEvent", 30)
local requestState = controlFolder:WaitForChild("RequestState", 30)
if not toggleEvent or not stateEvent or not requestState then
	return
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "KickControlUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local PANEL_COLOR = Color3.fromRGB(28, 28, 32)
local ON_COLOR = Color3.fromRGB(255, 90, 90)
local OFF_COLOR = Color3.fromRGB(90, 220, 130)
local ACCENT_COLOR = Color3.fromRGB(90, 180, 255)
local DIM_COLOR = Color3.fromRGB(150, 150, 160)

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(1, 0)
panel.Position = UDim2.new(1, -12, 0, 12)
panel.Size = UDim2.new(0, 240, 0, 282)
panel.BackgroundColor3 = PANEL_COLOR
panel.BorderSizePixel = 0
panel.Parent = screenGui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 8)
panelCorner.Parent = panel

local title = Instance.new("TextLabel")
title.Name = "Title"
title.BackgroundTransparency = 1
title.Position = UDim2.new(0, 12, 0, 6)
title.Size = UDim2.new(1, -118, 0, 24)
title.Font = Enum.Font.GothamBold
title.Text = "KICK CONTROL"
title.TextColor3 = Color3.fromRGB(240, 240, 240)
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = panel

local clearButton = Instance.new("TextButton")
clearButton.Name = "ClearButton"
clearButton.AnchorPoint = Vector2.new(1, 0)
clearButton.Position = UDim2.new(1, -68, 0, 6)
clearButton.Size = UDim2.new(0, 24, 0, 24)
clearButton.BackgroundColor3 = Color3.fromRGB(50, 50, 56)
clearButton.BorderSizePixel = 0
clearButton.Font = Enum.Font.GothamBold
clearButton.Text = "CLR"
clearButton.TextColor3 = Color3.fromRGB(220, 220, 220)
clearButton.TextSize = 10
clearButton.Parent = panel

local clearCorner = Instance.new("UICorner")
clearCorner.CornerRadius = UDim.new(0, 6)
clearCorner.Parent = clearButton

local minimizeButton = Instance.new("TextButton")
minimizeButton.Name = "MinimizeButton"
minimizeButton.AnchorPoint = Vector2.new(1, 0)
minimizeButton.Position = UDim2.new(1, -38, 0, 6)
minimizeButton.Size = UDim2.new(0, 24, 0, 24)
minimizeButton.BackgroundColor3 = Color3.fromRGB(50, 50, 56)
minimizeButton.BorderSizePixel = 0
minimizeButton.Font = Enum.Font.GothamBold
minimizeButton.Text = "—"
minimizeButton.TextColor3 = Color3.fromRGB(220, 220, 220)
minimizeButton.TextSize = 14
minimizeButton.Parent = panel

local minimizeCorner = Instance.new("UICorner")
minimizeCorner.CornerRadius = UDim.new(0, 6)
minimizeCorner.Parent = minimizeButton

local closeButton = Instance.new("TextButton")
closeButton.Name = "CloseButton"
closeButton.AnchorPoint = Vector2.new(1, 0)
closeButton.Position = UDim2.new(1, -8, 0, 6)
closeButton.Size = UDim2.new(0, 24, 0, 24)
closeButton.BackgroundColor3 = Color3.fromRGB(50, 50, 56)
closeButton.BorderSizePixel = 0
closeButton.Font = Enum.Font.GothamBold
closeButton.Text = "X"
closeButton.TextColor3 = Color3.fromRGB(220, 220, 220)
closeButton.TextSize = 14
closeButton.Parent = panel

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 6)
closeCorner.Parent = closeButton

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "StatusLabel"
statusLabel.BackgroundTransparency = 1
statusLabel.Position = UDim2.new(0, 12, 0, 40)
statusLabel.Size = UDim2.new(1, -24, 0, 20)
statusLabel.Font = Enum.Font.Gotham
statusLabel.Text = "Status: OFF"
statusLabel.TextColor3 = OFF_COLOR
statusLabel.TextSize = 14
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = panel

local counterLabel = Instance.new("TextLabel")
counterLabel.Name = "CounterLabel"
counterLabel.BackgroundTransparency = 1
counterLabel.Position = UDim2.new(0, 12, 0, 62)
counterLabel.Size = UDim2.new(1, -24, 0, 20)
counterLabel.Font = Enum.Font.Gotham
counterLabel.Text = "Kicked: 0"
counterLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
counterLabel.TextSize = 14
counterLabel.TextXAlignment = Enum.TextXAlignment.Left
counterLabel.Parent = panel

local historyHeader = Instance.new("TextLabel")
historyHeader.Name = "HistoryHeader"
historyHeader.BackgroundTransparency = 1
historyHeader.Position = UDim2.new(0, 12, 0, 92)
historyHeader.Size = UDim2.new(1, -24, 0, 16)
historyHeader.Font = Enum.Font.GothamBold
historyHeader.Text = "RECENT KICKS"
historyHeader.TextColor3 = DIM_COLOR
historyHeader.TextSize = 11
historyHeader.TextXAlignment = Enum.TextXAlignment.Left
historyHeader.Parent = panel

local historyNameLabels = {}
local historyTimeLabels = {}

for i = 1, HISTORY_ROWS do
	local rowY = 110 + (i - 1) * 25

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "HistoryName" .. i
	nameLabel.BackgroundTransparency = 1
	nameLabel.Position = UDim2.new(0, 12, 0, rowY)
	nameLabel.Size = UDim2.new(1, -104, 0, 22)
	nameLabel.Font = Enum.Font.Gotham
	nameLabel.Text = ""
	nameLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
	nameLabel.TextSize = 12
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.Visible = false
	nameLabel.Parent = panel
	historyNameLabels[i] = nameLabel

	local timeLabel = Instance.new("TextLabel")
	timeLabel.Name = "HistoryTime" .. i
	timeLabel.BackgroundTransparency = 1
	timeLabel.AnchorPoint = Vector2.new(1, 0)
	timeLabel.Position = UDim2.new(1, -12, 0, rowY)
	timeLabel.Size = UDim2.new(0, 84, 0, 22)
	timeLabel.Font = Enum.Font.Gotham
	timeLabel.Text = ""
	timeLabel.TextColor3 = DIM_COLOR
	timeLabel.TextSize = 12
	timeLabel.TextXAlignment = Enum.TextXAlignment.Right
	timeLabel.Visible = false
	timeLabel.Parent = panel
	historyTimeLabels[i] = timeLabel
end

local emptyLabel = Instance.new("TextLabel")
emptyLabel.Name = "HistoryEmpty"
emptyLabel.BackgroundTransparency = 1
emptyLabel.Position = UDim2.new(0, 12, 0, 112)
emptyLabel.Size = UDim2.new(1, -24, 0, 22)
emptyLabel.Font = Enum.Font.Gotham
emptyLabel.Text = "No kicks yet"
emptyLabel.TextColor3 = Color3.fromRGB(120, 120, 130)
emptyLabel.TextSize = 12
emptyLabel.TextXAlignment = Enum.TextXAlignment.Left
emptyLabel.Parent = panel

local startButton = Instance.new("TextButton")
startButton.Name = "StartButton"
startButton.Position = UDim2.new(0, 12, 1, -46)
startButton.Size = UDim2.new(0, 96, 0, 34)
startButton.BackgroundColor3 = Color3.fromRGB(40, 120, 60)
startButton.BorderSizePixel = 0
startButton.Font = Enum.Font.GothamBold
startButton.Text = "START"
startButton.TextColor3 = Color3.fromRGB(255, 255, 255)
startButton.TextSize = 14
startButton.Parent = panel

local startCorner = Instance.new("UICorner")
startCorner.CornerRadius = UDim.new(0, 6)
startCorner.Parent = startButton

local stopButton = Instance.new("TextButton")
stopButton.Name = "StopButton"
stopButton.AnchorPoint = Vector2.new(1, 0)
stopButton.Position = UDim2.new(1, -12, 1, -46)
stopButton.Size = UDim2.new(0, 96, 0, 34)
stopButton.BackgroundColor3 = Color3.fromRGB(120, 40, 40)
stopButton.BorderSizePixel = 0
stopButton.Font = Enum.Font.GothamBold
stopButton.Text = "STOP"
stopButton.TextColor3 = Color3.fromRGB(255, 255, 255)
stopButton.TextSize = 14
stopButton.Parent = panel

local stopCorner = Instance.new("UICorner")
stopCorner.CornerRadius = UDim.new(0, 6)
stopCorner.Parent = stopButton

local chip = Instance.new("TextButton")
chip.Name = "Chip"
chip.AnchorPoint = Vector2.new(1, 0)
chip.Position = UDim2.new(1, -12, 0, 12)
chip.Size = UDim2.new(0, 96, 0, 32)
chip.BackgroundColor3 = PANEL_COLOR
chip.BorderSizePixel = 0
chip.Font = Enum.Font.GothamBold
chip.Text = "IOCASO"
chip.TextColor3 = ACCENT_COLOR
chip.TextSize = 16
chip.Visible = false
chip.Parent = screenGui

local chipCorner = Instance.new("UICorner")
chipCorner.CornerRadius = UDim.new(0, 8)
chipCorner.Parent = chip

local function renderHistory(history)
	history = history or {}
	for i = 1, HISTORY_ROWS do
		local entry = history[i]
		local nameLabel = historyNameLabels[i]
		local timeLabel = historyTimeLabels[i]
		if entry then
			nameLabel.Text = tostring(entry.name) .. " (" .. tostring(entry.userId) .. ")"
			local ok, formatted = pcall(os.date, "%H:%M:%S", entry.time)
			timeLabel.Text = ok and formatted or ""
			nameLabel.Visible = true
			timeLabel.Visible = true
		else
			nameLabel.Visible = false
			timeLabel.Visible = false
		end
	end
	emptyLabel.Visible = #history == 0
end

local function showPanel()
	panel.Visible = true
	chip.Visible = false
end

local function showChip()
	panel.Visible = false
	chip.Visible = true
end

minimizeButton.Activated:Connect(showChip)
closeButton.Activated:Connect(showChip)
chip.Activated:Connect(showPanel)

startButton.Activated:Connect(function()
	toggleEvent:FireServer("start")
end)

stopButton.Activated:Connect(function()
	toggleEvent:FireServer("stop")
end)

clearButton.Activated:Connect(function()
	toggleEvent:FireServer("clearhistory")
end)

stateEvent.OnClientEvent:Connect(function(enabled, count, history)
	statusLabel.Text = "Status: " .. (enabled and "ON" or "OFF")
	statusLabel.TextColor3 = enabled and ON_COLOR or OFF_COLOR
	counterLabel.Text = "Kicked: " .. tostring(count)
	renderHistory(history)
end)

requestState:FireServer()
]==]

local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayerScripts = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")

local function install(parent, className, name, source)
	local existing = parent:FindFirstChild(name)
	if existing and existing.ClassName ~= className then
		existing:Destroy()
		existing = nil
	end
	local target = existing or Instance.new(className)
	target.Name = name
	target.Source = source
	pcall(function()
		target.Enabled = true
	end)
	target.Parent = parent
	return target
end

install(ServerScriptService, "Script", "KickAllPlayers", SERVER_SOURCE)
install(StarterPlayerScripts, "LocalScript", "KickControlUI", CLIENT_SOURCE)

print("[KickControl] Installed KickAllPlayers (server) + KickControlUI (client).")