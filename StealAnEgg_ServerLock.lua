--[[
    ╔══════════════════════════════════════════════════════════════╗
    ║           STEAL AN EGG — SERVER LOCK v2.0                   ║
    ║                                                              ║
    ║  Makes your public server feel like a private server.        ║
    ║  Auto-removes anyone who joins (unless whitelisted).         ║
    ║                                                              ║
    ║  Methods:                                                    ║
    ║    1. Fling — collision-based physics launch                 ║
    ║    2. RemoteEvent scan — tries game remotes for kick        ║
    ║                                                              ║
    ║  Usage: Execute in your Roblox executor while in-game.      ║
    ╚══════════════════════════════════════════════════════════════╝
]]

-- ═══════════════════════════════════════
-- CONFIGURATION
-- ═══════════════════════════════════════

local CONFIG = {
    -- Add your friends' UserIds here so they don't get targeted
    -- Find UserId: go to their profile, the number in the URL is their UserId
    WhitelistUserIds = {
        -- 123456789,
        -- 987654321,
    },

    -- Also whitelist by username (less reliable since names can change)
    WhitelistNames = {
        -- "FriendName1",
    },

    -- Fling power — how hard to launch them (default works well)
    FlingPower = 9999,

    -- How often to re-fling targets that respawn (seconds)
    FlingInterval = 0.1,

    -- GUI toggle key
    ToggleKey = Enum.KeyCode.RightShift,

    -- Enable/disable individual methods
    UseFling = true,
    UseRemoteScan = true,

    -- Lock starts ON when script loads
    LockEnabled = true,
}

-- ═══════════════════════════════════════
-- SERVICES
-- ═══════════════════════════════════════

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer

-- ═══════════════════════════════════════
-- STATE
-- ═══════════════════════════════════════

local State = {
    LockEnabled = CONFIG.LockEnabled,
    FlingTargets = {},          -- [UserId] = true (actively being flung)
    CharAddedConns = {},        -- [UserId] = RBXScriptConnection
    KickRemotes = {},           -- list of {Remote, Name, Type}
    PlayersBlocked = 0,
    Running = true,
    GUI = nil,
    Connections = {},           -- all RBXScriptConnections for cleanup
}

-- helper to track connections
local function TrackConnection(conn)
    table.insert(State.Connections, conn)
    return conn
end

-- ═══════════════════════════════════════
-- UTILITY
-- ═══════════════════════════════════════

local function IsWhitelisted(player)
    if player == LocalPlayer then return true end

    for _, id in ipairs(CONFIG.WhitelistUserIds) do
        if player.UserId == id then return true end
    end

    for _, name in ipairs(CONFIG.WhitelistNames) do
        if player.Name:lower() == name:lower() then return true end
        if player.DisplayName:lower() == name:lower() then return true end
    end

    return false
end

local function Notify(title, text, duration)
    pcall(function()
        game.StarterGui:SetCore("SendNotification", {
            Title = title or "Server Lock",
            Text = text or "",
            Duration = duration or 3,
        })
    end)
end

local function Log(msg)
    print("[ServerLock] " .. tostring(msg))
end

local function UpdateGUICounter()
    if State.GUI and State.GUI.Counter then
        pcall(function()
            State.GUI.Counter.Text = "Blocked: " .. State.PlayersBlocked
        end)
    end
end

-- ═══════════════════════════════════════
-- METHOD 1: FLING (collision-based)
-- ═══════════════════════════════════════
--
-- How this works:
--   Your character gets a BodyAngularVelocity (makes you spin fast)
--   + a BodyVelocity (keeps you locked in place on the target).
--   Then your CFrame is set to the target's CFrame each frame.
--   The fast-spinning collision between your character and theirs
--   launches them due to Roblox physics. This is the standard
--   client-side fling method used by most script hubs.
--
-- Why it works from client:
--   You have network ownership of YOUR character. By spinning
--   your character into theirs, the physics engine on YOUR client
--   resolves the collision and replicates the result to the server.

local flingActive = false

local function FlingPlayer(targetPlayer)
    if not CONFIG.UseFling then return end
    if not State.Running then return end
    if not State.LockEnabled then return end

    -- need our own character alive
    local myChar = LocalPlayer.Character
    if not myChar then return end
    local myHRP = myChar:FindFirstChild("HumanoidRootPart")
    if not myHRP then return end
    local myHumanoid = myChar:FindFirstChildOfClass("Humanoid")
    if not myHumanoid or myHumanoid.Health <= 0 then return end

    -- need target character
    local targetChar = targetPlayer.Character
    if not targetChar then return end
    local targetHRP = targetChar:FindFirstChild("HumanoidRootPart")
    if not targetHRP then return end

    -- save where we were
    local savedPos = myHRP.CFrame

    -- clean old body movers from our HRP
    for _, child in ipairs(myHRP:GetChildren()) do
        if child:IsA("BodyAngularVelocity") or child:IsA("BodyVelocity") then
            child:Destroy()
        end
    end

    -- spin: makes us a high-speed spinning object
    local spin = Instance.new("BodyAngularVelocity")
    spin.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    spin.P = math.huge
    spin.AngularVelocity = Vector3.new(0, CONFIG.FlingPower, 0)
    spin.Parent = myHRP

    -- velocity lock: keeps pushing us into the target
    local push = Instance.new("BodyVelocity")
    push.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    push.P = math.huge
    push.Velocity = Vector3.new(0, 0, 0)
    push.Parent = myHRP

    -- ram into target for several frames
    local frames = 15
    for i = 1, frames do
        if not State.Running then break end
        if not State.LockEnabled then break end

        -- recheck everything each frame
        targetChar = targetPlayer.Character
        if not targetChar then break end
        targetHRP = targetChar:FindFirstChild("HumanoidRootPart")
        if not targetHRP then break end
        if not targetHRP.Parent then break end

        myChar = LocalPlayer.Character
        if not myChar then break end
        myHRP = myChar:FindFirstChild("HumanoidRootPart")
        if not myHRP then break end

        -- teleport right on top of them
        pcall(function()
            local targetPos = targetHRP.Position
            push.Velocity = (targetPos - myHRP.Position).Unit * CONFIG.FlingPower
            myHRP.CFrame = targetHRP.CFrame
        end)

        RunService.Heartbeat:Wait()
    end

    -- cleanup body movers
    pcall(function() spin:Destroy() end)
    pcall(function() push:Destroy() end)

    -- return to saved position
    task.delay(0.1, function()
        pcall(function()
            local c = LocalPlayer.Character
            if c then
                local h = c:FindFirstChild("HumanoidRootPart")
                if h then
                    h.CFrame = savedPos
                end
            end
        end)
    end)
end

-- continuous fling loop per target
local function StartFlingLoop(targetPlayer)
    local uid = targetPlayer.UserId
    if State.FlingTargets[uid] then return end
    State.FlingTargets[uid] = true

    task.spawn(function()
        while State.Running
              and State.LockEnabled
              and State.FlingTargets[uid]
              and targetPlayer.Parent do -- .Parent is nil when they leave

            -- only fling if both characters exist
            local myChar = LocalPlayer.Character
            local targetChar = targetPlayer.Character
            if myChar and targetChar
               and myChar:FindFirstChild("HumanoidRootPart")
               and targetChar:FindFirstChild("HumanoidRootPart") then
                pcall(FlingPlayer, targetPlayer)
            end

            task.wait(CONFIG.FlingInterval)
        end

        State.FlingTargets[uid] = nil
    end)
end

local function StopFlingLoop(uid)
    State.FlingTargets[uid] = nil
end

-- ═══════════════════════════════════════
-- METHOD 2: REMOTE EVENT SCAN
-- ═══════════════════════════════════════

local function ScanForKickRemotes()
    if not CONFIG.UseRemoteScan then return end

    State.KickRemotes = {} -- reset

    local keywords = {"kick", "ban", "remove", "boot", "eject", "punish"}

    local function ScanContainer(container)
        local ok, descendants = pcall(function() return container:GetDescendants() end)
        if not ok or not descendants then return end

        for _, obj in ipairs(descendants) do
            if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
                local n = obj.Name:lower()
                for _, kw in ipairs(keywords) do
                    if n:find(kw) then
                        table.insert(State.KickRemotes, {
                            Remote = obj,
                            Name = obj.Name,
                            Type = obj.ClassName,
                        })
                        Log("Found remote: " .. obj:GetFullName())
                        break
                    end
                end
            end
        end
    end

    pcall(ScanContainer, ReplicatedStorage)
    pcall(function() ScanContainer(game:GetService("ReplicatedFirst")) end)
    pcall(function() ScanContainer(game:GetService("Workspace")) end)

    -- executor-specific: scan nil instances
    pcall(function()
        if getnilinstances then
            for _, obj in ipairs(getnilinstances()) do
                if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
                    local n = obj.Name:lower()
                    for _, kw in ipairs(keywords) do
                        if n:find(kw) then
                            table.insert(State.KickRemotes, {
                                Remote = obj,
                                Name = obj.Name,
                                Type = obj.ClassName,
                            })
                            Log("Found hidden remote: " .. obj.Name)
                            break
                        end
                    end
                end
            end
        end
    end)

    Log("Remote scan done. Found " .. #State.KickRemotes .. " potential kick remotes.")
end

local function TryFireKickRemotes(targetPlayer)
    if not CONFIG.UseRemoteScan then return end
    if #State.KickRemotes == 0 then return end

    for _, info in ipairs(State.KickRemotes) do
        pcall(function()
            if info.Type == "RemoteEvent" then
                info.Remote:FireServer(targetPlayer)
                info.Remote:FireServer(targetPlayer.Name)
                info.Remote:FireServer(targetPlayer.UserId)
                info.Remote:FireServer("kick", targetPlayer.Name)
            elseif info.Type == "RemoteFunction" then
                pcall(function() info.Remote:InvokeServer(targetPlayer) end)
                pcall(function() info.Remote:InvokeServer(targetPlayer.Name) end)
            end
        end)
    end
end

-- ═══════════════════════════════════════
-- PLAYER HANDLER
-- ═══════════════════════════════════════

local function HandlePlayer(player)
    if IsWhitelisted(player) then return end

    Log("Targeting: " .. player.Name .. " (" .. player.UserId .. ")")
    Notify("Server Lock", "Blocking: " .. player.Name, 3)
    State.PlayersBlocked = State.PlayersBlocked + 1
    UpdateGUICounter()

    -- try kick remotes (instant if game has vulnerable ones)
    TryFireKickRemotes(player)

    -- start continuous fling
    StartFlingLoop(player)

    -- also fling on every respawn
    local uid = player.UserId

    -- disconnect old connection if exists (prevent double-connecting)
    if State.CharAddedConns[uid] then
        pcall(function() State.CharAddedConns[uid]:Disconnect() end)
        State.CharAddedConns[uid] = nil
    end

    State.CharAddedConns[uid] = player.CharacterAdded:Connect(function(char)
        if not State.LockEnabled then return end
        -- wait for character to fully load
        local hrp = char:WaitForChild("HumanoidRootPart", 5)
        if not hrp then return end
        task.wait(0.3)
        -- re-fling after respawn
        if State.LockEnabled and player.Parent then
            pcall(FlingPlayer, player)
        end
    end)
end

local function CleanupPlayer(player)
    local uid = player.UserId
    StopFlingLoop(uid)
    if State.CharAddedConns[uid] then
        pcall(function() State.CharAddedConns[uid]:Disconnect() end)
        State.CharAddedConns[uid] = nil
    end
end

-- ═══════════════════════════════════════
-- GUI
-- ═══════════════════════════════════════

local function CreateGUI()
    -- destroy old GUI
    pcall(function()
        local old = LocalPlayer.PlayerGui:FindFirstChild("ServerLockGUI")
        if old then old:Destroy() end
    end)
    pcall(function()
        if gethui then
            for _, gui in ipairs(gethui():GetChildren()) do
                if gui.Name == "ServerLockGUI" then gui:Destroy() end
            end
        end
    end)

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "ServerLockGUI"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    -- protect from game scripts if executor supports it
    pcall(function()
        if syn and syn.protect_gui then
            syn.protect_gui(ScreenGui)
            ScreenGui.Parent = game:GetService("CoreGui")
        elseif gethui then
            ScreenGui.Parent = gethui()
        end
    end)
    if not ScreenGui.Parent then
        ScreenGui.Parent = LocalPlayer.PlayerGui
    end

    -- Main frame
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 220, 0, 160)
    MainFrame.Position = UDim2.new(0, 10, 0.5, -80)
    MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
    MainFrame.BackgroundTransparency = 0.1
    MainFrame.BorderSizePixel = 0
    MainFrame.Parent = ScreenGui

    Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(100, 60, 255)
    stroke.Thickness = 1.5
    stroke.Transparency = 0.3
    stroke.Parent = MainFrame

    -- Title bar
    local TitleBar = Instance.new("Frame")
    TitleBar.Name = "TitleBar"
    TitleBar.Size = UDim2.new(1, 0, 0, 32)
    TitleBar.BackgroundColor3 = Color3.fromRGB(100, 60, 255)
    TitleBar.BackgroundTransparency = 0.3
    TitleBar.BorderSizePixel = 0
    TitleBar.ClipsDescendants = true
    TitleBar.Parent = MainFrame

    Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 8)

    -- bottom fix for title bar corners
    local fix = Instance.new("Frame")
    fix.Size = UDim2.new(1, 0, 0, 10)
    fix.Position = UDim2.new(0, 0, 1, -10)
    fix.BackgroundColor3 = Color3.fromRGB(100, 60, 255)
    fix.BackgroundTransparency = 0.3
    fix.BorderSizePixel = 0
    fix.Parent = TitleBar

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -10, 1, 0)
    title.Position = UDim2.new(0, 10, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "SERVER LOCK"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextSize = 14
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = TitleBar

    -- Draggable title bar
    local dragging = false
    local dragStart, frameStart

    TrackConnection(TitleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or
           input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            frameStart = MainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end))

    TrackConnection(UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or
           input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(
                frameStart.X.Scale, frameStart.X.Offset + delta.X,
                frameStart.Y.Scale, frameStart.Y.Offset + delta.Y
            )
        end
    end))

    -- Status indicator
    local statusFrame = Instance.new("Frame")
    statusFrame.Size = UDim2.new(1, -20, 0, 26)
    statusFrame.Position = UDim2.new(0, 10, 0, 38)
    statusFrame.BackgroundColor3 = Color3.fromRGB(0, 180, 80)
    statusFrame.BackgroundTransparency = 0.7
    statusFrame.BorderSizePixel = 0
    statusFrame.Parent = MainFrame
    Instance.new("UICorner", statusFrame).CornerRadius = UDim.new(0, 6)

    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, 0, 1, 0)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = State.LockEnabled and "LOCK ACTIVE" or "LOCK DISABLED"
    statusLabel.TextColor3 = State.LockEnabled and Color3.fromRGB(100, 255, 150) or Color3.fromRGB(255, 100, 100)
    statusLabel.TextSize = 12
    statusLabel.Font = Enum.Font.GothamBold
    statusLabel.Parent = statusFrame

    -- Toggle button
    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(1, -20, 0, 26)
    toggleBtn.Position = UDim2.new(0, 10, 0, 70)
    toggleBtn.BackgroundColor3 = Color3.fromRGB(60, 40, 140)
    toggleBtn.BorderSizePixel = 0
    toggleBtn.Text = "Toggle Lock [RShift]"
    toggleBtn.TextColor3 = Color3.fromRGB(200, 200, 255)
    toggleBtn.TextSize = 11
    toggleBtn.Font = Enum.Font.GothamSemibold
    toggleBtn.Parent = MainFrame
    Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 6)

    -- Blocked counter
    local counterLabel = Instance.new("TextLabel")
    counterLabel.Name = "Counter"
    counterLabel.Size = UDim2.new(0.5, -15, 0, 18)
    counterLabel.Position = UDim2.new(0, 10, 0, 102)
    counterLabel.BackgroundTransparency = 1
    counterLabel.Text = "Blocked: 0"
    counterLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
    counterLabel.TextSize = 11
    counterLabel.Font = Enum.Font.Gotham
    counterLabel.TextXAlignment = Enum.TextXAlignment.Left
    counterLabel.Parent = MainFrame

    -- Player count
    local playerCountLabel = Instance.new("TextLabel")
    playerCountLabel.Name = "PlayerCount"
    playerCountLabel.Size = UDim2.new(0.5, -15, 0, 18)
    playerCountLabel.Position = UDim2.new(0.5, 5, 0, 102)
    playerCountLabel.BackgroundTransparency = 1
    playerCountLabel.Text = "In Server: " .. #Players:GetPlayers()
    playerCountLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
    playerCountLabel.TextSize = 11
    playerCountLabel.Font = Enum.Font.Gotham
    playerCountLabel.TextXAlignment = Enum.TextXAlignment.Left
    playerCountLabel.Parent = MainFrame

    -- Methods status
    local methodsLabel = Instance.new("TextLabel")
    methodsLabel.Size = UDim2.new(1, -20, 0, 18)
    methodsLabel.Position = UDim2.new(0, 10, 0, 124)
    methodsLabel.BackgroundTransparency = 1
    local methodsText = "Methods: "
    if CONFIG.UseFling then methodsText = methodsText .. "Fling " end
    if CONFIG.UseRemoteScan then methodsText = methodsText .. "RemoteScan " end
    methodsLabel.Text = methodsText
    methodsLabel.TextColor3 = Color3.fromRGB(120, 120, 150)
    methodsLabel.TextSize = 10
    methodsLabel.Font = Enum.Font.Gotham
    methodsLabel.TextXAlignment = Enum.TextXAlignment.Left
    methodsLabel.Parent = MainFrame

    -- Store refs
    State.GUI = {
        ScreenGui = ScreenGui,
        MainFrame = MainFrame,
        StatusLabel = statusLabel,
        StatusFrame = statusFrame,
        Counter = counterLabel,
        PlayerCount = playerCountLabel,
        ToggleBtn = toggleBtn,
    }

    -- Toggle function
    local function ToggleLock()
        State.LockEnabled = not State.LockEnabled

        if State.LockEnabled then
            statusLabel.Text = "LOCK ACTIVE"
            statusLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
            statusFrame.BackgroundColor3 = Color3.fromRGB(0, 180, 80)
            Notify("Server Lock", "Lock ENABLED", 2)
            -- re-target existing non-whitelisted players
            for _, p in ipairs(Players:GetPlayers()) do
                if not IsWhitelisted(p) then
                    HandlePlayer(p)
                end
            end
        else
            statusLabel.Text = "LOCK DISABLED"
            statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
            statusFrame.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
            Notify("Server Lock", "Lock DISABLED", 2)
            -- stop all fling loops
            for uid, _ in pairs(State.FlingTargets) do
                State.FlingTargets[uid] = nil
            end
            -- disconnect all character-added connections
            for uid, conn in pairs(State.CharAddedConns) do
                pcall(function() conn:Disconnect() end)
                State.CharAddedConns[uid] = nil
            end
        end
    end

    TrackConnection(toggleBtn.MouseButton1Click:Connect(ToggleLock))

    TrackConnection(UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.KeyCode == CONFIG.ToggleKey then
            ToggleLock()
        end
    end))

    -- live player count update
    task.spawn(function()
        while State.Running do
            pcall(function()
                playerCountLabel.Text = "In Server: " .. #Players:GetPlayers()
            end)
            task.wait(2)
        end
    end)

    -- double-click title to minimize
    local lastClickTime = 0
    TrackConnection(TitleBar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            local now = tick()
            if now - lastClickTime < 0.3 then
                local expanded = statusFrame.Visible
                statusFrame.Visible = not expanded
                toggleBtn.Visible = not expanded
                counterLabel.Visible = not expanded
                playerCountLabel.Visible = not expanded
                methodsLabel.Visible = not expanded
                MainFrame.Size = expanded
                    and UDim2.new(0, 220, 0, 32)
                    or UDim2.new(0, 220, 0, 160)
            end
            lastClickTime = now
        end
    end))
end

-- ═══════════════════════════════════════
-- CLEANUP (for re-execution)
-- ═══════════════════════════════════════

local function Cleanup()
    State.Running = false

    -- disconnect all tracked connections
    for _, conn in ipairs(State.Connections) do
        pcall(function() conn:Disconnect() end)
    end
    State.Connections = {}

    -- disconnect character-added connections
    for uid, conn in pairs(State.CharAddedConns) do
        pcall(function() conn:Disconnect() end)
        State.CharAddedConns[uid] = nil
    end

    -- stop fling loops
    for uid, _ in pairs(State.FlingTargets) do
        State.FlingTargets[uid] = nil
    end

    -- destroy GUI
    pcall(function()
        if State.GUI and State.GUI.ScreenGui then
            State.GUI.ScreenGui:Destroy()
        end
    end)

    Log("Cleaned up.")
end

-- cleanup previous instance
pcall(function()
    if _G.ServerLockCleanup then
        _G.ServerLockCleanup()
    end
end)
_G.ServerLockCleanup = Cleanup

-- ═══════════════════════════════════════
-- INITIALIZE
-- ═══════════════════════════════════════

local function Initialize()
    Log("===================================")
    Log("  STEAL AN EGG - SERVER LOCK v2.0")
    Log("===================================")

    -- auto-whitelist self
    table.insert(CONFIG.WhitelistUserIds, LocalPlayer.UserId)

    -- build GUI
    CreateGUI()
    Log("GUI ready")

    -- scan for kick-related remotes
    ScanForKickRemotes()

    -- handle all existing players
    for _, player in ipairs(Players:GetPlayers()) do
        if State.LockEnabled and not IsWhitelisted(player) then
            HandlePlayer(player)
        end
    end

    -- listen for new joins
    TrackConnection(Players.PlayerAdded:Connect(function(player)
        Log("Join: " .. player.Name)
        if State.LockEnabled and not IsWhitelisted(player) then
            task.wait(0.5)
            HandlePlayer(player)
        end
    end))

    -- listen for leaves (cleanup)
    TrackConnection(Players.PlayerRemoving:Connect(function(player)
        CleanupPlayer(player)
        if not IsWhitelisted(player) then
            Log("Left: " .. player.Name)
        end
    end))

    -- handle own character respawn (re-engage fling loops)
    TrackConnection(LocalPlayer.CharacterAdded:Connect(function()
        task.wait(1)
        if State.LockEnabled then
            for _, player in ipairs(Players:GetPlayers()) do
                if not IsWhitelisted(player) and not State.FlingTargets[player.UserId] then
                    StartFlingLoop(player)
                end
            end
        end
    end))

    Log("Your UserId: " .. LocalPlayer.UserId)
    Log("Whitelisted: " .. #CONFIG.WhitelistUserIds .. " IDs")
    Log("Toggle: RightShift")
    Log("Lock: " .. (State.LockEnabled and "ON" or "OFF"))
    Log("===================================")

    Notify("Server Lock", "Active! RShift to toggle.", 5)
end

-- ═══════════════════════════════════════
-- RUN
-- ═══════════════════════════════════════

Initialize()
