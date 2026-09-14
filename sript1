-- ==========================================================
-- UNIVERSAL ROBLOX SMALL SERVER FINDER (PENCARI SERVER SEPI)
-- Fitur:
--   1. Auto-Join Server Tersepi (Otomatis join ke server paling sepi)
--   2. Smart Fallback (Jika filter terlalu ketat, tetap cari server terkecil yang ada)
--   3. Daftar Server / Server Browser (Lihat pemain, ping, fps, & tombol join)
--   4. Filter Pemain Instan (1, 1-2, 1-3, 1-5, 1-10)
--   5. Anti-AFK Bawaan (Mencegah kick 20 menit)
--   6. Rejoin Server & Copy Job ID
--   7. Hotkey Toggle GUI (RightShift / RightControl)
-- Kompatibel: Solara, Wave, Delta, Codex, Arceus X, Fluxus, Synapse, dll.
-- ==========================================================

local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer
local PlaceId = game.PlaceId
local CurrentJobId = game.JobId

-- Konfigurasi & State
local Config = {
    MinPlayers = 1,
    MaxPlayers = 3,
    SearchLimit = 100,
    MaxPages = 8,
    RetryDelay = 2,
    AntiAFK = true
}

-- Deteksi Nama Game Otomatis
local GameName = "Roblox Experience"
pcall(function()
    local info = MarketplaceService:GetProductInfo(PlaceId)
    if info and info.Name then
        GameName = info.Name
    end
end)

-- Safe UI Parent Resolver
local function getGuiParent()
    if typeof(gethui) == "function" then
        return gethui()
    end
    local success, coreGui = pcall(function()
        return game:GetService("CoreGui")
    end)
    if success and coreGui then
        return coreGui
    end
    return LocalPlayer:WaitForChild("PlayerGui")
end

local parentContainer = getGuiParent()

-- Hapus instance sebelumnya jika ada
local oldGui = parentContainer:FindFirstChild("UniversalSmallServerFinderGUI")
if oldGui then
    oldGui:Destroy()
end

-- ==================== SCREEN GUI ROOT ====================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "UniversalSmallServerFinderGUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

if syn and typeof(syn.protect_gui) == "function" then
    pcall(syn.protect_gui, ScreenGui)
end
ScreenGui.Parent = parentContainer

-- Palette Desain Modern Dark
local Palette = {
    Bg = Color3.fromRGB(18, 20, 26),
    Header = Color3.fromRGB(13, 14, 18),
    Card = Color3.fromRGB(26, 29, 38),
    CardHover = Color3.fromRGB(33, 37, 48),
    Accent = Color3.fromRGB(79, 110, 247),
    AccentActive = Color3.fromRGB(99, 130, 255),
    Green = Color3.fromRGB(46, 204, 113),
    GreenHover = Color3.fromRGB(39, 174, 96),
    Yellow = Color3.fromRGB(241, 196, 15),
    Red = Color3.fromRGB(231, 76, 60),
    Text = Color3.fromRGB(240, 242, 245),
    TextMuted = Color3.fromRGB(150, 155, 170),
    Border = Color3.fromRGB(42, 46, 60)
}

-- Frame Utama (Window)
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 390, 0, 500)
MainFrame.Position = UDim2.new(0.5, -195, 0.45, -250)
MainFrame.BackgroundColor3 = Palette.Bg
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 10)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Palette.Border
MainStroke.Thickness = 1.2
MainStroke.Parent = MainFrame

-- ==================== TOP BAR (DRAGGABLE) ====================
local TopBar = Instance.new("Frame")
TopBar.Name = "TopBar"
TopBar.Size = UDim2.new(1, 0, 0, 44)
TopBar.BackgroundColor3 = Palette.Header
TopBar.BorderSizePixel = 0
TopBar.Parent = MainFrame

local TopBarCorner = Instance.new("UICorner")
TopBarCorner.CornerRadius = UDim.new(0, 10)
TopBarCorner.Parent = TopBar

local TopBarHider = Instance.new("Frame")
TopBarHider.Size = UDim2.new(1, 0, 0, 12)
TopBarHider.Position = UDim2.new(0, 0, 1, -12)
TopBarHider.BackgroundColor3 = Palette.Header
TopBarHider.BorderSizePixel = 0
TopBarHider.Parent = TopBar

local TitleIcon = Instance.new("TextLabel")
TitleIcon.Size = UDim2.new(0, 30, 1, 0)
TitleIcon.Position = UDim2.new(0, 10, 0, 0)
TitleIcon.BackgroundTransparency = 1
TitleIcon.Font = Enum.Font.GothamBold
TitleIcon.Text = "🌐"
TitleIcon.TextSize = 16
TitleIcon.Parent = TopBar

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -120, 0, 20)
TitleLabel.Position = UDim2.new(0, 42, 0, 5)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.Text = "Small Server Finder"
TitleLabel.TextColor3 = Palette.Text
TitleLabel.TextSize = 13
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = TopBar

local GameLabel = Instance.new("TextLabel")
GameLabel.Size = UDim2.new(1, -120, 0, 14)
GameLabel.Position = UDim2.new(0, 42, 0, 23)
GameLabel.BackgroundTransparency = 1
GameLabel.Font = Enum.Font.Gotham
GameLabel.Text = GameName
GameLabel.TextColor3 = Palette.TextMuted
GameLabel.TextSize = 10
GameLabel.TextTruncate = Enum.TextTruncate.AtEnd
GameLabel.TextXAlignment = Enum.TextXAlignment.Left
GameLabel.Parent = TopBar

-- Tombol Close
local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 28, 0, 28)
CloseBtn.Position = UDim2.new(1, -34, 0, 8)
CloseBtn.BackgroundColor3 = Color3.fromRGB(24, 26, 34)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = Palette.TextMuted
CloseBtn.TextSize = 12
CloseBtn.BorderSizePixel = 0
CloseBtn.Parent = TopBar

local CloseBtnCorner = Instance.new("UICorner")
CloseBtnCorner.CornerRadius = UDim.new(0, 6)
CloseBtnCorner.Parent = CloseBtn

CloseBtn.MouseEnter:Connect(function()
    CloseBtn.BackgroundColor3 = Palette.Red
    CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
end)
CloseBtn.MouseLeave:Connect(function()
    CloseBtn.BackgroundColor3 = Color3.fromRGB(24, 26, 34)
    CloseBtn.TextColor3 = Palette.TextMuted
end)
CloseBtn.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
end)

-- Tombol Minimize
local isMinimized = false
local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 28, 0, 28)
MinBtn.Position = UDim2.new(1, -66, 0, 8)
MinBtn.BackgroundColor3 = Color3.fromRGB(24, 26, 34)
MinBtn.Font = Enum.Font.GothamBold
MinBtn.Text = "−"
MinBtn.TextColor3 = Palette.TextMuted
MinBtn.TextSize = 14
MinBtn.BorderSizePixel = 0
MinBtn.Parent = TopBar

local MinBtnCorner = Instance.new("UICorner")
MinBtnCorner.CornerRadius = UDim.new(0, 6)
MinBtnCorner.Parent = MinBtn

MinBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    if isMinimized then
        TweenService:Create(MainFrame, TweenInfo.new(0.2), {Size = UDim2.new(0, 390, 0, 44)}):Play()
        MinBtn.Text = "+"
    else
        TweenService:Create(MainFrame, TweenInfo.new(0.2), {Size = UDim2.new(0, 390, 0, 500)}):Play()
        MinBtn.Text = "−"
    end
end)

-- Dragging Support (PC & Mobile Touch)
local isDragging = false
local dragStartPos = Vector2.zero
local frameStartPos = UDim2.new()

TopBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isDragging = true
        dragStartPos = input.Position
        frameStartPos = MainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                isDragging = false
            end
        end)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStartPos
        MainFrame.Position = UDim2.new(
            frameStartPos.X.Scale,
            frameStartPos.X.Offset + delta.X,
            frameStartPos.Y.Scale,
            frameStartPos.Y.Offset + delta.Y
        )
    end
end)

-- ==================== BODY CONTENT ====================
local Body = Instance.new("Frame")
Body.Name = "Body"
Body.Size = UDim2.new(1, -20, 1, -54)
Body.Position = UDim2.new(0, 10, 0, 48)
Body.BackgroundTransparency = 1
Body.Parent = MainFrame

-- Status Bar Box
local StatusBox = Instance.new("Frame")
StatusBox.Size = UDim2.new(1, 0, 0, 34)
StatusBox.BackgroundColor3 = Palette.Card
StatusBox.BorderSizePixel = 0
StatusBox.Parent = Body

local StatusCorner = Instance.new("UICorner")
StatusCorner.CornerRadius = UDim.new(0, 6)
StatusCorner.Parent = StatusBox

local StatusDot = Instance.new("Frame")
StatusDot.Size = UDim2.new(0, 8, 0, 8)
StatusDot.Position = UDim2.new(0, 10, 0.5, -4)
StatusDot.BackgroundColor3 = Palette.Green
StatusDot.BorderSizePixel = 0
StatusDot.Parent = StatusBox

local DotCorner = Instance.new("UICorner")
DotCorner.CornerRadius = UDim.new(1, 0)
DotCorner.Parent = StatusDot

local StatusText = Instance.new("TextLabel")
StatusText.Size = UDim2.new(1, -28, 1, 0)
StatusText.Position = UDim2.new(0, 24, 0, 0)
StatusText.BackgroundTransparency = 1
StatusText.Font = Enum.Font.GothamMedium
StatusText.Text = "Siap mencari server sepi."
StatusText.TextColor3 = Palette.Text
StatusText.TextSize = 11
StatusText.TextXAlignment = Enum.TextXAlignment.Left
StatusText.Parent = StatusBox

local function setStatus(msg, color)
    StatusText.Text = msg
    StatusDot.BackgroundColor3 = color or Palette.TextMuted
end

-- Filter Selector (Target Pemain)
local FilterBox = Instance.new("Frame")
FilterBox.Size = UDim2.new(1, 0, 0, 44)
FilterBox.Position = UDim2.new(0, 0, 0, 40)
FilterBox.BackgroundColor3 = Palette.Card
FilterBox.BorderSizePixel = 0
FilterBox.Parent = Body

local FilterCorner = Instance.new("UICorner")
FilterCorner.CornerRadius = UDim.new(0, 6)
FilterCorner.Parent = FilterBox

local FilterLabel = Instance.new("TextLabel")
FilterLabel.Size = UDim2.new(0, 85, 1, 0)
FilterLabel.Position = UDim2.new(0, 10, 0, 0)
FilterLabel.BackgroundTransparency = 1
FilterLabel.Font = Enum.Font.Gotham
FilterLabel.Text = "Target Player:"
FilterLabel.TextColor3 = Palette.TextMuted
FilterLabel.TextSize = 11
FilterLabel.TextXAlignment = Enum.TextXAlignment.Left
FilterLabel.Parent = FilterBox

-- Pilihan Cepat Filter (1, 1-2, 1-3, 1-5, 1-10)
local presetFilters = {
    {label = "1", min = 1, max = 1},
    {label = "1-2", min = 1, max = 2},
    {label = "1-3", min = 1, max = 3},
    {label = "1-5", min = 1, max = 5},
    {label = "1-10", min = 1, max = 10}
}

local filterButtons = {}
for i, preset in ipairs(presetFilters) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 50, 0, 26)
    btn.Position = UDim2.new(0, 95 + (i - 1) * 54, 0.5, -13)
    btn.BackgroundColor3 = (preset.max == Config.MaxPlayers and preset.min == Config.MinPlayers) and Palette.Accent or Color3.fromRGB(36, 40, 52)
    btn.Font = Enum.Font.GothamBold
    btn.Text = preset.label
    btn.TextColor3 = Palette.Text
    btn.TextSize = 11
    btn.BorderSizePixel = 0
    btn.Parent = FilterBox

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 5)
    btnCorner.Parent = btn

    btn.MouseButton1Click:Connect(function()
        Config.MinPlayers = preset.min
        Config.MaxPlayers = preset.max
        for _, otherBtn in ipairs(filterButtons) do
            otherBtn.BackgroundColor3 = Color3.fromRGB(36, 40, 52)
        end
        btn.BackgroundColor3 = Palette.Accent
        setStatus(string.format("Filter target: %d s/d %d pemain", Config.MinPlayers, Config.MaxPlayers), Palette.Accent)
    end)

    table.insert(filterButtons, btn)
end

-- ==================== ACTION BUTTONS ====================
-- Tombol 1: Auto-Join Server Paling Sepi
local QuickJoinBtn = Instance.new("TextButton")
QuickJoinBtn.Name = "QuickJoinBtn"
QuickJoinBtn.Size = UDim2.new(0.5, -4, 0, 36)
QuickJoinBtn.Position = UDim2.new(0, 0, 0, 90)
QuickJoinBtn.BackgroundColor3 = Palette.Green
QuickJoinBtn.Font = Enum.Font.GothamBold
QuickJoinBtn.Text = "⚡ Auto-Join Tersepi"
QuickJoinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
QuickJoinBtn.TextSize = 12
QuickJoinBtn.BorderSizePixel = 0
QuickJoinBtn.Parent = Body

local QJCorner = Instance.new("UICorner")
QJCorner.CornerRadius = UDim.new(0, 6)
QJCorner.Parent = QuickJoinBtn

-- Tombol 2: Cari & Tampilkan Daftar
local ScanBtn = Instance.new("TextButton")
ScanBtn.Name = "ScanBtn"
ScanBtn.Size = UDim2.new(0.5, -4, 0, 36)
ScanBtn.Position = UDim2.new(0.5, 4, 0, 90)
ScanBtn.BackgroundColor3 = Palette.Accent
ScanBtn.Font = Enum.Font.GothamBold
ScanBtn.Text = "🔍 Cari Daftar Server"
ScanBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ScanBtn.TextSize = 12
ScanBtn.BorderSizePixel = 0
ScanBtn.Parent = Body

local ScanCorner = Instance.new("UICorner")
ScanCorner.CornerRadius = UDim.new(0, 6)
ScanCorner.Parent = ScanBtn

-- Server List Container
local ListHeader = Instance.new("Frame")
ListHeader.Size = UDim2.new(1, 0, 0, 22)
ListHeader.Position = UDim2.new(0, 0, 0, 132)
ListHeader.BackgroundTransparency = 1
ListHeader.Parent = Body

local ListTitle = Instance.new("TextLabel")
ListTitle.Size = UDim2.new(0.6, 0, 1, 0)
ListTitle.Position = UDim2.new(0, 2, 0, 0)
ListTitle.BackgroundTransparency = 1
ListTitle.Font = Enum.Font.GothamBold
ListTitle.Text = "DAFTAR SERVER SEPI"
ListTitle.TextColor3 = Palette.TextMuted
ListTitle.TextSize = 10
ListTitle.TextXAlignment = Enum.TextXAlignment.Left
ListTitle.Parent = ListHeader

local ServerCountLabel = Instance.new("TextLabel")
ServerCountLabel.Size = UDim2.new(0.4, 0, 1, 0)
ServerCountLabel.Position = UDim2.new(0.6, -2, 0, 0)
ServerCountLabel.BackgroundTransparency = 1
ServerCountLabel.Font = Enum.Font.Gotham
ServerCountLabel.Text = "0 server ditemukan"
ServerCountLabel.TextColor3 = Palette.TextMuted
ServerCountLabel.TextSize = 10
ServerCountLabel.TextXAlignment = Enum.TextXAlignment.Right
ServerCountLabel.Parent = ListHeader

local ServerScroll = Instance.new("ScrollingFrame")
ServerScroll.Name = "ServerScroll"
ServerScroll.Size = UDim2.new(1, 0, 1, -210)
ServerScroll.Position = UDim2.new(0, 0, 0, 156)
ServerScroll.BackgroundColor3 = Palette.Card
ServerScroll.BorderSizePixel = 0
ServerScroll.ScrollBarThickness = 4
ServerScroll.ScrollBarImageColor3 = Palette.Border
ServerScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
ServerScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
ServerScroll.Parent = Body

local ScrollCorner = Instance.new("UICorner")
ScrollCorner.CornerRadius = UDim.new(0, 6)
ScrollCorner.Parent = ServerScroll

local ScrollLayout = Instance.new("UIListLayout")
ScrollLayout.SortOrder = Enum.SortOrder.LayoutOrder
ScrollLayout.Padding = UDim.new(0, 6)
ScrollLayout.Parent = ServerScroll

local ScrollPadding = Instance.new("UIPadding")
ScrollPadding.PaddingTop = UDim.new(0, 6)
ScrollPadding.PaddingLeft = UDim.new(0, 6)
ScrollPadding.PaddingRight = UDim.new(0, 6)
ScrollPadding.PaddingBottom = UDim.new(0, 6)
ScrollPadding.Parent = ServerScroll

-- Bottom Bar: Rejoin & Info
local BottomBar = Instance.new("Frame")
BottomBar.Size = UDim2.new(1, 0, 0, 42)
BottomBar.Position = UDim2.new(0, 0, 1, -44)
BottomBar.BackgroundTransparency = 1
BottomBar.Parent = Body

local RejoinBtn = Instance.new("TextButton")
RejoinBtn.Size = UDim2.new(0.48, 0, 0, 24)
RejoinBtn.Position = UDim2.new(0, 0, 0, 0)
RejoinBtn.BackgroundColor3 = Color3.fromRGB(30, 34, 44)
RejoinBtn.Font = Enum.Font.GothamMedium
RejoinBtn.Text = "🔄 Rejoin Server Ini"
RejoinBtn.TextColor3 = Palette.Text
RejoinBtn.TextSize = 10
RejoinBtn.BorderSizePixel = 0
RejoinBtn.Parent = BottomBar

local RejoinCorner = Instance.new("UICorner")
RejoinCorner.CornerRadius = UDim.new(0, 5)
RejoinCorner.Parent = RejoinBtn

RejoinBtn.MouseButton1Click:Connect(function()
    TeleportService:TeleportToPlaceInstance(PlaceId, CurrentJobId, LocalPlayer)
end)

local CopyJobBtn = Instance.new("TextButton")
CopyJobBtn.Size = UDim2.new(0.48, 0, 0, 24)
CopyJobBtn.Position = UDim2.new(0.52, 0, 0, 0)
CopyJobBtn.BackgroundColor3 = Color3.fromRGB(30, 34, 44)
CopyJobBtn.Font = Enum.Font.GothamMedium
CopyJobBtn.Text = "📋 Copy JobId"
CopyJobBtn.TextColor3 = Palette.Text
CopyJobBtn.TextSize = 10
CopyJobBtn.BorderSizePixel = 0
CopyJobBtn.Parent = BottomBar

local CopyCorner = Instance.new("UICorner")
CopyCorner.CornerRadius = UDim.new(0, 5)
CopyCorner.Parent = CopyJobBtn

CopyJobBtn.MouseButton1Click:Connect(function()
    if typeof(setclipboard) == "function" then
        setclipboard(tostring(CurrentJobId))
        setStatus("Job ID berhasil disalin ke clipboard!", Palette.Green)
    end
end)

local HelperNote = Instance.new("TextLabel")
HelperNote.Size = UDim2.new(1, 0, 0, 14)
HelperNote.Position = UDim2.new(0, 0, 0, 26)
HelperNote.BackgroundTransparency = 1
HelperNote.Font = Enum.Font.Gotham
HelperNote.Text = "🛡️ Anti-AFK Aktif • Tekan RightShift / RCtrl untuk hide GUI"
HelperNote.TextColor3 = Palette.TextMuted
HelperNote.TextSize = 9
HelperNote.TextXAlignment = Enum.TextXAlignment.Center
HelperNote.Parent = BottomBar

-- ==================== CORE API & TELEPORT LOGIC ====================
local isSearching = false

local function fetchApi(url)
    local requestFn = (syn and syn.request) or (http and http.request) or request or http_request
    if typeof(requestFn) == "function" then
        local success, res = pcall(requestFn, {
            Url = url,
            Method = "GET",
            Headers = {
                ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
            }
        })
        if success and res and res.Body then
            return res.Body
        end
    end

    if typeof(game.HttpGet) == "function" then
        local success, body = pcall(function()
            return game:HttpGet(url)
        end)
        if success and body then
            return body
        end
    end

    return nil
end

local function getServersPage(cursor)
    local url = string.format(
        "https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Asc&limit=%d%s",
        tostring(PlaceId),
        Config.SearchLimit,
        (cursor and cursor ~= "") and ("&cursor=" .. cursor) or ""
    )

    local raw = fetchApi(url)
    if not raw then
        return nil, "Gagal request API (Cek executor HttpGet/request)"
    end

    local success, decoded = pcall(function()
        return HttpService:JSONDecode(raw)
    end)

    if not success or not decoded or not decoded.data then
        return nil, "Format respon JSON tidak valid."
    end

    return decoded
end

local function clearServerList()
    for _, child in ipairs(ServerScroll:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
end

local function joinServerInstance(targetJobId, playerCount)
    setStatus(string.format("Teleporting ke server (%d pemain)...", playerCount or 1), Palette.Yellow)
    local success, err = pcall(function()
        TeleportService:TeleportToPlaceInstance(PlaceId, targetJobId, LocalPlayer)
    end)
    if not success then
        setStatus("Gagal teleport: " .. tostring(err), Palette.Red)
    end
end

local function renderServerCard(server, index)
    local card = Instance.new("Frame")
    card.Name = "ServerCard_" .. tostring(index)
    card.Size = UDim2.new(1, 0, 0, 42)
    card.BackgroundColor3 = Palette.Bg
    card.BorderSizePixel = 0
    card.Parent = ServerScroll

    local cardCorner = Instance.new("UICorner")
    cardCorner.CornerRadius = UDim.new(0, 6)
    cardCorner.Parent = card

    local playerIcon = Instance.new("TextLabel")
    playerIcon.Size = UDim2.new(0, 24, 1, 0)
    playerIcon.Position = UDim2.new(0, 8, 0, 0)
    playerIcon.BackgroundTransparency = 1
    playerIcon.Font = Enum.Font.GothamBold
    playerIcon.Text = "👤"
    playerIcon.TextSize = 13
    playerIcon.Parent = card

    local count = tonumber(server.playing) or 0
    local maxCount = tonumber(server.maxPlayers) or 0
    local ping = server.ping and tostring(server.ping) .. " ms" or "-- ms"
    local fps = server.fps and string.format("%.0f fps", server.fps) or ""

    local infoLabel = Instance.new("TextLabel")
    infoLabel.Size = UDim2.new(1, -120, 0, 20)
    infoLabel.Position = UDim2.new(0, 36, 0, 4)
    infoLabel.BackgroundTransparency = 1
    infoLabel.Font = Enum.Font.GothamBold
    infoLabel.Text = string.format("%d / %d Pemain", count, maxCount)
    infoLabel.TextColor3 = Palette.Text
    infoLabel.TextSize = 12
    infoLabel.TextXAlignment = Enum.TextXAlignment.Left
    infoLabel.Parent = card

    local subLabel = Instance.new("TextLabel")
    subLabel.Size = UDim2.new(1, -120, 0, 14)
    subLabel.Position = UDim2.new(0, 36, 0, 22)
    subLabel.BackgroundTransparency = 1
    subLabel.Font = Enum.Font.Gotham
    subLabel.Text = string.format("Ping: %s  %s", ping, fps)
    subLabel.TextColor3 = Palette.TextMuted
    subLabel.TextSize = 10
    subLabel.TextXAlignment = Enum.TextXAlignment.Left
    subLabel.Parent = card

    local joinBtn = Instance.new("TextButton")
    joinBtn.Size = UDim2.new(0, 68, 0, 28)
    joinBtn.Position = UDim2.new(1, -74, 0.5, -14)
    joinBtn.BackgroundColor3 = Palette.Green
    joinBtn.Font = Enum.Font.GothamBold
    joinBtn.Text = "Join"
    joinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    joinBtn.TextSize = 11
    joinBtn.BorderSizePixel = 0
    joinBtn.Parent = card

    local jCorner = Instance.new("UICorner")
    jCorner.CornerRadius = UDim.new(0, 5)
    jCorner.Parent = joinBtn

    joinBtn.MouseEnter:Connect(function()
        joinBtn.BackgroundColor3 = Palette.GreenHover
    end)
    joinBtn.MouseLeave:Connect(function()
        joinBtn.BackgroundColor3 = Palette.Green
    end)
    joinBtn.MouseButton1Click:Connect(function()
        joinServerInstance(server.id, count)
    end)
end

-- Function 1: Scan & Tampilkan Daftar
local function scanAndShowServers()
    if isSearching then return end
    isSearching = true
    ScanBtn.Text = "Mencari..."
    setStatus("Memindai server publik...", Palette.Yellow)
    clearServerList()

    task.spawn(function()
        local cursor = nil
        local found = {}
        local fallbackLowest = nil

        for page = 1, Config.MaxPages do
            setStatus(string.format("Scanning halaman %d...", page), Palette.Yellow)
            local result, err = getServersPage(cursor)

            if not result then
                setStatus("Error: " .. (err or "Gagal fetch"), Palette.Red)
                break
            end

            for _, server in ipairs(result.data) do
                local playing = tonumber(server.playing) or 0
                local maxP = tonumber(server.maxPlayers) or 0
                local sId = tostring(server.id)

                if sId ~= CurrentJobId and playing > 0 and playing < maxP then
                    if not fallbackLowest or playing < (fallbackLowest.playing or 999) then
                        fallbackLowest = server
                    end

                    if playing >= Config.MinPlayers and playing <= Config.MaxPlayers then
                        table.insert(found, server)
                    end
                end
            end

            cursor = result.nextPageCursor
            if not cursor or #found >= 25 then
                break
            end
        end

        table.sort(found, function(a, b)
            return (a.playing or 0) < (b.playing or 0)
        end)

        ServerCountLabel.Text = string.format("%d server ditemukan", #found)

        if #found == 0 then
            if fallbackLowest then
                table.insert(found, fallbackLowest)
                renderServerCard(fallbackLowest, 1)
                setStatus(string.format("Target ketat kosong. Server tersepi ditemukan: %d pemain.", fallbackLowest.playing), Palette.Yellow)
            else
                setStatus("Tidak ada server sepi ditemukan. Coba naikkan filter.", Palette.Red)
            end
        else
            for idx, s in ipairs(found) do
                renderServerCard(s, idx)
            end
            setStatus(string.format("Selesai! Ditemukan %d server sesuai filter.", #found), Palette.Green)
        end

        isSearching = false
        ScanBtn.Text = "🔍 Cari Daftar Server"
    end)
end

-- Function 2: Auto-Join Server Paling Sepi
local function autoJoinSmallest()
    if isSearching then return end
    isSearching = true
    QuickJoinBtn.Text = "Mencari..."
    setStatus("Mencari server paling sepi...", Palette.Yellow)

    task.spawn(function()
        local cursor = nil
        local candidates = {}
        local fallbackLowest = nil

        for page = 1, Config.MaxPages do
            setStatus(string.format("Scanning halaman %d...", page), Palette.Yellow)
            local result, err = getServersPage(cursor)

            if not result then
                setStatus("Error: " .. (err or "Gagal fetch"), Palette.Red)
                break
            end

            for _, server in ipairs(result.data) do
                local playing = tonumber(server.playing) or 0
                local maxP = tonumber(server.maxPlayers) or 0
                local sId = tostring(server.id)

                if sId ~= CurrentJobId and playing > 0 and playing < maxP then
                    if not fallbackLowest or playing < (fallbackLowest.playing or 999) then
                        fallbackLowest = server
                    end

                    if playing >= Config.MinPlayers and playing <= Config.MaxPlayers then
                        table.insert(candidates, server)
                    end
                end
            end

            if #candidates > 0 then
                break
            end

            cursor = result.nextPageCursor
            if not cursor then
                break
            end
        end

        -- Smart fallback jika target filter pasif tidak menemukan server
        if #candidates == 0 and fallbackLowest then
            table.insert(candidates, fallbackLowest)
        end

        if #candidates == 0 then
            setStatus("Tidak ada server sepi saat ini. Coba lagi nanti.", Palette.Red)
            isSearching = false
            QuickJoinBtn.Text = "⚡ Auto-Join Tersepi"
            return
        end

        table.sort(candidates, function(a, b)
            return (a.playing or 0) < (b.playing or 0)
        end)

        -- Coba kandidat berurutan jika ada kegagalan teleport
        for _, target in ipairs(candidates) do
            setStatus(string.format("Ditemukan server (%d pemain)! Menghubungkan...", target.playing), Palette.Green)
            local success = pcall(function()
                TeleportService:TeleportToPlaceInstance(PlaceId, target.id, LocalPlayer)
            end)

            if success then
                task.wait(Config.RetryDelay + 2)
            else
                setStatus("Gagal ke server itu, mencoba alternatif...", Palette.Yellow)
                task.wait(Config.RetryDelay)
            end
        end

        isSearching = false
        QuickJoinBtn.Text = "⚡ Auto-Join Tersepi"
    end)
end

-- Teleport Fail Event Listener (Server Penuh / Disconnect)
TeleportService.TeleportInitFailed:Connect(function(player, result, errorMessage)
    if player == LocalPlayer then
        setStatus("Teleport gagal: " .. (errorMessage or "Server penuh/error"), Palette.Red)
        isSearching = false
        QuickJoinBtn.Text = "⚡ Auto-Join Tersepi"
        ScanBtn.Text = "🔍 Cari Daftar Server"
    end
end)

-- Anti-AFK Mechanism (Mencegah kick 20 menit)
LocalPlayer.Idled:Connect(function()
    if Config.AntiAFK then
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end
end)

-- Hotkey Toggle GUI (RightShift / RightControl)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and (input.KeyCode == Enum.KeyCode.RightShift or input.KeyCode == Enum.KeyCode.RightControl) then
        MainFrame.Visible = not MainFrame.Visible
    end
end)

-- Event Bindings
QuickJoinBtn.MouseButton1Click:Connect(autoJoinSmallest)
ScanBtn.MouseButton1Click:Connect(scanAndShowServers)
