local ws = game:GetService("Workspace")
local rs = game:GetService("RunService")
local uis = game:GetService("UserInputService")
local pps = game:GetService("ProximityPromptService")
local plrs = game:GetService("Players")
local lighting = game:GetService("Lighting")
local cg = game:GetService("CoreGui")

local cam = ws.CurrentCamera
local lplr = plrs.LocalPlayer

-- Set to true by the Terminate button. Stops loops and blocks all file saving.
local terminated = false

local flySpeed = 55
local HttpService = game:GetService("HttpService")
local settingsFile = "HRSH_MenuSettings.json"
local loadedSettings = {}
local function loadSettings()
    if type(isfile) == "function" and type(readfile) == "function" then
        local ok, exists = pcall(isfile, settingsFile)
        if ok and exists then
            local readOk, raw = pcall(readfile, settingsFile)
            if readOk and type(raw) == "string" then
                local decodeOk, data = pcall(function() return HttpService:JSONDecode(raw) end)
                if decodeOk and type(data) == "table" then loadedSettings = data end
            end
        end
    end
end
loadSettings()

local toggles = {
    AimAssist = false,
    ESP = false,
    EnemyHP = false,
    PlayerESP = false,
    ItemESP = false,
    GeneratorESP = false,
    HeadArrow = false,
    NoFog = false,
    CustomFOV = false,
    Freecam = false,
    ViewLine = false,
    AntiAFK = false,
    HitboxExtender = false,
    HitboxHead = true,
    HitboxBody = false,
    HitboxLegs = false,
    HitboxVisual = true,
    OverheadText = true,
    Crosshair = false,
    Fly = false,
    Noclip = false,
    Fullbright = false,
    InstantInteract = false,
    DelCorpses = false,
    Speed = false,
    GatherNPCs = false,
    -- Optimization
    LowVisuals = false,
    InstanceOptimizer = false,
    ParticleCap = false,
    UltraPotato = false,
}

local cfg = {
    aimStrength = 0.5,
    fov = 60,
    targetPart = "Head",
    maxDist = 500,
    delCorpses = true,
    maxEsp = 10,
    espFill = Color3.fromRGB(255, 0, 0),
    espOutline = Color3.fromRGB(255, 255, 255),
    fillTrans = 0.5,
    outTrans = 0,
    scanRate = 0.5,
    speed = 16,
    gatherDistance = 8,
    npcFillOpacity = 0.5, -- NPC ESP fill opacity
    npcOutlineOpacity = 1, -- NPC ESP outline opacity
    playerFillOpacity = 0.5, -- Player ESP fill opacity
    playerOutlineOpacity = 1, -- Player ESP outline opacity
    genFillOpacity = 0.5, -- Generator ESP fill opacity (0 = invisible, 1 = solid)
    genOutlineOpacity = 1, -- Generator ESP outline opacity
    genHue = 33, -- Generator ESP color hue in degrees (33 = orange)
    textOpacity = 1, -- overhead text opacity
    textSize = 13, -- overhead text size
    camFov = 70, -- camera field of view (used by Custom FOV)
    freecamSpeed = 50, -- freecam move speed (studs/second)
    viewLineLength = 60, -- View Line length in studs
    hitboxSize = 8, -- Hitbox Extender: size (studs) of each extended part
    hitboxTransparency = 0.7, -- Hitbox Extender: how see-through the extended parts are
    hitboxBoxOpacity = 0.4, -- Hitbox Extender: opacity of the always-visible hitbox box
    crosshairSize = 3, -- crosshair dot radius
    crosshairOpacity = 1, -- crosshair dot opacity
    crosshairHue = 0, -- crosshair color hue in degrees
    crosshairSat = 0, -- crosshair color saturation (0 = white)
}

-- Shared state table (helper functions are added to it further down).
local ESPX = {}
ESPX.toggleList = {}   -- every createToggle(): {name, key}, in creation order
ESPX.togglePaints = {} -- [key] = function that repaints the toggle
ESPX.toggleFlips = {}  -- [key] = function that flips the toggle exactly like clicking it
ESPX.sliders = {}      -- sliders that can be reset: {key, set}
-- Snapshot of the built-in defaults, taken before saved settings are loaded (for "Reset to Defaults").
ESPX.defaultToggles = {}
for key, value in pairs(toggles) do ESPX.defaultToggles[key] = value end
ESPX.defaultCfg = {}
for key, value in pairs(cfg) do
    if type(value) == "number" then ESPX.defaultCfg[key] = value end
end

-- Restore only known, serializable settings; preserve defaults for missing/invalid values.
if type(loadedSettings.toggles) == "table" then
    for key, value in pairs(loadedSettings.toggles) do
        if toggles[key] ~= nil and type(value) == "boolean" then toggles[key] = value end
    end
end
if type(loadedSettings.cfg) == "table" then
    for key, value in pairs(loadedSettings.cfg) do
        if type(cfg[key]) == "number" and type(value) == "number" then cfg[key] = value end
    end
end
if type(loadedSettings.flySpeed) == "number" then flySpeed = math.clamp(loadedSettings.flySpeed, 1, 200) end

-- Shared helpers: overhead text style and ESP colors.
-- Service connections are registered here so Terminate can disconnect every one of them.
ESPX.conns = {}
function ESPX.track(connection)
    ESPX.conns[#ESPX.conns + 1] = connection
    return connection
end

-- Noclip keeps a cached list of the character's parts instead of re-walking it every frame.
ESPX.noclipParts = {}
ESPX.noclipChar = nil
ESPX.noclipBuilt = 0

-- Overhead text: one master toggle, opacity and size for every floating label.
function ESPX.styleText(label, gui)
    if gui then gui.Enabled = toggles.OverheadText end
    if label then
        local t = 1 - math.clamp(cfg.textOpacity, 0, 1)
        label.TextTransparency = t
        label.TextStrokeTransparency = t
        label.TextSize = cfg.textSize
    end
end

function ESPX.teamKey(player)
    if player.Team then return "team:" .. player.Team:GetFullName() end
    if player.TeamColor and player.TeamColor ~= BrickColor.new("Medium stone grey") then
        return "color:" .. player.TeamColor.Name
    end
    for _, attrName in ipairs({"Team", "team", "Faction", "faction", "Role", "role"}) do
        local value = player:GetAttribute(attrName)
        if value ~= nil then return attrName:lower() .. ":" .. tostring(value):lower() end
    end
    return nil
end

function ESPX.playerColor(plr)
    local myTeam, playerTeam = ESPX.teamKey(lplr), ESPX.teamKey(plr)
    if myTeam and playerTeam then
        return myTeam == playerTeam and Color3.fromRGB(0, 120, 255) or Color3.fromRGB(220, 50, 50)
    end
    return Color3.fromRGB(0, 200, 80)
end

local function saveSettings()
    if terminated then return false end
    if type(writefile) ~= "function" then return false end

    -- JSONEncode cannot serialize Color3 / other Roblox datatypes in cfg.
    -- Save only the numeric config fields that this menu actually edits.
    local numericCfg = {
        aimStrength = cfg.aimStrength,
        fov = cfg.fov,
        speed = cfg.speed,
        gatherDistance = cfg.gatherDistance,
        npcFillOpacity = cfg.npcFillOpacity,
        npcOutlineOpacity = cfg.npcOutlineOpacity,
        playerFillOpacity = cfg.playerFillOpacity,
        playerOutlineOpacity = cfg.playerOutlineOpacity,
        genFillOpacity = cfg.genFillOpacity,
        genOutlineOpacity = cfg.genOutlineOpacity,
        genHue = cfg.genHue,
        textOpacity = cfg.textOpacity,
        textSize = cfg.textSize,
        camFov = cfg.camFov,
        freecamSpeed = cfg.freecamSpeed,
        viewLineLength = cfg.viewLineLength,
        hitboxSize = cfg.hitboxSize,
        hitboxTransparency = cfg.hitboxTransparency,
        hitboxBoxOpacity = cfg.hitboxBoxOpacity,
        crosshairSize = cfg.crosshairSize,
        crosshairOpacity = cfg.crosshairOpacity,
        crosshairHue = cfg.crosshairHue,
        crosshairSat = cfg.crosshairSat,
    }
    local payload = {
        toggles = toggles,
        cfg = numericCfg,
        flySpeed = flySpeed,
    }

    local ok, encoded = pcall(function()
        return HttpService:JSONEncode(payload)
    end)
    if not ok then
        warn("[BLACKWALL] Could not encode settings: " .. tostring(encoded))
        return false
    end

    local writeOk, writeErr = pcall(writefile, settingsFile, encoded)
    if not writeOk then
        warn("[BLACKWALL] Could not write settings file: " .. tostring(writeErr))
        return false
    end
    return true
end

-- Sliders call this while dragging: wait until the value stops changing, then write the file once.
ESPX.saveToken = 0
function ESPX.queueSave()
    ESPX.saveToken += 1
    local token = ESPX.saveToken
    task.delay(0.6, function()
        if token == ESPX.saveToken and not terminated then saveSettings() end
    end)
end

-- UI ONLY: refreshed HRSH interface. Feature logic below this block is unchanged.
local oldGui = cg:FindFirstChild("OmniMenu")
if oldGui then oldGui:Destroy() end

local C = {
    -- BLACKWALL palette: pitch-black surfaces, red UI accents, cyan TRUE, red FALSE
    bg = Color3.fromRGB(0, 0, 0),
    panel = Color3.fromRGB(7, 7, 8),
    panel2 = Color3.fromRGB(18, 5, 7),
    hover = Color3.fromRGB(42, 8, 12),
    accent = Color3.fromRGB(220, 24, 42), -- red = general UI accents
    accentDark = Color3.fromRGB(150, 10, 24),
    trueState = Color3.fromRGB(0, 220, 235), -- cyan = TRUE / enabled
    outline = Color3.fromRGB(125, 16, 28),
    text = Color3.fromRGB(242, 242, 245),
    muted = Color3.fromRGB(155, 135, 138),
    off = Color3.fromRGB(220, 24, 42), -- red = FALSE / disabled
    green = Color3.fromRGB(0, 220, 235),
}

-- Blackwall style is hard-edged: UICorner calls are intentionally no-ops.
local function corner(parent, radius)
    return nil
end

local function stroke(parent, color, transparency, thickness)
    local s = Instance.new("UIStroke")
    s.Color = color or C.hover
    s.Transparency = transparency or 0
    s.Thickness = thickness or 1
    s.Parent = parent
    return s
end

local gui = Instance.new("ScreenGui")
gui.Name = "OmniMenu"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999999
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = cg

local TweenService = game:GetService("TweenService")

local main = Instance.new("Frame")
main.Name = "main"
main.Parent = gui
main.BackgroundColor3 = Color3.fromRGB(255, 255, 255) -- colored by the gradient below
main.BorderSizePixel = 0
main.Position = UDim2.new(0.035, 0, 0.12, 0)
main.Size = UDim2.new(0, 390, 0, 560)
main.Active = true
main.Draggable = false
main.ClipsDescendants = true
stroke(main, C.outline, 0.05, 1)
local sizeConstraint = Instance.new("UISizeConstraint")
sizeConstraint.Parent = main
sizeConstraint.MinSize = Vector2.new(320, 360)
sizeConstraint.MaxSize = Vector2.new(460, 760)

-- Pitch black fading into a faint blood-red haze at the bottom.
local mainGradient = Instance.new("UIGradient")
mainGradient.Rotation = 90
mainGradient.Color = ColorSequence.new(Color3.fromRGB(0, 0, 0), Color3.fromRGB(26, 2, 6))
mainGradient.Parent = main

local topAccent = Instance.new("Frame")
topAccent.Parent = main
topAccent.Size = UDim2.new(1, 0, 0, 2)
topAccent.BackgroundColor3 = C.accent
topAccent.BorderSizePixel = 0
topAccent.ZIndex = 4

-- Header ---------------------------------------------------------------
local header = Instance.new("Frame")
header.Parent = main
header.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
header.BorderSizePixel = 0
header.Position = UDim2.new(0, 0, 0, 3)
header.Size = UDim2.new(1, 0, 0, 58)
header.ZIndex = 3
local headerGradient = Instance.new("UIGradient")
headerGradient.Color = ColorSequence.new(Color3.fromRGB(7, 7, 8), Color3.fromRGB(58, 5, 12))
headerGradient.Parent = header

local headerLine = Instance.new("Frame")
headerLine.Parent = header
headerLine.AnchorPoint = Vector2.new(0, 1)
headerLine.Position = UDim2.new(0, 0, 1, 0)
headerLine.Size = UDim2.new(1, 0, 0, 1)
headerLine.BackgroundColor3 = C.outline
headerLine.BorderSizePixel = 0
headerLine.ZIndex = 4

local logo = Instance.new("Frame")
logo.Parent = header
logo.Position = UDim2.new(0, 12, 0, 12)
logo.Size = UDim2.new(0, 32, 0, 32)
logo.BackgroundColor3 = C.bg
logo.BorderSizePixel = 0
logo.ZIndex = 4
stroke(logo, C.accent, 0, 1)
-- Emblem built from frames (no font glyph needed): a diamond "ICE eye" with a pulsing core.
local logoRing = Instance.new("Frame")
logoRing.Parent = logo
logoRing.AnchorPoint = Vector2.new(0.5, 0.5)
logoRing.Position = UDim2.new(0.5, 0, 0.5, 0)
logoRing.Size = UDim2.new(0, 16, 0, 16)
logoRing.Rotation = 45
logoRing.BackgroundTransparency = 1
logoRing.BorderSizePixel = 0
logoRing.ZIndex = 5
stroke(logoRing, C.accent, 0, 2)
local logoCore = Instance.new("Frame")
logoCore.Parent = logo
logoCore.AnchorPoint = Vector2.new(0.5, 0.5)
logoCore.Position = UDim2.new(0.5, 0, 0.5, 0)
logoCore.Size = UDim2.new(0, 6, 0, 6)
logoCore.Rotation = 45
logoCore.BackgroundColor3 = C.accent
logoCore.BorderSizePixel = 0
logoCore.ZIndex = 6
for _, side in ipairs({0, 1}) do
    local tick = Instance.new("Frame")
    tick.Parent = logo
    tick.AnchorPoint = Vector2.new(side, 0.5)
    tick.Position = UDim2.new(side, 0, 0.5, 0)
    tick.Size = UDim2.new(0, 5, 0, 2)
    tick.BackgroundColor3 = C.accent
    tick.BorderSizePixel = 0
    tick.ZIndex = 5
end

local title = Instance.new("TextLabel")
title.Parent = header
title.BackgroundTransparency = 1
title.Position = UDim2.new(0, 54, 0, 10)
title.Size = UDim2.new(1, -140, 0, 22)
title.Font = Enum.Font.Code
title.Text = "BLACKWALL  //  MAIN SYSTEM"
title.TextColor3 = C.text
title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left
title.ZIndex = 5
local subtitle = Instance.new("TextLabel")
subtitle.Parent = header
subtitle.BackgroundTransparency = 1
subtitle.Position = UDim2.new(0, 54, 0, 33)
subtitle.Size = UDim2.new(1, -140, 0, 14)
subtitle.Font = Enum.Font.Code
subtitle.Text = "UNAUTHORIZED ACCESS  •  RightCTRL Default"
subtitle.TextColor3 = C.muted
subtitle.TextSize = 9
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.ZIndex = 5

-- Hazard stripes + blinking link status (top right of the header).
local stripes = Instance.new("TextLabel")
stripes.Parent = header
stripes.BackgroundTransparency = 1
stripes.AnchorPoint = Vector2.new(1, 0)
stripes.Position = UDim2.new(1, -12, 0, 9)
stripes.Size = UDim2.new(0, 80, 0, 16)
stripes.Font = Enum.Font.Code
stripes.Text = "////////"
stripes.TextColor3 = C.accent
stripes.TextTransparency = 0.35
stripes.TextSize = 14
stripes.TextXAlignment = Enum.TextXAlignment.Right
stripes.ZIndex = 5
local linkStatus = Instance.new("TextLabel")
linkStatus.Parent = header
linkStatus.BackgroundTransparency = 1
linkStatus.AnchorPoint = Vector2.new(1, 0)
linkStatus.Position = UDim2.new(1, -12, 0, 31)
linkStatus.Size = UDim2.new(0, 80, 0, 14)
linkStatus.Font = Enum.Font.Code
linkStatus.Text = "● LINK ACTIVE"
linkStatus.TextColor3 = C.trueState
linkStatus.TextSize = 9
linkStatus.TextXAlignment = Enum.TextXAlignment.Right
linkStatus.ZIndex = 5

-- Corner brackets
local function addBracket(parent, ax, ay)
    for _, size in ipairs({Vector2.new(14, 2), Vector2.new(2, 14)}) do
        local f = Instance.new("Frame")
        f.Parent = parent
        f.AnchorPoint = Vector2.new(ax, ay)
        f.Position = UDim2.new(ax, 0, ay, 0)
        f.Size = UDim2.new(0, size.X, 0, size.Y)
        f.BackgroundColor3 = C.accent
        f.BorderSizePixel = 0
        f.ZIndex = 60
    end
end
addBracket(main, 0, 0)
addBracket(main, 1, 0)
addBracket(main, 0, 1)
addBracket(main, 1, 1)

-- Slow red scanline sweeping down the panel (does not block input).
local scanline = Instance.new("Frame")
scanline.Name = "Scanline"
scanline.Parent = main
scanline.BackgroundColor3 = C.accent
scanline.BackgroundTransparency = 0.88
scanline.BorderSizePixel = 0
scanline.Active = false
scanline.Size = UDim2.new(1, 0, 0, 2)
scanline.Position = UDim2.new(0, 0, 0, 0)
scanline.ZIndex = 50
TweenService:Create(
    scanline,
    TweenInfo.new(4, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1, false, 0),
    {Position = UDim2.new(0, 0, 1, 0)}
):Play()

-- Occasional title glitch + blinking link light.
task.spawn(function()
    local basePos = title.Position
    while not terminated and title.Parent do
        task.wait(math.random(25, 60) / 10)
        for _ = 1, math.random(2, 4) do
            if terminated or not title.Parent then return end
            title.Position = basePos + UDim2.new(0, math.random(-3, 3), 0, math.random(-1, 1))
            title.TextColor3 = (math.random() > 0.5) and C.accent or C.trueState
            task.wait(0.04)
        end
        if title.Parent then
            title.Position = basePos
            title.TextColor3 = C.text
        end
    end
end)
task.spawn(function()
    local bright = true
    while not terminated and linkStatus.Parent do
        linkStatus.TextTransparency = bright and 0 or 0.65
        logoCore.BackgroundColor3 = bright and C.accent or C.accentDark
        bright = not bright
        task.wait(0.6)
    end
end)

-- Footer: operator name, FPS and ping --------------------------------------
local footer = Instance.new("Frame")
footer.Parent = main
footer.AnchorPoint = Vector2.new(0, 1)
footer.Position = UDim2.new(0, 0, 1, 0)
footer.Size = UDim2.new(1, 0, 0, 20)
footer.BackgroundColor3 = C.panel
footer.BorderSizePixel = 0
footer.ZIndex = 12
local footerLine = Instance.new("Frame")
footerLine.Parent = footer
footerLine.Size = UDim2.new(1, 0, 0, 1)
footerLine.BackgroundColor3 = C.outline
footerLine.BorderSizePixel = 0
footerLine.ZIndex = 13
local footerLeft = Instance.new("TextLabel")
footerLeft.Parent = footer
footerLeft.BackgroundTransparency = 1
footerLeft.Position = UDim2.new(0, 10, 0, 1)
footerLeft.Size = UDim2.new(0.6, 0, 1, -1)
footerLeft.Font = Enum.Font.Code
footerLeft.Text = "NETRUNNER  ▸  " .. string.upper(lplr.Name)
footerLeft.TextColor3 = C.muted
footerLeft.TextSize = 9
footerLeft.TextXAlignment = Enum.TextXAlignment.Left
footerLeft.TextTruncate = Enum.TextTruncate.AtEnd
footerLeft.ZIndex = 13
local footerRight = Instance.new("TextLabel")
footerRight.Parent = footer
footerRight.BackgroundTransparency = 1
footerRight.AnchorPoint = Vector2.new(1, 0)
footerRight.Position = UDim2.new(1, -10, 0, 1)
footerRight.Size = UDim2.new(0.4, 0, 1, -1)
footerRight.Font = Enum.Font.Code
footerRight.Text = "FPS --  |  PING --"
footerRight.TextColor3 = C.accent
footerRight.TextSize = 9
footerRight.TextXAlignment = Enum.TextXAlignment.Right
footerRight.ZIndex = 13

task.spawn(function()
    local frames, elapsed = 0, 0
    local hb = rs.Heartbeat:Connect(function(dt)
        frames += 1
        elapsed += dt
    end)
    while not terminated and footerRight.Parent do
        task.wait(0.5)
        local fps = elapsed > 0 and math.floor(frames / elapsed + 0.5) or 0
        frames, elapsed = 0, 0
        local ping = 0
        pcall(function() ping = math.floor(lplr:GetNetworkPing() * 1000 + 0.5) end)
        if footerRight.Parent then
            footerRight.Text = string.format("FPS %d  |  PING %dms", fps, ping)
        end
    end
    hb:Disconnect()
end)

-- Category tabs: horizontally scrollable so every category remains reachable.
local tabBar = Instance.new("ScrollingFrame")
tabBar.Name = "CategoryTabs"
tabBar.Parent = main
tabBar.BackgroundTransparency = 1
tabBar.BorderSizePixel = 0
tabBar.Position = UDim2.new(0, 8, 0, 65)
tabBar.Size = UDim2.new(1, -16, 0, 32)
tabBar.ZIndex = 8
tabBar.ScrollingDirection = Enum.ScrollingDirection.X
tabBar.ScrollBarThickness = 0
tabBar.ScrollBarImageColor3 = C.accent
tabBar.ScrollBarImageTransparency = 0.15
tabBar.CanvasSize = UDim2.new(0, 0, 0, 0)
tabBar.AutomaticCanvasSize = Enum.AutomaticSize.X
local tabLayout = Instance.new("UIListLayout")
tabLayout.Parent = tabBar
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabLayout.Padding = UDim.new(0, 5)
tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left

local tabDivider = Instance.new("Frame")
tabDivider.Parent = main
tabDivider.Position = UDim2.new(0, 8, 0, 100)
tabDivider.Size = UDim2.new(1, -16, 0, 1)
tabDivider.BackgroundColor3 = C.outline
tabDivider.BackgroundTransparency = 0.35
tabDivider.BorderSizePixel = 0
tabDivider.ZIndex = 8

-- Only the title/header strip and the footer can drag the menu.
-- Content controls (including the 3D avatar viewport) never initiate window dragging.
local menuDragging = false
local menuDragStart = nil
local menuStartPosition = nil
local function beginMenuDrag(input)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1
        and input.UserInputType ~= Enum.UserInputType.Touch then return end
    menuDragging = true
    menuDragStart = input.Position
    menuStartPosition = main.Position
end
header.InputBegan:Connect(beginMenuDrag)
footer.InputBegan:Connect(beginMenuDrag)
ESPX.track(uis.InputChanged:Connect(function(input)
    if menuDragging and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - menuDragStart
        main.Position = UDim2.new(
            menuStartPosition.X.Scale, menuStartPosition.X.Offset + delta.X,
            menuStartPosition.Y.Scale, menuStartPosition.Y.Offset + delta.Y
        )
    end
end))
ESPX.track(uis.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        menuDragging = false
    end
end))

local tabPages = {}
local tabButtons = {}
local tabIndicators = {}
local activeTab = "Main"
local scroll, layout
local function setTab(name)
    activeTab = name
    for tabName, page in pairs(tabPages) do
        page.Visible = (tabName == name)
    end
    for tabName, button in pairs(tabButtons) do
        local selected = tabName == name
        button.BackgroundColor3 = selected and C.hover or C.panel
        button.TextColor3 = selected and C.text or C.muted
        tabIndicators[tabName].Visible = selected
    end
    scroll = tabPages[name]
    layout = scroll and scroll:FindFirstChildOfClass("UIListLayout")
end

for order, name in ipairs({"Main", "Visual", "Movement", "Overwatch", "Settings", "Binds"}) do
    local page = Instance.new("ScrollingFrame")
    page.Name = name .. "Page"
    page.Parent = main
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.Position = UDim2.new(0, 0, 0, 105)
    page.Size = UDim2.new(1, 0, 1, -129)
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.ScrollBarThickness = 3
    page.ScrollBarImageColor3 = C.accent
    page.ScrollBarImageTransparency = 0
    page.ScrollingEnabled = true
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.Visible = false
    page.ZIndex = 5
    local pageLayout = Instance.new("UIListLayout")
    pageLayout.Parent = page
    pageLayout.Padding = UDim.new(0, 4)
    pageLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    pageLayout.SortOrder = Enum.SortOrder.LayoutOrder
    local pagePadding = Instance.new("UIPadding")
    pagePadding.Parent = page
    pagePadding.PaddingTop = UDim.new(0, 6)
    pagePadding.PaddingBottom = UDim.new(0, 8)

    local button = Instance.new("TextButton")
    button.Name = name .. "Tab"
    button.Parent = tabBar
    button.LayoutOrder = order
    local tabWidths = {Main = 46, Visual = 52, Movement = 62, Overwatch = 76, Settings = 54, Binds = 46}
    button.Size = UDim2.new(0, tabWidths[name] or 60, 1, 0)
    button.BackgroundColor3 = C.panel
    button.BorderSizePixel = 0
    button.AutoButtonColor = false
    button.Font = Enum.Font.Code
    button.Text = string.upper(name)
    button.TextSize = 10
    button.TextColor3 = C.muted
    button.ZIndex = 9
    stroke(button, C.outline, 0.4, 1)

    -- Bottom indicator bar for the active tab.
    local indicator = Instance.new("Frame")
    indicator.Name = "Indicator"
    indicator.Parent = button
    indicator.AnchorPoint = Vector2.new(0, 1)
    indicator.Position = UDim2.new(0, 0, 1, 0)
    indicator.Size = UDim2.new(1, 0, 0, 2)
    indicator.BackgroundColor3 = C.accent
    indicator.BorderSizePixel = 0
    indicator.Visible = false
    indicator.ZIndex = 10

    button.MouseButton1Click:Connect(function() setTab(name) end)
    button.MouseEnter:Connect(function()
        if activeTab ~= name then button.TextColor3 = C.text end
    end)
    button.MouseLeave:Connect(function()
        if activeTab ~= name then button.TextColor3 = C.muted end
    end)
    tabPages[name] = page
    tabButtons[name] = button
    tabIndicators[name] = indicator
end
setTab("Main")

-- Section header: red notch, "// TITLE", and a rule with a bright leading segment.
local function createSection(name)
    local clean = (string.gsub(string.gsub(name, "^%[%s*", ""), "%s*%]$", ""))
    local wrap = Instance.new("Frame")
    wrap.Parent = scroll
    wrap.BackgroundTransparency = 1
    wrap.Size = UDim2.new(1, -20, 0, 26)
    wrap.BorderSizePixel = 0
    local notch = Instance.new("Frame")
    notch.Parent = wrap
    notch.BackgroundColor3 = C.accent
    notch.BorderSizePixel = 0
    notch.Position = UDim2.new(0, 1, 0, 6)
    notch.Size = UDim2.new(0, 6, 0, 10)
    local lbl = Instance.new("TextLabel")
    lbl.Parent = wrap
    lbl.BackgroundTransparency = 1
    lbl.Position = UDim2.new(0, 14, 0, 0)
    lbl.Size = UDim2.new(1, -14, 0, 22)
    lbl.Font = Enum.Font.Code
    lbl.Text = "// " .. string.upper(clean)
    lbl.TextColor3 = C.accent
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    local rule = Instance.new("Frame")
    rule.Parent = wrap
    rule.BackgroundColor3 = C.outline
    rule.BackgroundTransparency = 0.35
    rule.BorderSizePixel = 0
    rule.Position = UDim2.new(0, 0, 1, -3)
    rule.Size = UDim2.new(1, 0, 0, 1)
    local ruleLead = Instance.new("Frame")
    ruleLead.Parent = wrap
    ruleLead.BackgroundColor3 = C.accent
    ruleLead.BorderSizePixel = 0
    ruleLead.Position = UDim2.new(0, 0, 1, -3)
    ruleLead.Size = UDim2.new(0, 36, 0, 1)
end

local function createActionButton(name, callback)
    local danger = (name == "Terminate")
    local prefix = "> "
    local baseText = danger and C.accent or C.text
    local baseBg = danger and C.panel2 or C.panel

    local b = Instance.new("TextButton")
    b.Parent = scroll
    b.BackgroundColor3 = baseBg
    b.Size = UDim2.new(1, -20, 0, 36)
    b.Font = Enum.Font.Code
    b.Text = prefix .. name
    b.TextColor3 = baseText
    b.TextSize = 12
    b.TextXAlignment = Enum.TextXAlignment.Left
    b.BorderSizePixel = 0
    b.ZIndex = 7
    b.AutoButtonColor = false
    local pad = Instance.new("UIPadding")
    pad.Parent = b
    pad.PaddingLeft = UDim.new(0, 14)
    local edge = stroke(b, C.outline, 0.12, 1)
    local bar = Instance.new("Frame")
    bar.Parent = b
    bar.BackgroundColor3 = danger and C.accent or C.accentDark
    bar.BorderSizePixel = 0
    bar.Position = UDim2.new(0, -14, 0, 0)
    bar.Size = UDim2.new(0, 3, 1, 0)
    bar.ZIndex = 8

    b.MouseEnter:Connect(function()
        b.BackgroundColor3 = C.hover
        b.TextColor3 = Color3.fromRGB(255, 255, 255)
        bar.BackgroundColor3 = C.accent
        edge.Color = C.accent
    end)
    b.MouseLeave:Connect(function()
        b.BackgroundColor3 = baseBg
        b.TextColor3 = baseText
        bar.BackgroundColor3 = danger and C.accent or C.accentDark
        edge.Color = C.outline
    end)
    b.MouseButton1Click:Connect(function()
        local ok, message = pcall(callback)
        b.Text = prefix .. name .. "  " .. (ok and (type(message) == "string" and message or "[DONE]") or "[ERROR]")
        if not ok then warn("[BLACKWALL] " .. tostring(message)) end
        task.delay(1.5, function()
            if b and b.Parent then b.Text = prefix .. name end
        end)
    end)
    return b
end

-- Toggle: status bar on the left, [ ON ] / [ OFF ] readout on the right.
local function createToggle(name, key)
    local b = Instance.new("TextButton")
    b.Parent = scroll
    b.BackgroundColor3 = C.panel
    b.Size = UDim2.new(1, -20, 0, 34)
    b.Font = Enum.Font.Code
    b.Text = ""
    b.TextColor3 = C.text
    b.TextSize = 12
    b.BorderSizePixel = 0
    b.ZIndex = 7
    b.AutoButtonColor = false
    local edge = stroke(b, C.outline, 0.2, 1)

    local bar = Instance.new("Frame")
    bar.Parent = b
    bar.BorderSizePixel = 0
    bar.Size = UDim2.new(0, 3, 1, 0)
    bar.ZIndex = 8

    local label = Instance.new("TextLabel")
    label.Parent = b
    label.BackgroundTransparency = 1
    label.Position = UDim2.new(0, 14, 0, 0)
    label.Size = UDim2.new(1, -90, 1, 0)
    label.Font = Enum.Font.Code
    label.Text = name
    label.TextColor3 = C.text
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.ZIndex = 8

    local status = Instance.new("TextLabel")
    status.Parent = b
    status.BackgroundTransparency = 1
    status.AnchorPoint = Vector2.new(1, 0.5)
    status.Position = UDim2.new(1, -10, 0.5, 0)
    status.Size = UDim2.new(0, 64, 0, 16)
    status.Font = Enum.Font.Code
    status.TextSize = 11
    status.TextXAlignment = Enum.TextXAlignment.Right
    status.ZIndex = 8

    local function paint()
        local on = toggles[key]
        status.Text = on and "[ ON ]" or "[ OFF ]"
        status.TextColor3 = on and C.trueState or C.off
        bar.BackgroundColor3 = on and C.trueState or C.off
        b.BackgroundColor3 = on and Color3.fromRGB(0, 18, 22) or C.panel
        edge.Color = on and C.trueState or C.outline
        edge.Transparency = on and 0.35 or 0.2
    end
    paint()
    b.MouseEnter:Connect(function()
        if not toggles[key] then
            b.BackgroundColor3 = C.panel2
            edge.Color = C.accent
        end
    end)
    b.MouseLeave:Connect(paint)
    local function flip()
        toggles[key] = not toggles[key]
        saveSettings()
        paint()
        if key == "ESP" and not toggles.ESP then
            for _, v in ipairs(ws:GetDescendants()) do
                if v.Name == "NPCHighlight" then v:Destroy() end
            end
        end
    end
    ESPX.toggleList[#ESPX.toggleList + 1] = {name = name, key = key}
    ESPX.togglePaints[key] = paint
    ESPX.toggleFlips[key] = flip
    b.MouseButton1Click:Connect(flip)
end

-- Slider: thin rail, red fill, diamond thumb and tick marks. Click anywhere on the rail or drag.
local function createSlider(name, minV, maxV, def, cb, key)
    local container = Instance.new("Frame")
    container.Parent = scroll
    container.BackgroundColor3 = C.panel
    container.Size = UDim2.new(1, -20, 0, 60)
    container.BorderSizePixel = 0
    container.ZIndex = 6
    stroke(container, C.outline, 0.15, 1)

    local sideBar = Instance.new("Frame")
    sideBar.Parent = container
    sideBar.BackgroundColor3 = C.accentDark
    sideBar.BorderSizePixel = 0
    sideBar.Size = UDim2.new(0, 3, 1, 0)
    sideBar.ZIndex = 7

    local lbl = Instance.new("TextLabel")
    lbl.Parent = container
    lbl.BackgroundTransparency = 1
    lbl.Position = UDim2.new(0, 14, 0, 7)
    lbl.Size = UDim2.new(1, -100, 0, 19)
    lbl.Font = Enum.Font.Code
    lbl.Text = name
    lbl.TextColor3 = C.text
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 7

    local valueBox = Instance.new("TextLabel")
    valueBox.Parent = container
    valueBox.AnchorPoint = Vector2.new(1, 0)
    valueBox.Position = UDim2.new(1, -11, 0, 7)
    valueBox.Size = UDim2.new(0, 62, 0, 18)
    valueBox.BackgroundColor3 = C.bg
    valueBox.BorderSizePixel = 0
    valueBox.Font = Enum.Font.Code
    valueBox.TextColor3 = C.accent
    valueBox.TextSize = 11
    valueBox.Text = tostring(def)
    valueBox.ZIndex = 8
    stroke(valueBox, C.outline, 0.2, 1)

    -- Transparent hit area so the rail is easy to click.
    local back = Instance.new("TextButton")
    back.Parent = container
    back.AutoButtonColor = false
    back.Text = ""
    back.BackgroundTransparency = 1
    back.Position = UDim2.new(0, 14, 0, 32)
    back.Size = UDim2.new(1, -28, 0, 18)
    back.BorderSizePixel = 0
    back.ZIndex = 7

    local rail = Instance.new("Frame")
    rail.Parent = back
    rail.AnchorPoint = Vector2.new(0, 0.5)
    rail.Position = UDim2.new(0, 0, 0.5, 0)
    rail.Size = UDim2.new(1, 0, 0, 4)
    rail.BackgroundColor3 = Color3.fromRGB(40, 8, 12)
    rail.BorderSizePixel = 0
    rail.ZIndex = 7

    local ratio0 = math.clamp((def - minV) / (maxV - minV), 0, 1)
    local fill = Instance.new("Frame")
    fill.Parent = rail
    fill.BackgroundColor3 = C.accent
    fill.Size = UDim2.new(ratio0, 0, 1, 0)
    fill.BorderSizePixel = 0
    fill.ZIndex = 8

    -- Tick marks every 10%.
    local ticks = Instance.new("Frame")
    ticks.Parent = container
    ticks.BackgroundTransparency = 1
    ticks.Position = UDim2.new(0, 14, 0, 51)
    ticks.Size = UDim2.new(1, -28, 0, 4)
    ticks.ZIndex = 7
    for i = 0, 10 do
        local tick = Instance.new("Frame")
        tick.Parent = ticks
        tick.AnchorPoint = Vector2.new(0.5, 0)
        tick.Position = UDim2.new(i / 10, 0, 0, 0)
        tick.Size = UDim2.new(0, 1, 0, (i % 5 == 0) and 4 or 2)
        tick.BackgroundColor3 = C.outline
        tick.BorderSizePixel = 0
        tick.ZIndex = 7
    end

    local thumb = Instance.new("Frame")
    thumb.Parent = back
    thumb.AnchorPoint = Vector2.new(0.5, 0.5)
    thumb.Position = UDim2.new(ratio0, 0, 0.5, 0)
    thumb.Size = UDim2.new(0, 9, 0, 9)
    thumb.Rotation = 45
    thumb.BackgroundColor3 = C.text
    thumb.BorderSizePixel = 0
    thumb.ZIndex = 9
    stroke(thumb, C.accent, 0, 2)

    local dragging = false
    local function updateFromX(x)
        local width = math.max(1, back.AbsoluteSize.X)
        local pos = math.clamp((x - back.AbsolutePosition.X) / width, 0, 1)
        local val = minV + (maxV - minV) * pos
        val = math.floor(val * 100 + 0.5) / 100
        if maxV - minV >= 10 then val = math.floor(val + 0.5) end
        local ratio = math.clamp((val - minV) / (maxV - minV), 0, 1)
        fill.Size = UDim2.new(ratio, 0, 1, 0)
        thumb.Position = UDim2.new(ratio, 0, 0.5, 0)
        valueBox.Text = tostring(val)
        if cb then cb(val) end
        ESPX.queueSave()
    end
    if key then
        ESPX.sliders[#ESPX.sliders + 1] = {
            key = key,
            set = function(val) -- used by Reset to Defaults (does not write the settings file)
                local ratio = math.clamp((val - minV) / (maxV - minV), 0, 1)
                fill.Size = UDim2.new(ratio, 0, 1, 0)
                thumb.Position = UDim2.new(ratio, 0, 0.5, 0)
                valueBox.Text = tostring(val)
                if cb then cb(val) end
            end,
        }
    end
    back.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            updateFromX(input.Position.X)
        end
    end)
    thumb.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            updateFromX(input.Position.X)
        end
    end)
    ESPX.track(uis.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end))
    ESPX.track(uis.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateFromX(input.Position.X)
        end
    end))
end

-- Main: ESP, targeting, and other visual/utility controls.
setTab("Main")
createSection("[ UTILITY ]")
createToggle("Aim Assist", "AimAssist")
createToggle("Instant Interact", "InstantInteract")
createToggle("Anti AFK", "AntiAFK")
createToggle("Del Corpses", "DelCorpses")
createToggle("Gather NPCs", "GatherNPCs")
createSection("[ AIM SETTINGS ]")
createSlider("Aim Strength", 0.01, 1.0, cfg.aimStrength, function(v) cfg.aimStrength = v end, "aimStrength")
createSlider("FOV", 10, 300, cfg.fov, function(v) cfg.fov = v end, "fov")
createSlider("Gather Distance", 1, 30, cfg.gatherDistance, function(v) cfg.gatherDistance = v end, "gatherDistance")
createSection("[ HITBOX EXTENDER ]")
createToggle("Hitbox Extender", "HitboxExtender")
createToggle("Extend Head", "HitboxHead")
createToggle("Extend Body", "HitboxBody")
createToggle("Extend Legs", "HitboxLegs")
createToggle("Show Hitbox", "HitboxVisual")
createSlider("Hitbox Size", 2, 30, cfg.hitboxSize, function(v) cfg.hitboxSize = v end, "hitboxSize")
createSlider("Hitbox Transparency", 0, 1, cfg.hitboxTransparency, function(v) cfg.hitboxTransparency = v end, "hitboxTransparency")
createSlider("Hitbox Box Opacity", 0, 1, cfg.hitboxBoxOpacity, function(v) cfg.hitboxBoxOpacity = v end, "hitboxBoxOpacity")

-- Visual: every ESP / overlay / on-screen display option lives here.
setTab("Visual")
createSection("[ VISUALS ]")
createToggle("NPC ESP", "ESP")
createToggle("Enemy HP", "EnemyHP")
createToggle("Player ESP", "PlayerESP")
createToggle("My HP", "SelfHP")
createToggle("Item ESP", "ItemESP")
createToggle("Generator ESP", "GeneratorESP")
createToggle("Head Arrow", "HeadArrow")
createSection("[ VIEW LINE ]")
createToggle("View Line", "ViewLine")
createSlider("View Line Length", 10, 300, cfg.viewLineLength, function(v) cfg.viewLineLength = v end, "viewLineLength")
createSection("[ WORLD ]")
createToggle("Fullbright", "Fullbright")
createToggle("No Fog", "NoFog")
createToggle("Custom FOV", "CustomFOV")
createSlider("Camera FOV", 30, 120, cfg.camFov, function(v) cfg.camFov = v end, "camFov")
createSection("[ CROSSHAIR ]")
createToggle("Crosshair", "Crosshair")
createSlider("Crosshair Size", 1, 12, cfg.crosshairSize, function(v) cfg.crosshairSize = v end, "crosshairSize")
createSlider("Crosshair Opacity", 0, 1, cfg.crosshairOpacity, function(v) cfg.crosshairOpacity = v end, "crosshairOpacity")
createSlider("Crosshair Hue", 0, 360, cfg.crosshairHue, function(v) cfg.crosshairHue = v end, "crosshairHue")
createSlider("Crosshair Saturation", 0, 1, cfg.crosshairSat, function(v) cfg.crosshairSat = v end, "crosshairSat")
createSection("[ OVERHEAD TEXT ]")
createToggle("Overhead Text", "OverheadText")
createSlider("Text Opacity", 0, 1, cfg.textOpacity, function(v) cfg.textOpacity = v end, "textOpacity")
createSlider("Text Size", 8, 24, cfg.textSize, function(v) cfg.textSize = v end, "textSize")
createSection("[ NPC ESP SETTINGS ]")
createSlider("NPC Fill Opacity", 0, 1, cfg.npcFillOpacity, function(v) cfg.npcFillOpacity = v end, "npcFillOpacity")
createSlider("NPC Outline Opacity", 0, 1, cfg.npcOutlineOpacity, function(v) cfg.npcOutlineOpacity = v end, "npcOutlineOpacity")
createSection("[ PLAYER ESP SETTINGS ]")
createSlider("Player Fill Opacity", 0, 1, cfg.playerFillOpacity, function(v) cfg.playerFillOpacity = v end, "playerFillOpacity")
createSlider("Player Outline Opacity", 0, 1, cfg.playerOutlineOpacity, function(v) cfg.playerOutlineOpacity = v end, "playerOutlineOpacity")
createSection("[ GENERATOR ESP SETTINGS ]")
createSlider("Fill Opacity", 0, 1, cfg.genFillOpacity, function(v) cfg.genFillOpacity = v end, "genFillOpacity")
createSlider("Outline Opacity", 0, 1, cfg.genOutlineOpacity, function(v) cfg.genOutlineOpacity = v end, "genOutlineOpacity")
createSlider("Color Hue", 0, 360, cfg.genHue, function(v) cfg.genHue = v end, "genHue")

-- Movement: movement toggles and speed controls.
setTab("Movement")
createSection("[ MOVEMENT ]")
createToggle("Noclip", "Noclip")
createToggle("Fly", "Fly")
createToggle("Speed Modifier", "Speed")

createSection("[ MOVEMENT SETTINGS ]")
createSlider("Walk Speed", 1, 100, cfg.speed, function(v) cfg.speed = v end, "speed")
createSlider("Fly Speed", 1, 200, 55, function(v) flySpeed = v end, "flySpeed")

-- Overwatch uses one shared player list for teleporting, spectating, and player info.
setTab("Overwatch")

createSection("[ FREECAM ]")
createToggle("Freecam", "Freecam")
createSlider("Freecam Speed", 1, 300, cfg.freecamSpeed, function(v) cfg.freecamSpeed = v end, "freecamSpeed")
createActionButton("Teleport to Freecam Position", function()
    local target = ESPX.getFreecamPos and ESPX.getFreecamPos()
    if not target then error("Turn Freecam on first") end
    local character = lplr.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then error("Your character is unavailable") end
    -- Keep your current facing, move to where the camera is, and drop any leftover momentum.
    root.CFrame = CFrame.new(target) * (root.CFrame - root.CFrame.Position)
    root.AssemblyLinearVelocity = Vector3.zero
end)

local selectedSpectatePlayer = nil
local updateSpectateInfo

-- The same list below drives both teleport and spectate actions.
createSection("[ PLAYER LIST ]")

local spectateTargetPlayer = nil
local spectateRenderConnection = nil
local spectatePlayerList = Instance.new("Frame")
spectatePlayerList.Name = "OverwatchPlayerList"
spectatePlayerList.Parent = scroll
spectatePlayerList.BackgroundColor3 = C.panel
spectatePlayerList.BorderSizePixel = 0
spectatePlayerList.Size = UDim2.new(1, -20, 0, 180)
spectatePlayerList.ZIndex = 7
corner(spectatePlayerList, 2)
stroke(spectatePlayerList, C.outline, 0.12, 1)

local spectateListScroll = Instance.new("ScrollingFrame")
spectateListScroll.Name = "Players"
spectateListScroll.Parent = spectatePlayerList
spectateListScroll.BackgroundTransparency = 1
spectateListScroll.BorderSizePixel = 0
spectateListScroll.Position = UDim2.new(0, 4, 0, 4)
spectateListScroll.Size = UDim2.new(1, -8, 1, -8)
spectateListScroll.ScrollBarThickness = 4
spectateListScroll.ScrollBarImageColor3 = C.accent
spectateListScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
spectateListScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
spectateListScroll.ScrollingDirection = Enum.ScrollingDirection.Y
spectateListScroll.ZIndex = 8
local spectateListLayout = Instance.new("UIListLayout")
spectateListLayout.Parent = spectateListScroll
spectateListLayout.Padding = UDim.new(0, 3)
spectateListLayout.SortOrder = Enum.SortOrder.LayoutOrder

local spectateInputBeganConnection = nil
local spectateInputEndedConnection = nil
local spectateMouseDeltaConnection = nil
local spectateKeys = {}
local spectateMouseLook = false
local spectateYaw = 0
local spectatePitch = 0
local spectateOrbitDistance = 12
local spectateOrbitHeight = 4
local spectateMouseSensitivity = 0.0035

local function stopSpectating()
    if spectateRenderConnection then
        spectateRenderConnection:Disconnect()
        spectateRenderConnection = nil
    end
    if spectateInputBeganConnection then
        spectateInputBeganConnection:Disconnect()
        spectateInputBeganConnection = nil
    end
    if spectateInputEndedConnection then
        spectateInputEndedConnection:Disconnect()
        spectateInputEndedConnection = nil
    end
    if spectateMouseDeltaConnection then
        spectateMouseDeltaConnection:Disconnect()
        spectateMouseDeltaConnection = nil
    end
    spectateKeys = {}
    spectateMouseLook = false
    pcall(function() uis.MouseBehavior = Enum.MouseBehavior.Default end)
    spectateTargetPlayer = nil

    local camera = ws.CurrentCamera
    if camera then
        camera.CameraType = Enum.CameraType.Custom
        local character = lplr.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if humanoid then camera.CameraSubject = humanoid end
    end
end

local function startSpectating(player)
    if not player or player == lplr or player.Parent ~= plrs then
        error("Select an available player from the list first")
    end
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not root or not humanoid or humanoid.Health <= 0 then
        error("Target character is unavailable")
    end

    stopSpectating()
    spectateTargetPlayer = player
    local camera = ws.CurrentCamera
    if not camera then error("Camera is unavailable") end

    -- Start behind the target. Hold RMB and move the mouse to orbit around them.
    -- Scriptable camera bypasses Roblox's default camera collision pushback (wall noclip).
    local initialPosition = (root.CFrame * CFrame.new(0, spectateOrbitHeight, spectateOrbitDistance)).Position
    local focusPosition = root.Position + Vector3.new(0, 2, 0)
    local initialCFrame = CFrame.lookAt(initialPosition, focusPosition)
    local lookVector = initialCFrame.LookVector
    spectateYaw = math.atan2(-lookVector.X, -lookVector.Z)
    spectatePitch = math.asin(math.clamp(lookVector.Y, -1, 1))
    camera.CameraType = Enum.CameraType.Scriptable
    camera.CFrame = initialCFrame

    spectateInputBeganConnection = uis.InputBegan:Connect(function(input, gameProcessed)
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            spectateMouseLook = true
            pcall(function() uis.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition end)
        end
    end)
    spectateInputEndedConnection = uis.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            spectateMouseLook = false
            pcall(function() uis.MouseBehavior = Enum.MouseBehavior.Default end)
        end
    end)
    spectateMouseDeltaConnection = uis.InputChanged:Connect(function(input, gameProcessed)
        -- MouseWheel input can be marked processed by Roblox UI, so handle it before
        -- the RMB-only rotation check. Zoom remains available while spectating.
        if input.UserInputType == Enum.UserInputType.MouseWheel then
            if spectateMouseLook then
                local wheelDelta = input.Position.Z
                spectateOrbitDistance = math.clamp(
                    spectateOrbitDistance - wheelDelta * 2.5,
                    2.5,
                    40
                )
            end
            return
        end

        if not spectateMouseLook then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            spectateYaw = spectateYaw - input.Delta.X * spectateMouseSensitivity
            spectatePitch = math.clamp(spectatePitch - input.Delta.Y * spectateMouseSensitivity, math.rad(-75), math.rad(75))
        end
    end)

    spectateRenderConnection = rs.RenderStepped:Connect(function()
        local currentCamera = ws.CurrentCamera
        local targetCharacter = spectateTargetPlayer and spectateTargetPlayer.Character
        local targetRoot = targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart")
        local targetHumanoid = targetCharacter and targetCharacter:FindFirstChildOfClass("Humanoid")
        if not currentCamera or not spectateTargetPlayer or spectateTargetPlayer.Parent ~= plrs
            or not targetRoot or not targetHumanoid or targetHumanoid.Health <= 0 then
            stopSpectating()
            return
        end

        currentCamera.CameraType = Enum.CameraType.Scriptable
        -- Orbit position stays a fixed distance from the target; mouse input only changes view angle.
        local rotation = CFrame.fromOrientation(spectatePitch, spectateYaw, 0)
        local focus = targetRoot.Position + Vector3.new(0, 2, 0)
        local orbitOffset = -rotation.LookVector * spectateOrbitDistance + Vector3.new(0, spectateOrbitHeight - 2, 0)
        currentCamera.CFrame = CFrame.lookAt(focus + orbitOffset, focus)
    end)
end

local updateSpectateInfo

local function refreshSpectatePlayers()
    for _, child in ipairs(spectateListScroll:GetChildren()) do
        if child:IsA("TextButton") or child:IsA("TextLabel") then
            child:Destroy()
        end
    end

    local targets = {}
    for _, player in ipairs(plrs:GetPlayers()) do
        if player ~= lplr then
            table.insert(targets, player)
        end
    end
    table.sort(targets, function(a, b)
        return a.Name:lower() < b.Name:lower()
    end)

    local selectionStillValid = false
    for _, player in ipairs(targets) do
        if player == selectedSpectatePlayer then selectionStillValid = true end
    end
    if not selectionStillValid then
        selectedSpectatePlayer = nil
        if updateSpectateInfo then updateSpectateInfo(nil) end
    end

    if #targets == 0 then
        local empty = Instance.new("TextLabel")
        empty.Name = "EmptyPlayerList"
        empty.Parent = spectateListScroll
        empty.Size = UDim2.new(1, -4, 0, 30)
        empty.BackgroundTransparency = 1
        empty.Font = Enum.Font.Code
        empty.Text = "NO OTHER PLAYERS FOUND"
        empty.TextColor3 = C.muted
        empty.TextSize = 12
        empty.ZIndex = 9
        return
    end

    for index, player in ipairs(targets) do
        local selected = player == selectedSpectatePlayer
        local item = Instance.new("TextButton")
        item.Name = "Player_" .. player.UserId
        item.Parent = spectateListScroll
        item.LayoutOrder = index
        item.Size = UDim2.new(1, -4, 0, 30)
        item.BackgroundColor3 = selected and C.panel2 or C.bg
        item.BorderSizePixel = 0
        item.AutoButtonColor = false
        item.Font = Enum.Font.Code
        item.Text = (selected and ">  " or "   ") .. player.Name .. "  (@" .. player.DisplayName .. ")"
        item.TextColor3 = selected and C.trueState or C.text
        item.TextSize = 11
        item.TextXAlignment = Enum.TextXAlignment.Left
        item.ZIndex = 9
        corner(item, 2)
        item.MouseButton1Click:Connect(function()
            if player.Parent ~= plrs then
                refreshSpectatePlayers()
                return
            end
            selectedSpectatePlayer = player
            refreshSpectatePlayers()
            updateSpectateInfo(player)
        end)
    end
end

createActionButton("Refresh Player List", refreshSpectatePlayers)
createActionButton("Teleport to Selected Player", function()
    local player = selectedSpectatePlayer
    if not player or player.Parent ~= plrs then
        error("Select a player from the list first")
    end
    local targetCharacter = player.Character
    local targetRoot = targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart")
    local character = lplr.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not targetRoot then error("Target character is unavailable") end
    if not root or not humanoid or humanoid.Health <= 0 then error("Your character is unavailable") end
    root.CFrame = targetRoot.CFrame * CFrame.new(3, 0, 0)
end)

createActionButton("Spectate Selected Player", function()
    startSpectating(selectedSpectatePlayer)
end)
createActionButton("Stop Spectating", function()
    stopSpectating()
end)

-- Selected-player information card, displayed directly below Stop Spectating.
local spectateInfoCard = Instance.new("Frame")
spectateInfoCard.Name = "SelectedPlayerInfo"
spectateInfoCard.Parent = scroll
spectateInfoCard.BackgroundColor3 = C.panel
spectateInfoCard.BorderSizePixel = 0
spectateInfoCard.Size = UDim2.new(1, -20, 0, 112)
spectateInfoCard.ZIndex = 7
corner(spectateInfoCard, 2)
stroke(spectateInfoCard, C.outline, 0.12, 1)

local spectateAvatar = Instance.new("ImageLabel")
spectateAvatar.Name = "Avatar"
spectateAvatar.Parent = spectateInfoCard
spectateAvatar.BackgroundColor3 = C.bg
spectateAvatar.BorderSizePixel = 0
spectateAvatar.Position = UDim2.new(0, 8, 0, 8)
spectateAvatar.Size = UDim2.new(0, 82, 0, 96)
spectateAvatar.ScaleType = Enum.ScaleType.Fit
spectateAvatar.Image = ""
spectateAvatar.ZIndex = 8
corner(spectateAvatar, 2)

local spectateInfoTitle = Instance.new("TextLabel")
spectateInfoTitle.Name = "InfoTitle"
spectateInfoTitle.Parent = spectateInfoCard
spectateInfoTitle.BackgroundTransparency = 1
spectateInfoTitle.Position = UDim2.new(0, 100, 0, 8)
spectateInfoTitle.Size = UDim2.new(1, -180, 0, 20)
spectateInfoTitle.Font = Enum.Font.Code
spectateInfoTitle.Text = "SELECTED PLAYER INFO"
spectateInfoTitle.TextColor3 = C.accent
spectateInfoTitle.TextSize = 12
spectateInfoTitle.TextXAlignment = Enum.TextXAlignment.Left
spectateInfoTitle.ZIndex = 8

local spectateInfoText = Instance.new("TextLabel")
spectateInfoText.Name = "PlayerDetails"
spectateInfoText.Parent = spectateInfoCard
spectateInfoText.BackgroundTransparency = 1
spectateInfoText.Position = UDim2.new(0, 100, 0, 32)
spectateInfoText.Size = UDim2.new(1, -190, 0, 72)
spectateInfoText.Font = Enum.Font.Code
spectateInfoText.Text = "Choose a player from the list above."
spectateInfoText.TextColor3 = C.muted
spectateInfoText.TextSize = 12
spectateInfoText.TextWrapped = true
spectateInfoText.TextXAlignment = Enum.TextXAlignment.Left
spectateInfoText.TextYAlignment = Enum.TextYAlignment.Top
spectateInfoText.ZIndex = 8

-- Interactive 3D preview of the currently selected player's avatar.
createSection("[ 3D AVATAR PREVIEW ]")
-- Wrapper lets the zoom controls render as normal 2D UI above the 3D viewport.
local avatarPreviewContainer = Instance.new("Frame")
avatarPreviewContainer.Name = "AvatarPreviewContainer"
avatarPreviewContainer.Parent = scroll
avatarPreviewContainer.BackgroundTransparency = 1
avatarPreviewContainer.BorderSizePixel = 0
avatarPreviewContainer.Size = UDim2.new(1, -20, 0, 220)
avatarPreviewContainer.ZIndex = 7

local spectateViewport = Instance.new("ViewportFrame")
spectateViewport.Name = "SelectedPlayer3DAvatar"
spectateViewport.Parent = avatarPreviewContainer
spectateViewport.Position = UDim2.new(0, 0, 0, 0)
spectateViewport.BackgroundColor3 = C.bg
spectateViewport.BorderSizePixel = 0
spectateViewport.Size = UDim2.new(1, 0, 1, 0)
spectateViewport.ZIndex = 7
spectateViewport.Active = true
spectateViewport.Ambient = Color3.fromRGB(170, 170, 170)
spectateViewport.LightColor = Color3.fromRGB(255, 255, 255)
spectateViewport.LightDirection = Vector3.new(-1, -1, -1)
corner(spectateViewport, 2)
stroke(spectateViewport, C.outline, 0.12, 1)

local avatarWorld = Instance.new("WorldModel")
avatarWorld.Parent = spectateViewport
local avatarViewportCamera = Instance.new("Camera")
avatarViewportCamera.Name = "AvatarCamera"
avatarViewportCamera.Parent = spectateViewport
spectateViewport.CurrentCamera = avatarViewportCamera

local avatarPreviewModel = nil
local avatarPreviewYaw = math.rad(180)
local avatarPreviewPitch = math.rad(-5)
local avatarPreviewDistance = 7
local avatarPreviewDragging = false
local avatarPreviewLastX = 0
local avatarPreviewLastY = 0
local avatarPreviewConnections = {}

-- Embedded zoom slider: mouse-wheel input is left alone for menu scrolling.
local avatarZoomMin, avatarZoomMax = 2.5, 20
local avatarZoomDragging = false

local avatarZoomPanel = Instance.new("Frame")
avatarZoomPanel.Name = "AvatarZoomControl"
avatarZoomPanel.Parent = avatarPreviewContainer
avatarZoomPanel.AnchorPoint = Vector2.new(0.5, 1)
avatarZoomPanel.Position = UDim2.new(0.5, 0, 1, -7)
avatarZoomPanel.Size = UDim2.new(1, -18, 0, 32)
avatarZoomPanel.BackgroundColor3 = C.panel
avatarZoomPanel.BackgroundTransparency = 0.12
avatarZoomPanel.BorderSizePixel = 0
avatarZoomPanel.ZIndex = 20
corner(avatarZoomPanel, 3)
stroke(avatarZoomPanel, C.outline, 0.15, 1)

local avatarZoomLabel = Instance.new("TextLabel")
avatarZoomLabel.Parent = avatarZoomPanel
avatarZoomLabel.BackgroundTransparency = 1
avatarZoomLabel.Position = UDim2.new(0, 8, 0, 0)
avatarZoomLabel.Size = UDim2.new(0, 42, 1, 0)
avatarZoomLabel.Font = Enum.Font.Code
avatarZoomLabel.Text = "ZOOM"
avatarZoomLabel.TextColor3 = C.text
avatarZoomLabel.TextSize = 10
avatarZoomLabel.TextXAlignment = Enum.TextXAlignment.Left
avatarZoomLabel.ZIndex = 21

local avatarZoomValue = Instance.new("TextLabel")
avatarZoomValue.Parent = avatarZoomPanel
avatarZoomValue.BackgroundTransparency = 1
avatarZoomValue.AnchorPoint = Vector2.new(1, 0)
avatarZoomValue.Position = UDim2.new(1, -7, 0, 0)
avatarZoomValue.Size = UDim2.new(0, 34, 1, 0)
avatarZoomValue.Font = Enum.Font.Code
avatarZoomValue.Text = "7.0"
avatarZoomValue.TextColor3 = C.accent
avatarZoomValue.TextSize = 10
avatarZoomValue.TextXAlignment = Enum.TextXAlignment.Right
avatarZoomValue.ZIndex = 21

local avatarZoomTrack = Instance.new("TextButton")
avatarZoomTrack.Parent = avatarZoomPanel
avatarZoomTrack.AutoButtonColor = false
avatarZoomTrack.Text = ""
avatarZoomTrack.BackgroundColor3 = C.off
avatarZoomTrack.BorderSizePixel = 0
avatarZoomTrack.Position = UDim2.new(0, 54, 0.5, -3)
avatarZoomTrack.Size = UDim2.new(1, -100, 0, 6)
avatarZoomTrack.ZIndex = 21
corner(avatarZoomTrack, 4)

local avatarZoomFill = Instance.new("Frame")
avatarZoomFill.Parent = avatarZoomTrack
avatarZoomFill.BackgroundColor3 = C.accent
avatarZoomFill.BorderSizePixel = 0
avatarZoomFill.Size = UDim2.new(0.65, 0, 1, 0)
avatarZoomFill.ZIndex = 22
corner(avatarZoomFill, 4)

local avatarZoomThumb = Instance.new("Frame")
avatarZoomThumb.Parent = avatarZoomTrack
avatarZoomThumb.AnchorPoint = Vector2.new(0.5, 0.5)
avatarZoomThumb.Position = UDim2.new(0.65, 0, 0.5, 0)
avatarZoomThumb.Size = UDim2.new(0, 11, 0, 11)
avatarZoomThumb.BackgroundColor3 = C.text
avatarZoomThumb.BorderSizePixel = 0
avatarZoomThumb.ZIndex = 23
corner(avatarZoomThumb, 8)
stroke(avatarZoomThumb, C.accent, 0, 2)

local function updateAvatarZoomSlider()
    local ratio = math.clamp((avatarZoomMax - avatarPreviewDistance) / (avatarZoomMax - avatarZoomMin), 0, 1)
    avatarZoomFill.Size = UDim2.new(ratio, 0, 1, 0)
    avatarZoomThumb.Position = UDim2.new(ratio, 0, 0.5, 0)
    avatarZoomValue.Text = string.format("%.1f", avatarPreviewDistance)
end

local function clearAvatarPreview()
    for _, child in ipairs(avatarWorld:GetChildren()) do
        child:Destroy()
    end
    avatarPreviewModel = nil
end

local function updateAvatarPreviewCamera()
    if not avatarPreviewModel then return end
    local boxCFrame, boxSize = avatarPreviewModel:GetBoundingBox()
    local focus = boxCFrame.Position + Vector3.new(0, boxSize.Y * 0.05, 0)
    -- Full orbit: yaw travels continuously through 360 degrees; pitch allows
    -- looking above and below the avatar without flipping the camera upside down.
    local rotation = CFrame.fromOrientation(avatarPreviewPitch, avatarPreviewYaw, 0)
    local offset = rotation:VectorToWorldSpace(Vector3.new(0, 0, avatarPreviewDistance))
    avatarViewportCamera.CFrame = CFrame.lookAt(focus + offset, focus)
end

local function setAvatarZoomFromX(x)
    local width = math.max(1, avatarZoomTrack.AbsoluteSize.X)
    local ratio = math.clamp((x - avatarZoomTrack.AbsolutePosition.X) / width, 0, 1)
    avatarPreviewDistance = avatarZoomMax - ratio * (avatarZoomMax - avatarZoomMin)
    updateAvatarZoomSlider()
    updateAvatarPreviewCamera()
end

local function showAvatarPreview(player)
    clearAvatarPreview()
    avatarPreviewYaw = math.rad(180)
    avatarPreviewPitch = math.rad(-5)
    avatarPreviewDistance = 7
    updateAvatarZoomSlider()
    if not player or player.Parent ~= plrs then return end

    local character = player.Character
    if not character then return end

    local oldArchivable = character.Archivable
    local clone
    local ok = pcall(function()
        character.Archivable = true
        clone = character:Clone()
        character.Archivable = oldArchivable
    end)
    character.Archivable = oldArchivable
    if not ok or not clone then return end

    clone.Name = "AvatarPreview"
    for _, descendant in ipairs(clone:GetDescendants()) do
        if descendant:IsA("Script") or descendant:IsA("LocalScript") then
            descendant:Destroy()
        elseif descendant:IsA("BasePart") then
            descendant.Anchored = true
            descendant.CanCollide = false
            descendant.CanTouch = false
            descendant.CanQuery = false
        elseif descendant:IsA("Humanoid") then
            descendant.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        end
    end
    clone.Parent = avatarWorld
    avatarPreviewModel = clone

    pcall(function()
        clone:PivotTo(CFrame.new(0, 0, 0))
        local _, size = clone:GetBoundingBox()
        avatarPreviewDistance = math.clamp(math.max(5, size.Magnitude * 0.85), avatarZoomMin, avatarZoomMax)
        updateAvatarZoomSlider()
        updateAvatarPreviewCamera()
    end)
end

-- Drag inside the avatar area to orbit. The embedded slider is the only
-- zoom control; mouse-wheel events are deliberately ignored here.
avatarZoomTrack.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        avatarZoomDragging = true
        setAvatarZoomFromX(input.Position.X)
    end
end)

spectateViewport.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        local p = input.Position
        local panelPos, panelSize = avatarZoomPanel.AbsolutePosition, avatarZoomPanel.AbsoluteSize
        local onZoomControl = p.X >= panelPos.X and p.X <= panelPos.X + panelSize.X
            and p.Y >= panelPos.Y and p.Y <= panelPos.Y + panelSize.Y
        if not onZoomControl then
            avatarPreviewDragging = true
            avatarPreviewLastX = p.X
            avatarPreviewLastY = p.Y
        end
    end
end)

ESPX.track(uis.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        avatarPreviewDragging = false
        avatarZoomDragging = false
    end
end))

table.insert(avatarPreviewConnections, uis.InputChanged:Connect(function(input)
    if avatarZoomDragging and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
        setAvatarZoomFromX(input.Position.X)
    elseif (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) and avatarPreviewDragging then
        local p = input.Position
        local deltaX = p.X - avatarPreviewLastX
        local deltaY = p.Y - avatarPreviewLastY
        avatarPreviewYaw = avatarPreviewYaw - deltaX * 0.012
        avatarPreviewPitch = math.clamp(avatarPreviewPitch - deltaY * 0.01, math.rad(-80), math.rad(80))
        avatarPreviewLastX = p.X
        avatarPreviewLastY = p.Y
        updateAvatarPreviewCamera()
    end
end))

local spectateCopyButton = Instance.new("TextButton")
spectateCopyButton.Name = "CopyPlayerInfo"
spectateCopyButton.Parent = spectateInfoCard
spectateCopyButton.Position = UDim2.new(1, -76, 0, 7)
spectateCopyButton.Size = UDim2.new(0, 66, 0, 24)
spectateCopyButton.BackgroundColor3 = C.accent
spectateCopyButton.BorderSizePixel = 0
spectateCopyButton.AutoButtonColor = true
spectateCopyButton.Font = Enum.Font.Code
spectateCopyButton.Text = "COPY"
spectateCopyButton.TextColor3 = C.bg
spectateCopyButton.TextSize = 13
spectateCopyButton.ZIndex = 20
corner(spectateCopyButton, 2)
stroke(spectateCopyButton, C.outline, 0.12, 1)

spectateCopyButton.MouseButton1Click:Connect(function()
    local player = selectedSpectatePlayer
    if not player or player.Parent ~= plrs then
        spectateCopyButton.Text = "NO PLAYER"
        task.delay(1.2, function()
            if spectateCopyButton.Parent then spectateCopyButton.Text = "COPY" end
        end)
        return
    end

    local info = "Username: @" .. player.Name
        .. "\nDisplay Name: " .. player.DisplayName
        .. "\nUser ID: " .. tostring(player.UserId)

    -- Clipboard functions are provided by some script executors, not standard Roblox Lua.
    local copyFn = setclipboard or toclipboard
    if type(copyFn) == "function" then
        local ok = pcall(copyFn, info)
        spectateCopyButton.Text = ok and "COPIED!" or "FAILED"
    else
        spectateCopyButton.Text = "UNAVAILABLE"
    end
    task.delay(1.5, function()
        if spectateCopyButton.Parent then spectateCopyButton.Text = "COPY" end
    end)
end)

updateSpectateInfo = function(player)
    showAvatarPreview(player)
    if not player or player.Parent ~= plrs then
        spectateAvatar.Image = ""
        spectateInfoText.Text = "Choose a player from the list above."
        return
    end

    spectateInfoText.Text = "Username: @" .. player.Name
        .. "\nDisplay Name: " .. player.DisplayName
        .. "\nUser ID: " .. tostring(player.UserId)

    task.spawn(function()
        local ok, imageUrl = pcall(function()
            local content, _isReady = plrs:GetUserThumbnailAsync(
                player.UserId,
                Enum.ThumbnailType.AvatarThumbnail,
                Enum.ThumbnailSize.Size150x150
            )
            return content
        end)
        -- Do not let a delayed thumbnail overwrite the newly selected player's avatar.
        if ok and selectedSpectatePlayer == player and player.Parent == plrs then
            spectateAvatar.Image = imageUrl
        end
    end)
end

refreshSpectatePlayers()
updateSpectateInfo(selectedSpectatePlayer)
ESPX.track(plrs.PlayerAdded:Connect(refreshSpectatePlayers))
ESPX.track(plrs.PlayerRemoving:Connect(function(player)
    if player == selectedSpectatePlayer then
        selectedSpectatePlayer = nil
        updateSpectateInfo(nil)
    end
    if player == spectateTargetPlayer then stopSpectating() end
    refreshSpectatePlayers()
end))
ESPX.track(lplr.CharacterAdded:Connect(function()
    -- Keep the camera local after respawning if the spectate target vanished.
    if not spectateTargetPlayer then
        task.defer(stopSpectating)
    end
end))

-- Gun tab and its obsolete weapon features have been removed.

-- Settings: menu keybind and performance controls.
setTab("Settings")
-- UI-only keybind selector for showing/hiding this menu.
-- Persist the selected key using executor file APIs when available.
local menuKeyFile = "HRSH_MenuToggleKey.txt"
local function loadMenuToggleKey()
    if type(isfile) == "function" and type(readfile) == "function" then
        local ok, exists = pcall(isfile, menuKeyFile)
        if ok and exists then
            local readOk, savedName = pcall(readfile, menuKeyFile)
            if readOk and type(savedName) == "string" then
                savedName = savedName:gsub("%s+", "")
                local success, keyCode = pcall(function() return Enum.KeyCode[savedName] end)
                if success and keyCode and keyCode ~= Enum.KeyCode.Unknown then
                    return keyCode
                end
            end
        end
    end
    return Enum.KeyCode.RightControl
end

local function saveMenuToggleKey(keyCode)
    if terminated then return end
    if type(writefile) == "function" then
        pcall(writefile, menuKeyFile, keyCode.Name)
    end
end

local menuToggleKey = loadMenuToggleKey()
local waitingForMenuKey = false
local keybindButton = Instance.new("TextButton")
keybindButton.Name = "MenuToggleKeybind"
keybindButton.Parent = scroll
keybindButton.Size = UDim2.new(1, -20, 0, 34)
keybindButton.BackgroundColor3 = C.panel
keybindButton.BorderSizePixel = 0
keybindButton.AutoButtonColor = false
keybindButton.Font = Enum.Font.GothamMedium
keybindButton.Text = ""
keybindButton.ZIndex = 7
corner(keybindButton, 2)
local keybindEdge = stroke(keybindButton, C.outline, 0.25, 1)
local keybindLabel = Instance.new("TextLabel")
keybindLabel.Parent = keybindButton
keybindLabel.BackgroundTransparency = 1
keybindLabel.Position = UDim2.new(0, 12, 0, 0)
keybindLabel.Size = UDim2.new(1, -105, 1, 0)
keybindLabel.Font = Enum.Font.Code
keybindLabel.Text = "Quickhacks"
keybindLabel.TextColor3 = C.text
keybindLabel.TextSize = 13
keybindLabel.TextXAlignment = Enum.TextXAlignment.Left
local keybindValue = Instance.new("TextLabel")
keybindValue.Parent = keybindButton
keybindValue.BackgroundColor3 = C.panel2
keybindValue.Position = UDim2.new(1, -91, 0.5, -12)
keybindValue.Size = UDim2.new(0, 79, 0, 22)
keybindValue.Font = Enum.Font.Code
keybindValue.Text = menuToggleKey.Name
keybindValue.TextColor3 = C.text
keybindValue.TextSize = 10
keybindValue.TextTruncate = Enum.TextTruncate.AtEnd
corner(keybindValue, 2)
keybindButton.MouseButton1Click:Connect(function()
    waitingForMenuKey = true
    keybindValue.Text = "Press key..."
    keybindEdge.Color = C.accent
    keybindEdge.Transparency = 0
end)
keybindButton.MouseEnter:Connect(function() keybindButton.BackgroundColor3 = C.panel2 end)
keybindButton.MouseLeave:Connect(function() keybindButton.BackgroundColor3 = C.panel end)

createSection("[ PERFORMANCE ]")
createToggle("Low Visuals", "LowVisuals")
createToggle("Instance Optimizer", "InstanceOptimizer")
createToggle("Particle Cap", "ParticleCap")
createToggle("Ultra Potato", "UltraPotato")

-- Config: put every toggle and slider back to its built-in default (keybinds are left alone).
function ESPX.resetToDefaults()
    for key, value in pairs(ESPX.defaultCfg) do cfg[key] = value end
    for _, entry in ipairs(ESPX.toggleList) do
        local key = entry.key
        local default = ESPX.defaultToggles[key] == true
        if toggles[key] ~= default then
            toggles[key] = default
            ESPX.togglePaints[key]()
            if key == "ESP" and not default then
                for _, v in ipairs(ws:GetDescendants()) do
                    if v.Name == "NPCHighlight" then v:Destroy() end
                end
            end
        end
    end
    for _, slider in ipairs(ESPX.sliders) do
        local default = (slider.key == "flySpeed") and 55 or ESPX.defaultCfg[slider.key]
        if default ~= nil then slider.set(default) end
    end
    saveSettings()
end

createSection("[ CONFIG ]")
createActionButton("Reset to Defaults", function()
    -- Two clicks within 3 seconds, so a stray click cannot wipe your settings.
    if os.clock() - (ESPX.resetArmedAt or -10) > 3 then
        ESPX.resetArmedAt = os.clock()
        return "[CLICK AGAIN]"
    end
    ESPX.resetArmedAt = nil
    ESPX.resetToDefaults()
    return "[RESET]"
end)

-- Server tools. The server list needs an executor HTTP function (request / http_request / HttpGet).
function ESPX.httpGet(url)
    local requestFn = (type(request) == "function" and request)
        or (type(http_request) == "function" and http_request)
        or (type(syn) == "table" and type(syn.request) == "function" and syn.request)
    if requestFn then
        local response = requestFn({Url = url, Method = "GET"})
        if response and response.Body then return response.Body end
    end
    local ok, body = pcall(function() return game:HttpGet(url) end)
    if ok and type(body) == "string" then return body end
    error("No HTTP request function available in this executor")
end

function ESPX.rejoin()
    local teleportService = game:GetService("TeleportService")
    if #plrs:GetPlayers() <= 1 then
        teleportService:Teleport(game.PlaceId, lplr) -- alone in the server: a new one is created
    else
        teleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, lplr)
    end
end

function ESPX.serverHop()
    local teleportService = game:GetService("TeleportService")
    local url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100", game.PlaceId)
    local data = HttpService:JSONDecode(ESPX.httpGet(url))
    local choices = {}
    for _, server in ipairs(data.data or {}) do
        if server.id ~= game.JobId and server.playing and server.maxPlayers and server.playing < server.maxPlayers then
            choices[#choices + 1] = server.id
        end
    end
    if #choices == 0 then error("No other open servers found") end
    teleportService:TeleportToPlaceInstance(game.PlaceId, choices[math.random(#choices)], lplr)
end

createSection("[ SERVER ]")
createActionButton("Rejoin Server", function() ESPX.rejoin() end)
createActionButton("Server Hop", function() ESPX.serverHop() end)

-- Per-feature keybinds: any toggle in the menu can be bound to a key (saved in HRSH_MenuBinds.json).
do
    local bindsFile = "HRSH_MenuBinds.json"
    local keyButtons = {} -- [toggleKey] = TextButton showing the bound key
    ESPX.binds = {}       -- [toggleKey] = KeyCode name
    ESPX.bindWaiting = nil

    local function showBind(key)
        local button = keyButtons[key]
        if not button then return end
        if ESPX.bindWaiting == key then
            button.Text = "PRESS KEY"
            button.TextColor3 = C.trueState
        else
            local keyName = ESPX.binds[key]
            button.Text = keyName and string.upper(keyName) or "NONE"
            button.TextColor3 = keyName and C.accent or C.muted
        end
    end

    local function saveBinds()
        if terminated or type(writefile) ~= "function" then return end
        pcall(function() writefile(bindsFile, HttpService:JSONEncode(ESPX.binds)) end)
    end

    local function loadBinds()
        if type(isfile) ~= "function" or type(readfile) ~= "function" then return end
        local ok, exists = pcall(isfile, bindsFile)
        if not (ok and exists) then return end
        local readOk, raw = pcall(readfile, bindsFile)
        if not (readOk and type(raw) == "string") then return end
        local decodeOk, data = pcall(function() return HttpService:JSONDecode(raw) end)
        if not (decodeOk and type(data) == "table") then return end
        for key, keyName in pairs(data) do
            if type(key) == "string" and type(keyName) == "string" and ESPX.toggleFlips[key] then
                local valid, keyCode = pcall(function() return Enum.KeyCode[keyName] end)
                if valid and keyCode then ESPX.binds[key] = keyName end
            end
        end
    end

    setTab("Binds")
    createSection("[ FEATURE KEYBINDS ]")
    local hint = Instance.new("TextLabel")
    hint.Parent = scroll
    hint.BackgroundTransparency = 1
    hint.Size = UDim2.new(1, -20, 0, 30)
    hint.Font = Enum.Font.Code
    hint.Text = "Click a key box, then press a key. Esc clears it."
    hint.TextColor3 = C.muted
    hint.TextSize = 10
    hint.TextWrapped = true
    hint.TextXAlignment = Enum.TextXAlignment.Left
    hint.ZIndex = 7

    for _, entry in ipairs(ESPX.toggleList) do
        local row = Instance.new("Frame")
        row.Parent = scroll
        row.BackgroundColor3 = C.panel
        row.BorderSizePixel = 0
        row.Size = UDim2.new(1, -20, 0, 30)
        row.ZIndex = 7
        stroke(row, C.outline, 0.2, 1)
        local rowBar = Instance.new("Frame")
        rowBar.Parent = row
        rowBar.BackgroundColor3 = C.accentDark
        rowBar.BorderSizePixel = 0
        rowBar.Size = UDim2.new(0, 3, 1, 0)
        rowBar.ZIndex = 8
        local rowLabel = Instance.new("TextLabel")
        rowLabel.Parent = row
        rowLabel.BackgroundTransparency = 1
        rowLabel.Position = UDim2.new(0, 14, 0, 0)
        rowLabel.Size = UDim2.new(1, -120, 1, 0)
        rowLabel.Font = Enum.Font.Code
        rowLabel.Text = entry.name
        rowLabel.TextColor3 = C.text
        rowLabel.TextSize = 12
        rowLabel.TextXAlignment = Enum.TextXAlignment.Left
        rowLabel.ZIndex = 8
        local keyButton = Instance.new("TextButton")
        keyButton.Parent = row
        keyButton.AnchorPoint = Vector2.new(1, 0.5)
        keyButton.Position = UDim2.new(1, -8, 0.5, 0)
        keyButton.Size = UDim2.new(0, 92, 0, 20)
        keyButton.BackgroundColor3 = C.bg
        keyButton.BorderSizePixel = 0
        keyButton.AutoButtonColor = false
        keyButton.Font = Enum.Font.Code
        keyButton.TextSize = 11
        keyButton.ZIndex = 8
        stroke(keyButton, C.outline, 0.2, 1)
        keyButtons[entry.key] = keyButton
        keyButton.MouseButton1Click:Connect(function()
            local previous = ESPX.bindWaiting
            ESPX.bindWaiting = entry.key
            if previous then showBind(previous) end
            showBind(entry.key)
        end)
    end

    createActionButton("Clear All Keybinds", function()
        ESPX.binds = {}
        ESPX.bindWaiting = nil
        for key in pairs(keyButtons) do showBind(key) end
        saveBinds()
    end)

    loadBinds()
    for key in pairs(keyButtons) do showBind(key) end

    ESPX.track(uis.InputBegan:Connect(function(input, gpe)
        if terminated or input.UserInputType ~= Enum.UserInputType.Keyboard then return end

        -- Capturing a new bind.
        local waiting = ESPX.bindWaiting
        if waiting then
            ESPX.bindWaiting = nil
            if input.KeyCode == Enum.KeyCode.Escape then
                ESPX.binds[waiting] = nil
            elseif input.KeyCode ~= Enum.KeyCode.Unknown then
                for otherKey, otherName in pairs(ESPX.binds) do
                    if otherName == input.KeyCode.Name and otherKey ~= waiting then
                        ESPX.binds[otherKey] = nil
                        showBind(otherKey)
                    end
                end
                ESPX.binds[waiting] = input.KeyCode.Name
            end
            showBind(waiting)
            saveBinds()
            return
        end

        -- Using a bind (ignored while typing in chat or choosing the menu key).
        if gpe or waitingForMenuKey then return end
        for key, keyName in pairs(ESPX.binds) do
            if input.KeyCode.Name == keyName then
                local flip = ESPX.toggleFlips[key]
                if flip then flip() end
            end
        end
    end))
end
setTab("Main")

ESPX.track(uis.InputBegan:Connect(function(input, gpe)
    if terminated then return end
    if waitingForMenuKey then
        if input.UserInputType == Enum.UserInputType.Keyboard then
            if input.KeyCode == Enum.KeyCode.Escape then
                waitingForMenuKey = false
                keybindValue.Text = menuToggleKey.Name
                keybindEdge.Color = C.hover
                keybindEdge.Transparency = 0.45
                return
            end
            if input.KeyCode ~= Enum.KeyCode.Unknown then
                menuToggleKey = input.KeyCode
                saveMenuToggleKey(menuToggleKey)
                waitingForMenuKey = false
                keybindValue.Text = menuToggleKey.Name
                keybindEdge.Color = C.hover
                keybindEdge.Transparency = 0.45
            end
        end
        return
    end
    if not gpe and input.KeyCode == menuToggleKey then
        main.Visible = not main.Visible
    end
end))

-- Speed modifier
local lastSpeed = false

ESPX.track(uis.InputBegan:Connect(function(input, gpe)
    if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
        if toggles.Speed then
            local hum = lplr.Character and lplr.Character:FindFirstChildOfClass("Humanoid")
            if hum then hum.WalkSpeed = 16 end
        end
    end
end))

ESPX.track(uis.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
        if toggles.Speed then
            local hum = lplr.Character and lplr.Character:FindFirstChildOfClass("Humanoid")
            if hum then hum.WalkSpeed = cfg.speed end
        end
    end
end))

ESPX.track(rs.Heartbeat:Connect(function()
    local char = lplr.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    if toggles.Speed ~= lastSpeed then
        lastSpeed = toggles.Speed
        if not toggles.Speed then
            hum.WalkSpeed = 16
        end
    end

    local shiftHeld = uis:IsKeyDown(Enum.KeyCode.LeftShift) or uis:IsKeyDown(Enum.KeyCode.RightShift)
    if toggles.Speed and not shiftHeld then
        hum.WalkSpeed = cfg.speed
    end
end))

-- Instant Interact
local validTargets = {}

ESPX.track(pps.PromptShown:Connect(function(prompt)
    if toggles.InstantInteract then
        prompt.HoldDuration = 0
    end
end))

-- NPC ESP
local function applyEsp(model)
    if not toggles.ESP then return end
    local hl = model:FindFirstChild("NPCHighlight")
    if not hl then
        hl = Instance.new("Highlight")
        hl.Name = "NPCHighlight"
        hl.Parent = model
    end
    hl.FillColor = cfg.espFill
    hl.OutlineColor = cfg.espOutline
    hl.FillTransparency = 1 - math.clamp(cfg.npcFillOpacity, 0, 1)
    hl.OutlineTransparency = 1 - math.clamp(cfg.npcOutlineOpacity, 0, 1)
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
end

-- Enemy HP ESP
local function addEnemyHPESP(model)
    if not toggles.EnemyHP then return end
    local hum = model:FindFirstChildOfClass("Humanoid")
    local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
    if not hum or not root or hum.Health <= 0 then return end

    local hpGui = root:FindFirstChild("EnemyHPESP")
    if not hpGui then
        hpGui = Instance.new("BillboardGui")
        hpGui.Name = "EnemyHPESP"
        hpGui.Size = UDim2.new(0, 140, 0, 24)
        hpGui.StudsOffset = Vector3.new(0, -3, 0)
        hpGui.AlwaysOnTop = true
        hpGui.MaxDistance = cfg.maxDist + 100
        hpGui.Parent = root

        local label = Instance.new("TextLabel")
        label.Name = "HP"
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamBold
        label.TextSize = 13
        label.TextStrokeTransparency = 0
        label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
        label.Parent = hpGui
    end

    local label = hpGui:FindFirstChild("HP")
    if label then
        ESPX.styleText(label, hpGui)
        local hp = math.max(0, hum.Health)
        local maxHp = math.max(1, hum.MaxHealth)
        local pct = math.clamp(hp / maxHp, 0, 1)
        label.Text = "HP: " .. math.floor(hp + 0.5) .. "/" .. math.floor(maxHp + 0.5)
        if pct > 0.6 then
            label.TextColor3 = Color3.fromRGB(100, 255, 100)
        elseif pct > 0.3 then
            label.TextColor3 = Color3.fromRGB(255, 220, 80)
        else
            label.TextColor3 = Color3.fromRGB(255, 80, 80)
        end
    end
end

local function removeEnemyHPESP(model)
    if not model then return end
    local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
    if root then
        local gui = root:FindFirstChild("EnemyHPESP")
        if gui then gui:Destroy() end
    end
end

local function updateEnemyHPESP()
    if not toggles.EnemyHP then return end
    for _, npc in ipairs(validTargets) do
        addEnemyHPESP(npc)
    end
end


-- Player ESP
local function getPlayerESPAnchor(char)
    -- R6/R15 and streamed/custom rigs may not have every standard part yet.
    for _, name in ipairs({"Head", "HumanoidRootPart", "UpperTorso", "Torso", "PrimaryPart"}) do
        local part = name == "PrimaryPart" and char.PrimaryPart or char:FindFirstChild(name)
        if part and part:IsA("BasePart") then
            return part
        end
    end
    return char:FindFirstChildWhichIsA("BasePart", true)
end

local function addPlayerInfoESP(plr, char)
    if not char or not char.Parent then return end

    local hl = char:FindFirstChild("PlayerHighlight")
    if not hl then
        hl = Instance.new("Highlight")
        hl.Name = "PlayerHighlight"
        hl.OutlineColor = Color3.fromRGB(255, 255, 255)
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Parent = char
    end
    hl.Adornee = char
    hl.Enabled = true
    hl.FillTransparency = 1 - math.clamp(cfg.playerFillOpacity, 0, 1)
    hl.OutlineTransparency = 1 - math.clamp(cfg.playerOutlineOpacity, 0, 1)

    hl.FillColor = ESPX.playerColor(plr)

    local hum = char:FindFirstChildOfClass("Humanoid")
    local anchor = getPlayerESPAnchor(char)
    -- Keep the highlight even while character parts are streaming in; retry next refresh.
    if not anchor or not hum then return end

    local infoGui = char:FindFirstChild("PlayerInfoESP", true)
    if infoGui and not infoGui:IsA("BillboardGui") then
        infoGui:Destroy()
        infoGui = nil
    end
    if not infoGui then
        infoGui = Instance.new("BillboardGui")
        infoGui.Name = "PlayerInfoESP"
        infoGui.Size = UDim2.new(0, 220, 0, 42)
        infoGui.StudsOffset = Vector3.new(0, 3, 0)
        infoGui.AlwaysOnTop = true
        infoGui.MaxDistance = 2000
        local label = Instance.new("TextLabel")
        label.Name = "Info"
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamBold
        label.TextSize = 13
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
        label.TextStrokeTransparency = 0
        label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        label.Parent = infoGui
    end
    -- Reparent if Head was streamed out or the rig uses a different anchor.
    if infoGui.Parent ~= anchor then infoGui.Parent = anchor end

    local label = infoGui:FindFirstChild("Info")
    if not label then return end
    ESPX.styleText(label, infoGui)
    local myChar = lplr.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local distance = myRoot and math.floor((myRoot.Position - anchor.Position).Magnitude + 0.5) or 0
    label.Text = string.format("%s\nHP: %d/%d  |  %d studs", plr.Name,
        math.floor(math.max(0, hum.Health) + 0.5),
        math.floor(math.max(1, hum.MaxHealth) + 0.5), distance)
end

local function removePlayerESP(char)
    if not char then return end
    local hl = char:FindFirstChild("PlayerHighlight")
    if hl then hl:Destroy() end
    for _, obj in ipairs(char:GetDescendants()) do
        if obj:IsA("BillboardGui") and obj.Name == "PlayerInfoESP" then obj:Destroy() end
    end
end

local function applyPlayerESP(state)
    for _, plr in ipairs(plrs:GetPlayers()) do
        if plr ~= lplr then
            local char = plr.Character
            if char then
                if state then addPlayerInfoESP(plr, char) else removePlayerESP(char) end
            end
        end
    end
end

local function watchPlayer(plr)
    plr.CharacterAdded:Connect(function(char)
        if not toggles.PlayerESP then return end
        task.wait(0.25)
        if toggles.PlayerESP and plr.Character == char then addPlayerInfoESP(plr, char) end
    end)
end
for _, plr in ipairs(plrs:GetPlayers()) do
    if plr ~= lplr then watchPlayer(plr) end
end
ESPX.track(plrs.PlayerAdded:Connect(function(plr)
    watchPlayer(plr)
    if toggles.PlayerESP and plr.Character then addPlayerInfoESP(plr, plr.Character) end
end))

local lastPlayerESP = false
local lastEnemyHP = false
local enemyHPUpdateTimer = 0
local playerESPUpdateTimer = 0

ESPX.track(rs.Heartbeat:Connect(function(dt)
    if toggles.PlayerESP ~= lastPlayerESP then
        lastPlayerESP = toggles.PlayerESP
        applyPlayerESP(toggles.PlayerESP)
    end

    -- Refresh at 10 Hz rather than every frame. This also retries when parts stream in.
    if toggles.PlayerESP then
        playerESPUpdateTimer += dt
        if playerESPUpdateTimer >= 0.1 then
            playerESPUpdateTimer = 0
            for _, plr in ipairs(plrs:GetPlayers()) do
                if plr ~= lplr and plr.Character then addPlayerInfoESP(plr, plr.Character) end
            end
        end
    else
        playerESPUpdateTimer = 0
    end

    if toggles.EnemyHP ~= lastEnemyHP then
        lastEnemyHP = toggles.EnemyHP
        if not toggles.EnemyHP then
            for _, npc in ipairs(ws:GetDescendants()) do
                if npc:IsA("Model") then removeEnemyHPESP(npc) end
            end
        end
    end

    if toggles.EnemyHP then
        enemyHPUpdateTimer += dt
        if enemyHPUpdateTimer >= 0.1 then
            enemyHPUpdateTimer = 0
            updateEnemyHPESP()
        end
    end
end))

-- My HP display
local selfHPGui
local selfHPLabel
local selfHPConnection

local function removeSelfHP()
    if selfHPConnection then
        selfHPConnection:Disconnect()
        selfHPConnection = nil
    end

    if selfHPGui then
        selfHPGui:Destroy()
        selfHPGui = nil
        selfHPLabel = nil
    end
end

local function setupSelfHP()
    removeSelfHP()

    if not toggles.SelfHP then
        return
    end

    local char = lplr.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")

    if not hum then
        return
    end

    selfHPGui = Instance.new("ScreenGui")
    selfHPGui.Name = "HRSH_SelfHP"
    selfHPGui.ResetOnSpawn = false
    selfHPGui.IgnoreGuiInset = true
    selfHPGui.DisplayOrder = 999998
    selfHPGui.Parent = cg

    selfHPLabel = Instance.new("TextLabel")
    selfHPLabel.Name = "HP"
    selfHPLabel.AnchorPoint = Vector2.new(0.5, 0)
    selfHPLabel.Position = UDim2.new(0.5, 0, 0, 25)
    selfHPLabel.Size = UDim2.new(0, 180, 0, 30)
    selfHPLabel.BackgroundTransparency = 1
    selfHPLabel.Font = Enum.Font.GothamBold
    selfHPLabel.TextSize = 18
    selfHPLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    selfHPLabel.TextStrokeTransparency = 0
    selfHPLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    selfHPLabel.Text = "100/100"
    selfHPLabel.Parent = selfHPGui

    local function update()
        if not selfHPLabel or not selfHPLabel.Parent then
            return
        end

        local current = math.max(0, hum.Health)
        local maximum = math.max(1, hum.MaxHealth)

        selfHPLabel.Text =
            string.format("%d/%d",
                math.floor(current + 0.5),
                math.floor(maximum + 0.5)
            )

        local pct = math.clamp(current / maximum, 0, 1)

        if pct > 0.6 then
            selfHPLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        elseif pct > 0.3 then
            selfHPLabel.TextColor3 = Color3.fromRGB(255, 220, 80)
        else
            selfHPLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
        end
    end

    update()

    selfHPConnection = hum.HealthChanged:Connect(update)
end

-- Recreate the display after respawn if the toggle remains enabled.
ESPX.track(lplr.CharacterAdded:Connect(function()
    if toggles.SelfHP then
        task.wait(0.25)
        setupSelfHP()
    end
end))

-- Watch the toggle without touching the existing GUI/event structure.
task.spawn(function()
    local last = toggles.SelfHP

    while not terminated do
        if toggles.SelfHP ~= last then
            last = toggles.SelfHP
            setupSelfHP()
        end

        task.wait(0.1)
    end
end)

-- Item ESP
local itemESPObjects = {}

local function getItemAdornee(obj)
    if obj:IsA("BasePart") then
        return obj
    elseif obj:IsA("Tool") then
        return obj:FindFirstChild("Handle")
            or obj:FindFirstChildWhichIsA("BasePart", true)
    elseif obj:IsA("Model") then
        return obj.PrimaryPart
            or obj:FindFirstChildWhichIsA("BasePart", true)
    end

    return nil
end

local function isPickupCandidate(obj)
    if not obj or obj.Parent ~= ws then
        return false
    end

    -- Never treat player characters as pickups.
    if plrs:GetPlayerFromCharacter(obj) then
        return false
    end

    -- This is the marker visible in the game's pickup hierarchy.
    if obj:FindFirstChild("Put Item In ServerStore", true) then
        return true
    end

    -- Fallback: anything directly under Workspace containing a prompt.
    if obj:FindFirstChildWhichIsA("ProximityPrompt", true) then
        return true
    end

    return obj:IsA("Tool")
end

local function addItemESP(obj)
    if not toggles.ItemESP or not isPickupCandidate(obj) then
        return
    end

    local adornee = getItemAdornee(obj)
    if not adornee then
        return
    end

    local gui = itemESPObjects[obj]

    if gui and gui.Parent then
        gui.Adornee = adornee

        local label = gui:FindFirstChild("Label")
        if label then
            label.Text = obj.Name
            ESPX.styleText(label, gui)
        end

        return
    end

    gui = Instance.new("BillboardGui")
    gui.Name = "ItemESP"
    gui.Size = UDim2.new(0, 220, 0, 28)
    gui.StudsOffset = Vector3.new(0, 2.5, 0)

    -- Do not use ProximityPrompt.Enabled or PromptShown.
    -- The ESP exists independently of prompt activation range.
    gui.AlwaysOnTop = true
    gui.MaxDistance = 2000
    gui.Adornee = adornee
    gui.Parent = cg

    local label = Instance.new("TextLabel")
    label.Name = "Label"
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.TextSize = 13
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextStrokeTransparency = 0
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)

    -- Only the item name. No GUN/MISC/GRENADE category.
    label.Text = obj.Name
    label.Parent = gui
    ESPX.styleText(label, gui)

    itemESPObjects[obj] = gui
end

local function removeItemESP(obj)
    local gui = itemESPObjects[obj]

    if gui then
        gui:Destroy()
        itemESPObjects[obj] = nil
    end
end

local function clearItemESP()
    -- Clear the ESPs tracked by this script.
    for obj, gui in pairs(itemESPObjects) do
        if gui then
            gui:Destroy()
        end

        itemESPObjects[obj] = nil
    end

    -- Also remove stale ItemESP billboards left behind by an older
    -- execution of the script. This fixes ESP remaining after OFF.
    for _, gui in ipairs(cg:GetDescendants()) do
        if gui:IsA("BillboardGui") and gui.Name == "ItemESP" then
            gui:Destroy()
        end
    end
end

local function updateItemESP()
    if not toggles.ItemESP then
        clearItemESP()
        return
    end

    local seen = {}

    -- IMPORTANT:
    -- The pickup objects you showed are direct children of Workspace.
    -- We inspect those objects directly instead of waiting for
    -- ProximityPromptService.PromptShown.
    for _, obj in ipairs(ws:GetChildren()) do
        if isPickupCandidate(obj) then
            seen[obj] = true
            addItemESP(obj)
        end
    end

    -- Remove ESP for pickups that were moved/removed.
    for obj in pairs(itemESPObjects) do
        if not seen[obj] or not obj:IsDescendantOf(ws) then
            removeItemESP(obj)
        end
    end
end

-- Noclip
local noclipOriginal = {}
local lastNoclip = false

local function setNoclip(enabled)
    local char = lplr.Character

    if not char then
        return
    end

    if enabled then
        -- Rebuild the cached part list on respawn and once a second (picks up new accessories/tools).
        if ESPX.noclipChar ~= char or os.clock() - ESPX.noclipBuilt > 1 then
            ESPX.noclipChar = char
            ESPX.noclipBuilt = os.clock()
            ESPX.noclipParts = {}
            for _, obj in ipairs(char:GetDescendants()) do
                if obj:IsA("BasePart") then
                    if noclipOriginal[obj] == nil then
                        noclipOriginal[obj] = obj.CanCollide
                    end
                    ESPX.noclipParts[#ESPX.noclipParts + 1] = obj
                end
            end
        end

        for _, part in ipairs(ESPX.noclipParts) do
            if part.CanCollide then part.CanCollide = false end
        end
    else
        for part, original in pairs(noclipOriginal) do
            if part and part.Parent then
                part.CanCollide = original
            end

            noclipOriginal[part] = nil
        end
        ESPX.noclipChar = nil
        ESPX.noclipParts = {}
    end
end

ESPX.track(lplr.CharacterAdded:Connect(function()
    task.wait(0.25)

    if toggles.Noclip then
        setNoclip(true)
    end
end))

-- Keep collision disabled while Noclip is enabled.
ESPX.track(rs.Stepped:Connect(function()
    if toggles.Noclip then
        setNoclip(true)
    end
end))

-- Fly toggle (WASD to move, Space to rise, LeftCtrl to descend).
-- Kept separate from the existing feature implementations.
local flyVelocity = nil
local flyGyro = nil
local flyRoot = nil
local flyConnection = nil
flySpeed = 55

local function stopFly()
    if flyConnection then
        flyConnection:Disconnect()
        flyConnection = nil
    end
    if flyVelocity then flyVelocity:Destroy(); flyVelocity = nil end
    if flyGyro then flyGyro:Destroy(); flyGyro = nil end
    flyRoot = nil
end

local function startFly()
    stopFly()
    local character = lplr.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not root or not humanoid then return end

    flyRoot = root
    flyVelocity = Instance.new("BodyVelocity")
    flyVelocity.Name = "HRSH_FlyVelocity"
    flyVelocity.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    flyVelocity.Velocity = Vector3.zero
    flyVelocity.Parent = root

    flyGyro = Instance.new("BodyGyro")
    flyGyro.Name = "HRSH_FlyGyro"
    flyGyro.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
    flyGyro.P = 1e4
    flyGyro.CFrame = root.CFrame
    flyGyro.Parent = root

    humanoid:ChangeState(Enum.HumanoidStateType.Physics)
    flyConnection = rs.RenderStepped:Connect(function()
        if not toggles.Fly or not flyRoot or not flyRoot.Parent or not flyVelocity or not flyGyro then
            stopFly()
            return
        end
        local camera = ws.CurrentCamera
        if not camera then return end
        local direction = Vector3.zero
        local look = camera.CFrame.LookVector
        local right = camera.CFrame.RightVector
        if uis:IsKeyDown(Enum.KeyCode.W) then direction += look end
        if uis:IsKeyDown(Enum.KeyCode.S) then direction -= look end
        if uis:IsKeyDown(Enum.KeyCode.D) then direction += right end
        if uis:IsKeyDown(Enum.KeyCode.A) then direction -= right end
        if uis:IsKeyDown(Enum.KeyCode.Space) then direction += Vector3.yAxis end
        if uis:IsKeyDown(Enum.KeyCode.LeftControl) then direction -= Vector3.yAxis end
        if toggles.Freecam then direction = Vector3.zero end -- WASD belongs to Freecam while it is on
        if direction.Magnitude > 0 then direction = direction.Unit * flySpeed end
        flyVelocity.Velocity = direction
        flyGyro.CFrame = CFrame.lookAt(flyRoot.Position, flyRoot.Position + camera.CFrame.LookVector)
    end)
end

local lastFlyState = false
ESPX.track(rs.Heartbeat:Connect(function()
    if toggles.Fly ~= lastFlyState then
        lastFlyState = toggles.Fly
        if toggles.Fly then startFly() else
            stopFly()
            local character = lplr.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            if humanoid then humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end
        end
    end
end))

ESPX.track(lplr.CharacterAdded:Connect(function()
    task.wait(0.35)
    if toggles.Fly then startFly() end
end))

-- Item scanner
-- Runs after the Item ESP functions have been declared.
-- It scans direct Workspace children, so ProximityPrompt activation range
-- does not control whether an item is detected.
task.spawn(function()
    -- Starts true so stale labels from an older run are cleaned once at startup.
    local wasOn = true
    while not terminated do
        if toggles.ItemESP then
            wasOn = true
            updateItemESP()
        elseif wasOn then
            wasOn = false
            clearItemESP() -- one cleanup when switched off, instead of scanning CoreGui forever
        end

        task.wait(0.15)
    end
end)

ESPX.track(ws.ChildAdded:Connect(function(obj)
    if toggles.ItemESP then
        task.defer(function()
            if obj and obj.Parent == ws then
                addItemESP(obj)
            end
        end)
    end
end))

ESPX.track(ws.ChildRemoved:Connect(function(obj)
    removeItemESP(obj)
end))

-- Crosshair
-- A filled dot with a thin black ring so it stays visible on bright backgrounds.
local crossDot = Drawing.new("Circle")
local crossOutline = Drawing.new("Circle")
crossDot.Filled = true
crossDot.NumSides = 32
crossDot.Visible = toggles.Crosshair
crossDot.Color = Color3.fromRGB(255, 255, 255)
crossOutline.Filled = false
crossOutline.NumSides = 32
crossOutline.Thickness = 1
crossOutline.Visible = toggles.Crosshair
crossOutline.Color = Color3.fromRGB(0, 0, 0)

local function refreshTargets()
    local tTargets = {}
    local inRange = {}
    local pPos = cam.CFrame.Position

    if lplr.Character and lplr.Character:FindFirstChild("HumanoidRootPart") then
        pPos = lplr.Character.HumanoidRootPart.Position
    end

    for _, obj in ipairs(ws:GetChildren()) do
        if not obj:IsA("Model") then continue end
        if obj.Name == "MI28_Aim" then
            local old = obj:FindFirstChild("NPCHighlight")
            if old then old:Destroy() end
            continue
        end
        if plrs:GetPlayerFromCharacter(obj) then continue end

        local root = obj.PrimaryPart or obj:FindFirstChild("HumanoidRootPart")
            or obj:FindFirstChildWhichIsA("BasePart", true)
        local objPos = root and root.Position
        local dist = objPos and (objPos - pPos).Magnitude or math.huge

        if dist > cfg.maxDist then
            local old = obj:FindFirstChild("NPCHighlight")
            if old then old:Destroy() end
            continue
        end

        local hum = obj:FindFirstChildOfClass("Humanoid")
        local part = obj:FindFirstChild(cfg.targetPart, true)
        local isMI28 = obj.Name:lower():find("mi28", 1, true) ~= nil
        local isNonHumanTarget = isMI28 and (root or obj:FindFirstChildWhichIsA("BasePart", true))
        if not part and isMI28 then
            part = root or obj:FindFirstChildWhichIsA("BasePart", true)
        end

        if hum then
            if toggles.DelCorpses and hum.Health <= 0 then continue end

            if hum.Health > 0 and (part or isNonHumanTarget) and not obj:FindFirstChild("REVIVE") then
                inRange[#inRange + 1] = {model = obj, dist = dist}
            else
                local old = obj:FindFirstChild("NPCHighlight")
                if old then old:Destroy() end
            end
        elseif isNonHumanTarget then
            -- MI28 can be highlighted even when the configured target part is absent.
            inRange[#inRange + 1] = {model = obj, dist = dist}
        else
            local old = obj:FindFirstChild("NPCHighlight")
            if old then old:Destroy() end
        end
    end

    table.sort(inRange, function(a, b) return a.dist < b.dist end)

    for i, data in ipairs(inRange) do
        tTargets[#tTargets + 1] = data.model
        if i <= cfg.maxEsp then
            applyEsp(data.model)
        else
            local old = data.model:FindFirstChild("NPCHighlight")
            if old then old:Destroy() end
        end
    end
    validTargets = tTargets
end

-- Gather NPCs: stack eligible NPC roots at one shared point in front of the player.
-- Performance: scan Workspace infrequently, then reuse a cached list for fast movement updates.
-- Excludes Armata/MI28 and any Dummy model, including nested Dummy/DummyTwo models.
local function hasGatherExcludedName(model)
    local name = string.lower(model.Name)
    return string.find(name, "armata", 1, true) ~= nil
        or string.find(name, "mi28", 1, true) ~= nil
        or string.find(name, "mi-28", 1, true) ~= nil
        or string.find(name, "dummy", 1, true) ~= nil
end

local function isGatherExcluded(model)
    local node = model
    while node and node ~= ws do
        if node:IsA("Model") and hasGatherExcludedName(node) then
            return true
        end
        node = node.Parent
    end
    -- Skip wrappers containing excluded models so moving a parent cannot move a boss/Dummy.
    for _, descendant in ipairs(model:GetDescendants()) do
        if descendant:IsA("Model") and hasGatherExcludedName(descendant) then
            return true
        end
    end
    return false
end

local function getGatherRoot(model)
    return model.PrimaryPart
        or model:FindFirstChild("HumanoidRootPart")
        or model:FindFirstChild("Torso")
        or model:FindFirstChildWhichIsA("BasePart", true)
end

local function isNestedInsideAnotherHumanoidModel(model)
    local parent = model.Parent
    while parent and parent ~= ws do
        if parent:IsA("Model") and parent:FindFirstChildOfClass("Humanoid") then
            return true
        end
        parent = parent.Parent
    end
    return false
end

local gatherCache = {}
local GATHER_SCAN_INTERVAL = 1.0 -- Workspace scan only once per second
local GATHER_MOVE_INTERVAL = 0.04 -- update target position about 25 times/sec for quick tracking

task.spawn(function()
    local scanElapsed = GATHER_SCAN_INTERVAL
    local moveElapsed = 0
    while not terminated do
        local dt = task.wait(toggles.GatherNPCs and 0.015 or 0.25)
        if not toggles.GatherNPCs then
            table.clear(gatherCache)
            scanElapsed = GATHER_SCAN_INTERVAL -- rescan immediately when enabled again
            moveElapsed = 0
        else
            scanElapsed += dt
            moveElapsed += dt
            local character = lplr.Character
            local myRoot = character and (character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart)
            if myRoot then
                if scanElapsed >= GATHER_SCAN_INTERVAL then
                    scanElapsed = 0
                    -- Start from Humanoids (cheap) so the expensive exclusion checks only run on real NPCs.
                    local candidates = {}
                    local seen = {}
                    for _, hum in ipairs(ws:GetDescendants()) do
                        if hum:IsA("Humanoid") and hum.Health > 0 then
                            local obj = hum.Parent
                            if obj and obj:IsA("Model") and obj ~= character and not seen[obj] then
                                seen[obj] = true
                                if not plrs:GetPlayerFromCharacter(obj)
                                    and not isNestedInsideAnotherHumanoidModel(obj)
                                    and not isGatherExcluded(obj) then
                                    local root = getGatherRoot(obj)
                                    if root then
                                        candidates[#candidates + 1] = {model = obj, root = root, humanoid = hum}
                                    end
                                end
                            end
                        end
                    end
                    gatherCache = candidates
                end

                if moveElapsed >= GATHER_MOVE_INTERVAL then
                    moveElapsed = 0
                    -- One shared point in front of the player; PivotTo snaps quickly without
                    -- repeatedly scanning Workspace or checking every descendant per update.
                    local forward = myRoot.CFrame.LookVector
                    local targetPos = myRoot.Position + forward * cfg.gatherDistance
                    local targetCFrame = CFrame.lookAt(targetPos, targetPos + forward)
                    for i = #gatherCache, 1, -1 do
                        local entry = gatherCache[i]
                        local npc, root, hum = entry.model, entry.root, entry.humanoid
                        if not npc.Parent or not root.Parent or not hum.Parent or hum.Health <= 0 then
                            table.remove(gatherCache, i)
                        else
                            pcall(function()
                                local pivot = npc:GetPivot()
                                local rootOffset = pivot:ToObjectSpace(root.CFrame)
                                npc:PivotTo(targetCFrame * rootOffset:Inverse())
                            end)
                        end
                    end
                end
            end
        end
    end
end)

-- Delete corpses loop
task.spawn(function()
    while not terminated do
        if toggles.DelCorpses then
            for _, obj in ipairs(ws:GetChildren()) do
                if obj:IsA("Model") then
                    local hum = obj:FindFirstChildOfClass("Humanoid")
                    if hum and hum.Health <= 0 then
                        obj:Destroy()
                    end
                end
            end
        end
        task.wait(0.1)
    end
end)

-- Target scan loop
task.spawn(function()
    while not terminated do
        refreshTargets()
        task.wait(cfg.scanRate)
    end
end)

-- Aim assist + crosshair
ESPX.track(rs.RenderStepped:Connect(function(dt)
    if terminated then return end
    local center = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)

    -- Crosshair can now be toggled independently of Aim Assist.
    crossDot.Visible = toggles.Crosshair
    crossOutline.Visible = toggles.Crosshair

    if toggles.Crosshair then
        local opacity = math.clamp(cfg.crosshairOpacity, 0, 1)
        crossDot.Position = center
        crossDot.Radius = cfg.crosshairSize
        crossDot.Color = Color3.fromHSV(
            math.clamp(cfg.crosshairHue, 0, 360) / 360,
            math.clamp(cfg.crosshairSat, 0, 1),
            1
        )
        crossDot.Transparency = opacity
        crossOutline.Position = center
        crossOutline.Radius = cfg.crosshairSize + 1
        crossOutline.Transparency = opacity
    end

    if not toggles.AimAssist then
        return
    end

    local bestTorso = nil
    local shortest = cfg.fov
    local ignore = { lplr.Character }

    for _, npc in ipairs(validTargets) do
        ignore[#ignore + 1] = npc
    end

    for _, npc in ipairs(validTargets) do
        local torso = npc:FindFirstChild(cfg.targetPart, true)
        -- MI28 helicopter models may not have the configured humanoid target part.
        -- Fall back to a usable model part so Aim Assist can lock onto the helicopter.
        if not torso and npc.Name:lower():find("mi28", 1, true) then
            torso = npc.PrimaryPart or npc:FindFirstChild("HumanoidRootPart", true)
                or npc:FindFirstChildWhichIsA("BasePart", true)
        end
        if torso then
            local sPos, onScreen = cam:WorldToViewportPoint(torso.Position)
            if onScreen then
                local dist = (Vector2.new(sPos.X, sPos.Y) - center).Magnitude
                if dist < shortest then
                    local obscuring = cam:GetPartsObscuringTarget({ torso.Position }, ignore)
                    local blocked = false
                    for _, part in ipairs(obscuring) do
                        local parent = part.Parent
                        local parentName = parent and parent.Name:lower() or ""
                        local isDoor = parentName:find("wooden door") or part.Name:lower():find("door")
                        if isDoor then continue end

                        local isGui = false
                        local guiCheck = part.Parent
                        while guiCheck and guiCheck ~= ws do
                            if guiCheck:IsA("GuiObject") or guiCheck:IsA("BasePlayerGui") or guiCheck:IsA("ScreenGui") then
                                isGui = true
                                break
                            end
                            guiCheck = guiCheck.Parent
                        end
                        if isGui then continue end

                        local ancestor = part.Parent
                        local inRoom = false
                        while ancestor and ancestor ~= ws do
                            local n = ancestor.Name:lower()
                            if ancestor:IsA("Model") and (n:find("room") or n:find("start") or n:find("bossfight")) then
                                inRoom = true
                                break
                            end
                            ancestor = ancestor.Parent
                        end

                        if inRoom then
                            blocked = true
                            break
                        end
                    end
                    if not blocked then
                        bestTorso = torso
                        shortest = dist
                    end
                end
            end
        end
    end

    if bestTorso then
        crossDot.Color = Color3.fromRGB(255, 0, 0) -- red while locked onto a target
        local root = bestTorso.Parent and bestTorso.Parent:FindFirstChild("HumanoidRootPart")
        local vel = root and root.AssemblyLinearVelocity or Vector3.zero
        local pingComp = 0.055
        local predictedPos = bestTorso.Position + vel * pingComp

        local sPos = cam:WorldToViewportPoint(predictedPos)
        local dx = sPos.X - center.X
        local dy = sPos.Y - center.Y
        local dist2D = math.sqrt(dx * dx + dy * dy)

        if dist2D > 0.5 then
            local distScale = math.clamp(dist2D / 80, 0.65, 1.0)
            local strength = cfg.aimStrength * distScale

            if mousemoverel and not uis.TouchEnabled then
                mousemoverel(dx * strength, dy * strength)
            else
                local lerpAlpha = math.clamp(strength * dt * 18, 0, 0.5)
                local targetCF = CFrame.new(cam.CFrame.Position, predictedPos)
                cam.CFrame = cam.CFrame:Lerp(targetCF, lerpAlpha)
            end
        end
    end
end))

-- Restore any NPC parts modified by an older Big Hitboxes version.
for _, obj in ipairs(ws:GetDescendants()) do
    if obj:IsA("BasePart") and obj:GetAttribute("OrigSize") then
        pcall(function()
            obj.Size = obj:GetAttribute("OrigSize")
            local originalTransparency = obj:GetAttribute("OrigTrans")
            if originalTransparency ~= nil then obj.Transparency = originalTransparency end
            local originalColor = obj:GetAttribute("OrigColor")
            if originalColor ~= nil then obj.BrickColor = BrickColor.new(originalColor) end
            obj:SetAttribute("OrigSize", nil)
            obj:SetAttribute("OrigTrans", nil)
            obj:SetAttribute("OrigColor", nil)
        end)
    end
end


-- Fullbright
ESPX.track(lighting.Changed:Connect(function()
    if not toggles.Fullbright then return end
    lighting.Brightness = 2
    lighting.ClockTime = 14
    lighting.FogEnd = 100000
    lighting.GlobalShadows = false
    lighting.Ambient = Color3.fromRGB(178, 178, 178)
    lighting.OutdoorAmbient = Color3.fromRGB(178, 178, 178)
end))

-- AI State Disabler: one pass over existing NPCs at startup, then only humanoids that get added later
-- (no more full Workspace scan every 2 seconds).
do
    local bannedStates = {
        Enum.HumanoidStateType.Climbing,
        Enum.HumanoidStateType.Swimming,
        Enum.HumanoidStateType.FallingDown,
        Enum.HumanoidStateType.Ragdoll
    }
    local function disableStates(obj)
        if terminated or not obj.Parent then return end
        if obj.Health > 0 and not plrs:GetPlayerFromCharacter(obj.Parent) then
            for _, state in ipairs(bannedStates) do
                pcall(obj.SetStateEnabled, obj, state, false)
            end
        end
    end

    task.spawn(function()
        local i = 0
        for _, obj in ipairs(ws:GetDescendants()) do
            if terminated then return end
            if obj:IsA("Humanoid") then disableStates(obj) end
            i += 1
            if i % 200 == 0 then task.wait() end
        end
    end)

    ESPX.track(ws.DescendantAdded:Connect(function(obj)
        if terminated or not obj:IsA("Humanoid") then return end
        task.defer(disableStates, obj)
    end))
end

-- Low Visuals
local lastLowVisuals = false
local function applyLowVisuals(state)
    lighting.GlobalShadows = not state
    for _, v in ipairs(lighting:GetChildren()) do
        if v:IsA("BlurEffect") or v:IsA("BloomEffect") or v:IsA("SunRaysEffect") then
            v.Enabled = not state
        end
    end
end

ESPX.track(rs.Heartbeat:Connect(function()
    if toggles.LowVisuals ~= lastLowVisuals then
        lastLowVisuals = toggles.LowVisuals
        applyLowVisuals(toggles.LowVisuals)
    end
end))

-- Instance Optimizer
task.spawn(function()
    while not terminated do
        task.wait(5)
        if not toggles.InstanceOptimizer then continue end
        local i = 0
        for _, v in ipairs(ws:GetDescendants()) do
            if v:IsA("MeshPart") or v:IsA("UnionOperation") then
                v.RenderFidelity = Enum.RenderFidelity.Performance
                local isDebris = not v.Anchored
                    and v.Size.Magnitude < 4
                    and not v.Parent:FindFirstChildOfClass("Humanoid")
                    and not plrs:GetPlayerFromCharacter(v.Parent)
                if isDebris then
                    v.CollisionFidelity = Enum.CollisionFidelity.Box
                end
            end
            if v:IsA("BasePart") and not v.Anchored then
                local sz = v.Size
                if sz.X < 1 and sz.Y < 1 and sz.Z < 1 then
                    v.CanTouch = false
                    v.CanQuery = false
                end
            end
            i += 1
            if i % 100 == 0 then task.wait() end
        end
    end
end)

-- Particle Cap
local cachedRates = {}

local function applyParticleCap(state)
    for _, v in ipairs(ws:GetDescendants()) do
        if v:IsA("ParticleEmitter") then
            if state then
                cachedRates[v] = v.Rate
                v.Rate = 5
            else
                if cachedRates[v] then
                    v.Rate = cachedRates[v]
                    cachedRates[v] = nil
                end
            end
        end
    end
end

local lastParticleCap = false
ESPX.track(rs.Heartbeat:Connect(function()
    if toggles.ParticleCap ~= lastParticleCap then
        lastParticleCap = toggles.ParticleCap
        applyParticleCap(toggles.ParticleCap)
    end
end))

-- Ultra Potato
local cachedTextures = {}

local function applyUltraPotato(state)
    for _, v in ipairs(ws:GetDescendants()) do
        if v:IsA("Texture") or v:IsA("Decal") then
            if state then
                cachedTextures[v] = v.Texture
                v.Texture = ""
            else
                if cachedTextures[v] then
                    v.Texture = cachedTextures[v]
                    cachedTextures[v] = nil
                end
            end
        end
    end
end

local lastUltraPotato = false
ESPX.track(rs.Heartbeat:Connect(function()
    if toggles.UltraPotato ~= lastUltraPotato then
        lastUltraPotato = toggles.UltraPotato
        applyUltraPotato(toggles.UltraPotato)
    end
end))

-- F1 Deep Clean
ESPX.track(uis.InputBegan:Connect(function(input, gpe)
    if terminated then return end
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.F1 then
        local cleaned = 0
        local i = 0
        for _, v in ipairs(ws:GetChildren()) do
            if v:IsA("BasePart") and not v.Anchored and not plrs:GetPlayerFromCharacter(v.Parent) then
                v:Destroy()
                cleaned += 1
            end
            i += 1
            if i % 50 == 0 then task.wait() end
        end
        applyParticleCap(true)
        lastParticleCap = true
        toggles.ParticleCap = true
        print("Deep Clean done, removed " .. cleaned .. " parts")
    end
end))

-- World: No Fog and Custom Camera FOV.
-- Kept in its own block (not nested in the generator block) to stay under Luau's 200-locals limit.
do
    local fogOriginal = nil
    local fogTimer = 1
    local fovOriginal = nil

    local function applyNoFog()
        if not fogOriginal then
            fogOriginal = {fogEnd = lighting.FogEnd, fogStart = lighting.FogStart, atmos = {}}
        end
        -- Same FogEnd Fullbright uses, so the two features never fight over it.
        if lighting.FogEnd ~= 100000 then lighting.FogEnd = 100000 end
        if lighting.FogStart ~= 99000 then lighting.FogStart = 99000 end
        for _, child in ipairs(lighting:GetChildren()) do
            if child:IsA("Atmosphere") then
                if not fogOriginal.atmos[child] then
                    fogOriginal.atmos[child] = {density = child.Density, haze = child.Haze}
                end
                child.Density = 0
                child.Haze = 0
            end
        end
    end

    local function restoreFog()
        if not fogOriginal then return end
        lighting.FogEnd = fogOriginal.fogEnd
        lighting.FogStart = fogOriginal.fogStart
        for atmo, original in pairs(fogOriginal.atmos) do
            if atmo.Parent then
                atmo.Density = original.density
                atmo.Haze = original.haze
            end
        end
        fogOriginal = nil
    end

    local function restoreFov()
        if fovOriginal ~= nil then
            local camera = ws.CurrentCamera
            if camera then camera.FieldOfView = fovOriginal end
            fovOriginal = nil
        end
    end

    -- Re-applied a few times a second because games often reset fog on their own.
    ESPX.track(rs.Heartbeat:Connect(function(dt)
        if terminated then return end
        if toggles.NoFog then
            fogTimer += dt
            if fogTimer >= 0.25 then
                fogTimer = 0
                applyNoFog()
            end
        elseif fogOriginal then
            restoreFog()
            fogTimer = 1
        end
    end))

    ESPX.track(rs.RenderStepped:Connect(function()
        if terminated then return end
        local camera = ws.CurrentCamera
        if not camera then return end
        if toggles.CustomFOV then
            if fovOriginal == nil then fovOriginal = camera.FieldOfView end
            camera.FieldOfView = cfg.camFov
        else
            restoreFov()
        end
    end))

    -- Used by the Terminate button.
    ESPX.restoreWorld = function()
        restoreFog()
        restoreFov()
    end
end

-- Freecam: the same Scriptable-camera approach Spectate uses (the CFrame is set directly every frame),
-- so the camera never gets pushed back by walls. Own block to stay under the 200-locals limit.
do
    local cas = game:GetService("ContextActionService")
    local SINK_ACTION = "HRSH_FreecamSink"
    local fc = {active = false, looking = false, yaw = 0, pitch = 0, pos = Vector3.zero}

    local function sinkInput()
        return Enum.ContextActionResult.Sink
    end

    local function startFreecam()
        local camera = ws.CurrentCamera
        if not camera then return end
        local look = camera.CFrame.LookVector
        fc.yaw = math.atan2(-look.X, -look.Z)
        fc.pitch = math.asin(math.clamp(look.Y, -1, 1))
        fc.pos = camera.CFrame.Position
        fc.active = true
        -- Stop the character from walking/jumping while WASD and Space move the camera instead.
        cas:BindActionAtPriority(
            SINK_ACTION, sinkInput, false, Enum.ContextActionPriority.High.Value,
            Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D,
            Enum.KeyCode.Space, Enum.KeyCode.E, Enum.KeyCode.Q,
            Enum.KeyCode.LeftControl, Enum.KeyCode.LeftShift
        )
    end

    local function stopFreecam()
        if not fc.active then return end
        fc.active = false
        fc.looking = false
        pcall(function() uis.MouseBehavior = Enum.MouseBehavior.Default end)
        pcall(function() cas:UnbindAction(SINK_ACTION) end)
        local camera = ws.CurrentCamera
        if camera then
            camera.CameraType = Enum.CameraType.Custom
            local character = lplr.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            if humanoid then camera.CameraSubject = humanoid end
        end
    end

    -- Hold right mouse button and move the mouse to look around (same as Spectate).
    ESPX.track(uis.InputBegan:Connect(function(input)
        if fc.active and input.UserInputType == Enum.UserInputType.MouseButton2 then
            fc.looking = true
            pcall(function() uis.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition end)
        end
    end))
    ESPX.track(uis.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton2 and fc.looking then
            fc.looking = false
            pcall(function() uis.MouseBehavior = Enum.MouseBehavior.Default end)
        end
    end))
    ESPX.track(uis.InputChanged:Connect(function(input)
        if fc.active and fc.looking and input.UserInputType == Enum.UserInputType.MouseMovement then
            fc.yaw = fc.yaw - input.Delta.X * 0.0035
            fc.pitch = math.clamp(fc.pitch - input.Delta.Y * 0.0035, math.rad(-89), math.rad(89))
        end
    end))

    ESPX.track(rs.RenderStepped:Connect(function(dt)
        if terminated then return end
        local camera = ws.CurrentCamera
        if not camera then return end

        if toggles.Freecam then
            if spectateTargetPlayer then return end -- Spectate owns the camera while it is running
            if not fc.active then startFreecam() end
            camera.CameraType = Enum.CameraType.Scriptable

            local rotation = CFrame.fromOrientation(fc.pitch, fc.yaw, 0)
            if not uis:GetFocusedTextBox() then
                local move = Vector3.zero
                if uis:IsKeyDown(Enum.KeyCode.W) then move += rotation.LookVector end
                if uis:IsKeyDown(Enum.KeyCode.S) then move -= rotation.LookVector end
                if uis:IsKeyDown(Enum.KeyCode.D) then move += rotation.RightVector end
                if uis:IsKeyDown(Enum.KeyCode.A) then move -= rotation.RightVector end
                if uis:IsKeyDown(Enum.KeyCode.Space) or uis:IsKeyDown(Enum.KeyCode.E) then move += Vector3.yAxis end
                if uis:IsKeyDown(Enum.KeyCode.LeftControl) or uis:IsKeyDown(Enum.KeyCode.Q) then move -= Vector3.yAxis end
                if move.Magnitude > 0 then
                    local speed = cfg.freecamSpeed * (uis:IsKeyDown(Enum.KeyCode.LeftShift) and 3 or 1)
                    fc.pos += move.Unit * speed * dt
                end
            end
            camera.CFrame = CFrame.new(fc.pos) * rotation
        elseif fc.active then
            stopFreecam()
        end
    end))

    -- Used by the Terminate button.
    ESPX.stopFreecam = stopFreecam
    ESPX.getFreecamPos = function()
        if fc.active then return fc.pos end
        return nil
    end
end

-- View Line: a red line from each player's head in the direction their head faces, so you can see
-- where they are looking. Drawn with the Drawing library (visible through walls). Own block to stay
-- under the 200-locals limit.
do
    local viewLines = {} -- [player] = Drawing line

    local function removeViewLine(plr)
        local line = viewLines[plr]
        if line then
            pcall(function() line:Remove() end)
            viewLines[plr] = nil
        end
    end

    -- Used by the Terminate button and when the toggle is switched off.
    ESPX.clearViewLines = function()
        for plr in pairs(viewLines) do removeViewLine(plr) end
    end

    ESPX.track(plrs.PlayerRemoving:Connect(removeViewLine))

    ESPX.track(rs.RenderStepped:Connect(function()
        if terminated then return end
        local camera = ws.CurrentCamera
        if not toggles.ViewLine or not camera then
            if next(viewLines) ~= nil then ESPX.clearViewLines() end
            return
        end

        local camCF = camera.CFrame
        local near = 0.2
        for _, plr in ipairs(plrs:GetPlayers()) do
            if plr ~= lplr then
                local char = plr.Character
                local head = char and (char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart"))
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                local line = viewLines[plr]
                local show = false

                if head and head:IsA("BasePart") and hum and hum.Health > 0 then
                    local a = head.Position
                    local b = a + head.CFrame.LookVector * cfg.viewLineLength
                    -- Clip the segment to the camera's near plane so it never flips when one end is behind you.
                    local da = -camCF:PointToObjectSpace(a).Z
                    local db = -camCF:PointToObjectSpace(b).Z
                    if da > near or db > near then
                        local t = (near - da) / (db - da)
                        if da <= near then
                            a = a + (b - a) * t
                        elseif db <= near then
                            b = a + (b - a) * t
                        end
                        local pa = camera:WorldToViewportPoint(a)
                        local pb = camera:WorldToViewportPoint(b)
                        if not line then
                            line = Drawing.new("Line")
                            line.Thickness = 2
                            line.Color = Color3.fromRGB(255, 0, 0)
                            viewLines[plr] = line
                        end
                        line.From = Vector2.new(pa.X, pa.Y)
                        line.To = Vector2.new(pb.X, pb.Y)
                        show = true
                    end
                end

                if line then line.Visible = show end
            end
        end
    end))
end

-- Anti AFK: answers Roblox's idle check so you are not kicked after 20 minutes without input.
do
    local virtualUser = game:GetService("VirtualUser")
    ESPX.track(lplr.Idled:Connect(function()
        if terminated or not toggles.AntiAFK then return end
        pcall(function()
            virtualUser:CaptureController()
            virtualUser:ClickButton2(Vector2.new())
        end)
    end))
end

-- Hitbox Extender (other players): grows the selected body parts into cubes. Head / Body / Legs can be
-- chosen independently. This only changes the parts on YOUR client, so it helps in games whose hit
-- detection runs locally. Own block to stay under the 200-locals limit.
do
    local PART_TOGGLE = {Head = "HitboxHead"}
    for _, name in ipairs({"HumanoidRootPart", "UpperTorso", "LowerTorso", "Torso"}) do
        PART_TOGGLE[name] = "HitboxBody"
    end
    for _, name in ipairs({
        "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot", -- R15
        "Left Leg", "Right Leg", -- R6
    }) do
        PART_TOGGLE[name] = "HitboxLegs"
    end

    local originals = {} -- [part] = its original size / transparency / collision settings
    local boxes = {}     -- [part] = BoxHandleAdornment that draws the real hitbox (see-through walls)

    local function removeBox(part)
        local box = boxes[part]
        if box then
            box:Destroy()
            boxes[part] = nil
        end
    end

    local function restorePart(part)
        removeBox(part)
        local original = originals[part]
        if not original then return end
        if part.Parent then
            part.Size = original.size
            part.Transparency = original.transparency
            part.CanCollide = original.canCollide
            part.Massless = original.massless
        end
        originals[part] = nil
    end

    local function restoreAll()
        for part in pairs(originals) do restorePart(part) end
    end

    -- Used by the Terminate button.
    ESPX.restoreHitboxes = restoreAll

    task.spawn(function()
        while not terminated do
            if toggles.HitboxExtender then
                local size = Vector3.new(cfg.hitboxSize, cfg.hitboxSize, cfg.hitboxSize)
                local active = {}
                for _, plr in ipairs(plrs:GetPlayers()) do
                    local char = plr ~= lplr and plr.Character
                    if char then
                        for _, part in ipairs(char:GetChildren()) do
                            local toggleKey = PART_TOGGLE[part.Name]
                            if toggleKey and toggles[toggleKey] and part:IsA("BasePart") then
                                active[part] = true
                                if not originals[part] then
                                    originals[part] = {
                                        size = part.Size,
                                        transparency = part.Transparency,
                                        canCollide = part.CanCollide,
                                        massless = part.Massless,
                                    }
                                end
                                if part.Size ~= size then part.Size = size end
                                part.Transparency = cfg.hitboxTransparency
                                part.CanCollide = false
                                part.Massless = true

                                -- Show Hitbox (only while Player ESP is on): a box that matches the real hitbox size
                                -- exactly, drawn through walls in the Player ESP color. Works even for avatars whose head is invisible
                                -- or a mesh that does not fill the part.
                                if toggles.HitboxVisual and toggles.PlayerESP then
                                    local box = boxes[part]
                                    if not box or not box.Parent then
                                        box = Instance.new("BoxHandleAdornment")
                                        box.Name = "HitboxVisual"
                                        box.AlwaysOnTop = true
                                        box.ZIndex = 1
                                        box.Adornee = part
                                        box.Parent = cg
                                        boxes[part] = box
                                    end
                                    box.Size = size
                                    box.Color3 = ESPX.playerColor(plr)
                                    box.Transparency = 1 - math.clamp(cfg.hitboxBoxOpacity, 0, 1)
                                else
                                    removeBox(part)
                                end
                            end
                        end
                    end
                end
                -- Put back anything that is no longer selected (or whose player left / respawned).
                for part in pairs(originals) do
                    if not active[part] then restorePart(part) end
                end
            elseif next(originals) ~= nil then
                restoreAll()
            end
            task.wait(0.1)
        end
    end)
end

-- Generator ESP (orange, styled like Player ESP) + Terminate button
do
    local function getGeneratorColor()
        return Color3.fromHSV(math.clamp(cfg.genHue, 0, 360) / 360, 1, 1)
    end

    local function getGeneratorAnchor(model)
        if model.PrimaryPart then return model.PrimaryPart end
        return model:FindFirstChildWhichIsA("BasePart", true)
    end

    -- Generator progress: the game's repair script is not readable from here, so this looks for a
    -- number/string stored as an Attribute or a Value object whose name sounds like progress.
    -- The first match is cached per generator.
    local PROGRESS_KEYWORDS = {"progress", "percent", "repair", "complet", "charge", "fixed", "fuel"}
    local progressSource = {}   -- [model] = {inst = Instance, attr = string?} or false
    local progressSearched = {} -- [model] = os.clock() of the last failed search

    local function nameLooksLikeProgress(name)
        local n = string.lower(name)
        for _, keyword in ipairs(PROGRESS_KEYWORDS) do
            if string.find(n, keyword, 1, true) then return true end
        end
        return false
    end

    local function findProgressSource(model)
        local candidates = {model}
        for _, d in ipairs(model:GetDescendants()) do candidates[#candidates + 1] = d end
        for _, inst in ipairs(candidates) do
            for attrName, value in pairs(inst:GetAttributes()) do
                if (type(value) == "number" or type(value) == "string") and nameLooksLikeProgress(attrName) then
                    return {inst = inst, attr = attrName}
                end
            end
            if (inst:IsA("NumberValue") or inst:IsA("IntValue") or inst:IsA("StringValue"))
                and nameLooksLikeProgress(inst.Name) then
                return {inst = inst}
            end
        end
        return nil
    end

    local function getProgressText(model)
        local src = progressSource[model]
        if src and (not src.inst.Parent) then src = nil; progressSource[model] = nil end
        if not src then
            local last = progressSearched[model]
            if last and os.clock() - last < 5 then return nil end -- retry a failed search every 5s
            src = findProgressSource(model)
            if not src then
                progressSearched[model] = os.clock()
                return nil
            end
            progressSource[model] = src
        end

        local value, shownName
        if src.attr then
            value = src.inst:GetAttribute(src.attr)
            shownName = src.attr
        else
            value = src.inst.Value
            shownName = src.inst.Name
        end
        if type(value) == "number" then
            if value >= 0 and value <= 1 and value ~= math.floor(value) then
                return string.format("%s: %d%%", shownName, math.floor(value * 100 + 0.5))
            end
            return string.format("%s: %s", shownName, tostring(math.floor(value * 10 + 0.5) / 10))
        end
        return string.format("%s: %s", shownName, tostring(value))
    end

    -- This game stores generator state as Attributes on the Generator model:
    -- RepairProgress, ProgressPaused, PlayersRepairingCount and kickcount.
    local function getGeneratorStatusLines(model)
        local lines = {}
        local progress = model:GetAttribute("RepairProgress")
        if type(progress) == "number" then
            -- Handles both a 0-100 scale and a 0-1 fraction.
            local pct = (progress > 0 and progress < 1) and (progress * 100) or progress
            pct = math.clamp(math.floor(pct + 0.5), 0, 100)
            lines[#lines + 1] = (pct >= 100) and "REPAIRED" or string.format("Repair: %d%%", pct)
        else
            local fallback = getProgressText(model) -- generic search for other games/maps
            if fallback then lines[#lines + 1] = fallback end
        end

        local extras = {}
        if model:GetAttribute("ProgressPaused") == true then extras[#extras + 1] = "PAUSED" end
        local repairing = model:GetAttribute("PlayersRepairingCount")
        if type(repairing) == "number" and repairing > 0 then
            extras[#extras + 1] = string.format("%d repairing", repairing)
        end
        local kicks = model:GetAttribute("kickcount")
        if type(kicks) == "number" and kicks > 0 then
            extras[#extras + 1] = string.format("kicked x%d", kicks)
        end
        if #extras > 0 then lines[#lines + 1] = table.concat(extras, "  |  ") end
        return lines
    end

    local function addGeneratorESP(model)
        if not model or not model.Parent then return end

        -- Highlight: same style as Player ESP (50% fill, white outline, always on top)
        local hl = model:FindFirstChild("GeneratorHighlight")
        if not hl then
            hl = Instance.new("Highlight")
            hl.Name = "GeneratorHighlight"
            hl.OutlineColor = Color3.fromRGB(255, 255, 255)
            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            hl.Parent = model
        end
        hl.Adornee = model
        local genColor = getGeneratorColor()
        hl.FillColor = genColor
        hl.FillTransparency = 1 - math.clamp(cfg.genFillOpacity, 0, 1)
        hl.OutlineTransparency = 1 - math.clamp(cfg.genOutlineOpacity, 0, 1)
        hl.Enabled = true

        -- Info label: name + distance, like Player ESP
        local anchor = getGeneratorAnchor(model)
        if not anchor then return end

        local infoGui = model:FindFirstChild("GeneratorInfoESP", true)
        if infoGui and not infoGui:IsA("BillboardGui") then
            infoGui:Destroy()
            infoGui = nil
        end
        if not infoGui then
            infoGui = Instance.new("BillboardGui")
            infoGui.Name = "GeneratorInfoESP"
            infoGui.Size = UDim2.new(0, 220, 0, 72)
            infoGui.StudsOffset = Vector3.new(0, 3, 0)
            infoGui.AlwaysOnTop = true
            infoGui.MaxDistance = 5000
            local label = Instance.new("TextLabel")
            label.Name = "Info"
            label.Size = UDim2.new(1, 0, 1, 0)
            label.BackgroundTransparency = 1
            label.Font = Enum.Font.GothamBold
            label.TextSize = 13
            label.TextColor3 = Color3.fromRGB(255, 140, 0)
            label.TextStrokeTransparency = 0
            label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
            label.Parent = infoGui
        end
        if infoGui.Parent ~= anchor then infoGui.Parent = anchor end
        infoGui.Size = UDim2.new(0, 220, 0, 72)

        local label = infoGui:FindFirstChild("Info")
        if label then
            ESPX.styleText(label, infoGui)
            label.TextColor3 = genColor
            local myChar = lplr.Character
            local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
            local distance = myRoot and math.floor((myRoot.Position - anchor.Position).Magnitude + 0.5) or 0
            local text = string.format("Generator\n%d studs", distance)
            for _, line in ipairs(getGeneratorStatusLines(model)) do
                text = text .. "\n" .. line
            end
            label.Text = text
        end
    end

    local function clearGeneratorESP()
        for _, v in ipairs(ws:GetDescendants()) do
            if (v:IsA("Highlight") and v.Name == "GeneratorHighlight")
                or (v:IsA("BillboardGui") and v.Name == "GeneratorInfoESP") then
                v:Destroy()
            end
        end
    end

    -- Finds "Generator" models. Checks Workspace.Map.Generators first; if that path
    -- is missing/empty (different map, streaming), falls back to scanning all of Workspace.
    local function findGenerators()
        local found = {}
        local map = ws:FindFirstChild("Map")
        local folder = map and map:FindFirstChild("Generators")
        if folder then
            for _, obj in ipairs(folder:GetChildren()) do
                if obj:IsA("Model") and obj.Name == "Generator" then
                    found[#found + 1] = obj
                end
            end
        end
        if #found == 0 then
            for _, obj in ipairs(ws:GetDescendants()) do
                if obj:IsA("Model") and obj.Name == "Generator" then
                    local parent = obj.Parent
                    if not (parent and parent:IsA("Model") and parent.Name == "Generator") then
                        found[#found + 1] = obj
                    end
                end
            end
        end
        return found
    end

    task.spawn(function()
        local wasOn = false
        local fullScanTimer = 0
        local cached = {}
        while not terminated do
            if toggles.GeneratorESP then
                wasOn = true
                fullScanTimer += 0.25
                -- Re-discover generators once per second; refresh labels every 0.25s.
                if fullScanTimer >= 1 or #cached == 0 then
                    fullScanTimer = 0
                    cached = findGenerators()
                end
                for _, model in ipairs(cached) do
                    pcall(addGeneratorESP, model)
                end
            elseif wasOn then
                wasOn = false
                cached = {}
                clearGeneratorESP()
            end
            task.wait(0.25)
        end
    end)

    -- Head marker (Cyberpunk 2077 scanner style): a small diamond over a double chevron that bobs
    -- toward the target and blinks. Built from frames so it never depends on font glyphs, and
    -- recolored every refresh to match the target's ESP highlight.
    local headArrows = {} -- [model] = BillboardGui

    local function buildArrow()
        local gui = Instance.new("BillboardGui")
        gui.Name = "HeadArrowESP"
        gui.Size = UDim2.new(0, 30, 0, 34)
        gui.AlwaysOnTop = true
        gui.MaxDistance = 5000
        local holder = Instance.new("Frame")
        holder.Name = "Arrow"
        holder.Size = UDim2.new(1, 0, 1, 0)
        holder.BackgroundTransparency = 1
        holder.Parent = gui

        local function piece(name, size, center, rotation, transparency)
            local f = Instance.new("Frame")
            f.Name = name
            f.AnchorPoint = Vector2.new(0.5, 0.5)
            f.Position = UDim2.new(0, center.X, 0, center.Y)
            f.Size = UDim2.new(0, size.X, 0, size.Y)
            f.Rotation = rotation
            f.BackgroundTransparency = transparency or 0
            f.BorderSizePixel = 0
            f.Parent = holder
            stroke(f, Color3.fromRGB(0, 0, 0), 0, 1)
            return f
        end

        local diamond = piece("Diamond", Vector2.new(5, 5), Vector2.new(15, 4), 45)
        -- Outer chevron (tip at y = 18), then a smaller, fainter one below it (tip at y = 27).
        piece("OuterLeft", Vector2.new(10, 3), Vector2.new(11.5, 14.5), 45)
        piece("OuterRight", Vector2.new(10, 3), Vector2.new(18.5, 14.5), -45)
        piece("InnerLeft", Vector2.new(7, 2), Vector2.new(12.5, 24.5), 45, 0.35)
        piece("InnerRight", Vector2.new(7, 2), Vector2.new(17.5, 24.5), -45, 0.35)

        -- Bob toward the target and blink the diamond (tweens stop when the GUI is destroyed).
        TweenService:Create(
            holder,
            TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
            {Position = UDim2.new(0, 0, 0, 4)}
        ):Play()
        TweenService:Create(
            diamond,
            TweenInfo.new(0.4, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, true),
            {BackgroundTransparency = 0.7}
        ):Play()
        return gui
    end

    local function setArrow(model, color)
        local anchor = model:FindFirstChild("Head")
            or model:FindFirstChild("HumanoidRootPart")
            or model.PrimaryPart
            or model:FindFirstChildWhichIsA("BasePart", true)
        if not anchor then return end
        local gui = headArrows[model]
        if not gui or not gui.Parent then
            gui = buildArrow()
            headArrows[model] = gui
        end
        gui.StudsOffset = Vector3.new(0, anchor.Name == "Head" and 2.4 or 4, 0)
        if gui.Parent ~= anchor then gui.Parent = anchor end
        local holder = gui:FindFirstChild("Arrow")
        if holder then
            for _, piece in ipairs(holder:GetChildren()) do
                if piece:IsA("Frame") then piece.BackgroundColor3 = color end
            end
        end
        gui.Enabled = true
    end

    local function clearHeadArrows()
        for model, gui in pairs(headArrows) do
            if gui then gui:Destroy() end
            headArrows[model] = nil
        end
        for _, v in ipairs(ws:GetDescendants()) do
            if v:IsA("BillboardGui") and v.Name == "HeadArrowESP" then v:Destroy() end
        end
    end

    task.spawn(function()
        local wasOn = false
        while not terminated do
            if toggles.HeadArrow then
                wasOn = true
                local seen = {}
                for _, npc in ipairs(validTargets) do
                    if npc.Parent then
                        seen[npc] = true
                        setArrow(npc, cfg.espFill) -- same color as NPC ESP
                    end
                end
                for _, plr in ipairs(plrs:GetPlayers()) do
                    local char = plr.Character
                    local hum = char and char:FindFirstChildOfClass("Humanoid")
                    if plr ~= lplr and char and hum and hum.Health > 0 then
                        seen[char] = true
                        setArrow(char, ESPX.playerColor(plr)) -- same color as Player ESP
                    end
                end
                for model, gui in pairs(headArrows) do
                    if not seen[model] or not model.Parent then
                        if gui then gui:Destroy() end
                        headArrows[model] = nil
                    end
                end
            elseif wasOn then
                wasOn = false
                clearHeadArrows()
            end
            task.wait(0.2)
        end
    end)

    -- Terminate button (Settings tab)
    setTab("Settings")
    createSection("[ DANGER ZONE ]")
    createActionButton("Terminate", function()
        -- Stop all saving first, so nothing below can write to the file.
        terminated = true

        for key in pairs(toggles) do toggles[key] = false end
        toggles.SelfHP = false

        pcall(stopSpectating)
        pcall(stopFly)
        pcall(setNoclip, false)
        pcall(clearItemESP)
        pcall(clearGeneratorESP)
        pcall(clearHeadArrows)
        pcall(ESPX.restoreWorld)
        pcall(ESPX.stopFreecam)
        pcall(ESPX.clearViewLines)
        pcall(ESPX.restoreHitboxes)
        pcall(removeSelfHP)
        pcall(function() crossDot:Remove(); crossOutline:Remove() end)

        for _, v in ipairs(ws:GetDescendants()) do
            if v:IsA("Highlight") and (v.Name == "NPCHighlight" or v.Name == "PlayerHighlight") then
                v:Destroy()
            elseif v:IsA("BillboardGui") and (v.Name == "EnemyHPESP" or v.Name == "PlayerInfoESP") then
                v:Destroy()
            end
        end

        local char = lplr.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = 16 end

        -- Disconnect every tracked service connection (input, render loops, player/workspace events).
        for _, connection in ipairs(ESPX.conns) do
            pcall(function() connection:Disconnect() end)
        end

        gui:Destroy()
    end)
    setTab("Main")
endlocal ws = game:GetService("Workspace")
local rs = game:GetService("RunService")
local uis = game:GetService("UserInputService")
local pps = game:GetService("ProximityPromptService")
local plrs = game:GetService("Players")
local lighting = game:GetService("Lighting")
local cg = game:GetService("CoreGui")

local cam = ws.CurrentCamera
local lplr = plrs.LocalPlayer

-- Set to true by the Terminate button. Stops loops and blocks all file saving.
local terminated = false

local flySpeed = 55
local HttpService = game:GetService("HttpService")
local settingsFile = "HRSH_MenuSettings.json"
local loadedSettings = {}
local function loadSettings()
    if type(isfile) == "function" and type(readfile) == "function" then
        local ok, exists = pcall(isfile, settingsFile)
        if ok and exists then
            local readOk, raw = pcall(readfile, settingsFile)
            if readOk and type(raw) == "string" then
                local decodeOk, data = pcall(function() return HttpService:JSONDecode(raw) end)
                if decodeOk and type(data) == "table" then loadedSettings = data end
            end
        end
    end
end
loadSettings()

local toggles = {
    AimAssist = false,
    ESP = false,
    EnemyHP = false,
    PlayerESP = false,
    ItemESP = false,
    GeneratorESP = false,
    HeadArrow = false,
    NoFog = false,
    CustomFOV = false,
    Freecam = false,
    ViewLine = false,
    AntiAFK = false,
    HitboxExtender = false,
    HitboxHead = true,
    HitboxBody = false,
    HitboxLegs = false,
    HitboxVisual = true,
    OverheadText = true,
    Crosshair = false,
    Fly = false,
    Noclip = false,
    Fullbright = false,
    InstantInteract = false,
    DelCorpses = false,
    Speed = false,
    GatherNPCs = false,
    -- Optimization
    LowVisuals = false,
    InstanceOptimizer = false,
    ParticleCap = false,
    UltraPotato = false,
}

local cfg = {
    aimStrength = 0.5,
    fov = 60,
    targetPart = "Head",
    maxDist = 500,
    delCorpses = true,
    maxEsp = 10,
    espFill = Color3.fromRGB(255, 0, 0),
    espOutline = Color3.fromRGB(255, 255, 255),
    fillTrans = 0.5,
    outTrans = 0,
    scanRate = 0.5,
    speed = 16,
    gatherDistance = 8,
    npcFillOpacity = 0.5, -- NPC ESP fill opacity
    npcOutlineOpacity = 1, -- NPC ESP outline opacity
    playerFillOpacity = 0.5, -- Player ESP fill opacity
    playerOutlineOpacity = 1, -- Player ESP outline opacity
    genFillOpacity = 0.5, -- Generator ESP fill opacity (0 = invisible, 1 = solid)
    genOutlineOpacity = 1, -- Generator ESP outline opacity
    genHue = 33, -- Generator ESP color hue in degrees (33 = orange)
    textOpacity = 1, -- overhead text opacity
    textSize = 13, -- overhead text size
    camFov = 70, -- camera field of view (used by Custom FOV)
    freecamSpeed = 50, -- freecam move speed (studs/second)
    viewLineLength = 60, -- View Line length in studs
    hitboxSize = 8, -- Hitbox Extender: size (studs) of each extended part
    hitboxTransparency = 0.7, -- Hitbox Extender: how see-through the extended parts are
    hitboxBoxOpacity = 0.4, -- Hitbox Extender: opacity of the always-visible hitbox box
    crosshairSize = 3, -- crosshair dot radius
    crosshairOpacity = 1, -- crosshair dot opacity
    crosshairHue = 0, -- crosshair color hue in degrees
    crosshairSat = 0, -- crosshair color saturation (0 = white)
}

-- Shared state table (helper functions are added to it further down).
local ESPX = {}
ESPX.toggleList = {}   -- every createToggle(): {name, key}, in creation order
ESPX.togglePaints = {} -- [key] = function that repaints the toggle
ESPX.toggleFlips = {}  -- [key] = function that flips the toggle exactly like clicking it
ESPX.sliders = {}      -- sliders that can be reset: {key, set}
-- Snapshot of the built-in defaults, taken before saved settings are loaded (for "Reset to Defaults").
ESPX.defaultToggles = {}
for key, value in pairs(toggles) do ESPX.defaultToggles[key] = value end
ESPX.defaultCfg = {}
for key, value in pairs(cfg) do
    if type(value) == "number" then ESPX.defaultCfg[key] = value end
end

-- Restore only known, serializable settings; preserve defaults for missing/invalid values.
if type(loadedSettings.toggles) == "table" then
    for key, value in pairs(loadedSettings.toggles) do
        if toggles[key] ~= nil and type(value) == "boolean" then toggles[key] = value end
    end
end
if type(loadedSettings.cfg) == "table" then
    for key, value in pairs(loadedSettings.cfg) do
        if type(cfg[key]) == "number" and type(value) == "number" then cfg[key] = value end
    end
end
if type(loadedSettings.flySpeed) == "number" then flySpeed = math.clamp(loadedSettings.flySpeed, 1, 200) end

-- Shared helpers: overhead text style and ESP colors.
-- Service connections are registered here so Terminate can disconnect every one of them.
ESPX.conns = {}
function ESPX.track(connection)
    ESPX.conns[#ESPX.conns + 1] = connection
    return connection
end

-- Noclip keeps a cached list of the character's parts instead of re-walking it every frame.
ESPX.noclipParts = {}
ESPX.noclipChar = nil
ESPX.noclipBuilt = 0

-- Overhead text: one master toggle, opacity and size for every floating label.
function ESPX.styleText(label, gui)
    if gui then gui.Enabled = toggles.OverheadText end
    if label then
        local t = 1 - math.clamp(cfg.textOpacity, 0, 1)
        label.TextTransparency = t
        label.TextStrokeTransparency = t
        label.TextSize = cfg.textSize
    end
end

function ESPX.teamKey(player)
    if player.Team then return "team:" .. player.Team:GetFullName() end
    if player.TeamColor and player.TeamColor ~= BrickColor.new("Medium stone grey") then
        return "color:" .. player.TeamColor.Name
    end
    for _, attrName in ipairs({"Team", "team", "Faction", "faction", "Role", "role"}) do
        local value = player:GetAttribute(attrName)
        if value ~= nil then return attrName:lower() .. ":" .. tostring(value):lower() end
    end
    return nil
end

function ESPX.playerColor(plr)
    local myTeam, playerTeam = ESPX.teamKey(lplr), ESPX.teamKey(plr)
    if myTeam and playerTeam then
        return myTeam == playerTeam and Color3.fromRGB(0, 120, 255) or Color3.fromRGB(220, 50, 50)
    end
    return Color3.fromRGB(0, 200, 80)
end

local function saveSettings()
    if terminated then return false end
    if type(writefile) ~= "function" then return false end

    -- JSONEncode cannot serialize Color3 / other Roblox datatypes in cfg.
    -- Save only the numeric config fields that this menu actually edits.
    local numericCfg = {
        aimStrength = cfg.aimStrength,
        fov = cfg.fov,
        speed = cfg.speed,
        gatherDistance = cfg.gatherDistance,
        npcFillOpacity = cfg.npcFillOpacity,
        npcOutlineOpacity = cfg.npcOutlineOpacity,
        playerFillOpacity = cfg.playerFillOpacity,
        playerOutlineOpacity = cfg.playerOutlineOpacity,
        genFillOpacity = cfg.genFillOpacity,
        genOutlineOpacity = cfg.genOutlineOpacity,
        genHue = cfg.genHue,
        textOpacity = cfg.textOpacity,
        textSize = cfg.textSize,
        camFov = cfg.camFov,
        freecamSpeed = cfg.freecamSpeed,
        viewLineLength = cfg.viewLineLength,
        hitboxSize = cfg.hitboxSize,
        hitboxTransparency = cfg.hitboxTransparency,
        hitboxBoxOpacity = cfg.hitboxBoxOpacity,
        crosshairSize = cfg.crosshairSize,
        crosshairOpacity = cfg.crosshairOpacity,
        crosshairHue = cfg.crosshairHue,
        crosshairSat = cfg.crosshairSat,
    }
    local payload = {
        toggles = toggles,
        cfg = numericCfg,
        flySpeed = flySpeed,
    }

    local ok, encoded = pcall(function()
        return HttpService:JSONEncode(payload)
    end)
    if not ok then
        warn("[BLACKWALL] Could not encode settings: " .. tostring(encoded))
        return false
    end

    local writeOk, writeErr = pcall(writefile, settingsFile, encoded)
    if not writeOk then
        warn("[BLACKWALL] Could not write settings file: " .. tostring(writeErr))
        return false
    end
    return true
end

-- Sliders call this while dragging: wait until the value stops changing, then write the file once.
ESPX.saveToken = 0
function ESPX.queueSave()
    ESPX.saveToken += 1
    local token = ESPX.saveToken
    task.delay(0.6, function()
        if token == ESPX.saveToken and not terminated then saveSettings() end
    end)
end

-- UI ONLY: refreshed HRSH interface. Feature logic below this block is unchanged.
local oldGui = cg:FindFirstChild("OmniMenu")
if oldGui then oldGui:Destroy() end

local C = {
    -- BLACKWALL palette: pitch-black surfaces, red UI accents, cyan TRUE, red FALSE
    bg = Color3.fromRGB(0, 0, 0),
    panel = Color3.fromRGB(7, 7, 8),
    panel2 = Color3.fromRGB(18, 5, 7),
    hover = Color3.fromRGB(42, 8, 12),
    accent = Color3.fromRGB(220, 24, 42), -- red = general UI accents
    accentDark = Color3.fromRGB(150, 10, 24),
    trueState = Color3.fromRGB(0, 220, 235), -- cyan = TRUE / enabled
    outline = Color3.fromRGB(125, 16, 28),
    text = Color3.fromRGB(242, 242, 245),
    muted = Color3.fromRGB(155, 135, 138),
    off = Color3.fromRGB(220, 24, 42), -- red = FALSE / disabled
    green = Color3.fromRGB(0, 220, 235),
}

-- Blackwall style is hard-edged: UICorner calls are intentionally no-ops.
local function corner(parent, radius)
    return nil
end

local function stroke(parent, color, transparency, thickness)
    local s = Instance.new("UIStroke")
    s.Color = color or C.hover
    s.Transparency = transparency or 0
    s.Thickness = thickness or 1
    s.Parent = parent
    return s
end

local gui = Instance.new("ScreenGui")
gui.Name = "OmniMenu"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999999
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = cg

local TweenService = game:GetService("TweenService")

local main = Instance.new("Frame")
main.Name = "main"
main.Parent = gui
main.BackgroundColor3 = Color3.fromRGB(255, 255, 255) -- colored by the gradient below
main.BorderSizePixel = 0
main.Position = UDim2.new(0.035, 0, 0.12, 0)
main.Size = UDim2.new(0, 390, 0, 560)
main.Active = true
main.Draggable = false
main.ClipsDescendants = true
stroke(main, C.outline, 0.05, 1)
local sizeConstraint = Instance.new("UISizeConstraint")
sizeConstraint.Parent = main
sizeConstraint.MinSize = Vector2.new(320, 360)
sizeConstraint.MaxSize = Vector2.new(460, 760)

-- Pitch black fading into a faint blood-red haze at the bottom.
local mainGradient = Instance.new("UIGradient")
mainGradient.Rotation = 90
mainGradient.Color = ColorSequence.new(Color3.fromRGB(0, 0, 0), Color3.fromRGB(26, 2, 6))
mainGradient.Parent = main

local topAccent = Instance.new("Frame")
topAccent.Parent = main
topAccent.Size = UDim2.new(1, 0, 0, 2)
topAccent.BackgroundColor3 = C.accent
topAccent.BorderSizePixel = 0
topAccent.ZIndex = 4

-- Header ---------------------------------------------------------------
local header = Instance.new("Frame")
header.Parent = main
header.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
header.BorderSizePixel = 0
header.Position = UDim2.new(0, 0, 0, 3)
header.Size = UDim2.new(1, 0, 0, 58)
header.ZIndex = 3
local headerGradient = Instance.new("UIGradient")
headerGradient.Color = ColorSequence.new(Color3.fromRGB(7, 7, 8), Color3.fromRGB(58, 5, 12))
headerGradient.Parent = header

local headerLine = Instance.new("Frame")
headerLine.Parent = header
headerLine.AnchorPoint = Vector2.new(0, 1)
headerLine.Position = UDim2.new(0, 0, 1, 0)
headerLine.Size = UDim2.new(1, 0, 0, 1)
headerLine.BackgroundColor3 = C.outline
headerLine.BorderSizePixel = 0
headerLine.ZIndex = 4

local logo = Instance.new("Frame")
logo.Parent = header
logo.Position = UDim2.new(0, 12, 0, 12)
logo.Size = UDim2.new(0, 32, 0, 32)
logo.BackgroundColor3 = C.bg
logo.BorderSizePixel = 0
logo.ZIndex = 4
stroke(logo, C.accent, 0, 1)
-- Emblem built from frames (no font glyph needed): a diamond "ICE eye" with a pulsing core.
local logoRing = Instance.new("Frame")
logoRing.Parent = logo
logoRing.AnchorPoint = Vector2.new(0.5, 0.5)
logoRing.Position = UDim2.new(0.5, 0, 0.5, 0)
logoRing.Size = UDim2.new(0, 16, 0, 16)
logoRing.Rotation = 45
logoRing.BackgroundTransparency = 1
logoRing.BorderSizePixel = 0
logoRing.ZIndex = 5
stroke(logoRing, C.accent, 0, 2)
local logoCore = Instance.new("Frame")
logoCore.Parent = logo
logoCore.AnchorPoint = Vector2.new(0.5, 0.5)
logoCore.Position = UDim2.new(0.5, 0, 0.5, 0)
logoCore.Size = UDim2.new(0, 6, 0, 6)
logoCore.Rotation = 45
logoCore.BackgroundColor3 = C.accent
logoCore.BorderSizePixel = 0
logoCore.ZIndex = 6
for _, side in ipairs({0, 1}) do
    local tick = Instance.new("Frame")
    tick.Parent = logo
    tick.AnchorPoint = Vector2.new(side, 0.5)
    tick.Position = UDim2.new(side, 0, 0.5, 0)
    tick.Size = UDim2.new(0, 5, 0, 2)
    tick.BackgroundColor3 = C.accent
    tick.BorderSizePixel = 0
    tick.ZIndex = 5
end

local title = Instance.new("TextLabel")
title.Parent = header
title.BackgroundTransparency = 1
title.Position = UDim2.new(0, 54, 0, 10)
title.Size = UDim2.new(1, -140, 0, 22)
title.Font = Enum.Font.Code
title.Text = "BLACKWALL  //  MAIN SYSTEM"
title.TextColor3 = C.text
title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left
title.ZIndex = 5
local subtitle = Instance.new("TextLabel")
subtitle.Parent = header
subtitle.BackgroundTransparency = 1
subtitle.Position = UDim2.new(0, 54, 0, 33)
subtitle.Size = UDim2.new(1, -140, 0, 14)
subtitle.Font = Enum.Font.Code
subtitle.Text = "UNAUTHORIZED ACCESS  •  RightCTRL Default"
subtitle.TextColor3 = C.muted
subtitle.TextSize = 9
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.ZIndex = 5

-- Hazard stripes + blinking link status (top right of the header).
local stripes = Instance.new("TextLabel")
stripes.Parent = header
stripes.BackgroundTransparency = 1
stripes.AnchorPoint = Vector2.new(1, 0)
stripes.Position = UDim2.new(1, -12, 0, 9)
stripes.Size = UDim2.new(0, 80, 0, 16)
stripes.Font = Enum.Font.Code
stripes.Text = "////////"
stripes.TextColor3 = C.accent
stripes.TextTransparency = 0.35
stripes.TextSize = 14
stripes.TextXAlignment = Enum.TextXAlignment.Right
stripes.ZIndex = 5
local linkStatus = Instance.new("TextLabel")
linkStatus.Parent = header
linkStatus.BackgroundTransparency = 1
linkStatus.AnchorPoint = Vector2.new(1, 0)
linkStatus.Position = UDim2.new(1, -12, 0, 31)
linkStatus.Size = UDim2.new(0, 80, 0, 14)
linkStatus.Font = Enum.Font.Code
linkStatus.Text = "● LINK ACTIVE"
linkStatus.TextColor3 = C.trueState
linkStatus.TextSize = 9
linkStatus.TextXAlignment = Enum.TextXAlignment.Right
linkStatus.ZIndex = 5

-- Corner brackets
local function addBracket(parent, ax, ay)
    for _, size in ipairs({Vector2.new(14, 2), Vector2.new(2, 14)}) do
        local f = Instance.new("Frame")
        f.Parent = parent
        f.AnchorPoint = Vector2.new(ax, ay)
        f.Position = UDim2.new(ax, 0, ay, 0)
        f.Size = UDim2.new(0, size.X, 0, size.Y)
        f.BackgroundColor3 = C.accent
        f.BorderSizePixel = 0
        f.ZIndex = 60
    end
end
addBracket(main, 0, 0)
addBracket(main, 1, 0)
addBracket(main, 0, 1)
addBracket(main, 1, 1)

-- Slow red scanline sweeping down the panel (does not block input).
local scanline = Instance.new("Frame")
scanline.Name = "Scanline"
scanline.Parent = main
scanline.BackgroundColor3 = C.accent
scanline.BackgroundTransparency = 0.88
scanline.BorderSizePixel = 0
scanline.Active = false
scanline.Size = UDim2.new(1, 0, 0, 2)
scanline.Position = UDim2.new(0, 0, 0, 0)
scanline.ZIndex = 50
TweenService:Create(
    scanline,
    TweenInfo.new(4, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1, false, 0),
    {Position = UDim2.new(0, 0, 1, 0)}
):Play()

-- Occasional title glitch + blinking link light.
task.spawn(function()
    local basePos = title.Position
    while not terminated and title.Parent do
        task.wait(math.random(25, 60) / 10)
        for _ = 1, math.random(2, 4) do
            if terminated or not title.Parent then return end
            title.Position = basePos + UDim2.new(0, math.random(-3, 3), 0, math.random(-1, 1))
            title.TextColor3 = (math.random() > 0.5) and C.accent or C.trueState
            task.wait(0.04)
        end
        if title.Parent then
            title.Position = basePos
            title.TextColor3 = C.text
        end
    end
end)
task.spawn(function()
    local bright = true
    while not terminated and linkStatus.Parent do
        linkStatus.TextTransparency = bright and 0 or 0.65
        logoCore.BackgroundColor3 = bright and C.accent or C.accentDark
        bright = not bright
        task.wait(0.6)
    end
end)

-- Footer: operator name, FPS and ping --------------------------------------
local footer = Instance.new("Frame")
footer.Parent = main
footer.AnchorPoint = Vector2.new(0, 1)
footer.Position = UDim2.new(0, 0, 1, 0)
footer.Size = UDim2.new(1, 0, 0, 20)
footer.BackgroundColor3 = C.panel
footer.BorderSizePixel = 0
footer.ZIndex = 12
local footerLine = Instance.new("Frame")
footerLine.Parent = footer
footerLine.Size = UDim2.new(1, 0, 0, 1)
footerLine.BackgroundColor3 = C.outline
footerLine.BorderSizePixel = 0
footerLine.ZIndex = 13
local footerLeft = Instance.new("TextLabel")
footerLeft.Parent = footer
footerLeft.BackgroundTransparency = 1
footerLeft.Position = UDim2.new(0, 10, 0, 1)
footerLeft.Size = UDim2.new(0.6, 0, 1, -1)
footerLeft.Font = Enum.Font.Code
footerLeft.Text = "NETRUNNER  ▸  " .. string.upper(lplr.Name)
footerLeft.TextColor3 = C.muted
footerLeft.TextSize = 9
footerLeft.TextXAlignment = Enum.TextXAlignment.Left
footerLeft.TextTruncate = Enum.TextTruncate.AtEnd
footerLeft.ZIndex = 13
local footerRight = Instance.new("TextLabel")
footerRight.Parent = footer
footerRight.BackgroundTransparency = 1
footerRight.AnchorPoint = Vector2.new(1, 0)
footerRight.Position = UDim2.new(1, -10, 0, 1)
footerRight.Size = UDim2.new(0.4, 0, 1, -1)
footerRight.Font = Enum.Font.Code
footerRight.Text = "FPS --  |  PING --"
footerRight.TextColor3 = C.accent
footerRight.TextSize = 9
footerRight.TextXAlignment = Enum.TextXAlignment.Right
footerRight.ZIndex = 13

task.spawn(function()
    local frames, elapsed = 0, 0
    local hb = rs.Heartbeat:Connect(function(dt)
        frames += 1
        elapsed += dt
    end)
    while not terminated and footerRight.Parent do
        task.wait(0.5)
        local fps = elapsed > 0 and math.floor(frames / elapsed + 0.5) or 0
        frames, elapsed = 0, 0
        local ping = 0
        pcall(function() ping = math.floor(lplr:GetNetworkPing() * 1000 + 0.5) end)
        if footerRight.Parent then
            footerRight.Text = string.format("FPS %d  |  PING %dms", fps, ping)
        end
    end
    hb:Disconnect()
end)

-- Category tabs: horizontally scrollable so every category remains reachable.
local tabBar = Instance.new("ScrollingFrame")
tabBar.Name = "CategoryTabs"
tabBar.Parent = main
tabBar.BackgroundTransparency = 1
tabBar.BorderSizePixel = 0
tabBar.Position = UDim2.new(0, 8, 0, 65)
tabBar.Size = UDim2.new(1, -16, 0, 32)
tabBar.ZIndex = 8
tabBar.ScrollingDirection = Enum.ScrollingDirection.X
tabBar.ScrollBarThickness = 0
tabBar.ScrollBarImageColor3 = C.accent
tabBar.ScrollBarImageTransparency = 0.15
tabBar.CanvasSize = UDim2.new(0, 0, 0, 0)
tabBar.AutomaticCanvasSize = Enum.AutomaticSize.X
local tabLayout = Instance.new("UIListLayout")
tabLayout.Parent = tabBar
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabLayout.Padding = UDim.new(0, 5)
tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left

local tabDivider = Instance.new("Frame")
tabDivider.Parent = main
tabDivider.Position = UDim2.new(0, 8, 0, 100)
tabDivider.Size = UDim2.new(1, -16, 0, 1)
tabDivider.BackgroundColor3 = C.outline
tabDivider.BackgroundTransparency = 0.35
tabDivider.BorderSizePixel = 0
tabDivider.ZIndex = 8

-- Only the title/header strip and the footer can drag the menu.
-- Content controls (including the 3D avatar viewport) never initiate window dragging.
local menuDragging = false
local menuDragStart = nil
local menuStartPosition = nil
local function beginMenuDrag(input)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1
        and input.UserInputType ~= Enum.UserInputType.Touch then return end
    menuDragging = true
    menuDragStart = input.Position
    menuStartPosition = main.Position
end
header.InputBegan:Connect(beginMenuDrag)
footer.InputBegan:Connect(beginMenuDrag)
ESPX.track(uis.InputChanged:Connect(function(input)
    if menuDragging and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - menuDragStart
        main.Position = UDim2.new(
            menuStartPosition.X.Scale, menuStartPosition.X.Offset + delta.X,
            menuStartPosition.Y.Scale, menuStartPosition.Y.Offset + delta.Y
        )
    end
end))
ESPX.track(uis.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        menuDragging = false
    end
end))

local tabPages = {}
local tabButtons = {}
local tabIndicators = {}
local activeTab = "Main"
local scroll, layout
local function setTab(name)
    activeTab = name
    for tabName, page in pairs(tabPages) do
        page.Visible = (tabName == name)
    end
    for tabName, button in pairs(tabButtons) do
        local selected = tabName == name
        button.BackgroundColor3 = selected and C.hover or C.panel
        button.TextColor3 = selected and C.text or C.muted
        tabIndicators[tabName].Visible = selected
    end
    scroll = tabPages[name]
    layout = scroll and scroll:FindFirstChildOfClass("UIListLayout")
end

for order, name in ipairs({"Main", "Visual", "Movement", "Overwatch", "Settings", "Binds"}) do
    local page = Instance.new("ScrollingFrame")
    page.Name = name .. "Page"
    page.Parent = main
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.Position = UDim2.new(0, 0, 0, 105)
    page.Size = UDim2.new(1, 0, 1, -129)
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.ScrollBarThickness = 3
    page.ScrollBarImageColor3 = C.accent
    page.ScrollBarImageTransparency = 0
    page.ScrollingEnabled = true
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.Visible = false
    page.ZIndex = 5
    local pageLayout = Instance.new("UIListLayout")
    pageLayout.Parent = page
    pageLayout.Padding = UDim.new(0, 4)
    pageLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    pageLayout.SortOrder = Enum.SortOrder.LayoutOrder
    local pagePadding = Instance.new("UIPadding")
    pagePadding.Parent = page
    pagePadding.PaddingTop = UDim.new(0, 6)
    pagePadding.PaddingBottom = UDim.new(0, 8)

    local button = Instance.new("TextButton")
    button.Name = name .. "Tab"
    button.Parent = tabBar
    button.LayoutOrder = order
    local tabWidths = {Main = 46, Visual = 52, Movement = 62, Overwatch = 76, Settings = 54, Binds = 46}
    button.Size = UDim2.new(0, tabWidths[name] or 60, 1, 0)
    button.BackgroundColor3 = C.panel
    button.BorderSizePixel = 0
    button.AutoButtonColor = false
    button.Font = Enum.Font.Code
    button.Text = string.upper(name)
    button.TextSize = 10
    button.TextColor3 = C.muted
    button.ZIndex = 9
    stroke(button, C.outline, 0.4, 1)

    -- Bottom indicator bar for the active tab.
    local indicator = Instance.new("Frame")
    indicator.Name = "Indicator"
    indicator.Parent = button
    indicator.AnchorPoint = Vector2.new(0, 1)
    indicator.Position = UDim2.new(0, 0, 1, 0)
    indicator.Size = UDim2.new(1, 0, 0, 2)
    indicator.BackgroundColor3 = C.accent
    indicator.BorderSizePixel = 0
    indicator.Visible = false
    indicator.ZIndex = 10

    button.MouseButton1Click:Connect(function() setTab(name) end)
    button.MouseEnter:Connect(function()
        if activeTab ~= name then button.TextColor3 = C.text end
    end)
    button.MouseLeave:Connect(function()
        if activeTab ~= name then button.TextColor3 = C.muted end
    end)
    tabPages[name] = page
    tabButtons[name] = button
    tabIndicators[name] = indicator
end
setTab("Main")

-- Section header: red notch, "// TITLE", and a rule with a bright leading segment.
local function createSection(name)
    local clean = (string.gsub(string.gsub(name, "^%[%s*", ""), "%s*%]$", ""))
    local wrap = Instance.new("Frame")
    wrap.Parent = scroll
    wrap.BackgroundTransparency = 1
    wrap.Size = UDim2.new(1, -20, 0, 26)
    wrap.BorderSizePixel = 0
    local notch = Instance.new("Frame")
    notch.Parent = wrap
    notch.BackgroundColor3 = C.accent
    notch.BorderSizePixel = 0
    notch.Position = UDim2.new(0, 1, 0, 6)
    notch.Size = UDim2.new(0, 6, 0, 10)
    local lbl = Instance.new("TextLabel")
    lbl.Parent = wrap
    lbl.BackgroundTransparency = 1
    lbl.Position = UDim2.new(0, 14, 0, 0)
    lbl.Size = UDim2.new(1, -14, 0, 22)
    lbl.Font = Enum.Font.Code
    lbl.Text = "// " .. string.upper(clean)
    lbl.TextColor3 = C.accent
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    local rule = Instance.new("Frame")
    rule.Parent = wrap
    rule.BackgroundColor3 = C.outline
    rule.BackgroundTransparency = 0.35
    rule.BorderSizePixel = 0
    rule.Position = UDim2.new(0, 0, 1, -3)
    rule.Size = UDim2.new(1, 0, 0, 1)
    local ruleLead = Instance.new("Frame")
    ruleLead.Parent = wrap
    ruleLead.BackgroundColor3 = C.accent
    ruleLead.BorderSizePixel = 0
    ruleLead.Position = UDim2.new(0, 0, 1, -3)
    ruleLead.Size = UDim2.new(0, 36, 0, 1)
end

local function createActionButton(name, callback)
    local danger = (name == "Terminate")
    local prefix = "> "
    local baseText = danger and C.accent or C.text
    local baseBg = danger and C.panel2 or C.panel

    local b = Instance.new("TextButton")
    b.Parent = scroll
    b.BackgroundColor3 = baseBg
    b.Size = UDim2.new(1, -20, 0, 36)
    b.Font = Enum.Font.Code
    b.Text = prefix .. name
    b.TextColor3 = baseText
    b.TextSize = 12
    b.TextXAlignment = Enum.TextXAlignment.Left
    b.BorderSizePixel = 0
    b.ZIndex = 7
    b.AutoButtonColor = false
    local pad = Instance.new("UIPadding")
    pad.Parent = b
    pad.PaddingLeft = UDim.new(0, 14)
    local edge = stroke(b, C.outline, 0.12, 1)
    local bar = Instance.new("Frame")
    bar.Parent = b
    bar.BackgroundColor3 = danger and C.accent or C.accentDark
    bar.BorderSizePixel = 0
    bar.Position = UDim2.new(0, -14, 0, 0)
    bar.Size = UDim2.new(0, 3, 1, 0)
    bar.ZIndex = 8

    b.MouseEnter:Connect(function()
        b.BackgroundColor3 = C.hover
        b.TextColor3 = Color3.fromRGB(255, 255, 255)
        bar.BackgroundColor3 = C.accent
        edge.Color = C.accent
    end)
    b.MouseLeave:Connect(function()
        b.BackgroundColor3 = baseBg
        b.TextColor3 = baseText
        bar.BackgroundColor3 = danger and C.accent or C.accentDark
        edge.Color = C.outline
    end)
    b.MouseButton1Click:Connect(function()
        local ok, message = pcall(callback)
        b.Text = prefix .. name .. "  " .. (ok and (type(message) == "string" and message or "[DONE]") or "[ERROR]")
        if not ok then warn("[BLACKWALL] " .. tostring(message)) end
        task.delay(1.5, function()
            if b and b.Parent then b.Text = prefix .. name end
        end)
    end)
    return b
end

-- Toggle: status bar on the left, [ ON ] / [ OFF ] readout on the right.
local function createToggle(name, key)
    local b = Instance.new("TextButton")
    b.Parent = scroll
    b.BackgroundColor3 = C.panel
    b.Size = UDim2.new(1, -20, 0, 34)
    b.Font = Enum.Font.Code
    b.Text = ""
    b.TextColor3 = C.text
    b.TextSize = 12
    b.BorderSizePixel = 0
    b.ZIndex = 7
    b.AutoButtonColor = false
    local edge = stroke(b, C.outline, 0.2, 1)

    local bar = Instance.new("Frame")
    bar.Parent = b
    bar.BorderSizePixel = 0
    bar.Size = UDim2.new(0, 3, 1, 0)
    bar.ZIndex = 8

    local label = Instance.new("TextLabel")
    label.Parent = b
    label.BackgroundTransparency = 1
    label.Position = UDim2.new(0, 14, 0, 0)
    label.Size = UDim2.new(1, -90, 1, 0)
    label.Font = Enum.Font.Code
    label.Text = name
    label.TextColor3 = C.text
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.ZIndex = 8

    local status = Instance.new("TextLabel")
    status.Parent = b
    status.BackgroundTransparency = 1
    status.AnchorPoint = Vector2.new(1, 0.5)
    status.Position = UDim2.new(1, -10, 0.5, 0)
    status.Size = UDim2.new(0, 64, 0, 16)
    status.Font = Enum.Font.Code
    status.TextSize = 11
    status.TextXAlignment = Enum.TextXAlignment.Right
    status.ZIndex = 8

    local function paint()
        local on = toggles[key]
        status.Text = on and "[ ON ]" or "[ OFF ]"
        status.TextColor3 = on and C.trueState or C.off
        bar.BackgroundColor3 = on and C.trueState or C.off
        b.BackgroundColor3 = on and Color3.fromRGB(0, 18, 22) or C.panel
        edge.Color = on and C.trueState or C.outline
        edge.Transparency = on and 0.35 or 0.2
    end
    paint()
    b.MouseEnter:Connect(function()
        if not toggles[key] then
            b.BackgroundColor3 = C.panel2
            edge.Color = C.accent
        end
    end)
    b.MouseLeave:Connect(paint)
    local function flip()
        toggles[key] = not toggles[key]
        saveSettings()
        paint()
        if key == "ESP" and not toggles.ESP then
            for _, v in ipairs(ws:GetDescendants()) do
                if v.Name == "NPCHighlight" then v:Destroy() end
            end
        end
    end
    ESPX.toggleList[#ESPX.toggleList + 1] = {name = name, key = key}
    ESPX.togglePaints[key] = paint
    ESPX.toggleFlips[key] = flip
    b.MouseButton1Click:Connect(flip)
end

-- Slider: thin rail, red fill, diamond thumb and tick marks. Click anywhere on the rail or drag.
local function createSlider(name, minV, maxV, def, cb, key)
    local container = Instance.new("Frame")
    container.Parent = scroll
    container.BackgroundColor3 = C.panel
    container.Size = UDim2.new(1, -20, 0, 60)
    container.BorderSizePixel = 0
    container.ZIndex = 6
    stroke(container, C.outline, 0.15, 1)

    local sideBar = Instance.new("Frame")
    sideBar.Parent = container
    sideBar.BackgroundColor3 = C.accentDark
    sideBar.BorderSizePixel = 0
    sideBar.Size = UDim2.new(0, 3, 1, 0)
    sideBar.ZIndex = 7

    local lbl = Instance.new("TextLabel")
    lbl.Parent = container
    lbl.BackgroundTransparency = 1
    lbl.Position = UDim2.new(0, 14, 0, 7)
    lbl.Size = UDim2.new(1, -100, 0, 19)
    lbl.Font = Enum.Font.Code
    lbl.Text = name
    lbl.TextColor3 = C.text
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 7

    local valueBox = Instance.new("TextLabel")
    valueBox.Parent = container
    valueBox.AnchorPoint = Vector2.new(1, 0)
    valueBox.Position = UDim2.new(1, -11, 0, 7)
    valueBox.Size = UDim2.new(0, 62, 0, 18)
    valueBox.BackgroundColor3 = C.bg
    valueBox.BorderSizePixel = 0
    valueBox.Font = Enum.Font.Code
    valueBox.TextColor3 = C.accent
    valueBox.TextSize = 11
    valueBox.Text = tostring(def)
    valueBox.ZIndex = 8
    stroke(valueBox, C.outline, 0.2, 1)

    -- Transparent hit area so the rail is easy to click.
    local back = Instance.new("TextButton")
    back.Parent = container
    back.AutoButtonColor = false
    back.Text = ""
    back.BackgroundTransparency = 1
    back.Position = UDim2.new(0, 14, 0, 32)
    back.Size = UDim2.new(1, -28, 0, 18)
    back.BorderSizePixel = 0
    back.ZIndex = 7

    local rail = Instance.new("Frame")
    rail.Parent = back
    rail.AnchorPoint = Vector2.new(0, 0.5)
    rail.Position = UDim2.new(0, 0, 0.5, 0)
    rail.Size = UDim2.new(1, 0, 0, 4)
    rail.BackgroundColor3 = Color3.fromRGB(40, 8, 12)
    rail.BorderSizePixel = 0
    rail.ZIndex = 7

    local ratio0 = math.clamp((def - minV) / (maxV - minV), 0, 1)
    local fill = Instance.new("Frame")
    fill.Parent = rail
    fill.BackgroundColor3 = C.accent
    fill.Size = UDim2.new(ratio0, 0, 1, 0)
    fill.BorderSizePixel = 0
    fill.ZIndex = 8

    -- Tick marks every 10%.
    local ticks = Instance.new("Frame")
    ticks.Parent = container
    ticks.BackgroundTransparency = 1
    ticks.Position = UDim2.new(0, 14, 0, 51)
    ticks.Size = UDim2.new(1, -28, 0, 4)
    ticks.ZIndex = 7
    for i = 0, 10 do
        local tick = Instance.new("Frame")
        tick.Parent = ticks
        tick.AnchorPoint = Vector2.new(0.5, 0)
        tick.Position = UDim2.new(i / 10, 0, 0, 0)
        tick.Size = UDim2.new(0, 1, 0, (i % 5 == 0) and 4 or 2)
        tick.BackgroundColor3 = C.outline
        tick.BorderSizePixel = 0
        tick.ZIndex = 7
    end

    local thumb = Instance.new("Frame")
    thumb.Parent = back
    thumb.AnchorPoint = Vector2.new(0.5, 0.5)
    thumb.Position = UDim2.new(ratio0, 0, 0.5, 0)
    thumb.Size = UDim2.new(0, 9, 0, 9)
    thumb.Rotation = 45
    thumb.BackgroundColor3 = C.text
    thumb.BorderSizePixel = 0
    thumb.ZIndex = 9
    stroke(thumb, C.accent, 0, 2)

    local dragging = false
    local function updateFromX(x)
        local width = math.max(1, back.AbsoluteSize.X)
        local pos = math.clamp((x - back.AbsolutePosition.X) / width, 0, 1)
        local val = minV + (maxV - minV) * pos
        val = math.floor(val * 100 + 0.5) / 100
        if maxV - minV >= 10 then val = math.floor(val + 0.5) end
        local ratio = math.clamp((val - minV) / (maxV - minV), 0, 1)
        fill.Size = UDim2.new(ratio, 0, 1, 0)
        thumb.Position = UDim2.new(ratio, 0, 0.5, 0)
        valueBox.Text = tostring(val)
        if cb then cb(val) end
        ESPX.queueSave()
    end
    if key then
        ESPX.sliders[#ESPX.sliders + 1] = {
            key = key,
            set = function(val) -- used by Reset to Defaults (does not write the settings file)
                local ratio = math.clamp((val - minV) / (maxV - minV), 0, 1)
                fill.Size = UDim2.new(ratio, 0, 1, 0)
                thumb.Position = UDim2.new(ratio, 0, 0.5, 0)
                valueBox.Text = tostring(val)
                if cb then cb(val) end
            end,
        }
    end
    back.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            updateFromX(input.Position.X)
        end
    end)
    thumb.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            updateFromX(input.Position.X)
        end
    end)
    ESPX.track(uis.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end))
    ESPX.track(uis.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateFromX(input.Position.X)
        end
    end))
end

-- Main: ESP, targeting, and other visual/utility controls.
setTab("Main")
createSection("[ UTILITY ]")
createToggle("Aim Assist", "AimAssist")
createToggle("Instant Interact", "InstantInteract")
createToggle("Anti AFK", "AntiAFK")
createToggle("Del Corpses", "DelCorpses")
createToggle("Gather NPCs", "GatherNPCs")
createSection("[ AIM SETTINGS ]")
createSlider("Aim Strength", 0.01, 1.0, cfg.aimStrength, function(v) cfg.aimStrength = v end, "aimStrength")
createSlider("FOV", 10, 300, cfg.fov, function(v) cfg.fov = v end, "fov")
createSlider("Gather Distance", 1, 30, cfg.gatherDistance, function(v) cfg.gatherDistance = v end, "gatherDistance")
createSection("[ HITBOX EXTENDER ]")
createToggle("Hitbox Extender", "HitboxExtender")
createToggle("Extend Head", "HitboxHead")
createToggle("Extend Body", "HitboxBody")
createToggle("Extend Legs", "HitboxLegs")
createToggle("Show Hitbox", "HitboxVisual")
createSlider("Hitbox Size", 2, 30, cfg.hitboxSize, function(v) cfg.hitboxSize = v end, "hitboxSize")
createSlider("Hitbox Transparency", 0, 1, cfg.hitboxTransparency, function(v) cfg.hitboxTransparency = v end, "hitboxTransparency")
createSlider("Hitbox Box Opacity", 0, 1, cfg.hitboxBoxOpacity, function(v) cfg.hitboxBoxOpacity = v end, "hitboxBoxOpacity")

-- Visual: every ESP / overlay / on-screen display option lives here.
setTab("Visual")
createSection("[ VISUALS ]")
createToggle("NPC ESP", "ESP")
createToggle("Enemy HP", "EnemyHP")
createToggle("Player ESP", "PlayerESP")
createToggle("My HP", "SelfHP")
createToggle("Item ESP", "ItemESP")
createToggle("Generator ESP", "GeneratorESP")
createToggle("Head Arrow", "HeadArrow")
createSection("[ VIEW LINE ]")
createToggle("View Line", "ViewLine")
createSlider("View Line Length", 10, 300, cfg.viewLineLength, function(v) cfg.viewLineLength = v end, "viewLineLength")
createSection("[ WORLD ]")
createToggle("Fullbright", "Fullbright")
createToggle("No Fog", "NoFog")
createToggle("Custom FOV", "CustomFOV")
createSlider("Camera FOV", 30, 120, cfg.camFov, function(v) cfg.camFov = v end, "camFov")
createSection("[ CROSSHAIR ]")
createToggle("Crosshair", "Crosshair")
createSlider("Crosshair Size", 1, 12, cfg.crosshairSize, function(v) cfg.crosshairSize = v end, "crosshairSize")
createSlider("Crosshair Opacity", 0, 1, cfg.crosshairOpacity, function(v) cfg.crosshairOpacity = v end, "crosshairOpacity")
createSlider("Crosshair Hue", 0, 360, cfg.crosshairHue, function(v) cfg.crosshairHue = v end, "crosshairHue")
createSlider("Crosshair Saturation", 0, 1, cfg.crosshairSat, function(v) cfg.crosshairSat = v end, "crosshairSat")
createSection("[ OVERHEAD TEXT ]")
createToggle("Overhead Text", "OverheadText")
createSlider("Text Opacity", 0, 1, cfg.textOpacity, function(v) cfg.textOpacity = v end, "textOpacity")
createSlider("Text Size", 8, 24, cfg.textSize, function(v) cfg.textSize = v end, "textSize")
createSection("[ NPC ESP SETTINGS ]")
createSlider("NPC Fill Opacity", 0, 1, cfg.npcFillOpacity, function(v) cfg.npcFillOpacity = v end, "npcFillOpacity")
createSlider("NPC Outline Opacity", 0, 1, cfg.npcOutlineOpacity, function(v) cfg.npcOutlineOpacity = v end, "npcOutlineOpacity")
createSection("[ PLAYER ESP SETTINGS ]")
createSlider("Player Fill Opacity", 0, 1, cfg.playerFillOpacity, function(v) cfg.playerFillOpacity = v end, "playerFillOpacity")
createSlider("Player Outline Opacity", 0, 1, cfg.playerOutlineOpacity, function(v) cfg.playerOutlineOpacity = v end, "playerOutlineOpacity")
createSection("[ GENERATOR ESP SETTINGS ]")
createSlider("Fill Opacity", 0, 1, cfg.genFillOpacity, function(v) cfg.genFillOpacity = v end, "genFillOpacity")
createSlider("Outline Opacity", 0, 1, cfg.genOutlineOpacity, function(v) cfg.genOutlineOpacity = v end, "genOutlineOpacity")
createSlider("Color Hue", 0, 360, cfg.genHue, function(v) cfg.genHue = v end, "genHue")

-- Movement: movement toggles and speed controls.
setTab("Movement")
createSection("[ MOVEMENT ]")
createToggle("Noclip", "Noclip")
createToggle("Fly", "Fly")
createToggle("Speed Modifier", "Speed")

createSection("[ MOVEMENT SETTINGS ]")
createSlider("Walk Speed", 1, 100, cfg.speed, function(v) cfg.speed = v end, "speed")
createSlider("Fly Speed", 1, 200, 55, function(v) flySpeed = v end, "flySpeed")

-- Overwatch uses one shared player list for teleporting, spectating, and player info.
setTab("Overwatch")

createSection("[ FREECAM ]")
createToggle("Freecam", "Freecam")
createSlider("Freecam Speed", 1, 300, cfg.freecamSpeed, function(v) cfg.freecamSpeed = v end, "freecamSpeed")
createActionButton("Teleport to Freecam Position", function()
    local target = ESPX.getFreecamPos and ESPX.getFreecamPos()
    if not target then error("Turn Freecam on first") end
    local character = lplr.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then error("Your character is unavailable") end
    -- Keep your current facing, move to where the camera is, and drop any leftover momentum.
    root.CFrame = CFrame.new(target) * (root.CFrame - root.CFrame.Position)
    root.AssemblyLinearVelocity = Vector3.zero
end)

local selectedSpectatePlayer = nil
local updateSpectateInfo

-- The same list below drives both teleport and spectate actions.
createSection("[ PLAYER LIST ]")

local spectateTargetPlayer = nil
local spectateRenderConnection = nil
local spectatePlayerList = Instance.new("Frame")
spectatePlayerList.Name = "OverwatchPlayerList"
spectatePlayerList.Parent = scroll
spectatePlayerList.BackgroundColor3 = C.panel
spectatePlayerList.BorderSizePixel = 0
spectatePlayerList.Size = UDim2.new(1, -20, 0, 180)
spectatePlayerList.ZIndex = 7
corner(spectatePlayerList, 2)
stroke(spectatePlayerList, C.outline, 0.12, 1)

local spectateListScroll = Instance.new("ScrollingFrame")
spectateListScroll.Name = "Players"
spectateListScroll.Parent = spectatePlayerList
spectateListScroll.BackgroundTransparency = 1
spectateListScroll.BorderSizePixel = 0
spectateListScroll.Position = UDim2.new(0, 4, 0, 4)
spectateListScroll.Size = UDim2.new(1, -8, 1, -8)
spectateListScroll.ScrollBarThickness = 4
spectateListScroll.ScrollBarImageColor3 = C.accent
spectateListScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
spectateListScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
spectateListScroll.ScrollingDirection = Enum.ScrollingDirection.Y
spectateListScroll.ZIndex = 8
local spectateListLayout = Instance.new("UIListLayout")
spectateListLayout.Parent = spectateListScroll
spectateListLayout.Padding = UDim.new(0, 3)
spectateListLayout.SortOrder = Enum.SortOrder.LayoutOrder

local spectateInputBeganConnection = nil
local spectateInputEndedConnection = nil
local spectateMouseDeltaConnection = nil
local spectateKeys = {}
local spectateMouseLook = false
local spectateYaw = 0
local spectatePitch = 0
local spectateOrbitDistance = 12
local spectateOrbitHeight = 4
local spectateMouseSensitivity = 0.0035

local function stopSpectating()
    if spectateRenderConnection then
        spectateRenderConnection:Disconnect()
        spectateRenderConnection = nil
    end
    if spectateInputBeganConnection then
        spectateInputBeganConnection:Disconnect()
        spectateInputBeganConnection = nil
    end
    if spectateInputEndedConnection then
        spectateInputEndedConnection:Disconnect()
        spectateInputEndedConnection = nil
    end
    if spectateMouseDeltaConnection then
        spectateMouseDeltaConnection:Disconnect()
        spectateMouseDeltaConnection = nil
    end
    spectateKeys = {}
    spectateMouseLook = false
    pcall(function() uis.MouseBehavior = Enum.MouseBehavior.Default end)
    spectateTargetPlayer = nil

    local camera = ws.CurrentCamera
    if camera then
        camera.CameraType = Enum.CameraType.Custom
        local character = lplr.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if humanoid then camera.CameraSubject = humanoid end
    end
end

local function startSpectating(player)
    if not player or player == lplr or player.Parent ~= plrs then
        error("Select an available player from the list first")
    end
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not root or not humanoid or humanoid.Health <= 0 then
        error("Target character is unavailable")
    end

    stopSpectating()
    spectateTargetPlayer = player
    local camera = ws.CurrentCamera
    if not camera then error("Camera is unavailable") end

    -- Start behind the target. Hold RMB and move the mouse to orbit around them.
    -- Scriptable camera bypasses Roblox's default camera collision pushback (wall noclip).
    local initialPosition = (root.CFrame * CFrame.new(0, spectateOrbitHeight, spectateOrbitDistance)).Position
    local focusPosition = root.Position + Vector3.new(0, 2, 0)
    local initialCFrame = CFrame.lookAt(initialPosition, focusPosition)
    local lookVector = initialCFrame.LookVector
    spectateYaw = math.atan2(-lookVector.X, -lookVector.Z)
    spectatePitch = math.asin(math.clamp(lookVector.Y, -1, 1))
    camera.CameraType = Enum.CameraType.Scriptable
    camera.CFrame = initialCFrame

    spectateInputBeganConnection = uis.InputBegan:Connect(function(input, gameProcessed)
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            spectateMouseLook = true
            pcall(function() uis.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition end)
        end
    end)
    spectateInputEndedConnection = uis.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            spectateMouseLook = false
            pcall(function() uis.MouseBehavior = Enum.MouseBehavior.Default end)
        end
    end)
    spectateMouseDeltaConnection = uis.InputChanged:Connect(function(input, gameProcessed)
        -- MouseWheel input can be marked processed by Roblox UI, so handle it before
        -- the RMB-only rotation check. Zoom remains available while spectating.
        if input.UserInputType == Enum.UserInputType.MouseWheel then
            if spectateMouseLook then
                local wheelDelta = input.Position.Z
                spectateOrbitDistance = math.clamp(
                    spectateOrbitDistance - wheelDelta * 2.5,
                    2.5,
                    40
                )
            end
            return
        end

        if not spectateMouseLook then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            spectateYaw = spectateYaw - input.Delta.X * spectateMouseSensitivity
            spectatePitch = math.clamp(spectatePitch - input.Delta.Y * spectateMouseSensitivity, math.rad(-75), math.rad(75))
        end
    end)

    spectateRenderConnection = rs.RenderStepped:Connect(function()
        local currentCamera = ws.CurrentCamera
        local targetCharacter = spectateTargetPlayer and spectateTargetPlayer.Character
        local targetRoot = targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart")
        local targetHumanoid = targetCharacter and targetCharacter:FindFirstChildOfClass("Humanoid")
        if not currentCamera or not spectateTargetPlayer or spectateTargetPlayer.Parent ~= plrs
            or not targetRoot or not targetHumanoid or targetHumanoid.Health <= 0 then
            stopSpectating()
            return
        end

        currentCamera.CameraType = Enum.CameraType.Scriptable
        -- Orbit position stays a fixed distance from the target; mouse input only changes view angle.
        local rotation = CFrame.fromOrientation(spectatePitch, spectateYaw, 0)
        local focus = targetRoot.Position + Vector3.new(0, 2, 0)
        local orbitOffset = -rotation.LookVector * spectateOrbitDistance + Vector3.new(0, spectateOrbitHeight - 2, 0)
        currentCamera.CFrame = CFrame.lookAt(focus + orbitOffset, focus)
    end)
end

local updateSpectateInfo

local function refreshSpectatePlayers()
    for _, child in ipairs(spectateListScroll:GetChildren()) do
        if child:IsA("TextButton") or child:IsA("TextLabel") then
            child:Destroy()
        end
    end

    local targets = {}
    for _, player in ipairs(plrs:GetPlayers()) do
        if player ~= lplr then
            table.insert(targets, player)
        end
    end
    table.sort(targets, function(a, b)
        return a.Name:lower() < b.Name:lower()
    end)

    local selectionStillValid = false
    for _, player in ipairs(targets) do
        if player == selectedSpectatePlayer then selectionStillValid = true end
    end
    if not selectionStillValid then
        selectedSpectatePlayer = nil
        if updateSpectateInfo then updateSpectateInfo(nil) end
    end

    if #targets == 0 then
        local empty = Instance.new("TextLabel")
        empty.Name = "EmptyPlayerList"
        empty.Parent = spectateListScroll
        empty.Size = UDim2.new(1, -4, 0, 30)
        empty.BackgroundTransparency = 1
        empty.Font = Enum.Font.Code
        empty.Text = "NO OTHER PLAYERS FOUND"
        empty.TextColor3 = C.muted
        empty.TextSize = 12
        empty.ZIndex = 9
        return
    end

    for index, player in ipairs(targets) do
        local selected = player == selectedSpectatePlayer
        local item = Instance.new("TextButton")
        item.Name = "Player_" .. player.UserId
        item.Parent = spectateListScroll
        item.LayoutOrder = index
        item.Size = UDim2.new(1, -4, 0, 30)
        item.BackgroundColor3 = selected and C.panel2 or C.bg
        item.BorderSizePixel = 0
        item.AutoButtonColor = false
        item.Font = Enum.Font.Code
        item.Text = (selected and ">  " or "   ") .. player.Name .. "  (@" .. player.DisplayName .. ")"
        item.TextColor3 = selected and C.trueState or C.text
        item.TextSize = 11
        item.TextXAlignment = Enum.TextXAlignment.Left
        item.ZIndex = 9
        corner(item, 2)
        item.MouseButton1Click:Connect(function()
            if player.Parent ~= plrs then
                refreshSpectatePlayers()
                return
            end
            selectedSpectatePlayer = player
            refreshSpectatePlayers()
            updateSpectateInfo(player)
        end)
    end
end

createActionButton("Refresh Player List", refreshSpectatePlayers)
createActionButton("Teleport to Selected Player", function()
    local player = selectedSpectatePlayer
    if not player or player.Parent ~= plrs then
        error("Select a player from the list first")
    end
    local targetCharacter = player.Character
    local targetRoot = targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart")
    local character = lplr.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not targetRoot then error("Target character is unavailable") end
    if not root or not humanoid or humanoid.Health <= 0 then error("Your character is unavailable") end
    root.CFrame = targetRoot.CFrame * CFrame.new(3, 0, 0)
end)

createActionButton("Spectate Selected Player", function()
    startSpectating(selectedSpectatePlayer)
end)
createActionButton("Stop Spectating", function()
    stopSpectating()
end)

-- Selected-player information card, displayed directly below Stop Spectating.
local spectateInfoCard = Instance.new("Frame")
spectateInfoCard.Name = "SelectedPlayerInfo"
spectateInfoCard.Parent = scroll
spectateInfoCard.BackgroundColor3 = C.panel
spectateInfoCard.BorderSizePixel = 0
spectateInfoCard.Size = UDim2.new(1, -20, 0, 112)
spectateInfoCard.ZIndex = 7
corner(spectateInfoCard, 2)
stroke(spectateInfoCard, C.outline, 0.12, 1)

local spectateAvatar = Instance.new("ImageLabel")
spectateAvatar.Name = "Avatar"
spectateAvatar.Parent = spectateInfoCard
spectateAvatar.BackgroundColor3 = C.bg
spectateAvatar.BorderSizePixel = 0
spectateAvatar.Position = UDim2.new(0, 8, 0, 8)
spectateAvatar.Size = UDim2.new(0, 82, 0, 96)
spectateAvatar.ScaleType = Enum.ScaleType.Fit
spectateAvatar.Image = ""
spectateAvatar.ZIndex = 8
corner(spectateAvatar, 2)

local spectateInfoTitle = Instance.new("TextLabel")
spectateInfoTitle.Name = "InfoTitle"
spectateInfoTitle.Parent = spectateInfoCard
spectateInfoTitle.BackgroundTransparency = 1
spectateInfoTitle.Position = UDim2.new(0, 100, 0, 8)
spectateInfoTitle.Size = UDim2.new(1, -180, 0, 20)
spectateInfoTitle.Font = Enum.Font.Code
spectateInfoTitle.Text = "SELECTED PLAYER INFO"
spectateInfoTitle.TextColor3 = C.accent
spectateInfoTitle.TextSize = 12
spectateInfoTitle.TextXAlignment = Enum.TextXAlignment.Left
spectateInfoTitle.ZIndex = 8

local spectateInfoText = Instance.new("TextLabel")
spectateInfoText.Name = "PlayerDetails"
spectateInfoText.Parent = spectateInfoCard
spectateInfoText.BackgroundTransparency = 1
spectateInfoText.Position = UDim2.new(0, 100, 0, 32)
spectateInfoText.Size = UDim2.new(1, -190, 0, 72)
spectateInfoText.Font = Enum.Font.Code
spectateInfoText.Text = "Choose a player from the list above."
spectateInfoText.TextColor3 = C.muted
spectateInfoText.TextSize = 12
spectateInfoText.TextWrapped = true
spectateInfoText.TextXAlignment = Enum.TextXAlignment.Left
spectateInfoText.TextYAlignment = Enum.TextYAlignment.Top
spectateInfoText.ZIndex = 8

-- Interactive 3D preview of the currently selected player's avatar.
createSection("[ 3D AVATAR PREVIEW ]")
-- Wrapper lets the zoom controls render as normal 2D UI above the 3D viewport.
local avatarPreviewContainer = Instance.new("Frame")
avatarPreviewContainer.Name = "AvatarPreviewContainer"
avatarPreviewContainer.Parent = scroll
avatarPreviewContainer.BackgroundTransparency = 1
avatarPreviewContainer.BorderSizePixel = 0
avatarPreviewContainer.Size = UDim2.new(1, -20, 0, 220)
avatarPreviewContainer.ZIndex = 7

local spectateViewport = Instance.new("ViewportFrame")
spectateViewport.Name = "SelectedPlayer3DAvatar"
spectateViewport.Parent = avatarPreviewContainer
spectateViewport.Position = UDim2.new(0, 0, 0, 0)
spectateViewport.BackgroundColor3 = C.bg
spectateViewport.BorderSizePixel = 0
spectateViewport.Size = UDim2.new(1, 0, 1, 0)
spectateViewport.ZIndex = 7
spectateViewport.Active = true
spectateViewport.Ambient = Color3.fromRGB(170, 170, 170)
spectateViewport.LightColor = Color3.fromRGB(255, 255, 255)
spectateViewport.LightDirection = Vector3.new(-1, -1, -1)
corner(spectateViewport, 2)
stroke(spectateViewport, C.outline, 0.12, 1)

local avatarWorld = Instance.new("WorldModel")
avatarWorld.Parent = spectateViewport
local avatarViewportCamera = Instance.new("Camera")
avatarViewportCamera.Name = "AvatarCamera"
avatarViewportCamera.Parent = spectateViewport
spectateViewport.CurrentCamera = avatarViewportCamera

local avatarPreviewModel = nil
local avatarPreviewYaw = math.rad(180)
local avatarPreviewPitch = math.rad(-5)
local avatarPreviewDistance = 7
local avatarPreviewDragging = false
local avatarPreviewLastX = 0
local avatarPreviewLastY = 0
local avatarPreviewConnections = {}

-- Embedded zoom slider: mouse-wheel input is left alone for menu scrolling.
local avatarZoomMin, avatarZoomMax = 2.5, 20
local avatarZoomDragging = false

local avatarZoomPanel = Instance.new("Frame")
avatarZoomPanel.Name = "AvatarZoomControl"
avatarZoomPanel.Parent = avatarPreviewContainer
avatarZoomPanel.AnchorPoint = Vector2.new(0.5, 1)
avatarZoomPanel.Position = UDim2.new(0.5, 0, 1, -7)
avatarZoomPanel.Size = UDim2.new(1, -18, 0, 32)
avatarZoomPanel.BackgroundColor3 = C.panel
avatarZoomPanel.BackgroundTransparency = 0.12
avatarZoomPanel.BorderSizePixel = 0
avatarZoomPanel.ZIndex = 20
corner(avatarZoomPanel, 3)
stroke(avatarZoomPanel, C.outline, 0.15, 1)

local avatarZoomLabel = Instance.new("TextLabel")
avatarZoomLabel.Parent = avatarZoomPanel
avatarZoomLabel.BackgroundTransparency = 1
avatarZoomLabel.Position = UDim2.new(0, 8, 0, 0)
avatarZoomLabel.Size = UDim2.new(0, 42, 1, 0)
avatarZoomLabel.Font = Enum.Font.Code
avatarZoomLabel.Text = "ZOOM"
avatarZoomLabel.TextColor3 = C.text
avatarZoomLabel.TextSize = 10
avatarZoomLabel.TextXAlignment = Enum.TextXAlignment.Left
avatarZoomLabel.ZIndex = 21

local avatarZoomValue = Instance.new("TextLabel")
avatarZoomValue.Parent = avatarZoomPanel
avatarZoomValue.BackgroundTransparency = 1
avatarZoomValue.AnchorPoint = Vector2.new(1, 0)
avatarZoomValue.Position = UDim2.new(1, -7, 0, 0)
avatarZoomValue.Size = UDim2.new(0, 34, 1, 0)
avatarZoomValue.Font = Enum.Font.Code
avatarZoomValue.Text = "7.0"
avatarZoomValue.TextColor3 = C.accent
avatarZoomValue.TextSize = 10
avatarZoomValue.TextXAlignment = Enum.TextXAlignment.Right
avatarZoomValue.ZIndex = 21

local avatarZoomTrack = Instance.new("TextButton")
avatarZoomTrack.Parent = avatarZoomPanel
avatarZoomTrack.AutoButtonColor = false
avatarZoomTrack.Text = ""
avatarZoomTrack.BackgroundColor3 = C.off
avatarZoomTrack.BorderSizePixel = 0
avatarZoomTrack.Position = UDim2.new(0, 54, 0.5, -3)
avatarZoomTrack.Size = UDim2.new(1, -100, 0, 6)
avatarZoomTrack.ZIndex = 21
corner(avatarZoomTrack, 4)

local avatarZoomFill = Instance.new("Frame")
avatarZoomFill.Parent = avatarZoomTrack
avatarZoomFill.BackgroundColor3 = C.accent
avatarZoomFill.BorderSizePixel = 0
avatarZoomFill.Size = UDim2.new(0.65, 0, 1, 0)
avatarZoomFill.ZIndex = 22
corner(avatarZoomFill, 4)

local avatarZoomThumb = Instance.new("Frame")
avatarZoomThumb.Parent = avatarZoomTrack
avatarZoomThumb.AnchorPoint = Vector2.new(0.5, 0.5)
avatarZoomThumb.Position = UDim2.new(0.65, 0, 0.5, 0)
avatarZoomThumb.Size = UDim2.new(0, 11, 0, 11)
avatarZoomThumb.BackgroundColor3 = C.text
avatarZoomThumb.BorderSizePixel = 0
avatarZoomThumb.ZIndex = 23
corner(avatarZoomThumb, 8)
stroke(avatarZoomThumb, C.accent, 0, 2)

local function updateAvatarZoomSlider()
    local ratio = math.clamp((avatarZoomMax - avatarPreviewDistance) / (avatarZoomMax - avatarZoomMin), 0, 1)
    avatarZoomFill.Size = UDim2.new(ratio, 0, 1, 0)
    avatarZoomThumb.Position = UDim2.new(ratio, 0, 0.5, 0)
    avatarZoomValue.Text = string.format("%.1f", avatarPreviewDistance)
end

local function clearAvatarPreview()
    for _, child in ipairs(avatarWorld:GetChildren()) do
        child:Destroy()
    end
    avatarPreviewModel = nil
end

local function updateAvatarPreviewCamera()
    if not avatarPreviewModel then return end
    local boxCFrame, boxSize = avatarPreviewModel:GetBoundingBox()
    local focus = boxCFrame.Position + Vector3.new(0, boxSize.Y * 0.05, 0)
    -- Full orbit: yaw travels continuously through 360 degrees; pitch allows
    -- looking above and below the avatar without flipping the camera upside down.
    local rotation = CFrame.fromOrientation(avatarPreviewPitch, avatarPreviewYaw, 0)
    local offset = rotation:VectorToWorldSpace(Vector3.new(0, 0, avatarPreviewDistance))
    avatarViewportCamera.CFrame = CFrame.lookAt(focus + offset, focus)
end

local function setAvatarZoomFromX(x)
    local width = math.max(1, avatarZoomTrack.AbsoluteSize.X)
    local ratio = math.clamp((x - avatarZoomTrack.AbsolutePosition.X) / width, 0, 1)
    avatarPreviewDistance = avatarZoomMax - ratio * (avatarZoomMax - avatarZoomMin)
    updateAvatarZoomSlider()
    updateAvatarPreviewCamera()
end

local function showAvatarPreview(player)
    clearAvatarPreview()
    avatarPreviewYaw = math.rad(180)
    avatarPreviewPitch = math.rad(-5)
    avatarPreviewDistance = 7
    updateAvatarZoomSlider()
    if not player or player.Parent ~= plrs then return end

    local character = player.Character
    if not character then return end

    local oldArchivable = character.Archivable
    local clone
    local ok = pcall(function()
        character.Archivable = true
        clone = character:Clone()
        character.Archivable = oldArchivable
    end)
    character.Archivable = oldArchivable
    if not ok or not clone then return end

    clone.Name = "AvatarPreview"
    for _, descendant in ipairs(clone:GetDescendants()) do
        if descendant:IsA("Script") or descendant:IsA("LocalScript") then
            descendant:Destroy()
        elseif descendant:IsA("BasePart") then
            descendant.Anchored = true
            descendant.CanCollide = false
            descendant.CanTouch = false
            descendant.CanQuery = false
        elseif descendant:IsA("Humanoid") then
            descendant.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        end
    end
    clone.Parent = avatarWorld
    avatarPreviewModel = clone

    pcall(function()
        clone:PivotTo(CFrame.new(0, 0, 0))
        local _, size = clone:GetBoundingBox()
        avatarPreviewDistance = math.clamp(math.max(5, size.Magnitude * 0.85), avatarZoomMin, avatarZoomMax)
        updateAvatarZoomSlider()
        updateAvatarPreviewCamera()
    end)
end

-- Drag inside the avatar area to orbit. The embedded slider is the only
-- zoom control; mouse-wheel events are deliberately ignored here.
avatarZoomTrack.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        avatarZoomDragging = true
        setAvatarZoomFromX(input.Position.X)
    end
end)

spectateViewport.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        local p = input.Position
        local panelPos, panelSize = avatarZoomPanel.AbsolutePosition, avatarZoomPanel.AbsoluteSize
        local onZoomControl = p.X >= panelPos.X and p.X <= panelPos.X + panelSize.X
            and p.Y >= panelPos.Y and p.Y <= panelPos.Y + panelSize.Y
        if not onZoomControl then
            avatarPreviewDragging = true
            avatarPreviewLastX = p.X
            avatarPreviewLastY = p.Y
        end
    end
end)

ESPX.track(uis.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        avatarPreviewDragging = false
        avatarZoomDragging = false
    end
end))

table.insert(avatarPreviewConnections, uis.InputChanged:Connect(function(input)
    if avatarZoomDragging and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
        setAvatarZoomFromX(input.Position.X)
    elseif (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) and avatarPreviewDragging then
        local p = input.Position
        local deltaX = p.X - avatarPreviewLastX
        local deltaY = p.Y - avatarPreviewLastY
        avatarPreviewYaw = avatarPreviewYaw - deltaX * 0.012
        avatarPreviewPitch = math.clamp(avatarPreviewPitch - deltaY * 0.01, math.rad(-80), math.rad(80))
        avatarPreviewLastX = p.X
        avatarPreviewLastY = p.Y
        updateAvatarPreviewCamera()
    end
end))

local spectateCopyButton = Instance.new("TextButton")
spectateCopyButton.Name = "CopyPlayerInfo"
spectateCopyButton.Parent = spectateInfoCard
spectateCopyButton.Position = UDim2.new(1, -76, 0, 7)
spectateCopyButton.Size = UDim2.new(0, 66, 0, 24)
spectateCopyButton.BackgroundColor3 = C.accent
spectateCopyButton.BorderSizePixel = 0
spectateCopyButton.AutoButtonColor = true
spectateCopyButton.Font = Enum.Font.Code
spectateCopyButton.Text = "COPY"
spectateCopyButton.TextColor3 = C.bg
spectateCopyButton.TextSize = 13
spectateCopyButton.ZIndex = 20
corner(spectateCopyButton, 2)
stroke(spectateCopyButton, C.outline, 0.12, 1)

spectateCopyButton.MouseButton1Click:Connect(function()
    local player = selectedSpectatePlayer
    if not player or player.Parent ~= plrs then
        spectateCopyButton.Text = "NO PLAYER"
        task.delay(1.2, function()
            if spectateCopyButton.Parent then spectateCopyButton.Text = "COPY" end
        end)
        return
    end

    local info = "Username: @" .. player.Name
        .. "\nDisplay Name: " .. player.DisplayName
        .. "\nUser ID: " .. tostring(player.UserId)

    -- Clipboard functions are provided by some script executors, not standard Roblox Lua.
    local copyFn = setclipboard or toclipboard
    if type(copyFn) == "function" then
        local ok = pcall(copyFn, info)
        spectateCopyButton.Text = ok and "COPIED!" or "FAILED"
    else
        spectateCopyButton.Text = "UNAVAILABLE"
    end
    task.delay(1.5, function()
        if spectateCopyButton.Parent then spectateCopyButton.Text = "COPY" end
    end)
end)

updateSpectateInfo = function(player)
    showAvatarPreview(player)
    if not player or player.Parent ~= plrs then
        spectateAvatar.Image = ""
        spectateInfoText.Text = "Choose a player from the list above."
        return
    end

    spectateInfoText.Text = "Username: @" .. player.Name
        .. "\nDisplay Name: " .. player.DisplayName
        .. "\nUser ID: " .. tostring(player.UserId)

    task.spawn(function()
        local ok, imageUrl = pcall(function()
            local content, _isReady = plrs:GetUserThumbnailAsync(
                player.UserId,
                Enum.ThumbnailType.AvatarThumbnail,
                Enum.ThumbnailSize.Size150x150
            )
            return content
        end)
        -- Do not let a delayed thumbnail overwrite the newly selected player's avatar.
        if ok and selectedSpectatePlayer == player and player.Parent == plrs then
            spectateAvatar.Image = imageUrl
        end
    end)
end

refreshSpectatePlayers()
updateSpectateInfo(selectedSpectatePlayer)
ESPX.track(plrs.PlayerAdded:Connect(refreshSpectatePlayers))
ESPX.track(plrs.PlayerRemoving:Connect(function(player)
    if player == selectedSpectatePlayer then
        selectedSpectatePlayer = nil
        updateSpectateInfo(nil)
    end
    if player == spectateTargetPlayer then stopSpectating() end
    refreshSpectatePlayers()
end))
ESPX.track(lplr.CharacterAdded:Connect(function()
    -- Keep the camera local after respawning if the spectate target vanished.
    if not spectateTargetPlayer then
        task.defer(stopSpectating)
    end
end))

-- Gun tab and its obsolete weapon features have been removed.

-- Settings: menu keybind and performance controls.
setTab("Settings")
-- UI-only keybind selector for showing/hiding this menu.
-- Persist the selected key using executor file APIs when available.
local menuKeyFile = "HRSH_MenuToggleKey.txt"
local function loadMenuToggleKey()
    if type(isfile) == "function" and type(readfile) == "function" then
        local ok, exists = pcall(isfile, menuKeyFile)
        if ok and exists then
            local readOk, savedName = pcall(readfile, menuKeyFile)
            if readOk and type(savedName) == "string" then
                savedName = savedName:gsub("%s+", "")
                local success, keyCode = pcall(function() return Enum.KeyCode[savedName] end)
                if success and keyCode and keyCode ~= Enum.KeyCode.Unknown then
                    return keyCode
                end
            end
        end
    end
    return Enum.KeyCode.RightControl
end

local function saveMenuToggleKey(keyCode)
    if terminated then return end
    if type(writefile) == "function" then
        pcall(writefile, menuKeyFile, keyCode.Name)
    end
end

local menuToggleKey = loadMenuToggleKey()
local waitingForMenuKey = false
local keybindButton = Instance.new("TextButton")
keybindButton.Name = "MenuToggleKeybind"
keybindButton.Parent = scroll
keybindButton.Size = UDim2.new(1, -20, 0, 34)
keybindButton.BackgroundColor3 = C.panel
keybindButton.BorderSizePixel = 0
keybindButton.AutoButtonColor = false
keybindButton.Font = Enum.Font.GothamMedium
keybindButton.Text = ""
keybindButton.ZIndex = 7
corner(keybindButton, 2)
local keybindEdge = stroke(keybindButton, C.outline, 0.25, 1)
local keybindLabel = Instance.new("TextLabel")
keybindLabel.Parent = keybindButton
keybindLabel.BackgroundTransparency = 1
keybindLabel.Position = UDim2.new(0, 12, 0, 0)
keybindLabel.Size = UDim2.new(1, -105, 1, 0)
keybindLabel.Font = Enum.Font.Code
keybindLabel.Text = "Quickhacks"
keybindLabel.TextColor3 = C.text
keybindLabel.TextSize = 13
keybindLabel.TextXAlignment = Enum.TextXAlignment.Left
local keybindValue = Instance.new("TextLabel")
keybindValue.Parent = keybindButton
keybindValue.BackgroundColor3 = C.panel2
keybindValue.Position = UDim2.new(1, -91, 0.5, -12)
keybindValue.Size = UDim2.new(0, 79, 0, 22)
keybindValue.Font = Enum.Font.Code
keybindValue.Text = menuToggleKey.Name
keybindValue.TextColor3 = C.text
keybindValue.TextSize = 10
keybindValue.TextTruncate = Enum.TextTruncate.AtEnd
corner(keybindValue, 2)
keybindButton.MouseButton1Click:Connect(function()
    waitingForMenuKey = true
    keybindValue.Text = "Press key..."
    keybindEdge.Color = C.accent
    keybindEdge.Transparency = 0
end)
keybindButton.MouseEnter:Connect(function() keybindButton.BackgroundColor3 = C.panel2 end)
keybindButton.MouseLeave:Connect(function() keybindButton.BackgroundColor3 = C.panel end)

createSection("[ PERFORMANCE ]")
createToggle("Low Visuals", "LowVisuals")
createToggle("Instance Optimizer", "InstanceOptimizer")
createToggle("Particle Cap", "ParticleCap")
createToggle("Ultra Potato", "UltraPotato")

-- Config: put every toggle and slider back to its built-in default (keybinds are left alone).
function ESPX.resetToDefaults()
    for key, value in pairs(ESPX.defaultCfg) do cfg[key] = value end
    for _, entry in ipairs(ESPX.toggleList) do
        local key = entry.key
        local default = ESPX.defaultToggles[key] == true
        if toggles[key] ~= default then
            toggles[key] = default
            ESPX.togglePaints[key]()
            if key == "ESP" and not default then
                for _, v in ipairs(ws:GetDescendants()) do
                    if v.Name == "NPCHighlight" then v:Destroy() end
                end
            end
        end
    end
    for _, slider in ipairs(ESPX.sliders) do
        local default = (slider.key == "flySpeed") and 55 or ESPX.defaultCfg[slider.key]
        if default ~= nil then slider.set(default) end
    end
    saveSettings()
end

createSection("[ CONFIG ]")
createActionButton("Reset to Defaults", function()
    -- Two clicks within 3 seconds, so a stray click cannot wipe your settings.
    if os.clock() - (ESPX.resetArmedAt or -10) > 3 then
        ESPX.resetArmedAt = os.clock()
        return "[CLICK AGAIN]"
    end
    ESPX.resetArmedAt = nil
    ESPX.resetToDefaults()
    return "[RESET]"
end)

-- Server tools. The server list needs an executor HTTP function (request / http_request / HttpGet).
function ESPX.httpGet(url)
    local requestFn = (type(request) == "function" and request)
        or (type(http_request) == "function" and http_request)
        or (type(syn) == "table" and type(syn.request) == "function" and syn.request)
    if requestFn then
        local response = requestFn({Url = url, Method = "GET"})
        if response and response.Body then return response.Body end
    end
    local ok, body = pcall(function() return game:HttpGet(url) end)
    if ok and type(body) == "string" then return body end
    error("No HTTP request function available in this executor")
end

function ESPX.rejoin()
    local teleportService = game:GetService("TeleportService")
    if #plrs:GetPlayers() <= 1 then
        teleportService:Teleport(game.PlaceId, lplr) -- alone in the server: a new one is created
    else
        teleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, lplr)
    end
end

function ESPX.serverHop()
    local teleportService = game:GetService("TeleportService")
    local url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100", game.PlaceId)
    local data = HttpService:JSONDecode(ESPX.httpGet(url))
    local choices = {}
    for _, server in ipairs(data.data or {}) do
        if server.id ~= game.JobId and server.playing and server.maxPlayers and server.playing < server.maxPlayers then
            choices[#choices + 1] = server.id
        end
    end
    if #choices == 0 then error("No other open servers found") end
    teleportService:TeleportToPlaceInstance(game.PlaceId, choices[math.random(#choices)], lplr)
end

createSection("[ SERVER ]")
createActionButton("Rejoin Server", function() ESPX.rejoin() end)
createActionButton("Server Hop", function() ESPX.serverHop() end)

-- Per-feature keybinds: any toggle in the menu can be bound to a key (saved in HRSH_MenuBinds.json).
do
    local bindsFile = "HRSH_MenuBinds.json"
    local keyButtons = {} -- [toggleKey] = TextButton showing the bound key
    ESPX.binds = {}       -- [toggleKey] = KeyCode name
    ESPX.bindWaiting = nil

    local function showBind(key)
        local button = keyButtons[key]
        if not button then return end
        if ESPX.bindWaiting == key then
            button.Text = "PRESS KEY"
            button.TextColor3 = C.trueState
        else
            local keyName = ESPX.binds[key]
            button.Text = keyName and string.upper(keyName) or "NONE"
            button.TextColor3 = keyName and C.accent or C.muted
        end
    end

    local function saveBinds()
        if terminated or type(writefile) ~= "function" then return end
        pcall(function() writefile(bindsFile, HttpService:JSONEncode(ESPX.binds)) end)
    end

    local function loadBinds()
        if type(isfile) ~= "function" or type(readfile) ~= "function" then return end
        local ok, exists = pcall(isfile, bindsFile)
        if not (ok and exists) then return end
        local readOk, raw = pcall(readfile, bindsFile)
        if not (readOk and type(raw) == "string") then return end
        local decodeOk, data = pcall(function() return HttpService:JSONDecode(raw) end)
        if not (decodeOk and type(data) == "table") then return end
        for key, keyName in pairs(data) do
            if type(key) == "string" and type(keyName) == "string" and ESPX.toggleFlips[key] then
                local valid, keyCode = pcall(function() return Enum.KeyCode[keyName] end)
                if valid and keyCode then ESPX.binds[key] = keyName end
            end
        end
    end

    setTab("Binds")
    createSection("[ FEATURE KEYBINDS ]")
    local hint = Instance.new("TextLabel")
    hint.Parent = scroll
    hint.BackgroundTransparency = 1
    hint.Size = UDim2.new(1, -20, 0, 30)
    hint.Font = Enum.Font.Code
    hint.Text = "Click a key box, then press a key. Esc clears it."
    hint.TextColor3 = C.muted
    hint.TextSize = 10
    hint.TextWrapped = true
    hint.TextXAlignment = Enum.TextXAlignment.Left
    hint.ZIndex = 7

    for _, entry in ipairs(ESPX.toggleList) do
        local row = Instance.new("Frame")
        row.Parent = scroll
        row.BackgroundColor3 = C.panel
        row.BorderSizePixel = 0
        row.Size = UDim2.new(1, -20, 0, 30)
        row.ZIndex = 7
        stroke(row, C.outline, 0.2, 1)
        local rowBar = Instance.new("Frame")
        rowBar.Parent = row
        rowBar.BackgroundColor3 = C.accentDark
        rowBar.BorderSizePixel = 0
        rowBar.Size = UDim2.new(0, 3, 1, 0)
        rowBar.ZIndex = 8
        local rowLabel = Instance.new("TextLabel")
        rowLabel.Parent = row
        rowLabel.BackgroundTransparency = 1
        rowLabel.Position = UDim2.new(0, 14, 0, 0)
        rowLabel.Size = UDim2.new(1, -120, 1, 0)
        rowLabel.Font = Enum.Font.Code
        rowLabel.Text = entry.name
        rowLabel.TextColor3 = C.text
        rowLabel.TextSize = 12
        rowLabel.TextXAlignment = Enum.TextXAlignment.Left
        rowLabel.ZIndex = 8
        local keyButton = Instance.new("TextButton")
        keyButton.Parent = row
        keyButton.AnchorPoint = Vector2.new(1, 0.5)
        keyButton.Position = UDim2.new(1, -8, 0.5, 0)
        keyButton.Size = UDim2.new(0, 92, 0, 20)
        keyButton.BackgroundColor3 = C.bg
        keyButton.BorderSizePixel = 0
        keyButton.AutoButtonColor = false
        keyButton.Font = Enum.Font.Code
        keyButton.TextSize = 11
        keyButton.ZIndex = 8
        stroke(keyButton, C.outline, 0.2, 1)
        keyButtons[entry.key] = keyButton
        keyButton.MouseButton1Click:Connect(function()
            local previous = ESPX.bindWaiting
            ESPX.bindWaiting = entry.key
            if previous then showBind(previous) end
            showBind(entry.key)
        end)
    end

    createActionButton("Clear All Keybinds", function()
        ESPX.binds = {}
        ESPX.bindWaiting = nil
        for key in pairs(keyButtons) do showBind(key) end
        saveBinds()
    end)

    loadBinds()
    for key in pairs(keyButtons) do showBind(key) end

    ESPX.track(uis.InputBegan:Connect(function(input, gpe)
        if terminated or input.UserInputType ~= Enum.UserInputType.Keyboard then return end

        -- Capturing a new bind.
        local waiting = ESPX.bindWaiting
        if waiting then
            ESPX.bindWaiting = nil
            if input.KeyCode == Enum.KeyCode.Escape then
                ESPX.binds[waiting] = nil
            elseif input.KeyCode ~= Enum.KeyCode.Unknown then
                for otherKey, otherName in pairs(ESPX.binds) do
                    if otherName == input.KeyCode.Name and otherKey ~= waiting then
                        ESPX.binds[otherKey] = nil
                        showBind(otherKey)
                    end
                end
                ESPX.binds[waiting] = input.KeyCode.Name
            end
            showBind(waiting)
            saveBinds()
            return
        end

        -- Using a bind (ignored while typing in chat or choosing the menu key).
        if gpe or waitingForMenuKey then return end
        for key, keyName in pairs(ESPX.binds) do
            if input.KeyCode.Name == keyName then
                local flip = ESPX.toggleFlips[key]
                if flip then flip() end
            end
        end
    end))
end
setTab("Main")

ESPX.track(uis.InputBegan:Connect(function(input, gpe)
    if terminated then return end
    if waitingForMenuKey then
        if input.UserInputType == Enum.UserInputType.Keyboard then
            if input.KeyCode == Enum.KeyCode.Escape then
                waitingForMenuKey = false
                keybindValue.Text = menuToggleKey.Name
                keybindEdge.Color = C.hover
                keybindEdge.Transparency = 0.45
                return
            end
            if input.KeyCode ~= Enum.KeyCode.Unknown then
                menuToggleKey = input.KeyCode
                saveMenuToggleKey(menuToggleKey)
                waitingForMenuKey = false
                keybindValue.Text = menuToggleKey.Name
                keybindEdge.Color = C.hover
                keybindEdge.Transparency = 0.45
            end
        end
        return
    end
    if not gpe and input.KeyCode == menuToggleKey then
        main.Visible = not main.Visible
    end
end))

-- Speed modifier
local lastSpeed = false

ESPX.track(uis.InputBegan:Connect(function(input, gpe)
    if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
        if toggles.Speed then
            local hum = lplr.Character and lplr.Character:FindFirstChildOfClass("Humanoid")
            if hum then hum.WalkSpeed = 16 end
        end
    end
end))

ESPX.track(uis.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
        if toggles.Speed then
            local hum = lplr.Character and lplr.Character:FindFirstChildOfClass("Humanoid")
            if hum then hum.WalkSpeed = cfg.speed end
        end
    end
end))

ESPX.track(rs.Heartbeat:Connect(function()
    local char = lplr.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    if toggles.Speed ~= lastSpeed then
        lastSpeed = toggles.Speed
        if not toggles.Speed then
            hum.WalkSpeed = 16
        end
    end

    local shiftHeld = uis:IsKeyDown(Enum.KeyCode.LeftShift) or uis:IsKeyDown(Enum.KeyCode.RightShift)
    if toggles.Speed and not shiftHeld then
        hum.WalkSpeed = cfg.speed
    end
end))

-- Instant Interact
local validTargets = {}

ESPX.track(pps.PromptShown:Connect(function(prompt)
    if toggles.InstantInteract then
        prompt.HoldDuration = 0
    end
end))

-- NPC ESP
local function applyEsp(model)
    if not toggles.ESP then return end
    local hl = model:FindFirstChild("NPCHighlight")
    if not hl then
        hl = Instance.new("Highlight")
        hl.Name = "NPCHighlight"
        hl.Parent = model
    end
    hl.FillColor = cfg.espFill
    hl.OutlineColor = cfg.espOutline
    hl.FillTransparency = 1 - math.clamp(cfg.npcFillOpacity, 0, 1)
    hl.OutlineTransparency = 1 - math.clamp(cfg.npcOutlineOpacity, 0, 1)
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
end

-- Enemy HP ESP
local function addEnemyHPESP(model)
    if not toggles.EnemyHP then return end
    local hum = model:FindFirstChildOfClass("Humanoid")
    local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
    if not hum or not root or hum.Health <= 0 then return end

    local hpGui = root:FindFirstChild("EnemyHPESP")
    if not hpGui then
        hpGui = Instance.new("BillboardGui")
        hpGui.Name = "EnemyHPESP"
        hpGui.Size = UDim2.new(0, 140, 0, 24)
        hpGui.StudsOffset = Vector3.new(0, -3, 0)
        hpGui.AlwaysOnTop = true
        hpGui.MaxDistance = cfg.maxDist + 100
        hpGui.Parent = root

        local label = Instance.new("TextLabel")
        label.Name = "HP"
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamBold
        label.TextSize = 13
        label.TextStrokeTransparency = 0
        label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
        label.Parent = hpGui
    end

    local label = hpGui:FindFirstChild("HP")
    if label then
        ESPX.styleText(label, hpGui)
        local hp = math.max(0, hum.Health)
        local maxHp = math.max(1, hum.MaxHealth)
        local pct = math.clamp(hp / maxHp, 0, 1)
        label.Text = "HP: " .. math.floor(hp + 0.5) .. "/" .. math.floor(maxHp + 0.5)
        if pct > 0.6 then
            label.TextColor3 = Color3.fromRGB(100, 255, 100)
        elseif pct > 0.3 then
            label.TextColor3 = Color3.fromRGB(255, 220, 80)
        else
            label.TextColor3 = Color3.fromRGB(255, 80, 80)
        end
    end
end

local function removeEnemyHPESP(model)
    if not model then return end
    local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
    if root then
        local gui = root:FindFirstChild("EnemyHPESP")
        if gui then gui:Destroy() end
    end
end

local function updateEnemyHPESP()
    if not toggles.EnemyHP then return end
    for _, npc in ipairs(validTargets) do
        addEnemyHPESP(npc)
    end
end


-- Player ESP
local function getPlayerESPAnchor(char)
    -- R6/R15 and streamed/custom rigs may not have every standard part yet.
    for _, name in ipairs({"Head", "HumanoidRootPart", "UpperTorso", "Torso", "PrimaryPart"}) do
        local part = name == "PrimaryPart" and char.PrimaryPart or char:FindFirstChild(name)
        if part and part:IsA("BasePart") then
            return part
        end
    end
    return char:FindFirstChildWhichIsA("BasePart", true)
end

local function addPlayerInfoESP(plr, char)
    if not char or not char.Parent then return end

    local hl = char:FindFirstChild("PlayerHighlight")
    if not hl then
        hl = Instance.new("Highlight")
        hl.Name = "PlayerHighlight"
        hl.OutlineColor = Color3.fromRGB(255, 255, 255)
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Parent = char
    end
    hl.Adornee = char
    hl.Enabled = true
    hl.FillTransparency = 1 - math.clamp(cfg.playerFillOpacity, 0, 1)
    hl.OutlineTransparency = 1 - math.clamp(cfg.playerOutlineOpacity, 0, 1)

    hl.FillColor = ESPX.playerColor(plr)

    local hum = char:FindFirstChildOfClass("Humanoid")
    local anchor = getPlayerESPAnchor(char)
    -- Keep the highlight even while character parts are streaming in; retry next refresh.
    if not anchor or not hum then return end

    local infoGui = char:FindFirstChild("PlayerInfoESP", true)
    if infoGui and not infoGui:IsA("BillboardGui") then
        infoGui:Destroy()
        infoGui = nil
    end
    if not infoGui then
        infoGui = Instance.new("BillboardGui")
        infoGui.Name = "PlayerInfoESP"
        infoGui.Size = UDim2.new(0, 220, 0, 42)
        infoGui.StudsOffset = Vector3.new(0, 3, 0)
        infoGui.AlwaysOnTop = true
        infoGui.MaxDistance = 2000
        local label = Instance.new("TextLabel")
        label.Name = "Info"
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamBold
        label.TextSize = 13
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
        label.TextStrokeTransparency = 0
        label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        label.Parent = infoGui
    end
    -- Reparent if Head was streamed out or the rig uses a different anchor.
    if infoGui.Parent ~= anchor then infoGui.Parent = anchor end

    local label = infoGui:FindFirstChild("Info")
    if not label then return end
    ESPX.styleText(label, infoGui)
    local myChar = lplr.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local distance = myRoot and math.floor((myRoot.Position - anchor.Position).Magnitude + 0.5) or 0
    label.Text = string.format("%s\nHP: %d/%d  |  %d studs", plr.Name,
        math.floor(math.max(0, hum.Health) + 0.5),
        math.floor(math.max(1, hum.MaxHealth) + 0.5), distance)
end

local function removePlayerESP(char)
    if not char then return end
    local hl = char:FindFirstChild("PlayerHighlight")
    if hl then hl:Destroy() end
    for _, obj in ipairs(char:GetDescendants()) do
        if obj:IsA("BillboardGui") and obj.Name == "PlayerInfoESP" then obj:Destroy() end
    end
end

local function applyPlayerESP(state)
    for _, plr in ipairs(plrs:GetPlayers()) do
        if plr ~= lplr then
            local char = plr.Character
            if char then
                if state then addPlayerInfoESP(plr, char) else removePlayerESP(char) end
            end
        end
    end
end

local function watchPlayer(plr)
    plr.CharacterAdded:Connect(function(char)
        if not toggles.PlayerESP then return end
        task.wait(0.25)
        if toggles.PlayerESP and plr.Character == char then addPlayerInfoESP(plr, char) end
    end)
end
for _, plr in ipairs(plrs:GetPlayers()) do
    if plr ~= lplr then watchPlayer(plr) end
end
ESPX.track(plrs.PlayerAdded:Connect(function(plr)
    watchPlayer(plr)
    if toggles.PlayerESP and plr.Character then addPlayerInfoESP(plr, plr.Character) end
end))

local lastPlayerESP = false
local lastEnemyHP = false
local enemyHPUpdateTimer = 0
local playerESPUpdateTimer = 0

ESPX.track(rs.Heartbeat:Connect(function(dt)
    if toggles.PlayerESP ~= lastPlayerESP then
        lastPlayerESP = toggles.PlayerESP
        applyPlayerESP(toggles.PlayerESP)
    end

    -- Refresh at 10 Hz rather than every frame. This also retries when parts stream in.
    if toggles.PlayerESP then
        playerESPUpdateTimer += dt
        if playerESPUpdateTimer >= 0.1 then
            playerESPUpdateTimer = 0
            for _, plr in ipairs(plrs:GetPlayers()) do
                if plr ~= lplr and plr.Character then addPlayerInfoESP(plr, plr.Character) end
            end
        end
    else
        playerESPUpdateTimer = 0
    end

    if toggles.EnemyHP ~= lastEnemyHP then
        lastEnemyHP = toggles.EnemyHP
        if not toggles.EnemyHP then
            for _, npc in ipairs(ws:GetDescendants()) do
                if npc:IsA("Model") then removeEnemyHPESP(npc) end
            end
        end
    end

    if toggles.EnemyHP then
        enemyHPUpdateTimer += dt
        if enemyHPUpdateTimer >= 0.1 then
            enemyHPUpdateTimer = 0
            updateEnemyHPESP()
        end
    end
end))

-- My HP display
local selfHPGui
local selfHPLabel
local selfHPConnection

local function removeSelfHP()
    if selfHPConnection then
        selfHPConnection:Disconnect()
        selfHPConnection = nil
    end

    if selfHPGui then
        selfHPGui:Destroy()
        selfHPGui = nil
        selfHPLabel = nil
    end
end

local function setupSelfHP()
    removeSelfHP()

    if not toggles.SelfHP then
        return
    end

    local char = lplr.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")

    if not hum then
        return
    end

    selfHPGui = Instance.new("ScreenGui")
    selfHPGui.Name = "HRSH_SelfHP"
    selfHPGui.ResetOnSpawn = false
    selfHPGui.IgnoreGuiInset = true
    selfHPGui.DisplayOrder = 999998
    selfHPGui.Parent = cg

    selfHPLabel = Instance.new("TextLabel")
    selfHPLabel.Name = "HP"
    selfHPLabel.AnchorPoint = Vector2.new(0.5, 0)
    selfHPLabel.Position = UDim2.new(0.5, 0, 0, 25)
    selfHPLabel.Size = UDim2.new(0, 180, 0, 30)
    selfHPLabel.BackgroundTransparency = 1
    selfHPLabel.Font = Enum.Font.GothamBold
    selfHPLabel.TextSize = 18
    selfHPLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    selfHPLabel.TextStrokeTransparency = 0
    selfHPLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    selfHPLabel.Text = "100/100"
    selfHPLabel.Parent = selfHPGui

    local function update()
        if not selfHPLabel or not selfHPLabel.Parent then
            return
        end

        local current = math.max(0, hum.Health)
        local maximum = math.max(1, hum.MaxHealth)

        selfHPLabel.Text =
            string.format("%d/%d",
                math.floor(current + 0.5),
                math.floor(maximum + 0.5)
            )

        local pct = math.clamp(current / maximum, 0, 1)

        if pct > 0.6 then
            selfHPLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        elseif pct > 0.3 then
            selfHPLabel.TextColor3 = Color3.fromRGB(255, 220, 80)
        else
            selfHPLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
        end
    end

    update()

    selfHPConnection = hum.HealthChanged:Connect(update)
end

-- Recreate the display after respawn if the toggle remains enabled.
ESPX.track(lplr.CharacterAdded:Connect(function()
    if toggles.SelfHP then
        task.wait(0.25)
        setupSelfHP()
    end
end))

-- Watch the toggle without touching the existing GUI/event structure.
task.spawn(function()
    local last = toggles.SelfHP

    while not terminated do
        if toggles.SelfHP ~= last then
            last = toggles.SelfHP
            setupSelfHP()
        end

        task.wait(0.1)
    end
end)

-- Item ESP
local itemESPObjects = {}

local function getItemAdornee(obj)
    if obj:IsA("BasePart") then
        return obj
    elseif obj:IsA("Tool") then
        return obj:FindFirstChild("Handle")
            or obj:FindFirstChildWhichIsA("BasePart", true)
    elseif obj:IsA("Model") then
        return obj.PrimaryPart
            or obj:FindFirstChildWhichIsA("BasePart", true)
    end

    return nil
end

local function isPickupCandidate(obj)
    if not obj or obj.Parent ~= ws then
        return false
    end

    -- Never treat player characters as pickups.
    if plrs:GetPlayerFromCharacter(obj) then
        return false
    end

    -- This is the marker visible in the game's pickup hierarchy.
    if obj:FindFirstChild("Put Item In ServerStore", true) then
        return true
    end

    -- Fallback: anything directly under Workspace containing a prompt.
    if obj:FindFirstChildWhichIsA("ProximityPrompt", true) then
        return true
    end

    return obj:IsA("Tool")
end

local function addItemESP(obj)
    if not toggles.ItemESP or not isPickupCandidate(obj) then
        return
    end

    local adornee = getItemAdornee(obj)
    if not adornee then
        return
    end

    local gui = itemESPObjects[obj]

    if gui and gui.Parent then
        gui.Adornee = adornee

        local label = gui:FindFirstChild("Label")
        if label then
            label.Text = obj.Name
            ESPX.styleText(label, gui)
        end

        return
    end

    gui = Instance.new("BillboardGui")
    gui.Name = "ItemESP"
    gui.Size = UDim2.new(0, 220, 0, 28)
    gui.StudsOffset = Vector3.new(0, 2.5, 0)

    -- Do not use ProximityPrompt.Enabled or PromptShown.
    -- The ESP exists independently of prompt activation range.
    gui.AlwaysOnTop = true
    gui.MaxDistance = 2000
    gui.Adornee = adornee
    gui.Parent = cg

    local label = Instance.new("TextLabel")
    label.Name = "Label"
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.TextSize = 13
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextStrokeTransparency = 0
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)

    -- Only the item name. No GUN/MISC/GRENADE category.
    label.Text = obj.Name
    label.Parent = gui
    ESPX.styleText(label, gui)

    itemESPObjects[obj] = gui
end

local function removeItemESP(obj)
    local gui = itemESPObjects[obj]

    if gui then
        gui:Destroy()
        itemESPObjects[obj] = nil
    end
end

local function clearItemESP()
    -- Clear the ESPs tracked by this script.
    for obj, gui in pairs(itemESPObjects) do
        if gui then
            gui:Destroy()
        end

        itemESPObjects[obj] = nil
    end

    -- Also remove stale ItemESP billboards left behind by an older
    -- execution of the script. This fixes ESP remaining after OFF.
    for _, gui in ipairs(cg:GetDescendants()) do
        if gui:IsA("BillboardGui") and gui.Name == "ItemESP" then
            gui:Destroy()
        end
    end
end

local function updateItemESP()
    if not toggles.ItemESP then
        clearItemESP()
        return
    end

    local seen = {}

    -- IMPORTANT:
    -- The pickup objects you showed are direct children of Workspace.
    -- We inspect those objects directly instead of waiting for
    -- ProximityPromptService.PromptShown.
    for _, obj in ipairs(ws:GetChildren()) do
        if isPickupCandidate(obj) then
            seen[obj] = true
            addItemESP(obj)
        end
    end

    -- Remove ESP for pickups that were moved/removed.
    for obj in pairs(itemESPObjects) do
        if not seen[obj] or not obj:IsDescendantOf(ws) then
            removeItemESP(obj)
        end
    end
end

-- Noclip
local noclipOriginal = {}
local lastNoclip = false

local function setNoclip(enabled)
    local char = lplr.Character

    if not char then
        return
    end

    if enabled then
        -- Rebuild the cached part list on respawn and once a second (picks up new accessories/tools).
        if ESPX.noclipChar ~= char or os.clock() - ESPX.noclipBuilt > 1 then
            ESPX.noclipChar = char
            ESPX.noclipBuilt = os.clock()
            ESPX.noclipParts = {}
            for _, obj in ipairs(char:GetDescendants()) do
                if obj:IsA("BasePart") then
                    if noclipOriginal[obj] == nil then
                        noclipOriginal[obj] = obj.CanCollide
                    end
                    ESPX.noclipParts[#ESPX.noclipParts + 1] = obj
                end
            end
        end

        for _, part in ipairs(ESPX.noclipParts) do
            if part.CanCollide then part.CanCollide = false end
        end
    else
        for part, original in pairs(noclipOriginal) do
            if part and part.Parent then
                part.CanCollide = original
            end

            noclipOriginal[part] = nil
        end
        ESPX.noclipChar = nil
        ESPX.noclipParts = {}
    end
end

ESPX.track(lplr.CharacterAdded:Connect(function()
    task.wait(0.25)

    if toggles.Noclip then
        setNoclip(true)
    end
end))

-- Keep collision disabled while Noclip is enabled.
ESPX.track(rs.Stepped:Connect(function()
    if toggles.Noclip then
        setNoclip(true)
    end
end))

-- Fly toggle (WASD to move, Space to rise, LeftCtrl to descend).
-- Kept separate from the existing feature implementations.
local flyVelocity = nil
local flyGyro = nil
local flyRoot = nil
local flyConnection = nil
flySpeed = 55

local function stopFly()
    if flyConnection then
        flyConnection:Disconnect()
        flyConnection = nil
    end
    if flyVelocity then flyVelocity:Destroy(); flyVelocity = nil end
    if flyGyro then flyGyro:Destroy(); flyGyro = nil end
    flyRoot = nil
end

local function startFly()
    stopFly()
    local character = lplr.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not root or not humanoid then return end

    flyRoot = root
    flyVelocity = Instance.new("BodyVelocity")
    flyVelocity.Name = "HRSH_FlyVelocity"
    flyVelocity.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    flyVelocity.Velocity = Vector3.zero
    flyVelocity.Parent = root

    flyGyro = Instance.new("BodyGyro")
    flyGyro.Name = "HRSH_FlyGyro"
    flyGyro.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
    flyGyro.P = 1e4
    flyGyro.CFrame = root.CFrame
    flyGyro.Parent = root

    humanoid:ChangeState(Enum.HumanoidStateType.Physics)
    flyConnection = rs.RenderStepped:Connect(function()
        if not toggles.Fly or not flyRoot or not flyRoot.Parent or not flyVelocity or not flyGyro then
            stopFly()
            return
        end
        local camera = ws.CurrentCamera
        if not camera then return end
        local direction = Vector3.zero
        local look = camera.CFrame.LookVector
        local right = camera.CFrame.RightVector
        if uis:IsKeyDown(Enum.KeyCode.W) then direction += look end
        if uis:IsKeyDown(Enum.KeyCode.S) then direction -= look end
        if uis:IsKeyDown(Enum.KeyCode.D) then direction += right end
        if uis:IsKeyDown(Enum.KeyCode.A) then direction -= right end
        if uis:IsKeyDown(Enum.KeyCode.Space) then direction += Vector3.yAxis end
        if uis:IsKeyDown(Enum.KeyCode.LeftControl) then direction -= Vector3.yAxis end
        if toggles.Freecam then direction = Vector3.zero end -- WASD belongs to Freecam while it is on
        if direction.Magnitude > 0 then direction = direction.Unit * flySpeed end
        flyVelocity.Velocity = direction
        flyGyro.CFrame = CFrame.lookAt(flyRoot.Position, flyRoot.Position + camera.CFrame.LookVector)
    end)
end

local lastFlyState = false
ESPX.track(rs.Heartbeat:Connect(function()
    if toggles.Fly ~= lastFlyState then
        lastFlyState = toggles.Fly
        if toggles.Fly then startFly() else
            stopFly()
            local character = lplr.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            if humanoid then humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end
        end
    end
end))

ESPX.track(lplr.CharacterAdded:Connect(function()
    task.wait(0.35)
    if toggles.Fly then startFly() end
end))

-- Item scanner
-- Runs after the Item ESP functions have been declared.
-- It scans direct Workspace children, so ProximityPrompt activation range
-- does not control whether an item is detected.
task.spawn(function()
    -- Starts true so stale labels from an older run are cleaned once at startup.
    local wasOn = true
    while not terminated do
        if toggles.ItemESP then
            wasOn = true
            updateItemESP()
        elseif wasOn then
            wasOn = false
            clearItemESP() -- one cleanup when switched off, instead of scanning CoreGui forever
        end

        task.wait(0.15)
    end
end)

ESPX.track(ws.ChildAdded:Connect(function(obj)
    if toggles.ItemESP then
        task.defer(function()
            if obj and obj.Parent == ws then
                addItemESP(obj)
            end
        end)
    end
end))

ESPX.track(ws.ChildRemoved:Connect(function(obj)
    removeItemESP(obj)
end))

-- Crosshair
-- A filled dot with a thin black ring so it stays visible on bright backgrounds.
local crossDot = Drawing.new("Circle")
local crossOutline = Drawing.new("Circle")
crossDot.Filled = true
crossDot.NumSides = 32
crossDot.Visible = toggles.Crosshair
crossDot.Color = Color3.fromRGB(255, 255, 255)
crossOutline.Filled = false
crossOutline.NumSides = 32
crossOutline.Thickness = 1
crossOutline.Visible = toggles.Crosshair
crossOutline.Color = Color3.fromRGB(0, 0, 0)

local function refreshTargets()
    local tTargets = {}
    local inRange = {}
    local pPos = cam.CFrame.Position

    if lplr.Character and lplr.Character:FindFirstChild("HumanoidRootPart") then
        pPos = lplr.Character.HumanoidRootPart.Position
    end

    for _, obj in ipairs(ws:GetChildren()) do
        if not obj:IsA("Model") then continue end
        if obj.Name == "MI28_Aim" then
            local old = obj:FindFirstChild("NPCHighlight")
            if old then old:Destroy() end
            continue
        end
        if plrs:GetPlayerFromCharacter(obj) then continue end

        local root = obj.PrimaryPart or obj:FindFirstChild("HumanoidRootPart")
            or obj:FindFirstChildWhichIsA("BasePart", true)
        local objPos = root and root.Position
        local dist = objPos and (objPos - pPos).Magnitude or math.huge

        if dist > cfg.maxDist then
            local old = obj:FindFirstChild("NPCHighlight")
            if old then old:Destroy() end
            continue
        end

        local hum = obj:FindFirstChildOfClass("Humanoid")
        local part = obj:FindFirstChild(cfg.targetPart, true)
        local isMI28 = obj.Name:lower():find("mi28", 1, true) ~= nil
        local isNonHumanTarget = isMI28 and (root or obj:FindFirstChildWhichIsA("BasePart", true))
        if not part and isMI28 then
            part = root or obj:FindFirstChildWhichIsA("BasePart", true)
        end

        if hum then
            if toggles.DelCorpses and hum.Health <= 0 then continue end

            if hum.Health > 0 and (part or isNonHumanTarget) and not obj:FindFirstChild("REVIVE") then
                inRange[#inRange + 1] = {model = obj, dist = dist}
            else
                local old = obj:FindFirstChild("NPCHighlight")
                if old then old:Destroy() end
            end
        elseif isNonHumanTarget then
            -- MI28 can be highlighted even when the configured target part is absent.
            inRange[#inRange + 1] = {model = obj, dist = dist}
        else
            local old = obj:FindFirstChild("NPCHighlight")
            if old then old:Destroy() end
        end
    end

    table.sort(inRange, function(a, b) return a.dist < b.dist end)

    for i, data in ipairs(inRange) do
        tTargets[#tTargets + 1] = data.model
        if i <= cfg.maxEsp then
            applyEsp(data.model)
        else
            local old = data.model:FindFirstChild("NPCHighlight")
            if old then old:Destroy() end
        end
    end
    validTargets = tTargets
end

-- Gather NPCs: stack eligible NPC roots at one shared point in front of the player.
-- Performance: scan Workspace infrequently, then reuse a cached list for fast movement updates.
-- Excludes Armata/MI28 and any Dummy model, including nested Dummy/DummyTwo models.
local function hasGatherExcludedName(model)
    local name = string.lower(model.Name)
    return string.find(name, "armata", 1, true) ~= nil
        or string.find(name, "mi28", 1, true) ~= nil
        or string.find(name, "mi-28", 1, true) ~= nil
        or string.find(name, "dummy", 1, true) ~= nil
end

local function isGatherExcluded(model)
    local node = model
    while node and node ~= ws do
        if node:IsA("Model") and hasGatherExcludedName(node) then
            return true
        end
        node = node.Parent
    end
    -- Skip wrappers containing excluded models so moving a parent cannot move a boss/Dummy.
    for _, descendant in ipairs(model:GetDescendants()) do
        if descendant:IsA("Model") and hasGatherExcludedName(descendant) then
            return true
        end
    end
    return false
end

local function getGatherRoot(model)
    return model.PrimaryPart
        or model:FindFirstChild("HumanoidRootPart")
        or model:FindFirstChild("Torso")
        or model:FindFirstChildWhichIsA("BasePart", true)
end

local function isNestedInsideAnotherHumanoidModel(model)
    local parent = model.Parent
    while parent and parent ~= ws do
        if parent:IsA("Model") and parent:FindFirstChildOfClass("Humanoid") then
            return true
        end
        parent = parent.Parent
    end
    return false
end

local gatherCache = {}
local GATHER_SCAN_INTERVAL = 1.0 -- Workspace scan only once per second
local GATHER_MOVE_INTERVAL = 0.04 -- update target position about 25 times/sec for quick tracking

task.spawn(function()
    local scanElapsed = GATHER_SCAN_INTERVAL
    local moveElapsed = 0
    while not terminated do
        local dt = task.wait(toggles.GatherNPCs and 0.015 or 0.25)
        if not toggles.GatherNPCs then
            table.clear(gatherCache)
            scanElapsed = GATHER_SCAN_INTERVAL -- rescan immediately when enabled again
            moveElapsed = 0
        else
            scanElapsed += dt
            moveElapsed += dt
            local character = lplr.Character
            local myRoot = character and (character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart)
            if myRoot then
                if scanElapsed >= GATHER_SCAN_INTERVAL then
                    scanElapsed = 0
                    -- Start from Humanoids (cheap) so the expensive exclusion checks only run on real NPCs.
                    local candidates = {}
                    local seen = {}
                    for _, hum in ipairs(ws:GetDescendants()) do
                        if hum:IsA("Humanoid") and hum.Health > 0 then
                            local obj = hum.Parent
                            if obj and obj:IsA("Model") and obj ~= character and not seen[obj] then
                                seen[obj] = true
                                if not plrs:GetPlayerFromCharacter(obj)
                                    and not isNestedInsideAnotherHumanoidModel(obj)
                                    and not isGatherExcluded(obj) then
                                    local root = getGatherRoot(obj)
                                    if root then
                                        candidates[#candidates + 1] = {model = obj, root = root, humanoid = hum}
                                    end
                                end
                            end
                        end
                    end
                    gatherCache = candidates
                end

                if moveElapsed >= GATHER_MOVE_INTERVAL then
                    moveElapsed = 0
                    -- One shared point in front of the player; PivotTo snaps quickly without
                    -- repeatedly scanning Workspace or checking every descendant per update.
                    local forward = myRoot.CFrame.LookVector
                    local targetPos = myRoot.Position + forward * cfg.gatherDistance
                    local targetCFrame = CFrame.lookAt(targetPos, targetPos + forward)
                    for i = #gatherCache, 1, -1 do
                        local entry = gatherCache[i]
                        local npc, root, hum = entry.model, entry.root, entry.humanoid
                        if not npc.Parent or not root.Parent or not hum.Parent or hum.Health <= 0 then
                            table.remove(gatherCache, i)
                        else
                            pcall(function()
                                local pivot = npc:GetPivot()
                                local rootOffset = pivot:ToObjectSpace(root.CFrame)
                                npc:PivotTo(targetCFrame * rootOffset:Inverse())
                            end)
                        end
                    end
                end
            end
        end
    end
end)

-- Delete corpses loop
task.spawn(function()
    while not terminated do
        if toggles.DelCorpses then
            for _, obj in ipairs(ws:GetChildren()) do
                if obj:IsA("Model") then
                    local hum = obj:FindFirstChildOfClass("Humanoid")
                    if hum and hum.Health <= 0 then
                        obj:Destroy()
                    end
                end
            end
        end
        task.wait(0.1)
    end
end)

-- Target scan loop
task.spawn(function()
    while not terminated do
        refreshTargets()
        task.wait(cfg.scanRate)
    end
end)

-- Aim assist + crosshair
ESPX.track(rs.RenderStepped:Connect(function(dt)
    if terminated then return end
    local center = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)

    -- Crosshair can now be toggled independently of Aim Assist.
    crossDot.Visible = toggles.Crosshair
    crossOutline.Visible = toggles.Crosshair

    if toggles.Crosshair then
        local opacity = math.clamp(cfg.crosshairOpacity, 0, 1)
        crossDot.Position = center
        crossDot.Radius = cfg.crosshairSize
        crossDot.Color = Color3.fromHSV(
            math.clamp(cfg.crosshairHue, 0, 360) / 360,
            math.clamp(cfg.crosshairSat, 0, 1),
            1
        )
        crossDot.Transparency = opacity
        crossOutline.Position = center
        crossOutline.Radius = cfg.crosshairSize + 1
        crossOutline.Transparency = opacity
    end

    if not toggles.AimAssist then
        return
    end

    local bestTorso = nil
    local shortest = cfg.fov
    local ignore = { lplr.Character }

    for _, npc in ipairs(validTargets) do
        ignore[#ignore + 1] = npc
    end

    for _, npc in ipairs(validTargets) do
        local torso = npc:FindFirstChild(cfg.targetPart, true)
        -- MI28 helicopter models may not have the configured humanoid target part.
        -- Fall back to a usable model part so Aim Assist can lock onto the helicopter.
        if not torso and npc.Name:lower():find("mi28", 1, true) then
            torso = npc.PrimaryPart or npc:FindFirstChild("HumanoidRootPart", true)
                or npc:FindFirstChildWhichIsA("BasePart", true)
        end
        if torso then
            local sPos, onScreen = cam:WorldToViewportPoint(torso.Position)
            if onScreen then
                local dist = (Vector2.new(sPos.X, sPos.Y) - center).Magnitude
                if dist < shortest then
                    local obscuring = cam:GetPartsObscuringTarget({ torso.Position }, ignore)
                    local blocked = false
                    for _, part in ipairs(obscuring) do
                        local parent = part.Parent
                        local parentName = parent and parent.Name:lower() or ""
                        local isDoor = parentName:find("wooden door") or part.Name:lower():find("door")
                        if isDoor then continue end

                        local isGui = false
                        local guiCheck = part.Parent
                        while guiCheck and guiCheck ~= ws do
                            if guiCheck:IsA("GuiObject") or guiCheck:IsA("BasePlayerGui") or guiCheck:IsA("ScreenGui") then
                                isGui = true
                                break
                            end
                            guiCheck = guiCheck.Parent
                        end
                        if isGui then continue end

                        local ancestor = part.Parent
                        local inRoom = false
                        while ancestor and ancestor ~= ws do
                            local n = ancestor.Name:lower()
                            if ancestor:IsA("Model") and (n:find("room") or n:find("start") or n:find("bossfight")) then
                                inRoom = true
                                break
                            end
                            ancestor = ancestor.Parent
                        end

                        if inRoom then
                            blocked = true
                            break
                        end
                    end
                    if not blocked then
                        bestTorso = torso
                        shortest = dist
                    end
                end
            end
        end
    end

    if bestTorso then
        crossDot.Color = Color3.fromRGB(255, 0, 0) -- red while locked onto a target
        local root = bestTorso.Parent and bestTorso.Parent:FindFirstChild("HumanoidRootPart")
        local vel = root and root.AssemblyLinearVelocity or Vector3.zero
        local pingComp = 0.055
        local predictedPos = bestTorso.Position + vel * pingComp

        local sPos = cam:WorldToViewportPoint(predictedPos)
        local dx = sPos.X - center.X
        local dy = sPos.Y - center.Y
        local dist2D = math.sqrt(dx * dx + dy * dy)

        if dist2D > 0.5 then
            local distScale = math.clamp(dist2D / 80, 0.65, 1.0)
            local strength = cfg.aimStrength * distScale

            if mousemoverel and not uis.TouchEnabled then
                mousemoverel(dx * strength, dy * strength)
            else
                local lerpAlpha = math.clamp(strength * dt * 18, 0, 0.5)
                local targetCF = CFrame.new(cam.CFrame.Position, predictedPos)
                cam.CFrame = cam.CFrame:Lerp(targetCF, lerpAlpha)
            end
        end
    end
end))

-- Restore any NPC parts modified by an older Big Hitboxes version.
for _, obj in ipairs(ws:GetDescendants()) do
    if obj:IsA("BasePart") and obj:GetAttribute("OrigSize") then
        pcall(function()
            obj.Size = obj:GetAttribute("OrigSize")
            local originalTransparency = obj:GetAttribute("OrigTrans")
            if originalTransparency ~= nil then obj.Transparency = originalTransparency end
            local originalColor = obj:GetAttribute("OrigColor")
            if originalColor ~= nil then obj.BrickColor = BrickColor.new(originalColor) end
            obj:SetAttribute("OrigSize", nil)
            obj:SetAttribute("OrigTrans", nil)
            obj:SetAttribute("OrigColor", nil)
        end)
    end
end


-- Fullbright
ESPX.track(lighting.Changed:Connect(function()
    if not toggles.Fullbright then return end
    lighting.Brightness = 2
    lighting.ClockTime = 14
    lighting.FogEnd = 100000
    lighting.GlobalShadows = false
    lighting.Ambient = Color3.fromRGB(178, 178, 178)
    lighting.OutdoorAmbient = Color3.fromRGB(178, 178, 178)
end))

-- AI State Disabler: one pass over existing NPCs at startup, then only humanoids that get added later
-- (no more full Workspace scan every 2 seconds).
do
    local bannedStates = {
        Enum.HumanoidStateType.Climbing,
        Enum.HumanoidStateType.Swimming,
        Enum.HumanoidStateType.FallingDown,
        Enum.HumanoidStateType.Ragdoll
    }
    local function disableStates(obj)
        if terminated or not obj.Parent then return end
        if obj.Health > 0 and not plrs:GetPlayerFromCharacter(obj.Parent) then
            for _, state in ipairs(bannedStates) do
                pcall(obj.SetStateEnabled, obj, state, false)
            end
        end
    end

    task.spawn(function()
        local i = 0
        for _, obj in ipairs(ws:GetDescendants()) do
            if terminated then return end
            if obj:IsA("Humanoid") then disableStates(obj) end
            i += 1
            if i % 200 == 0 then task.wait() end
        end
    end)

    ESPX.track(ws.DescendantAdded:Connect(function(obj)
        if terminated or not obj:IsA("Humanoid") then return end
        task.defer(disableStates, obj)
    end))
end

-- Low Visuals
local lastLowVisuals = false
local function applyLowVisuals(state)
    lighting.GlobalShadows = not state
    for _, v in ipairs(lighting:GetChildren()) do
        if v:IsA("BlurEffect") or v:IsA("BloomEffect") or v:IsA("SunRaysEffect") then
            v.Enabled = not state
        end
    end
end

ESPX.track(rs.Heartbeat:Connect(function()
    if toggles.LowVisuals ~= lastLowVisuals then
        lastLowVisuals = toggles.LowVisuals
        applyLowVisuals(toggles.LowVisuals)
    end
end))

-- Instance Optimizer
task.spawn(function()
    while not terminated do
        task.wait(5)
        if not toggles.InstanceOptimizer then continue end
        local i = 0
        for _, v in ipairs(ws:GetDescendants()) do
            if v:IsA("MeshPart") or v:IsA("UnionOperation") then
                v.RenderFidelity = Enum.RenderFidelity.Performance
                local isDebris = not v.Anchored
                    and v.Size.Magnitude < 4
                    and not v.Parent:FindFirstChildOfClass("Humanoid")
                    and not plrs:GetPlayerFromCharacter(v.Parent)
                if isDebris then
                    v.CollisionFidelity = Enum.CollisionFidelity.Box
                end
            end
            if v:IsA("BasePart") and not v.Anchored then
                local sz = v.Size
                if sz.X < 1 and sz.Y < 1 and sz.Z < 1 then
                    v.CanTouch = false
                    v.CanQuery = false
                end
            end
            i += 1
            if i % 100 == 0 then task.wait() end
        end
    end
end)

-- Particle Cap
local cachedRates = {}

local function applyParticleCap(state)
    for _, v in ipairs(ws:GetDescendants()) do
        if v:IsA("ParticleEmitter") then
            if state then
                cachedRates[v] = v.Rate
                v.Rate = 5
            else
                if cachedRates[v] then
                    v.Rate = cachedRates[v]
                    cachedRates[v] = nil
                end
            end
        end
    end
end

local lastParticleCap = false
ESPX.track(rs.Heartbeat:Connect(function()
    if toggles.ParticleCap ~= lastParticleCap then
        lastParticleCap = toggles.ParticleCap
        applyParticleCap(toggles.ParticleCap)
    end
end))

-- Ultra Potato
local cachedTextures = {}

local function applyUltraPotato(state)
    for _, v in ipairs(ws:GetDescendants()) do
        if v:IsA("Texture") or v:IsA("Decal") then
            if state then
                cachedTextures[v] = v.Texture
                v.Texture = ""
            else
                if cachedTextures[v] then
                    v.Texture = cachedTextures[v]
                    cachedTextures[v] = nil
                end
            end
        end
    end
end

local lastUltraPotato = false
ESPX.track(rs.Heartbeat:Connect(function()
    if toggles.UltraPotato ~= lastUltraPotato then
        lastUltraPotato = toggles.UltraPotato
        applyUltraPotato(toggles.UltraPotato)
    end
end))

-- F1 Deep Clean
ESPX.track(uis.InputBegan:Connect(function(input, gpe)
    if terminated then return end
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.F1 then
        local cleaned = 0
        local i = 0
        for _, v in ipairs(ws:GetChildren()) do
            if v:IsA("BasePart") and not v.Anchored and not plrs:GetPlayerFromCharacter(v.Parent) then
                v:Destroy()
                cleaned += 1
            end
            i += 1
            if i % 50 == 0 then task.wait() end
        end
        applyParticleCap(true)
        lastParticleCap = true
        toggles.ParticleCap = true
        print("Deep Clean done, removed " .. cleaned .. " parts")
    end
end))

-- World: No Fog and Custom Camera FOV.
-- Kept in its own block (not nested in the generator block) to stay under Luau's 200-locals limit.
do
    local fogOriginal = nil
    local fogTimer = 1
    local fovOriginal = nil

    local function applyNoFog()
        if not fogOriginal then
            fogOriginal = {fogEnd = lighting.FogEnd, fogStart = lighting.FogStart, atmos = {}}
        end
        -- Same FogEnd Fullbright uses, so the two features never fight over it.
        if lighting.FogEnd ~= 100000 then lighting.FogEnd = 100000 end
        if lighting.FogStart ~= 99000 then lighting.FogStart = 99000 end
        for _, child in ipairs(lighting:GetChildren()) do
            if child:IsA("Atmosphere") then
                if not fogOriginal.atmos[child] then
                    fogOriginal.atmos[child] = {density = child.Density, haze = child.Haze}
                end
                child.Density = 0
                child.Haze = 0
            end
        end
    end

    local function restoreFog()
        if not fogOriginal then return end
        lighting.FogEnd = fogOriginal.fogEnd
        lighting.FogStart = fogOriginal.fogStart
        for atmo, original in pairs(fogOriginal.atmos) do
            if atmo.Parent then
                atmo.Density = original.density
                atmo.Haze = original.haze
            end
        end
        fogOriginal = nil
    end

    local function restoreFov()
        if fovOriginal ~= nil then
            local camera = ws.CurrentCamera
            if camera then camera.FieldOfView = fovOriginal end
            fovOriginal = nil
        end
    end

    -- Re-applied a few times a second because games often reset fog on their own.
    ESPX.track(rs.Heartbeat:Connect(function(dt)
        if terminated then return end
        if toggles.NoFog then
            fogTimer += dt
            if fogTimer >= 0.25 then
                fogTimer = 0
                applyNoFog()
            end
        elseif fogOriginal then
            restoreFog()
            fogTimer = 1
        end
    end))

    ESPX.track(rs.RenderStepped:Connect(function()
        if terminated then return end
        local camera = ws.CurrentCamera
        if not camera then return end
        if toggles.CustomFOV then
            if fovOriginal == nil then fovOriginal = camera.FieldOfView end
            camera.FieldOfView = cfg.camFov
        else
            restoreFov()
        end
    end))

    -- Used by the Terminate button.
    ESPX.restoreWorld = function()
        restoreFog()
        restoreFov()
    end
end

-- Freecam: the same Scriptable-camera approach Spectate uses (the CFrame is set directly every frame),
-- so the camera never gets pushed back by walls. Own block to stay under the 200-locals limit.
do
    local cas = game:GetService("ContextActionService")
    local SINK_ACTION = "HRSH_FreecamSink"
    local fc = {active = false, looking = false, yaw = 0, pitch = 0, pos = Vector3.zero}

    local function sinkInput()
        return Enum.ContextActionResult.Sink
    end

    local function startFreecam()
        local camera = ws.CurrentCamera
        if not camera then return end
        local look = camera.CFrame.LookVector
        fc.yaw = math.atan2(-look.X, -look.Z)
        fc.pitch = math.asin(math.clamp(look.Y, -1, 1))
        fc.pos = camera.CFrame.Position
        fc.active = true
        -- Stop the character from walking/jumping while WASD and Space move the camera instead.
        cas:BindActionAtPriority(
            SINK_ACTION, sinkInput, false, Enum.ContextActionPriority.High.Value,
            Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D,
            Enum.KeyCode.Space, Enum.KeyCode.E, Enum.KeyCode.Q,
            Enum.KeyCode.LeftControl, Enum.KeyCode.LeftShift
        )
    end

    local function stopFreecam()
        if not fc.active then return end
        fc.active = false
        fc.looking = false
        pcall(function() uis.MouseBehavior = Enum.MouseBehavior.Default end)
        pcall(function() cas:UnbindAction(SINK_ACTION) end)
        local camera = ws.CurrentCamera
        if camera then
            camera.CameraType = Enum.CameraType.Custom
            local character = lplr.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            if humanoid then camera.CameraSubject = humanoid end
        end
    end

    -- Hold right mouse button and move the mouse to look around (same as Spectate).
    ESPX.track(uis.InputBegan:Connect(function(input)
        if fc.active and input.UserInputType == Enum.UserInputType.MouseButton2 then
            fc.looking = true
            pcall(function() uis.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition end)
        end
    end))
    ESPX.track(uis.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton2 and fc.looking then
            fc.looking = false
            pcall(function() uis.MouseBehavior = Enum.MouseBehavior.Default end)
        end
    end))
    ESPX.track(uis.InputChanged:Connect(function(input)
        if fc.active and fc.looking and input.UserInputType == Enum.UserInputType.MouseMovement then
            fc.yaw = fc.yaw - input.Delta.X * 0.0035
            fc.pitch = math.clamp(fc.pitch - input.Delta.Y * 0.0035, math.rad(-89), math.rad(89))
        end
    end))

    ESPX.track(rs.RenderStepped:Connect(function(dt)
        if terminated then return end
        local camera = ws.CurrentCamera
        if not camera then return end

        if toggles.Freecam then
            if spectateTargetPlayer then return end -- Spectate owns the camera while it is running
            if not fc.active then startFreecam() end
            camera.CameraType = Enum.CameraType.Scriptable

            local rotation = CFrame.fromOrientation(fc.pitch, fc.yaw, 0)
            if not uis:GetFocusedTextBox() then
                local move = Vector3.zero
                if uis:IsKeyDown(Enum.KeyCode.W) then move += rotation.LookVector end
                if uis:IsKeyDown(Enum.KeyCode.S) then move -= rotation.LookVector end
                if uis:IsKeyDown(Enum.KeyCode.D) then move += rotation.RightVector end
                if uis:IsKeyDown(Enum.KeyCode.A) then move -= rotation.RightVector end
                if uis:IsKeyDown(Enum.KeyCode.Space) or uis:IsKeyDown(Enum.KeyCode.E) then move += Vector3.yAxis end
                if uis:IsKeyDown(Enum.KeyCode.LeftControl) or uis:IsKeyDown(Enum.KeyCode.Q) then move -= Vector3.yAxis end
                if move.Magnitude > 0 then
                    local speed = cfg.freecamSpeed * (uis:IsKeyDown(Enum.KeyCode.LeftShift) and 3 or 1)
                    fc.pos += move.Unit * speed * dt
                end
            end
            camera.CFrame = CFrame.new(fc.pos) * rotation
        elseif fc.active then
            stopFreecam()
        end
    end))

    -- Used by the Terminate button.
    ESPX.stopFreecam = stopFreecam
    ESPX.getFreecamPos = function()
        if fc.active then return fc.pos end
        return nil
    end
end

-- View Line: a red line from each player's head in the direction their head faces, so you can see
-- where they are looking. Drawn with the Drawing library (visible through walls). Own block to stay
-- under the 200-locals limit.
do
    local viewLines = {} -- [player] = Drawing line

    local function removeViewLine(plr)
        local line = viewLines[plr]
        if line then
            pcall(function() line:Remove() end)
            viewLines[plr] = nil
        end
    end

    -- Used by the Terminate button and when the toggle is switched off.
    ESPX.clearViewLines = function()
        for plr in pairs(viewLines) do removeViewLine(plr) end
    end

    ESPX.track(plrs.PlayerRemoving:Connect(removeViewLine))

    ESPX.track(rs.RenderStepped:Connect(function()
        if terminated then return end
        local camera = ws.CurrentCamera
        if not toggles.ViewLine or not camera then
            if next(viewLines) ~= nil then ESPX.clearViewLines() end
            return
        end

        local camCF = camera.CFrame
        local near = 0.2
        for _, plr in ipairs(plrs:GetPlayers()) do
            if plr ~= lplr then
                local char = plr.Character
                local head = char and (char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart"))
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                local line = viewLines[plr]
                local show = false

                if head and head:IsA("BasePart") and hum and hum.Health > 0 then
                    local a = head.Position
                    local b = a + head.CFrame.LookVector * cfg.viewLineLength
                    -- Clip the segment to the camera's near plane so it never flips when one end is behind you.
                    local da = -camCF:PointToObjectSpace(a).Z
                    local db = -camCF:PointToObjectSpace(b).Z
                    if da > near or db > near then
                        local t = (near - da) / (db - da)
                        if da <= near then
                            a = a + (b - a) * t
                        elseif db <= near then
                            b = a + (b - a) * t
                        end
                        local pa = camera:WorldToViewportPoint(a)
                        local pb = camera:WorldToViewportPoint(b)
                        if not line then
                            line = Drawing.new("Line")
                            line.Thickness = 2
                            line.Color = Color3.fromRGB(255, 0, 0)
                            viewLines[plr] = line
                        end
                        line.From = Vector2.new(pa.X, pa.Y)
                        line.To = Vector2.new(pb.X, pb.Y)
                        show = true
                    end
                end

                if line then line.Visible = show end
            end
        end
    end))
end

-- Anti AFK: answers Roblox's idle check so you are not kicked after 20 minutes without input.
do
    local virtualUser = game:GetService("VirtualUser")
    ESPX.track(lplr.Idled:Connect(function()
        if terminated or not toggles.AntiAFK then return end
        pcall(function()
            virtualUser:CaptureController()
            virtualUser:ClickButton2(Vector2.new())
        end)
    end))
end

-- Hitbox Extender (other players): grows the selected body parts into cubes. Head / Body / Legs can be
-- chosen independently. This only changes the parts on YOUR client, so it helps in games whose hit
-- detection runs locally. Own block to stay under the 200-locals limit.
do
    local PART_TOGGLE = {Head = "HitboxHead"}
    for _, name in ipairs({"HumanoidRootPart", "UpperTorso", "LowerTorso", "Torso"}) do
        PART_TOGGLE[name] = "HitboxBody"
    end
    for _, name in ipairs({
        "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot", -- R15
        "Left Leg", "Right Leg", -- R6
    }) do
        PART_TOGGLE[name] = "HitboxLegs"
    end

    local originals = {} -- [part] = its original size / transparency / collision settings
    local boxes = {}     -- [part] = BoxHandleAdornment that draws the real hitbox (see-through walls)

    local function removeBox(part)
        local box = boxes[part]
        if box then
            box:Destroy()
            boxes[part] = nil
        end
    end

    local function restorePart(part)
        removeBox(part)
        local original = originals[part]
        if not original then return end
        if part.Parent then
            part.Size = original.size
            part.Transparency = original.transparency
            part.CanCollide = original.canCollide
            part.Massless = original.massless
        end
        originals[part] = nil
    end

    local function restoreAll()
        for part in pairs(originals) do restorePart(part) end
    end

    -- Used by the Terminate button.
    ESPX.restoreHitboxes = restoreAll

    task.spawn(function()
        while not terminated do
            if toggles.HitboxExtender then
                local size = Vector3.new(cfg.hitboxSize, cfg.hitboxSize, cfg.hitboxSize)
                local active = {}
                for _, plr in ipairs(plrs:GetPlayers()) do
                    local char = plr ~= lplr and plr.Character
                    if char then
                        for _, part in ipairs(char:GetChildren()) do
                            local toggleKey = PART_TOGGLE[part.Name]
                            if toggleKey and toggles[toggleKey] and part:IsA("BasePart") then
                                active[part] = true
                                if not originals[part] then
                                    originals[part] = {
                                        size = part.Size,
                                        transparency = part.Transparency,
                                        canCollide = part.CanCollide,
                                        massless = part.Massless,
                                    }
                                end
                                if part.Size ~= size then part.Size = size end
                                part.Transparency = cfg.hitboxTransparency
                                part.CanCollide = false
                                part.Massless = true

                                -- Show Hitbox (only while Player ESP is on): a box that matches the real hitbox size
                                -- exactly, drawn through walls in the Player ESP color. Works even for avatars whose head is invisible
                                -- or a mesh that does not fill the part.
                                if toggles.HitboxVisual and toggles.PlayerESP then
                                    local box = boxes[part]
                                    if not box or not box.Parent then
                                        box = Instance.new("BoxHandleAdornment")
                                        box.Name = "HitboxVisual"
                                        box.AlwaysOnTop = true
                                        box.ZIndex = 1
                                        box.Adornee = part
                                        box.Parent = cg
                                        boxes[part] = box
                                    end
                                    box.Size = size
                                    box.Color3 = ESPX.playerColor(plr)
                                    box.Transparency = 1 - math.clamp(cfg.hitboxBoxOpacity, 0, 1)
                                else
                                    removeBox(part)
                                end
                            end
                        end
                    end
                end
                -- Put back anything that is no longer selected (or whose player left / respawned).
                for part in pairs(originals) do
                    if not active[part] then restorePart(part) end
                end
            elseif next(originals) ~= nil then
                restoreAll()
            end
            task.wait(0.1)
        end
    end)
end

-- Generator ESP (orange, styled like Player ESP) + Terminate button
do
    local function getGeneratorColor()
        return Color3.fromHSV(math.clamp(cfg.genHue, 0, 360) / 360, 1, 1)
    end

    local function getGeneratorAnchor(model)
        if model.PrimaryPart then return model.PrimaryPart end
        return model:FindFirstChildWhichIsA("BasePart", true)
    end

    -- Generator progress: the game's repair script is not readable from here, so this looks for a
    -- number/string stored as an Attribute or a Value object whose name sounds like progress.
    -- The first match is cached per generator.
    local PROGRESS_KEYWORDS = {"progress", "percent", "repair", "complet", "charge", "fixed", "fuel"}
    local progressSource = {}   -- [model] = {inst = Instance, attr = string?} or false
    local progressSearched = {} -- [model] = os.clock() of the last failed search

    local function nameLooksLikeProgress(name)
        local n = string.lower(name)
        for _, keyword in ipairs(PROGRESS_KEYWORDS) do
            if string.find(n, keyword, 1, true) then return true end
        end
        return false
    end

    local function findProgressSource(model)
        local candidates = {model}
        for _, d in ipairs(model:GetDescendants()) do candidates[#candidates + 1] = d end
        for _, inst in ipairs(candidates) do
            for attrName, value in pairs(inst:GetAttributes()) do
                if (type(value) == "number" or type(value) == "string") and nameLooksLikeProgress(attrName) then
                    return {inst = inst, attr = attrName}
                end
            end
            if (inst:IsA("NumberValue") or inst:IsA("IntValue") or inst:IsA("StringValue"))
                and nameLooksLikeProgress(inst.Name) then
                return {inst = inst}
            end
        end
        return nil
    end

    local function getProgressText(model)
        local src = progressSource[model]
        if src and (not src.inst.Parent) then src = nil; progressSource[model] = nil end
        if not src then
            local last = progressSearched[model]
            if last and os.clock() - last < 5 then return nil end -- retry a failed search every 5s
            src = findProgressSource(model)
            if not src then
                progressSearched[model] = os.clock()
                return nil
            end
            progressSource[model] = src
        end

        local value, shownName
        if src.attr then
            value = src.inst:GetAttribute(src.attr)
            shownName = src.attr
        else
            value = src.inst.Value
            shownName = src.inst.Name
        end
        if type(value) == "number" then
            if value >= 0 and value <= 1 and value ~= math.floor(value) then
                return string.format("%s: %d%%", shownName, math.floor(value * 100 + 0.5))
            end
            return string.format("%s: %s", shownName, tostring(math.floor(value * 10 + 0.5) / 10))
        end
        return string.format("%s: %s", shownName, tostring(value))
    end

    -- This game stores generator state as Attributes on the Generator model:
    -- RepairProgress, ProgressPaused, PlayersRepairingCount and kickcount.
    local function getGeneratorStatusLines(model)
        local lines = {}
        local progress = model:GetAttribute("RepairProgress")
        if type(progress) == "number" then
            -- Handles both a 0-100 scale and a 0-1 fraction.
            local pct = (progress > 0 and progress < 1) and (progress * 100) or progress
            pct = math.clamp(math.floor(pct + 0.5), 0, 100)
            lines[#lines + 1] = (pct >= 100) and "REPAIRED" or string.format("Repair: %d%%", pct)
        else
            local fallback = getProgressText(model) -- generic search for other games/maps
            if fallback then lines[#lines + 1] = fallback end
        end

        local extras = {}
        if model:GetAttribute("ProgressPaused") == true then extras[#extras + 1] = "PAUSED" end
        local repairing = model:GetAttribute("PlayersRepairingCount")
        if type(repairing) == "number" and repairing > 0 then
            extras[#extras + 1] = string.format("%d repairing", repairing)
        end
        local kicks = model:GetAttribute("kickcount")
        if type(kicks) == "number" and kicks > 0 then
            extras[#extras + 1] = string.format("kicked x%d", kicks)
        end
        if #extras > 0 then lines[#lines + 1] = table.concat(extras, "  |  ") end
        return lines
    end

    local function addGeneratorESP(model)
        if not model or not model.Parent then return end

        -- Highlight: same style as Player ESP (50% fill, white outline, always on top)
        local hl = model:FindFirstChild("GeneratorHighlight")
        if not hl then
            hl = Instance.new("Highlight")
            hl.Name = "GeneratorHighlight"
            hl.OutlineColor = Color3.fromRGB(255, 255, 255)
            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            hl.Parent = model
        end
        hl.Adornee = model
        local genColor = getGeneratorColor()
        hl.FillColor = genColor
        hl.FillTransparency = 1 - math.clamp(cfg.genFillOpacity, 0, 1)
        hl.OutlineTransparency = 1 - math.clamp(cfg.genOutlineOpacity, 0, 1)
        hl.Enabled = true

        -- Info label: name + distance, like Player ESP
        local anchor = getGeneratorAnchor(model)
        if not anchor then return end

        local infoGui = model:FindFirstChild("GeneratorInfoESP", true)
        if infoGui and not infoGui:IsA("BillboardGui") then
            infoGui:Destroy()
            infoGui = nil
        end
        if not infoGui then
            infoGui = Instance.new("BillboardGui")
            infoGui.Name = "GeneratorInfoESP"
            infoGui.Size = UDim2.new(0, 220, 0, 72)
            infoGui.StudsOffset = Vector3.new(0, 3, 0)
            infoGui.AlwaysOnTop = true
            infoGui.MaxDistance = 5000
            local label = Instance.new("TextLabel")
            label.Name = "Info"
            label.Size = UDim2.new(1, 0, 1, 0)
            label.BackgroundTransparency = 1
            label.Font = Enum.Font.GothamBold
            label.TextSize = 13
            label.TextColor3 = Color3.fromRGB(255, 140, 0)
            label.TextStrokeTransparency = 0
            label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
            label.Parent = infoGui
        end
        if infoGui.Parent ~= anchor then infoGui.Parent = anchor end
        infoGui.Size = UDim2.new(0, 220, 0, 72)

        local label = infoGui:FindFirstChild("Info")
        if label then
            ESPX.styleText(label, infoGui)
            label.TextColor3 = genColor
            local myChar = lplr.Character
            local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
            local distance = myRoot and math.floor((myRoot.Position - anchor.Position).Magnitude + 0.5) or 0
            local text = string.format("Generator\n%d studs", distance)
            for _, line in ipairs(getGeneratorStatusLines(model)) do
                text = text .. "\n" .. line
            end
            label.Text = text
        end
    end

    local function clearGeneratorESP()
        for _, v in ipairs(ws:GetDescendants()) do
            if (v:IsA("Highlight") and v.Name == "GeneratorHighlight")
                or (v:IsA("BillboardGui") and v.Name == "GeneratorInfoESP") then
                v:Destroy()
            end
        end
    end

    -- Finds "Generator" models. Checks Workspace.Map.Generators first; if that path
    -- is missing/empty (different map, streaming), falls back to scanning all of Workspace.
    local function findGenerators()
        local found = {}
        local map = ws:FindFirstChild("Map")
        local folder = map and map:FindFirstChild("Generators")
        if folder then
            for _, obj in ipairs(folder:GetChildren()) do
                if obj:IsA("Model") and obj.Name == "Generator" then
                    found[#found + 1] = obj
                end
            end
        end
        if #found == 0 then
            for _, obj in ipairs(ws:GetDescendants()) do
                if obj:IsA("Model") and obj.Name == "Generator" then
                    local parent = obj.Parent
                    if not (parent and parent:IsA("Model") and parent.Name == "Generator") then
                        found[#found + 1] = obj
                    end
                end
            end
        end
        return found
    end

    task.spawn(function()
        local wasOn = false
        local fullScanTimer = 0
        local cached = {}
        while not terminated do
            if toggles.GeneratorESP then
                wasOn = true
                fullScanTimer += 0.25
                -- Re-discover generators once per second; refresh labels every 0.25s.
                if fullScanTimer >= 1 or #cached == 0 then
                    fullScanTimer = 0
                    cached = findGenerators()
                end
                for _, model in ipairs(cached) do
                    pcall(addGeneratorESP, model)
                end
            elseif wasOn then
                wasOn = false
                cached = {}
                clearGeneratorESP()
            end
            task.wait(0.25)
        end
    end)

    -- Head marker (Cyberpunk 2077 scanner style): a small diamond over a double chevron that bobs
    -- toward the target and blinks. Built from frames so it never depends on font glyphs, and
    -- recolored every refresh to match the target's ESP highlight.
    local headArrows = {} -- [model] = BillboardGui

    local function buildArrow()
        local gui = Instance.new("BillboardGui")
        gui.Name = "HeadArrowESP"
        gui.Size = UDim2.new(0, 30, 0, 34)
        gui.AlwaysOnTop = true
        gui.MaxDistance = 5000
        local holder = Instance.new("Frame")
        holder.Name = "Arrow"
        holder.Size = UDim2.new(1, 0, 1, 0)
        holder.BackgroundTransparency = 1
        holder.Parent = gui

        local function piece(name, size, center, rotation, transparency)
            local f = Instance.new("Frame")
            f.Name = name
            f.AnchorPoint = Vector2.new(0.5, 0.5)
            f.Position = UDim2.new(0, center.X, 0, center.Y)
            f.Size = UDim2.new(0, size.X, 0, size.Y)
            f.Rotation = rotation
            f.BackgroundTransparency = transparency or 0
            f.BorderSizePixel = 0
            f.Parent = holder
            stroke(f, Color3.fromRGB(0, 0, 0), 0, 1)
            return f
        end

        local diamond = piece("Diamond", Vector2.new(5, 5), Vector2.new(15, 4), 45)
        -- Outer chevron (tip at y = 18), then a smaller, fainter one below it (tip at y = 27).
        piece("OuterLeft", Vector2.new(10, 3), Vector2.new(11.5, 14.5), 45)
        piece("OuterRight", Vector2.new(10, 3), Vector2.new(18.5, 14.5), -45)
        piece("InnerLeft", Vector2.new(7, 2), Vector2.new(12.5, 24.5), 45, 0.35)
        piece("InnerRight", Vector2.new(7, 2), Vector2.new(17.5, 24.5), -45, 0.35)

        -- Bob toward the target and blink the diamond (tweens stop when the GUI is destroyed).
        TweenService:Create(
            holder,
            TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
            {Position = UDim2.new(0, 0, 0, 4)}
        ):Play()
        TweenService:Create(
            diamond,
            TweenInfo.new(0.4, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, true),
            {BackgroundTransparency = 0.7}
        ):Play()
        return gui
    end

    local function setArrow(model, color)
        local anchor = model:FindFirstChild("Head")
            or model:FindFirstChild("HumanoidRootPart")
            or model.PrimaryPart
            or model:FindFirstChildWhichIsA("BasePart", true)
        if not anchor then return end
        local gui = headArrows[model]
        if not gui or not gui.Parent then
            gui = buildArrow()
            headArrows[model] = gui
        end
        gui.StudsOffset = Vector3.new(0, anchor.Name == "Head" and 2.4 or 4, 0)
        if gui.Parent ~= anchor then gui.Parent = anchor end
        local holder = gui:FindFirstChild("Arrow")
        if holder then
            for _, piece in ipairs(holder:GetChildren()) do
                if piece:IsA("Frame") then piece.BackgroundColor3 = color end
            end
        end
        gui.Enabled = true
    end

    local function clearHeadArrows()
        for model, gui in pairs(headArrows) do
            if gui then gui:Destroy() end
            headArrows[model] = nil
        end
        for _, v in ipairs(ws:GetDescendants()) do
            if v:IsA("BillboardGui") and v.Name == "HeadArrowESP" then v:Destroy() end
        end
    end

    task.spawn(function()
        local wasOn = false
        while not terminated do
            if toggles.HeadArrow then
                wasOn = true
                local seen = {}
                for _, npc in ipairs(validTargets) do
                    if npc.Parent then
                        seen[npc] = true
                        setArrow(npc, cfg.espFill) -- same color as NPC ESP
                    end
                end
                for _, plr in ipairs(plrs:GetPlayers()) do
                    local char = plr.Character
                    local hum = char and char:FindFirstChildOfClass("Humanoid")
                    if plr ~= lplr and char and hum and hum.Health > 0 then
                        seen[char] = true
                        setArrow(char, ESPX.playerColor(plr)) -- same color as Player ESP
                    end
                end
                for model, gui in pairs(headArrows) do
                    if not seen[model] or not model.Parent then
                        if gui then gui:Destroy() end
                        headArrows[model] = nil
                    end
                end
            elseif wasOn then
                wasOn = false
                clearHeadArrows()
            end
            task.wait(0.2)
        end
    end)

    -- Terminate button (Settings tab)
    setTab("Settings")
    createSection("[ DANGER ZONE ]")
    createActionButton("Terminate", function()
        -- Stop all saving first, so nothing below can write to the file.
        terminated = true

        for key in pairs(toggles) do toggles[key] = false end
        toggles.SelfHP = false

        pcall(stopSpectating)
        pcall(stopFly)
        pcall(setNoclip, false)
        pcall(clearItemESP)
        pcall(clearGeneratorESP)
        pcall(clearHeadArrows)
        pcall(ESPX.restoreWorld)
        pcall(ESPX.stopFreecam)
        pcall(ESPX.clearViewLines)
        pcall(ESPX.restoreHitboxes)
        pcall(removeSelfHP)
        pcall(function() crossDot:Remove(); crossOutline:Remove() end)

        for _, v in ipairs(ws:GetDescendants()) do
            if v:IsA("Highlight") and (v.Name == "NPCHighlight" or v.Name == "PlayerHighlight") then
                v:Destroy()
            elseif v:IsA("BillboardGui") and (v.Name == "EnemyHPESP" or v.Name == "PlayerInfoESP") then
                v:Destroy()
            end
        end

        local char = lplr.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = 16 end

        -- Disconnect every tracked service connection (input, render loops, player/workspace events).
        for _, connection in ipairs(ESPX.conns) do
            pcall(function() connection:Disconnect() end)
        end

        gui:Destroy()
    end)
    setTab("Main")
end
