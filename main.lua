local ws = game:GetService("Workspace")
local rs = game:GetService("RunService")
local uis = game:GetService("UserInputService")
local pps = game:GetService("ProximityPromptService")
local plrs = game:GetService("Players")
local lighting = game:GetService("Lighting")
local cg = game:GetService("CoreGui")

local cam = ws.CurrentCamera
local lplr = plrs.LocalPlayer

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
    ProjectilePreview = false,
    AntiAFK = false,
    HitboxExtender = false,
    HitboxHead = true,
    HitboxBody = false,
    HitboxLegs = false,
    RemoveUI = false,
    RemoveNearBlur = false,
    CustomDoF = false,
    DoFAutoFocus = false,
    GunFOV = false,
    Ragdoll = false,
    Sit = false,
    Reshade = false,
    FreecamTrack = false,
    CleanShot = false,
    HideCursor = false,
    CinemaBars = false,
    PhotoGrid = false,
    FreezePose = false,
    HideNametags = false,
    HideOthers = false,
    HideNPCs = false,
    RsClean = false,
    RsNoShadows = false,
    RsTime = false,
    RsVignette = false,
    OverheadText = true,
    Crosshair = false,
    Fly = false,
    Noclip = false,
    Fullbright = false,
    InstantInteract = false,
    DelCorpses = false,
    Speed = false,
    GatherNPCs = false,
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
    npcFillOpacity = 0.5,
    npcOutlineOpacity = 1,
    playerFillOpacity = 0.5,
    playerOutlineOpacity = 1,
    genFillOpacity = 0.5,
    genOutlineOpacity = 1,
    genHue = 33,
    textOpacity = 1,
    textSize = 13,
    rsBrightness = 0, rsContrast = 0, rsSaturation = 0, rsTintHue = 0, rsTintStrength = 0,
    rsBloomIntensity = 0, rsBloomSize = 24, rsBloomThreshold = 2,
    rsSunIntensity = 0, rsSunSpread = 0.5,
    rsExposure = 0, rsLightBrightness = 0, rsShadowLift = 0, rsShadowSoftness = 0,
    rsSkylight = 1, rsReflection = 1, rsClockTime = 14, rsVignette = 0.5,
    menuWidth = 460, menuHeight = 620, menuScale = 1,
    headCamFov = 90, headCamOffset = 0.6, headCamSmooth = 0, headCamMotion = 1,
    freecamRoll = 0, freecamSmooth = 0, camSlot = 1, barSize = 0.12,
    camFov = 70,
    freecamSpeed = 50,
    viewLineLength = 60,
    projSpeed = 158, projGravity = 0.47, projRange = 300, projPitch = 0, projHeight = 1.5, projForward = 2,
    hitboxSize = 8,
    hitboxTransparency = 0.7,
    dofFar = 0.8,
    dofNear = 0,
    dofFocusDistance = 10,
    dofFocusRadius = 5,
    dofLayers = 1,
    gunFov = 90,
    crosshairSize = 3,
    crosshairOpacity = 1,
    crosshairHue = 0,
    crosshairSat = 0,
}

local ESPX = {}
ESPX.toggleList = {}
ESPX.togglePaints = {}
ESPX.toggleFlips = {}
ESPX.sliders = {}
ESPX.defaultToggles = {}
for key, value in pairs(toggles) do ESPX.defaultToggles[key] = value end
ESPX.defaultCfg = {}
for key, value in pairs(cfg) do
    if type(value) == "number" then ESPX.defaultCfg[key] = value end
end

if type(loadedSettings.toggles) == "table" then
    for key, value in pairs(loadedSettings.toggles) do
        if toggles[key] ~= nil and type(value) == "boolean" then toggles[key] = value end
    end
end
toggles.RemoveUI = false
toggles.Ragdoll = false
toggles.Sit = false
toggles.FreezePose = false
toggles.CleanShot = false
toggles.HideCursor = false
if type(loadedSettings.cfg) == "table" then
    for key, value in pairs(loadedSettings.cfg) do
        if type(cfg[key]) == "number" and type(value) == "number" then cfg[key] = value end
    end
end
if type(loadedSettings.flySpeed) == "number" then flySpeed = math.clamp(loadedSettings.flySpeed, 1, 200) end

ESPX.conns = {}
function ESPX.track(connection)
    ESPX.conns[#ESPX.conns + 1] = connection
    return connection
end

ESPX.noclipParts = {}
ESPX.noclipChar = nil
ESPX.noclipBuilt = 0

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
        rsBrightness = cfg.rsBrightness, rsContrast = cfg.rsContrast, rsSaturation = cfg.rsSaturation,
        rsTintHue = cfg.rsTintHue, rsTintStrength = cfg.rsTintStrength,
        rsBloomIntensity = cfg.rsBloomIntensity, rsBloomSize = cfg.rsBloomSize, rsBloomThreshold = cfg.rsBloomThreshold,
        rsSunIntensity = cfg.rsSunIntensity, rsSunSpread = cfg.rsSunSpread,
        rsExposure = cfg.rsExposure, rsLightBrightness = cfg.rsLightBrightness,
        rsShadowLift = cfg.rsShadowLift, rsShadowSoftness = cfg.rsShadowSoftness,
        rsSkylight = cfg.rsSkylight, rsReflection = cfg.rsReflection,
        rsClockTime = cfg.rsClockTime, rsVignette = cfg.rsVignette,
        menuWidth = cfg.menuWidth, menuHeight = cfg.menuHeight, menuScale = cfg.menuScale,
        headCamFov = cfg.headCamFov, headCamOffset = cfg.headCamOffset, headCamSmooth = cfg.headCamSmooth,
        headCamMotion = cfg.headCamMotion,
        freecamRoll = cfg.freecamRoll, freecamSmooth = cfg.freecamSmooth, camSlot = cfg.camSlot, barSize = cfg.barSize,
        camFov = cfg.camFov,
        freecamSpeed = cfg.freecamSpeed,
        viewLineLength = cfg.viewLineLength,
        projSpeed = cfg.projSpeed, projGravity = cfg.projGravity, projRange = cfg.projRange,
        projPitch = cfg.projPitch, projHeight = cfg.projHeight, projForward = cfg.projForward,
        hitboxSize = cfg.hitboxSize,
        hitboxTransparency = cfg.hitboxTransparency,
        dofFar = cfg.dofFar,
        dofNear = cfg.dofNear,
        dofFocusDistance = cfg.dofFocusDistance,
        dofFocusRadius = cfg.dofFocusRadius,
        dofLayers = cfg.dofLayers,
        gunFov = cfg.gunFov,
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

ESPX.saveToken = 0
function ESPX.queueSave()
    ESPX.saveToken += 1
    local token = ESPX.saveToken
    task.delay(0.6, function()
        if token == ESPX.saveToken and not terminated then saveSettings() end
    end)
end

local oldGui = cg:FindFirstChild("OmniMenu")
if oldGui then oldGui:Destroy() end

local C = {
    bg = Color3.fromRGB(0, 0, 0),
    panel = Color3.fromRGB(7, 7, 8),
    panel2 = Color3.fromRGB(18, 5, 7),
    hover = Color3.fromRGB(42, 8, 12),
    accent = Color3.fromRGB(220, 24, 42),
    accentDark = Color3.fromRGB(150, 10, 24),
    trueState = Color3.fromRGB(0, 220, 235),
    outline = Color3.fromRGB(125, 16, 28),
    text = Color3.fromRGB(242, 242, 245),
    muted = Color3.fromRGB(155, 135, 138),
    off = Color3.fromRGB(220, 24, 42),
    green = Color3.fromRGB(0, 220, 235),
}

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
main.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
main.BorderSizePixel = 0
main.Position = UDim2.new(0.035, 0, 0.12, 0)
main.Size = UDim2.new(0, cfg.menuWidth, 0, cfg.menuHeight)
main.Active = true
main.Draggable = false
main.ClipsDescendants = true
stroke(main, C.outline, 0.05, 1)
local sizeConstraint = Instance.new("UISizeConstraint")
sizeConstraint.Parent = main
sizeConstraint.MinSize = Vector2.new(340, 420)
sizeConstraint.MaxSize = Vector2.new(1100, 1000)

do
    local menuScale = Instance.new("UIScale")
    menuScale.Scale = math.clamp(cfg.menuScale, 0.6, 1.8)
    menuScale.Parent = main

    ESPX.applyMenuSize = function()
        main.Size = UDim2.new(0, cfg.menuWidth, 0, cfg.menuHeight)
        menuScale.Scale = math.clamp(cfg.menuScale, 0.6, 1.8)
    end

    local handle = Instance.new("TextButton")
    handle.Name = "ResizeHandle"
    handle.Parent = main
    handle.AnchorPoint = Vector2.new(1, 1)
    handle.Position = UDim2.new(1, 0, 1, 0)
    handle.Size = UDim2.new(0, 22, 0, 22)
    handle.BackgroundTransparency = 1
    handle.Text = ""
    handle.AutoButtonColor = false
    handle.ZIndex = 80
    for _, offset in ipairs({Vector2.new(15, 15), Vector2.new(9, 15), Vector2.new(15, 9)}) do
        local dot = Instance.new("Frame")
        dot.Parent = handle
        dot.Position = UDim2.new(0, offset.X, 0, offset.Y)
        dot.Size = UDim2.new(0, 3, 0, 3)
        dot.BackgroundColor3 = C.accent
        dot.BorderSizePixel = 0
        dot.ZIndex = 81
    end
    ESPX.resizeHandle = handle

    local resizing = false
    local startMouse, startWidth, startHeight = nil, 0, 0
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            resizing = true
            startMouse = input.Position
            startWidth = cfg.menuWidth
            startHeight = cfg.menuHeight
        end
    end)
    ESPX.track(uis.InputChanged:Connect(function(input)
        if resizing and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local scale = math.max(0.1, menuScale.Scale)
            local delta = input.Position - startMouse
            local screen = ws.CurrentCamera and ws.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
            cfg.menuWidth = math.clamp(startWidth + delta.X / scale, 340, math.min(1100, screen.X / scale))
            cfg.menuHeight = math.clamp(startHeight + delta.Y / scale, 420, math.min(1000, screen.Y / scale))
            main.Size = UDim2.new(0, cfg.menuWidth, 0, cfg.menuHeight)
        end
    end))
    ESPX.track(uis.InputEnded:Connect(function(input)
        if resizing and (input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch) then
            resizing = false
            ESPX.queueSave()
        end
    end))
end

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
footerLeft.Text = "NETRUNNER  ▸  " .. string.upper(lplr.Name) .. "  •  BUILD: VEIL-PREVIEW"
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
tabLayout.Padding = UDim.new(0, 2)
tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left

local tabDivider = Instance.new("Frame")
tabDivider.Parent = main
tabDivider.Position = UDim2.new(0, 8, 0, 100)
tabDivider.Size = UDim2.new(1, -16, 0, 1)
tabDivider.BackgroundColor3 = C.outline
tabDivider.BackgroundTransparency = 0.35
tabDivider.BorderSizePixel = 0
tabDivider.ZIndex = 8

local menuDragging = false
local menuDragStart = nil
local menuStartPosition = nil
local function beginMenuDrag(input)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1
        and input.UserInputType ~= Enum.UserInputType.Touch then return end
    local handle = ESPX.resizeHandle
    if handle then
        local p, pos, size = input.Position, handle.AbsolutePosition, handle.AbsoluteSize
        if p.X >= pos.X and p.X <= pos.X + size.X and p.Y >= pos.Y and p.Y <= pos.Y + size.Y then return end
    end
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

for order, name in ipairs({"Main", "Visual", "Shader", "Photo", "Movement", "Overwatch", "Fun", "Settings", "Binds"}) do
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
    local tabWidths = {Main = 36, Visual = 42, Shader = 42, Photo = 38, Movement = 54, Overwatch = 66, Fun = 30, Settings = 48, Binds = 38}
    button.Size = UDim2.new(0, tabWidths[name] or 60, 1, 0)
    button.BackgroundColor3 = C.panel
    button.BorderSizePixel = 0
    button.AutoButtonColor = false
    button.Font = Enum.Font.Code
    button.Text = string.upper(name)
    button.TextSize = 9
    button.TextColor3 = C.muted
    button.ZIndex = 9
    stroke(button, C.outline, 0.4, 1)

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

local function createSlider(name, minV, maxV, def, cb, key, step)
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
        if maxV - minV >= 10 and not step then val = math.floor(val + 0.5) end
        if step then
            val = math.floor(val / step + 0.5) * step
            val = math.floor(val * 1000 + 0.5) / 1000
        end
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
            set = function(val)
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
createSlider("Hitbox Size", 2, 30, cfg.hitboxSize, function(v) cfg.hitboxSize = v end, "hitboxSize")
createSlider("Hitbox Transparency", 0, 1, cfg.hitboxTransparency, function(v) cfg.hitboxTransparency = v end, "hitboxTransparency")
createSection("[ GUN ]")
createToggle("Gun FOV", "GunFOV")
createSlider("Gun FOV Value", 30, 120, cfg.gunFov, function(v) cfg.gunFov = v end, "gunFov")

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
createSection("[ PROJECTILE PREVIEW ]")
createToggle("Projectile Preview", "ProjectilePreview")
createActionButton("Use Veil Spear Values", function()
    for _, slider in ipairs(ESPX.sliders) do
        if slider.key == "projSpeed" then slider.set(158)
        elseif slider.key == "projGravity" then slider.set(0.47)
        elseif slider.key == "projRange" then slider.set(300)
        elseif slider.key == "projPitch" then slider.set(0) end
    end
    if not toggles.ProjectilePreview then
        toggles.ProjectilePreview = true
        if ESPX.togglePaints.ProjectilePreview then ESPX.togglePaints.ProjectilePreview() end
    end
    saveSettings()
    return "[VEIL SPEAR]"
end)
createSlider("Projectile Speed", 20, 500, cfg.projSpeed, function(v) cfg.projSpeed = v end, "projSpeed")
createSlider("Projectile Gravity", 0, 2, cfg.projGravity, function(v) cfg.projGravity = v end, "projGravity")
createSlider("Projectile Range", 50, 1000, cfg.projRange, function(v) cfg.projRange = v end, "projRange")
createSlider("Projectile Pitch (+/-)", -20, 20, cfg.projPitch, function(v) cfg.projPitch = v end, "projPitch", 0.5)
createSlider("Projectile Start Height", 0, 5, cfg.projHeight, function(v) cfg.projHeight = v end, "projHeight")
createSlider("Projectile Start Forward", 0, 6, cfg.projForward, function(v) cfg.projForward = v end, "projForward")
createSection("[ WORLD ]")
createToggle("Fullbright", "Fullbright")
createToggle("No Fog", "NoFog")
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

setTab("Movement")
createSection("[ MOVEMENT ]")
createToggle("Noclip", "Noclip")
createToggle("Fly", "Fly")
createToggle("Speed Modifier", "Speed")

createSection("[ MOVEMENT SETTINGS ]")
createSlider("Walk Speed", 1, 100, cfg.speed, function(v) cfg.speed = v end, "speed")
createSlider("Fly Speed", 1, 200, 55, function(v) flySpeed = v end, "flySpeed")

setTab("Overwatch")

local selectedSpectatePlayer = nil
local updateSpectateInfo

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
    if ESPX.stopHeadCam then ESPX.stopHeadCam() end
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
        local rotation = CFrame.fromOrientation(spectatePitch, spectateYaw, 0)
        local focus = targetRoot.Position + Vector3.new(0, 2, 0)
        local orbitOffset = -rotation.LookVector * spectateOrbitDistance + Vector3.new(0, spectateOrbitHeight - 2, 0)
        currentCamera.CFrame = CFrame.lookAt(focus + orbitOffset, focus)
    end)
end

local updateSpectateInfo

do
    local function setLocalHidden(state, item)
        local ok, original = pcall(function() return item.LocalTransparencyModifier end)
        if not ok then return end
        if state.hidden[item] == nil then state.hidden[item] = original end
        if original ~= 1 then pcall(function() item.LocalTransparencyModifier = 1 end) end
    end

    local function hideHeadParts(state, character, head)
        setLocalHidden(state, head)
        for _, child in ipairs(head:GetChildren()) do
            if child:IsA("Decal") or child:IsA("Texture") then setLocalHidden(state, child) end
        end
        for _, accessory in ipairs(character:GetChildren()) do
            if accessory:IsA("Accessory") then
                local handle = accessory:FindFirstChild("Handle")
                if handle and handle:IsA("BasePart") then
                    local weld = handle:FindFirstChildWhichIsA("Weld") or handle:FindFirstChildWhichIsA("WeldConstraint")
                    local attachedToHead = false
                    if weld then
                        local part0 = weld:IsA("Weld") and weld.Part0 or weld.Part0
                        local part1 = weld.Part1
                        attachedToHead = (part0 == head) or (part1 == head)
                    end
                    if attachedToHead then
                        setLocalHidden(state, handle)
                        for _, extra in ipairs(handle:GetDescendants()) do
                            if extra:IsA("BasePart") or extra:IsA("Decal") or extra:IsA("Texture") then
                                setLocalHidden(state, extra)
                            end
                        end
                    end
                end
            end
        end
    end

    local function restoreHidden(state)
        for item, original in pairs(state.hidden) do
            if item.Parent then pcall(function() item.LocalTransparencyModifier = original end) end
            state.hidden[item] = nil
        end
    end

    function ESPX.stopHeadCam()
        local state = ESPX.headCam
        if not state then return end
        ESPX.headCam = nil
        if state.connection then state.connection:Disconnect() end
        restoreHidden(state)
        local camera = ws.CurrentCamera
        if camera and state.originalFov then camera.FieldOfView = state.originalFov end
    end

    function ESPX.startHeadCam(player)
        if not player or player == lplr or player.Parent ~= plrs then
            error("Select an available player from the list first")
        end
        local character = player.Character
        local head = character and character:FindFirstChild("Head")
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if not head or not humanoid or humanoid.Health <= 0 then error("Target character is unavailable") end
        local camera = ws.CurrentCamera
        if not camera then error("Camera is unavailable") end

        stopSpectating()
        spectateTargetPlayer = player
        local state = {
            player = player, character = nil, hidden = {}, cframe = nil,
            originalFov = camera.FieldOfView,
            lastYaw = nil, lastPos = nil, rate = 0, speed = 0, phase = 0,
        }
        ESPX.headCam = state
        camera.CameraType = Enum.CameraType.Scriptable

        state.connection = rs.RenderStepped:Connect(function(dt)
            local currentCamera = ws.CurrentCamera
            local targetCharacter = player.Character
            local targetHead = targetCharacter and targetCharacter:FindFirstChild("Head")
            local targetHumanoid = targetCharacter and targetCharacter:FindFirstChildOfClass("Humanoid")
            if not currentCamera or player.Parent ~= plrs or not targetHead or not targetHumanoid
                or targetHumanoid.Health <= 0 then
                stopSpectating()
                return
            end
            if state.character ~= targetCharacter then
                restoreHidden(state)
                state.character = targetCharacter
                state.cframe = nil
                state.lastYaw, state.lastPos, state.rate, state.speed = nil, nil, 0, 0
            end
            hideHeadParts(state, targetCharacter, targetHead)

            currentCamera.CameraType = Enum.CameraType.Scriptable
            currentCamera.FieldOfView = cfg.headCamFov
            local wanted = targetHead.CFrame * CFrame.new(0, 0.15, -cfg.headCamOffset)
            local smooth = math.clamp(cfg.headCamSmooth, 0, 0.95)
            if state.cframe and smooth > 0 then
                wanted = state.cframe:Lerp(wanted, 1 - smooth ^ (dt * 60))
            end
            state.cframe = wanted

            local motion = cfg.headCamMotion
            local final = wanted
            local root = targetCharacter:FindFirstChild("HumanoidRootPart")
            if motion > 0 and root then
                local look = root.CFrame.LookVector
                local yaw = math.atan2(-look.X, -look.Z)
                local position = root.Position
                local step = math.max(dt, 1e-3)
                if state.lastYaw then
                    local delta = (yaw - state.lastYaw + math.pi) % (2 * math.pi) - math.pi
                    local rate = math.clamp(delta / step, -12, 12)
                    state.rate = state.rate + (rate - state.rate) * math.min(1, dt * 10)
                    local flat = Vector3.new(position.X - state.lastPos.X, 0, position.Z - state.lastPos.Z).Magnitude / step
                    state.speed = state.speed + (math.min(flat, 40) - state.speed) * math.min(1, dt * 8)
                end
                state.lastYaw, state.lastPos = yaw, position

                local walking = math.clamp(state.speed / 14, 0, 1)
                state.phase += dt * state.speed * 0.9
                local now = os.clock()
                local bobY = math.sin(state.phase * 2) * 0.07 * walking
                local sway = math.sin(state.phase) * math.rad(1.2) * walking
                local nod = math.sin(state.phase * 2 + 0.6) * math.rad(0.9) * walking
                local breatheP = math.sin(now * 1.3) * math.rad(0.35)
                local breatheR = math.sin(now * 0.8 + 1) * math.rad(0.25)
                local lead = math.clamp(state.rate * 0.12, -math.rad(25), math.rad(25))
                local lean = math.clamp(state.rate * 0.045, -math.rad(8), math.rad(8))
                final = wanted
                    * CFrame.new(0, bobY * motion, 0)
                    * CFrame.Angles((nod + breatheP) * motion, lead * motion, (lean + sway + breatheR) * motion)
            end
            currentCamera.CFrame = final
        end)
    end
end

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
createActionButton("First Person Spectate (Head Cam)", function()
    ESPX.startHeadCam(selectedSpectatePlayer)
end)
createActionButton("Stop Spectating", function()
    stopSpectating()
end)
createSlider("Head Cam FOV", 50, 120, cfg.headCamFov, function(v) cfg.headCamFov = v end, "headCamFov")
createSlider("Head Cam Forward", 0, 2, cfg.headCamOffset, function(v) cfg.headCamOffset = v end, "headCamOffset", 0.05)
createSlider("Head Cam Smoothing", 0, 0.95, cfg.headCamSmooth, function(v) cfg.headCamSmooth = v end, "headCamSmooth", 0.05)
createSlider("Head Cam Motion", 0, 2, cfg.headCamMotion, function(v) cfg.headCamMotion = v end, "headCamMotion", 0.05)

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

createSection("[ 3D AVATAR PREVIEW ]")
local avatarPreviewContainer = Instance.new("Frame")
avatarPreviewContainer.Name = "AvatarPreviewContainer"
avatarPreviewContainer.Parent = scroll
avatarPreviewContainer.BackgroundTransparency = 1
avatarPreviewContainer.BorderSizePixel = 0
avatarPreviewContainer.Size = UDim2.new(1, -20, 0, 260)
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
ESPX.avatarPan = {x = 0, y = 0, panning = false, moveMode = false}

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
    local rotation = CFrame.fromOrientation(avatarPreviewPitch, avatarPreviewYaw, 0)
    local pan = ESPX.avatarPan
    focus = focus + rotation.RightVector * pan.x + rotation.UpVector * pan.y
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

function ESPX.placePreviewModel(clone)
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

local function showAvatarPreview(player)
    clearAvatarPreview()
    avatarPreviewYaw = math.rad(180)
    avatarPreviewPitch = math.rad(-5)
    avatarPreviewDistance = 7
    ESPX.avatarPan.x, ESPX.avatarPan.y = 0, 0
    updateAvatarZoomSlider()
    if ESPX.setAvatarViewLabel then ESPX.setAvatarViewLabel(player and player.Name or "nobody") end
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

    ESPX.placePreviewModel(clone)
end

function ESPX.showOutfitModel(model, label)
    clearAvatarPreview()
    avatarPreviewYaw = math.rad(180)
    avatarPreviewPitch = math.rad(-5)
    avatarPreviewDistance = 7
    ESPX.avatarPan.x, ESPX.avatarPan.y = 0, 0
    updateAvatarZoomSlider()
    if ESPX.setAvatarViewLabel then ESPX.setAvatarViewLabel(label) end
    ESPX.placePreviewModel(model)
end

avatarZoomTrack.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        avatarZoomDragging = true
        setAvatarZoomFromX(input.Position.X)
    end
end)

spectateViewport.InputBegan:Connect(function(input)
    local isLeft = input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch
    local isRight = input.UserInputType == Enum.UserInputType.MouseButton2
    if isLeft or isRight then
        local p = input.Position
        local overControl = ESPX.isOverAvatarControl and ESPX.isOverAvatarControl(p)
        if not overControl then
            avatarPreviewDragging = true
            avatarPreviewLastX = p.X
            avatarPreviewLastY = p.Y
            ESPX.avatarPan.panning = isRight or ESPX.avatarPan.moveMode or uis:IsKeyDown(Enum.KeyCode.LeftShift)
        end
    end
end)

ESPX.track(uis.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.MouseButton2
        or input.UserInputType == Enum.UserInputType.Touch then
        avatarPreviewDragging = false
        ESPX.avatarPan.panning = false
        if input.UserInputType ~= Enum.UserInputType.MouseButton2 then avatarZoomDragging = false end
    end
end))

table.insert(avatarPreviewConnections, ESPX.track(uis.InputChanged:Connect(function(input)
    if avatarZoomDragging and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
        setAvatarZoomFromX(input.Position.X)
    elseif (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) and avatarPreviewDragging then
        local p = input.Position
        local deltaX = p.X - avatarPreviewLastX
        local deltaY = p.Y - avatarPreviewLastY
        avatarPreviewLastX = p.X
        avatarPreviewLastY = p.Y
        local pan = ESPX.avatarPan
        if pan.panning then
            local height = math.max(1, spectateViewport.AbsoluteSize.Y)
            local perPixel = avatarPreviewDistance * 2 * math.tan(math.rad(avatarViewportCamera.FieldOfView) / 2) / height
            pan.x = math.clamp(pan.x - deltaX * perPixel, -25, 25)
            pan.y = math.clamp(pan.y + deltaY * perPixel, -25, 25)
        else
            avatarPreviewYaw = avatarPreviewYaw - deltaX * 0.012
            avatarPreviewPitch = math.clamp(avatarPreviewPitch - deltaY * 0.01, math.rad(-80), math.rad(80))
        end
        updateAvatarPreviewCamera()
    end
end)))

do
    local function previewButton(text, xOffset)
        local button = Instance.new("TextButton")
        button.Parent = avatarPreviewContainer
        button.AnchorPoint = Vector2.new(1, 0)
        button.Position = UDim2.new(1, xOffset, 0, 8)
        button.Size = UDim2.new(0, 90, 0, 22)
        button.BackgroundColor3 = C.panel
        button.BackgroundTransparency = 0.1
        button.BorderSizePixel = 0
        button.AutoButtonColor = false
        button.Font = Enum.Font.Code
        button.Text = text
        button.TextColor3 = C.accent
        button.TextSize = 10
        button.ZIndex = 20
        stroke(button, C.outline, 0.15, 1)
        return button
    end
    local resetButton = previewButton("RESET VIEW", -8)
    local modeButton = previewButton("MODE: ROTATE", -102)

    local viewLabel = Instance.new("TextLabel")
    viewLabel.Parent = avatarPreviewContainer
    viewLabel.BackgroundTransparency = 1
    viewLabel.Position = UDim2.new(0, 8, 0, 8)
    viewLabel.Size = UDim2.new(1, -208, 0, 22)
    viewLabel.Font = Enum.Font.Code
    viewLabel.Text = "VIEWING: NOBODY"
    viewLabel.TextColor3 = C.muted
    viewLabel.TextSize = 10
    viewLabel.TextXAlignment = Enum.TextXAlignment.Left
    viewLabel.TextTruncate = Enum.TextTruncate.AtEnd
    viewLabel.ZIndex = 20

    ESPX.setAvatarViewLabel = function(text)
        viewLabel.Text = "VIEWING: " .. string.upper(tostring(text))
    end

    ESPX.isOverAvatarControl = function(p)
        for _, object in ipairs({avatarZoomPanel, resetButton, modeButton}) do
            local pos, size = object.AbsolutePosition, object.AbsoluteSize
            if p.X >= pos.X and p.X <= pos.X + size.X and p.Y >= pos.Y and p.Y <= pos.Y + size.Y then
                return true
            end
        end
        return false
    end

    ESPX.resetAvatarView = function()
        avatarPreviewYaw = math.rad(180)
        avatarPreviewPitch = math.rad(-5)
        ESPX.avatarPan.x, ESPX.avatarPan.y = 0, 0
        if avatarPreviewModel then
            pcall(function()
                local _, size = avatarPreviewModel:GetBoundingBox()
                avatarPreviewDistance = math.clamp(math.max(5, size.Magnitude * 0.85), avatarZoomMin, avatarZoomMax)
            end)
        else
            avatarPreviewDistance = 7
        end
        updateAvatarZoomSlider()
        updateAvatarPreviewCamera()
    end

    resetButton.MouseButton1Click:Connect(function() ESPX.resetAvatarView() end)
    modeButton.MouseButton1Click:Connect(function()
        ESPX.avatarPan.moveMode = not ESPX.avatarPan.moveMode
        modeButton.Text = ESPX.avatarPan.moveMode and "MODE: MOVE" or "MODE: ROTATE"
    end)
end

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
    if ESPX.clearSavedAvatars then ESPX.clearSavedAvatars() end
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
        if ok and selectedSpectatePlayer == player and player.Parent == plrs then
            spectateAvatar.Image = imageUrl
        end
    end)
end

function ESPX.fetchOutfitPage(userId, cursor)
    local suffix = cursor and ("&paginationToken=" .. cursor) or ""
    local candidates = {
        string.format("https://avatar.roblox.com/v2/avatar/users/%d/outfits?itemsPerPage=50&isEditable=true%s", userId, suffix),
        string.format("https://avatar.roproxy.com/v2/avatar/users/%d/outfits?itemsPerPage=50&isEditable=true%s", userId, suffix),
    }
    local problems = {}
    for _, url in ipairs(candidates) do
        local okGet, body, status = pcall(ESPX.httpGet, url)
        if okGet and (status == 429 or string.find(string.lower(tostring(body)), "too many requests", 1, true)) then
            task.wait(2.5)
            okGet, body, status = pcall(ESPX.httpGet, url)
        end
        if okGet then
            local okJson, data = pcall(function() return HttpService:JSONDecode(body) end)
            if okJson and type(data) == "table" and type(data.data) == "table" then return data end
            problems[#problems + 1] = string.sub(tostring(body), 1, 120)
        else
            problems[#problems + 1] = tostring(body)
        end
    end
    error("the avatar service said: " .. table.concat(problems, "  |  "))
end

do
    createSection("[ SAVED AVATARS ]")
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Parent = scroll
    statusLabel.BackgroundTransparency = 1
    statusLabel.Size = UDim2.new(1, -20, 0, 32)
    statusLabel.AutomaticSize = Enum.AutomaticSize.Y
    statusLabel.Font = Enum.Font.Code
    statusLabel.Text = "Select a player, then press Load Saved Avatars."
    statusLabel.TextColor3 = C.muted
    statusLabel.TextSize = 11
    statusLabel.TextWrapped = true
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.ZIndex = 7

    createActionButton("Load Saved Avatars", function() return ESPX.loadSavedAvatars() end)
    createActionButton("Back to Current Avatar", function()
        showAvatarPreview(selectedSpectatePlayer)
    end)

    local gridHolder = Instance.new("ScrollingFrame")
    gridHolder.Name = "SavedAvatarGrid"
    gridHolder.Parent = scroll
    gridHolder.BackgroundColor3 = C.panel
    gridHolder.BorderSizePixel = 0
    gridHolder.Size = UDim2.new(1, -20, 0, 260)
    gridHolder.ScrollBarThickness = 4
    gridHolder.ScrollBarImageColor3 = C.accent
    gridHolder.CanvasSize = UDim2.new(0, 0, 0, 0)
    gridHolder.AutomaticCanvasSize = Enum.AutomaticSize.Y
    gridHolder.ScrollingDirection = Enum.ScrollingDirection.Y
    gridHolder.ZIndex = 7
    stroke(gridHolder, C.outline, 0.12, 1)
    local gridLayout = Instance.new("UIGridLayout")
    gridLayout.Parent = gridHolder
    gridLayout.CellSize = UDim2.new(0, 92, 0, 122)
    gridLayout.CellPadding = UDim2.new(0, 6, 0, 6)
    gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
    local gridPadding = Instance.new("UIPadding")
    gridPadding.Parent = gridHolder
    gridPadding.PaddingTop = UDim.new(0, 6)
    gridPadding.PaddingLeft = UDim.new(0, 6)
    gridPadding.PaddingBottom = UDim.new(0, 6)

    local loadToken = 0
    local outfitCache = {}

    local function showError(text)
        statusLabel.Text = text
        print("[BLACKWALL] " .. text)
        local copyFn = setclipboard or toclipboard
        if type(copyFn) == "function" then pcall(copyFn, text) end
    end

    local function clearGrid()
        for _, child in ipairs(gridHolder:GetChildren()) do
            if child:IsA("GuiButton") then child:Destroy() end
        end
    end

    ESPX.clearSavedAvatars = function()
        loadToken += 1
        clearGrid()
        statusLabel.Text = "Select a player, then press Load Saved Avatars."
    end

    local function addCell(outfit, order)
        local cell = Instance.new("TextButton")
        cell.Parent = gridHolder
        cell.LayoutOrder = order
        cell.BackgroundColor3 = C.bg
        cell.BorderSizePixel = 0
        cell.AutoButtonColor = false
        cell.Text = ""
        cell.ZIndex = 8
        local edge = stroke(cell, C.outline, 0.2, 1)
        local image = Instance.new("ImageLabel")
        image.Parent = cell
        image.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
        image.BorderSizePixel = 0
        image.Position = UDim2.new(0, 3, 0, 3)
        image.Size = UDim2.new(1, -6, 0, 86)
        image.ScaleType = Enum.ScaleType.Fit
        image.Image = string.format("rbxthumb://type=Outfit&id=%.0f&w=150&h=150", outfit.id)
        image.ZIndex = 9
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Parent = cell
        nameLabel.BackgroundTransparency = 1
        nameLabel.Position = UDim2.new(0, 3, 0, 91)
        nameLabel.Size = UDim2.new(1, -6, 0, 28)
        nameLabel.Font = Enum.Font.Code
        nameLabel.Text = outfit.name
        nameLabel.TextColor3 = C.text
        nameLabel.TextSize = 10
        nameLabel.TextWrapped = true
        nameLabel.TextYAlignment = Enum.TextYAlignment.Top
        nameLabel.ZIndex = 9
        cell.MouseEnter:Connect(function() edge.Color = C.accent end)
        cell.MouseLeave:Connect(function() edge.Color = C.outline end)
        cell.MouseButton1Click:Connect(function() ESPX.inspectOutfit(outfit) end)
    end

    ESPX.loadSavedAvatars = function()
        local player = selectedSpectatePlayer
        if not player or player.Parent ~= plrs then error("Select a player from the list first") end
        loadToken += 1
        local token = loadToken
        clearGrid()

        local cached = outfitCache[player.UserId]
        if cached and os.clock() - cached.time < 180 then
            statusLabel.Text = string.format("%d saved avatars (from the last load). Click one to inspect it in 3D.", #cached.outfits)
            for index, outfit in ipairs(cached.outfits) do addCell(outfit, index) end
            return "[CACHED]"
        end
        statusLabel.Text = "Loading the saved avatars of @" .. player.Name .. " ..."

        task.spawn(function()
            local outfits = {}
            local ok, err = pcall(function()
                local cursor = nil
                for _ = 1, 6 do
                    local data = ESPX.fetchOutfitPage(player.UserId, cursor)
                    for _, item in ipairs(data.data) do
                        if item.id then outfits[#outfits + 1] = {id = item.id, name = tostring(item.name or item.id)} end
                    end
                    cursor = data.nextPageCursor
                    if type(cursor) ~= "string" or cursor == "" then break end
                end
            end)
            if token ~= loadToken then return end
            if #outfits == 0 then
                if ok then
                    statusLabel.Text = "No saved avatars found (the player may keep them private)."
                else
                    showError("Could not load: " .. tostring(err))
                end
                return
            end
            outfitCache[player.UserId] = {time = os.clock(), outfits = outfits}
            statusLabel.Text = string.format("%d saved avatars. Click one to inspect it in the 3D preview.", #outfits)
            for index, outfit in ipairs(outfits) do addCell(outfit, index) end
        end)
        return "[LOADING]"
    end

    ESPX.inspectOutfit = function(outfit)
        local token = loadToken
        statusLabel.Text = "Loading " .. outfit.name .. " ..."
        task.spawn(function()
            local ok, model = pcall(function()
                local description = plrs:GetHumanoidDescriptionFromOutfitId(outfit.id)
                return plrs:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
            end)
            if token ~= loadToken then
                if ok and typeof(model) == "Instance" then model:Destroy() end
                return
            end
            if not ok or typeof(model) ~= "Instance" then
                showError("Could not load that avatar: " .. tostring(model))
                return
            end
            ESPX.showOutfitModel(model, outfit.name)
            statusLabel.Text = "Viewing: " .. outfit.name .. " (scroll up for the 3D preview)."
        end)
    end
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
    if not spectateTargetPlayer then
        task.defer(stopSpectating)
    end
end))

setTab("Photo")
createSection("[ FREECAM ]")
createToggle("Freecam", "Freecam")
createSlider("Freecam Speed", 1, 300, cfg.freecamSpeed, function(v) cfg.freecamSpeed = v end, "freecamSpeed")
createSlider("Freecam Smoothing", 0, 0.95, cfg.freecamSmooth, function(v) cfg.freecamSmooth = v end, "freecamSmooth", 0.05)
createSlider("Freecam Roll", -180, 180, cfg.freecamRoll, function(v) cfg.freecamRoll = v end, "freecamRoll")
createToggle("Freecam Track Player", "FreecamTrack")
createActionButton("Teleport to Freecam Position", function()
    local target = ESPX.getFreecamPos and ESPX.getFreecamPos()
    if not target then error("Turn Freecam on first") end
    local character = lplr.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then error("Your character is unavailable") end
    root.CFrame = CFrame.new(target) * (root.CFrame - root.CFrame.Position)
    root.AssemblyLinearVelocity = Vector3.zero
end)
createSection("[ CAMERA SLOTS ]")
createSlider("Camera Slot", 1, 5, cfg.camSlot, function(v) cfg.camSlot = v end, "camSlot", 1)
createActionButton("Save Camera Slot", function() return ESPX.saveCameraSlot(math.floor(cfg.camSlot + 0.5)) end)
createActionButton("Go To Camera Slot", function() return ESPX.loadCameraSlot(math.floor(cfg.camSlot + 0.5)) end)
createSection("[ CAMERA ]")
createToggle("Custom FOV", "CustomFOV")
createSlider("Camera FOV", 30, 120, cfg.camFov, function(v) cfg.camFov = v end, "camFov")
createSection("[ INTERFACE ]")
createToggle("Remove UI", "RemoveUI")
createActionButton("Restore UI", function()
    toggles.RemoveUI = false
    if ESPX.togglePaints.RemoveUI then ESPX.togglePaints.RemoveUI() end
    if ESPX.restoreUI then ESPX.restoreUI() end
    saveSettings()
end)
createToggle("Clean Shot", "CleanShot")
createToggle("Hide Cursor", "HideCursor")
createToggle("Cinematic Bars", "CinemaBars")
createSlider("Bar Size", 0, 0.35, cfg.barSize, function(v) cfg.barSize = v end, "barSize")
createToggle("Composition Grid", "PhotoGrid")
createSection("[ SCENE ]")
createToggle("Freeze Pose", "FreezePose")
createToggle("Hide Nametags", "HideNametags")
createToggle("Hide Other Players", "HideOthers")
createToggle("Hide NPCs", "HideNPCs")
createSection("[ BLUR & DEPTH OF FIELD ]")
createToggle("Remove Near Blur", "RemoveNearBlur")
createToggle("Custom DoF", "CustomDoF")
createToggle("DoF Auto Focus", "DoFAutoFocus")
createSlider("DoF Far Intensity", 0, 1, cfg.dofFar, function(v) cfg.dofFar = v end, "dofFar")
createSlider("DoF Near Intensity", 0, 1, cfg.dofNear, function(v) cfg.dofNear = v end, "dofNear")
createSlider("DoF Focus Distance", 0, 100, cfg.dofFocusDistance, function(v) cfg.dofFocusDistance = v end, "dofFocusDistance", 0.5)
createSlider("DoF Focus Radius", 0, 50, cfg.dofFocusRadius, function(v) cfg.dofFocusRadius = v end, "dofFocusRadius", 0.5)
createSlider("DoF Layers", 1, 3, cfg.dofLayers, function(v) cfg.dofLayers = v end, "dofLayers", 1)

setTab("Shader")
createSection("[ RESHADE ]")
createToggle("Reshade", "Reshade")
createToggle("Disable Game Effects", "RsClean")
createSection("[ PRESETS ]")
createActionButton("Cinematic", function() ESPX.applyShaderPreset("Cinematic") end)
createActionButton("Warm Sunset", function() ESPX.applyShaderPreset("Warm Sunset") end)
createActionButton("Cold Night", function() ESPX.applyShaderPreset("Cold Night") end)
createActionButton("Noir", function() ESPX.applyShaderPreset("Noir") end)
createActionButton("Vibrant", function() ESPX.applyShaderPreset("Vibrant") end)
createActionButton("Reset Look", function() ESPX.applyShaderPreset("Neutral") end)
createSection("[ COLOR ]")
createSlider("Brightness", -0.5, 0.5, cfg.rsBrightness, function(v) cfg.rsBrightness = v end, "rsBrightness")
createSlider("Contrast", -1, 1, cfg.rsContrast, function(v) cfg.rsContrast = v end, "rsContrast")
createSlider("Saturation", -1, 1, cfg.rsSaturation, function(v) cfg.rsSaturation = v end, "rsSaturation")
createSlider("Tint Hue", 0, 360, cfg.rsTintHue, function(v) cfg.rsTintHue = v end, "rsTintHue")
createSlider("Tint Strength", 0, 1, cfg.rsTintStrength, function(v) cfg.rsTintStrength = v end, "rsTintStrength")
createSection("[ BLOOM & SUN RAYS ]")
createSlider("Bloom Intensity", 0, 3, cfg.rsBloomIntensity, function(v) cfg.rsBloomIntensity = v end, "rsBloomIntensity")
createSlider("Bloom Size", 0, 56, cfg.rsBloomSize, function(v) cfg.rsBloomSize = v end, "rsBloomSize")
createSlider("Bloom Threshold", 0, 4, cfg.rsBloomThreshold, function(v) cfg.rsBloomThreshold = v end, "rsBloomThreshold")
createSlider("Sun Ray Intensity", 0, 1, cfg.rsSunIntensity, function(v) cfg.rsSunIntensity = v end, "rsSunIntensity")
createSlider("Sun Ray Spread", 0, 1, cfg.rsSunSpread, function(v) cfg.rsSunSpread = v end, "rsSunSpread")
createSection("[ LIGHTING ]")
createSlider("Exposure", -3, 3, cfg.rsExposure, function(v) cfg.rsExposure = v end, "rsExposure")
createSlider("Light Brightness (+/-)", -3, 3, cfg.rsLightBrightness, function(v) cfg.rsLightBrightness = v end, "rsLightBrightness")
createSlider("Skylight", 0, 2, cfg.rsSkylight, function(v) cfg.rsSkylight = v end, "rsSkylight")
createSlider("Reflections", 0, 2, cfg.rsReflection, function(v) cfg.rsReflection = v end, "rsReflection")
createToggle("Override Time of Day", "RsTime")
createSlider("Clock Time", 0, 24, cfg.rsClockTime, function(v) cfg.rsClockTime = v end, "rsClockTime", 0.1)
createSection("[ SHADOWS ]")
createToggle("Disable Shadows", "RsNoShadows")
createSlider("Shadow Lift (+/-)", -0.5, 0.5, cfg.rsShadowLift, function(v) cfg.rsShadowLift = v end, "rsShadowLift")
createSlider("Shadow Softness (+/-)", -1, 1, cfg.rsShadowSoftness, function(v) cfg.rsShadowSoftness = v end, "rsShadowSoftness")
createSection("[ SCREEN ]")
createToggle("Vignette", "RsVignette")
createSlider("Vignette Strength", 0, 1, cfg.rsVignette, function(v) cfg.rsVignette = v end, "rsVignette")

setTab("Fun")
createSection("[ FUN ]")
createToggle("Ragdoll", "Ragdoll")
createToggle("Sit", "Sit")

setTab("Settings")
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

createSection("[ MENU ]")
createSlider("Menu Scale", 0.6, 1.8, cfg.menuScale, function(v)
    cfg.menuScale = v
    if ESPX.applyMenuSize then ESPX.applyMenuSize() end
end, "menuScale", 0.05)
createActionButton("Reset Menu Size", function()
    cfg.menuWidth = ESPX.defaultCfg.menuWidth
    cfg.menuHeight = ESPX.defaultCfg.menuHeight
    for _, slider in ipairs(ESPX.sliders) do
        if slider.key == "menuScale" then slider.set(ESPX.defaultCfg.menuScale) end
    end
    if ESPX.applyMenuSize then ESPX.applyMenuSize() end
    saveSettings()
end)
createSection("[ PERFORMANCE ]")
createToggle("Low Visuals", "LowVisuals")
createToggle("Instance Optimizer", "InstanceOptimizer")
createToggle("Particle Cap", "ParticleCap")
createToggle("Ultra Potato", "UltraPotato")

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
    if ESPX.applyMenuSize then ESPX.applyMenuSize() end
    saveSettings()
end

createSection("[ CONFIG ]")
createActionButton("Reset to Defaults", function()
    if os.clock() - (ESPX.resetArmedAt or -10) > 3 then
        ESPX.resetArmedAt = os.clock()
        return "[CLICK AGAIN]"
    end
    ESPX.resetArmedAt = nil
    ESPX.resetToDefaults()
    return "[RESET]"
end)

function ESPX.httpGet(url)
    local requestFn = (type(request) == "function" and request)
        or (type(http_request) == "function" and http_request)
        or (type(syn) == "table" and type(syn.request) == "function" and syn.request)
    if requestFn then
        local response = requestFn({Url = url, Method = "GET"})
        if response and response.Body then return response.Body, response.StatusCode end
    end
    local ok, body = pcall(function() return game:HttpGet(url) end)
    if ok and type(body) == "string" then return body end
    error("No HTTP request function available in this executor")
end

function ESPX.rejoin()
    local teleportService = game:GetService("TeleportService")
    if #plrs:GetPlayers() <= 1 then
        teleportService:Teleport(game.PlaceId, lplr)
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

function ESPX.dumpKillerInfo()
    local lines = {}
    local MAX_LINES = 900
    local function add(text)
        if #lines < MAX_LINES then
            lines[#lines + 1] = text
        elseif #lines == MAX_LINES then
            lines[#lines + 1] = "... (output truncated)"
        end
    end

    local NOISE = {
        "ParticleEmitter", "Attachment", "Motor6D", "Weld", "WeldConstraint", "SurfaceAppearance", "Decal",
        "Texture", "Trail", "Beam", "SpecialMesh", "PointLight", "SpotLight", "SurfaceLight", "Highlight",
        "Sound", "Animation", "UICorner", "UIStroke", "UIListLayout", "Accessory", "Clothing", "BodyColors",
    }
    local function isNoise(inst)
        for _, className in ipairs(NOISE) do
            if inst:IsA(className) then return true end
        end
        return false
    end
    local function describe(inst, depth)
        local line = string.rep("  ", depth) .. inst.Name .. " [" .. inst.ClassName .. "]"
        if inst:IsA("ValueBase") then
            pcall(function() line = line .. " = " .. tostring(inst.Value) end)
        end
        for attrName, attrValue in pairs(inst:GetAttributes()) do
            line = line .. "  @" .. attrName .. "=" .. tostring(attrValue)
        end
        add(line)
    end
    local function walk(root, depth, maxDepth)
        describe(root, depth)
        local children = root:GetChildren()
        if depth >= maxDepth then
            if #children > 0 then add(string.rep("  ", depth + 1) .. "... (" .. #children .. " children not shown)") end
            return
        end
        local hidden = 0
        for _, child in ipairs(children) do
            if isNoise(child) then
                hidden += 1
            else
                walk(child, depth + 1, maxDepth)
            end
        end
        if hidden > 0 then add(string.rep("  ", depth + 1) .. "(" .. hidden .. " visual/helper instances hidden)") end
    end

    local character = lplr.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local backpack = lplr:FindFirstChildOfClass("Backpack")

    add("PlaceId: " .. tostring(game.PlaceId) .. "   World gravity: " .. tostring(ws.Gravity))
    add("")
    add("== ATTRIBUTES (player / character / humanoid) ==")
    for label, inst in pairs({player = lplr, character = character, humanoid = humanoid}) do
        if inst then
            for attrName, attrValue in pairs(inst:GetAttributes()) do
                add(label .. " @" .. attrName .. " = " .. tostring(attrValue))
            end
        end
    end
    add("Team: " .. (lplr.Team and lplr.Team.Name or "none"))

    add("")
    add("== CHARACTER (structure) ==")
    if character then walk(character, 0, 3) else add("(no character)") end

    add("")
    add("== TOOLS ==")
    local tools = {}
    for _, container in ipairs({character, backpack}) do
        if container then
            for _, child in ipairs(container:GetChildren()) do
                if child:IsA("Tool") then tools[#tools + 1] = child end
            end
        end
    end
    if #tools == 0 then add("(no tools)") end
    for _, tool in ipairs(tools) do walk(tool, 0, 5) end

    add("")
    add("== ABILITY-LOOKING INSTANCES (path only) ==")
    local KEYWORDS = {"veil", "spear", "lance", "projectile", "ability", "skill", "killer", "throw", "weapon", "damage", "hitbox"}
    local function looksLikeAbility(name)
        local lowered = string.lower(name)
        for _, keyword in ipairs(KEYWORDS) do
            if string.find(lowered, keyword, 1, true) then return true end
        end
        return false
    end
    local CONFIG_WORDS = {"setting", "config", "stat", "data", "info"}
    local function looksLikeConfig(name)
        local lowered = string.lower(name)
        for _, word in ipairs(CONFIG_WORDS) do
            if string.find(lowered, word, 1, true) then return true end
        end
        return false
    end

    local replicated = game:GetService("ReplicatedStorage")
    local containers = {character, backpack, lplr:FindFirstChildOfClass("PlayerGui"), replicated}
    local readable = {}
    local matches = 0
    for _, container in ipairs(containers) do
        if container then
            for _, item in ipairs(container:GetDescendants()) do
                if looksLikeAbility(item.Name) and (
                    item:IsA("LuaSourceContainer") or item:IsA("RemoteEvent") or item:IsA("RemoteFunction")
                    or item:IsA("BindableEvent") or item:IsA("Configuration") or item:IsA("Folder") or item:IsA("Model")
                ) then
                    matches += 1
                    if matches <= 150 then add(item.ClassName .. "  " .. item:GetFullName()) end
                end
                if item:IsA("ModuleScript") and #readable < 8 then
                    local ownTool = (container == character or container == backpack) and (looksLikeAbility(item.Name) or looksLikeConfig(item.Name))
                    local configLike = container == replicated and looksLikeConfig(item.Name) and looksLikeAbility(item:GetFullName())
                    if ownTool or configLike then readable[#readable + 1] = item end
                end
            end
        end
    end
    if matches > 150 then add("... (" .. (matches - 150) .. " more not shown)") end
    if matches == 0 then add("(nothing matched)") end

    local function format(value)
        local kind = typeof(value)
        if kind == "function" then return "<function>" end
        return tostring(value) .. "  (" .. kind .. ")"
    end
    local function dumpTable(tbl, depth, seen, budget)
        local keys = {}
        for key in pairs(tbl) do keys[#keys + 1] = key end
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
        for _, key in ipairs(keys) do
            if budget.left <= 0 then return end
            budget.left -= 1
            local value = tbl[key]
            local indent = string.rep("  ", depth)
            if type(value) == "table" then
                if seen[value] or depth >= 2 then
                    add(indent .. tostring(key) .. " = <table>")
                else
                    seen[value] = true
                    add(indent .. tostring(key) .. " = {")
                    dumpTable(value, depth + 1, seen, budget)
                    add(indent .. "}")
                end
            else
                add(indent .. tostring(key) .. " = " .. format(value))
            end
        end
    end
    for _, moduleScript in ipairs(readable) do
        add("")
        add("== VALUES OF " .. moduleScript:GetFullName() .. " ==")
        local ok, result = pcall(require, moduleScript)
        if not ok then
            add("(could not read it: " .. tostring(result) .. ")")
        elseif type(result) == "table" then
            dumpTable(result, 0, {[result] = true}, {left = 80})
        else
            add(format(result))
        end
    end

    local text = table.concat(lines, "\n")
    print(text)
    local copyFn = setclipboard or toclipboard
    if type(copyFn) == "function" then pcall(copyFn, text) end
    return "[" .. #lines .. " LINES]"
end

function ESPX.dumpVeilSpear()
    local lines = {}
    local MAX_LINES = 600
    local function add(text)
        if #lines < MAX_LINES then
            lines[#lines + 1] = text
        elseif #lines == MAX_LINES then
            lines[#lines + 1] = "... (output truncated)"
        end
    end
    local function format(value)
        local kind = typeof(value)
        if kind == "function" then
            local details = ""
            pcall(function()
                local params, vararg = debug.info(value, "a")
                details = " params=" .. tostring(params) .. (vararg and "+vararg" or "")
            end)
            return "<function" .. details .. ">"
        end
        return tostring(value) .. "  (" .. kind .. ")"
    end
    local function dumpTable(tbl, depth, seen, budget)
        local keys = {}
        for key in pairs(tbl) do keys[#keys + 1] = key end
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
        for _, key in ipairs(keys) do
            if budget.left <= 0 then
                add(string.rep("  ", depth) .. "... (more not shown)")
                return
            end
            budget.left -= 1
            local value = tbl[key]
            local indent = string.rep("  ", depth)
            if type(value) == "table" then
                if seen[value] or depth >= 3 then
                    add(indent .. tostring(key) .. " = <table>")
                else
                    seen[value] = true
                    add(indent .. tostring(key) .. " = {")
                    dumpTable(value, depth + 1, seen, budget)
                    add(indent .. "}")
                end
            else
                add(indent .. tostring(key) .. " = " .. format(value))
            end
        end
    end

    local replicated = game:GetService("ReplicatedStorage")
    local function find(path)
        local node = replicated
        for part in string.gmatch(path, "[^%.]+") do
            node = node and node:FindFirstChild(part)
        end
        return node
    end

    add("World gravity: " .. tostring(ws.Gravity))
    local veilFolder = find("Modules.Killers.Veil")
    add("")
    add("== ReplicatedStorage.Modules.Killers.Veil contains ==")
    if veilFolder then
        for _, child in ipairs(veilFolder:GetChildren()) do add(child.ClassName .. "  " .. child.Name) end
    else
        add("(folder not found)")
    end

    for _, path in ipairs({
        "Modules.Killers.Veil.SpearMath",
        "Modules.Killers.Veil.SpearWorld",
        "Modules.Killers.Veil.SpearDebugClient",
        "Modules.World.ProjectileVisualsClient",
    }) do
        add("")
        add("== VALUES OF ReplicatedStorage." .. path .. " ==")
        local moduleScript = find(path)
        if not (moduleScript and moduleScript:IsA("ModuleScript")) then
            add("(not found)")
        else
            local ok, result = pcall(require, moduleScript)
            if not ok then
                add("(could not read it: " .. tostring(result) .. ")")
            elseif type(result) == "table" then
                dumpTable(result, 0, {[result] = true}, {left = 120})
            else
                add(format(result))
            end
        end
    end

    add("")
    add("== YOUR SPEAR MODEL (positions relative to your HumanoidRootPart) ==")
    local character = lplr.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local spear = character and character:FindFirstChild("Spear")
    if not (root and spear) then
        add("(no Spear model on your character - play as Veil)")
    else
        for _, item in ipairs(spear:GetDescendants()) do
            if item:IsA("BasePart") then
                local offset = root.CFrame:ToObjectSpace(item.CFrame).Position
                local line = string.format("%s [%s] offset=%s size=%s anchored=%s", item.Name, item.ClassName,
                    tostring(offset), tostring(item.Size), tostring(item.Anchored))
                for attrName, attrValue in pairs(item:GetAttributes()) do
                    line = line .. "  @" .. attrName .. "=" .. tostring(attrValue)
                end
                add(line)
            end
        end
        for attrName, attrValue in pairs(spear:GetAttributes()) do
            add("Spear @" .. attrName .. " = " .. tostring(attrValue))
        end
    end

    local text = table.concat(lines, "\n")
    print(text)
    local copyFn = setclipboard or toclipboard
    if type(copyFn) == "function" then pcall(copyFn, text) end
    return "[" .. #lines .. " LINES]"
end

function ESPX.recordProjectiles()
    if ESPX.recordingProjectiles then error("Already recording") end
    ESPX.recordingProjectiles = true
    local DURATION = 10
    local tracked, order = {}, {}

    local added = ws.DescendantAdded:Connect(function(item)
        if #order >= 80 or not item:IsA("BasePart") then return end
        local model = item:FindFirstAncestorOfClass("Model")
        if model and plrs:GetPlayerFromCharacter(model) then return end
        tracked[item] = {birth = os.clock(), samples = {}, velocity = item.AssemblyLinearVelocity}
        order[#order + 1] = item
    end)
    local beat = rs.Heartbeat:Connect(function()
        local now = os.clock()
        for _, part in ipairs(order) do
            local info = tracked[part]
            if info and part.Parent and now - info.birth < 2 and #info.samples < 150 then
                info.samples[#info.samples + 1] = {now, part.Position}
            end
        end
    end)

    task.spawn(function()
        task.wait(DURATION)
        added:Disconnect()
        beat:Disconnect()
        ESPX.recordingProjectiles = false

        local function median(list)
            if #list == 0 then return nil end
            table.sort(list)
            return list[math.ceil(#list / 2)]
        end

        local reports = {}
        for _, part in ipairs(order) do
            local info = tracked[part]
            local samples = info.samples
            if #samples >= 5 then
                local first, last = samples[1], samples[#samples]
                local distance = (last[2] - first[2]).Magnitude
                local duration = last[1] - first[1]
                if distance >= 8 and duration > 0 then
                    local early = math.min(#samples, 6)
                    local initialSpeed = (samples[early][2] - first[2]).Magnitude / math.max(samples[early][1] - first[1], 1e-3)
                    local accelerations = {}
                    local gap = 3
                    for index = 1, #samples - 2 * gap do
                        local a, b, c = samples[index], samples[index + gap], samples[index + 2 * gap]
                        local v1 = (b[2].Y - a[2].Y) / math.max(b[1] - a[1], 1e-3)
                        local v2 = (c[2].Y - b[2].Y) / math.max(c[1] - b[1], 1e-3)
                        accelerations[#accelerations + 1] = (v2 - v1) / math.max((c[1] - a[1]) / 2, 1e-3)
                    end
                    reports[#reports + 1] = {
                        part = part, distance = distance, duration = duration,
                        speed = distance / duration, initialSpeed = initialSpeed,
                        accel = median(accelerations), info = info,
                    }
                end
            end
        end
        table.sort(reports, function(a, b) return a.distance > b.distance end)

        local lines = {"World gravity: " .. tostring(ws.Gravity), "New parts seen: " .. #order, ""}
        if #reports == 0 then
            lines[#lines + 1] = "No new part travelled 8+ studs. The projectile may be created before this was pressed,"
            lines[#lines + 1] = "or it may be moved by a script that does not create a new part."
        end
        for index = 1, math.min(#reports, 6) do
            local report = reports[index]
            local part = report.part
            lines[#lines + 1] = "-- #" .. index .. "  " .. part.Name .. " [" .. part.ClassName .. "]"
            lines[#lines + 1] = "path: " .. part:GetFullName()
            lines[#lines + 1] = string.format("size: %s   anchored: %s", tostring(part.Size), tostring(part.Anchored))
            lines[#lines + 1] = string.format("travelled %.1f studs in %.2f s", report.distance, report.duration)
            lines[#lines + 1] = string.format("average speed %.1f studs/s, speed over the first frames %.1f studs/s",
                report.speed, report.initialSpeed)
            lines[#lines + 1] = "velocity right after it appeared: " .. tostring(report.info.velocity)
            if report.accel then
                lines[#lines + 1] = string.format("vertical acceleration about %.1f studs/s^2 (%.2f x world gravity)",
                    report.accel, -report.accel / math.max(ws.Gravity, 1))
            end
            for attrName, attrValue in pairs(part:GetAttributes()) do
                lines[#lines + 1] = "@" .. attrName .. " = " .. tostring(attrValue)
            end
            if part.Parent and part.Parent:IsA("Model") then
                for attrName, attrValue in pairs(part.Parent:GetAttributes()) do
                    lines[#lines + 1] = "model @" .. attrName .. " = " .. tostring(attrValue)
                end
            end
            lines[#lines + 1] = string.format(
                "suggested sliders: Projectile Speed ~ %.0f, Projectile Gravity ~ %.2f",
                report.initialSpeed, math.max(0, report.accel and (-report.accel / math.max(ws.Gravity, 1)) or 0)
            )
            lines[#lines + 1] = ""
        end
        local text = table.concat(lines, "\n")
        print(text)
        local copyFn = setclipboard or toclipboard
        if type(copyFn) == "function" then pcall(copyFn, text) end
    end)
    return "[RECORDING " .. DURATION .. "s - THROW NOW]"
end

createSection("[ SERVER ]")
createActionButton("Rejoin Server", function() ESPX.rejoin() end)
createActionButton("Server Hop", function() ESPX.serverHop() end)

createSection("[ DEBUG ]")
createActionButton("Dump Killer Info", function() return ESPX.dumpKillerInfo() end)
createActionButton("Dump Veil Spear", function() return ESPX.dumpVeilSpear() end)
createActionButton("Record Projectile (10s)", function() return ESPX.recordProjectiles() end)

do
    local bindsFile = "HRSH_MenuBinds.json"
    local keyButtons = {}
    ESPX.binds = {}
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

local validTargets = {}

ESPX.track(pps.PromptShown:Connect(function(prompt)
    if toggles.InstantInteract then
        prompt.HoldDuration = 0
    end
end))

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

local function getPlayerESPAnchor(char)
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

ESPX.track(lplr.CharacterAdded:Connect(function()
    if toggles.SelfHP then
        task.wait(0.25)
        setupSelfHP()
    end
end))

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

    if plrs:GetPlayerFromCharacter(obj) then
        return false
    end

    if obj:FindFirstChild("Put Item In ServerStore", true) then
        return true
    end

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
    for obj, gui in pairs(itemESPObjects) do
        if gui then
            gui:Destroy()
        end

        itemESPObjects[obj] = nil
    end

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

    for _, obj in ipairs(ws:GetChildren()) do
        if isPickupCandidate(obj) then
            seen[obj] = true
            addItemESP(obj)
        end
    end

    for obj in pairs(itemESPObjects) do
        if not seen[obj] or not obj:IsDescendantOf(ws) then
            removeItemESP(obj)
        end
    end
end

local noclipOriginal = {}
local lastNoclip = false

local function setNoclip(enabled)
    local char = lplr.Character

    if not char then
        return
    end

    if enabled then
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

ESPX.track(rs.Stepped:Connect(function()
    if toggles.Noclip then
        setNoclip(true)
    end
end))

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
        if toggles.Freecam then direction = Vector3.zero end
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

task.spawn(function()
    local wasOn = true
    while not terminated do
        if toggles.ItemESP then
            wasOn = true
            updateItemESP()
        elseif wasOn then
            wasOn = false
            clearItemESP()
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
local GATHER_SCAN_INTERVAL = 1.0
local GATHER_MOVE_INTERVAL = 0.04

task.spawn(function()
    local scanElapsed = GATHER_SCAN_INTERVAL
    local moveElapsed = 0
    while not terminated do
        local dt = task.wait(toggles.GatherNPCs and 0.015 or 0.25)
        if not toggles.GatherNPCs then
            table.clear(gatherCache)
            scanElapsed = GATHER_SCAN_INTERVAL
            moveElapsed = 0
        else
            scanElapsed += dt
            moveElapsed += dt
            local character = lplr.Character
            local myRoot = character and (character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart)
            if myRoot then
                if scanElapsed >= GATHER_SCAN_INTERVAL then
                    scanElapsed = 0
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

task.spawn(function()
    while not terminated do
        refreshTargets()
        task.wait(cfg.scanRate)
    end
end)

ESPX.track(rs.RenderStepped:Connect(function(dt)
    if terminated then return end
    local center = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)

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
        crossDot.Color = Color3.fromRGB(255, 0, 0)
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

ESPX.track(lighting.Changed:Connect(function()
    if not toggles.Fullbright then return end
    lighting.Brightness = 2
    lighting.ClockTime = 14
    lighting.FogEnd = 100000
    lighting.GlobalShadows = false
    lighting.Ambient = Color3.fromRGB(178, 178, 178)
    lighting.OutdoorAmbient = Color3.fromRGB(178, 178, 178)
end))

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

do
    local fogOriginal = nil
    local fogTimer = 1
    local fovOriginal = nil

    local function applyNoFog()
        if not fogOriginal then
            fogOriginal = {fogEnd = lighting.FogEnd, fogStart = lighting.FogStart, atmos = {}}
        end
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

    ESPX.restoreWorld = function()
        restoreFog()
        restoreFov()
    end
end

do
    local cas = game:GetService("ContextActionService")
    local SINK_ACTION = "HRSH_FreecamSink"
    local fc = {active = false, looking = false, yaw = 0, pitch = 0, pos = Vector3.zero, smoothed = nil, pending = nil}
    local slots = {}

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
        fc.smoothed = nil
        fc.active = true
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
        fc.smoothed = nil
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
            if spectateTargetPlayer then return end
            if not fc.active then startFreecam() end
            camera.CameraType = Enum.CameraType.Scriptable

            if fc.pending then
                local slot = fc.pending
                fc.pending = nil
                fc.pos, fc.yaw, fc.pitch = slot.pos, slot.yaw, slot.pitch
                fc.smoothed = nil
            end

            if toggles.FreecamTrack then
                local subject = selectedSpectatePlayer
                local subjectCharacter = (subject and subject.Parent == plrs and subject.Character) or lplr.Character
                local subjectPart = subjectCharacter
                    and (subjectCharacter:FindFirstChild("Head") or subjectCharacter:FindFirstChild("HumanoidRootPart"))
                if subjectPart then
                    local direction = subjectPart.Position - fc.pos
                    if direction.Magnitude > 0.5 then
                        direction = direction.Unit
                        fc.yaw = math.atan2(-direction.X, -direction.Z)
                        fc.pitch = math.clamp(math.asin(math.clamp(direction.Y, -1, 1)), math.rad(-89), math.rad(89))
                    end
                end
            end

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
            local target = CFrame.new(fc.pos) * rotation * CFrame.Angles(0, 0, math.rad(cfg.freecamRoll))
            local smooth = math.clamp(cfg.freecamSmooth, 0, 0.95)
            if fc.smoothed and smooth > 0 then
                target = fc.smoothed:Lerp(target, 1 - smooth ^ (dt * 60))
            end
            fc.smoothed = target
            camera.CFrame = target
        elseif fc.active then
            stopFreecam()
        end
    end))

    ESPX.stopFreecam = stopFreecam
    ESPX.getFreecamPos = function()
        if fc.active then return fc.pos end
        return nil
    end

    ESPX.saveCameraSlot = function(index)
        local camera = ws.CurrentCamera
        local position, yaw, pitch
        if fc.active then
            position, yaw, pitch = fc.pos, fc.yaw, fc.pitch
        elseif camera then
            local look = camera.CFrame.LookVector
            position = camera.CFrame.Position
            yaw = math.atan2(-look.X, -look.Z)
            pitch = math.asin(math.clamp(look.Y, -1, 1))
        else
            error("No camera available")
        end
        slots[index] = {pos = position, yaw = yaw, pitch = pitch}
        return "[SAVED SLOT " .. index .. "]"
    end

    ESPX.loadCameraSlot = function(index)
        local slot = slots[index]
        if not slot then error("Slot " .. index .. " is empty") end
        fc.pending = slot
        if not toggles.Freecam then
            toggles.Freecam = true
            if ESPX.togglePaints.Freecam then ESPX.togglePaints.Freecam() end
        end
        return "[SLOT " .. index .. "]"
    end
end

do
    local viewLines = {}

    local function removeViewLine(plr)
        local line = viewLines[plr]
        if line then
            pcall(function() line:Remove() end)
            viewLines[plr] = nil
        end
    end

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

do
    local PART_TOGGLE = {Head = "HitboxHead"}
    for _, name in ipairs({"HumanoidRootPart", "UpperTorso", "LowerTorso", "Torso"}) do
        PART_TOGGLE[name] = "HitboxBody"
    end
    for _, name in ipairs({
        "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot",
        "Left Leg", "Right Leg",
    }) do
        PART_TOGGLE[name] = "HitboxLegs"
    end

    local originals = {}
    local boxes = {}

    local function removeBox(part)
        local box = boxes[part]
        if box then
            box:Destroy()
            boxes[part] = nil
        end
    end

    local function updateBox(part, plr, size)
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
        box.Transparency = math.min(math.clamp(cfg.hitboxTransparency, 0, 1), 0.6)
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

                                if toggles.PlayerESP then
                                    pcall(updateBox, part, plr, size)
                                else
                                    removeBox(part)
                                end
                            end
                        end
                    end
                end
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

do
    local starterGui = game:GetService("StarterGui")
    local CORE_NAMES = {"Backpack", "Chat", "EmotesMenu", "Health", "PlayerList", "SelfView"}

    local hidden = false
    local guiOriginal = {}
    local coreOriginal = {}
    local topbarCoreOriginal = nil
    local topBarAppOriginal = nil

    local function applyHide()
        local playerGui = lplr:FindFirstChildOfClass("PlayerGui")
        if playerGui then
            for _, screenGui in ipairs(playerGui:GetChildren()) do
                if screenGui:IsA("ScreenGui") then
                    if guiOriginal[screenGui] == nil then guiOriginal[screenGui] = screenGui.Enabled end
                    if screenGui.Enabled then screenGui.Enabled = false end
                end
            end
        end

        if not hidden then
            hidden = true
            for _, name in ipairs(CORE_NAMES) do
                local okType, coreType = pcall(function() return Enum.CoreGuiType[name] end)
                if okType and coreType then
                    local okGet, enabled = pcall(starterGui.GetCoreGuiEnabled, starterGui, coreType)
                    if okGet then coreOriginal[name] = enabled end
                end
            end
            local okTop, topEnabled = pcall(starterGui.GetCore, starterGui, "TopbarEnabled")
            if okTop then topbarCoreOriginal = topEnabled end
            local topBarApp = cg:FindFirstChild("TopBarApp")
            if topBarApp and topBarApp:IsA("ScreenGui") then topBarAppOriginal = topBarApp.Enabled end
        end

        for name in pairs(coreOriginal) do
            pcall(function() starterGui:SetCoreGuiEnabled(Enum.CoreGuiType[name], false) end)
        end
        pcall(function() starterGui:SetCore("TopbarEnabled", false) end)
        local topBarApp = cg:FindFirstChild("TopBarApp")
        if topBarApp and topBarApp:IsA("ScreenGui") and topBarApp.Enabled then topBarApp.Enabled = false end
    end

    local function restoreUI()
        if not hidden and next(guiOriginal) == nil then return end
        for screenGui, enabled in pairs(guiOriginal) do
            if screenGui.Parent then screenGui.Enabled = enabled end
            guiOriginal[screenGui] = nil
        end
        for name, enabled in pairs(coreOriginal) do
            pcall(function() starterGui:SetCoreGuiEnabled(Enum.CoreGuiType[name], enabled) end)
            coreOriginal[name] = nil
        end
        if topbarCoreOriginal ~= nil then
            pcall(function() starterGui:SetCore("TopbarEnabled", topbarCoreOriginal) end)
        end
        local topBarApp = cg:FindFirstChild("TopBarApp")
        if topBarApp and topBarApp:IsA("ScreenGui") and topBarAppOriginal ~= nil then
            topBarApp.Enabled = topBarAppOriginal
        end
        topbarCoreOriginal = nil
        topBarAppOriginal = nil
        hidden = false
    end

    local nearOriginal = {}

    local function applyNearBlurRemoval()
        local function scan(container)
            for _, effect in ipairs(container:GetChildren()) do
                if effect:IsA("DepthOfFieldEffect") and string.find(effect.Name, "HRSH_DepthOfField", 1, true) ~= 1 then
                    if nearOriginal[effect] == nil then nearOriginal[effect] = effect.NearIntensity end
                    if effect.NearIntensity ~= 0 then effect.NearIntensity = 0 end
                end
            end
        end
        scan(lighting)
        local camera = ws.CurrentCamera
        if camera then scan(camera) end
    end

    local function restoreNearBlur()
        for effect, original in pairs(nearOriginal) do
            if effect.Parent then effect.NearIntensity = original end
            nearOriginal[effect] = nil
        end
    end

    local dofEffects = {}
    local focusSmoothed = nil

    local function getDofEffect(index)
        local effect = dofEffects[index]
        if not effect or not effect.Parent then
            effect = Instance.new("DepthOfFieldEffect")
            effect.Name = (index == 1) and "HRSH_DepthOfField" or ("HRSH_DepthOfField" .. index)
            effect.Parent = lighting
            dofEffects[index] = effect
        end
        return effect
    end

    local function updateDof()
        local layers = math.clamp(math.floor(cfg.dofLayers + 0.5), 1, 3)
        for index = 1, 3 do
            if toggles.CustomDoF and index <= layers then
                local effect = getDofEffect(index)
                effect.Enabled = true
                effect.FarIntensity = cfg.dofFar
                effect.NearIntensity = cfg.dofNear
                effect.InFocusRadius = cfg.dofFocusRadius
                if not toggles.DoFAutoFocus then effect.FocusDistance = cfg.dofFocusDistance end
            elseif dofEffects[index] then
                dofEffects[index].Enabled = false
            end
        end
    end

    ESPX.track(rs.RenderStepped:Connect(function(dt)
        if terminated or not (toggles.CustomDoF and toggles.DoFAutoFocus) then
            focusSmoothed = nil
            return
        end
        local camera = ws.CurrentCamera
        if not camera then return end
        local hit = ws:Raycast(camera.CFrame.Position, camera.CFrame.LookVector * 1000)
        local target = hit and hit.Distance or cfg.dofFocusDistance
        if focusSmoothed then
            focusSmoothed = focusSmoothed + (target - focusSmoothed) * math.min(1, dt * 8)
        else
            focusSmoothed = target
        end
        for index = 1, 3 do
            local effect = dofEffects[index]
            if effect and effect.Enabled then effect.FocusDistance = focusSmoothed end
        end
    end))

    task.spawn(function()
        local uiTimer = 1
        while not terminated do
            uiTimer += 0.1
            if uiTimer >= 0.25 then
                uiTimer = 0
                if toggles.RemoveUI then
                    applyHide()
                elseif hidden or next(guiOriginal) ~= nil then
                    restoreUI()
                end
            end

            if toggles.RemoveNearBlur then
                applyNearBlurRemoval()
            elseif next(nearOriginal) ~= nil then
                restoreNearBlur()
            end

            updateDof()
            task.wait(0.1)
        end
    end)

    ESPX.restoreUI = restoreUI
    ESPX.restoreCinematic = function()
        restoreUI()
        restoreNearBlur()
        for index, effect in pairs(dofEffects) do
            effect:Destroy()
            dofEffects[index] = nil
        end
    end
end

do
    local function holdingGun()
        local character = lplr.Character
        local tool = character and character:FindFirstChildOfClass("Tool")
        local settingsModule = tool and tool:FindFirstChild("ACS_Settings")
        return settingsModule ~= nil and settingsModule:IsA("ModuleScript")
    end

    local fovApplied = false
    local fovOriginal = nil
    rs:BindToRenderStep("HRSH_GunFOV", Enum.RenderPriority.Last.Value, function()
        if terminated then return end
        local camera = ws.CurrentCamera
        if not camera then return end
        local active = toggles.GunFOV
            and not toggles.Freecam
            and not spectateTargetPlayer
            and holdingGun()
            and not uis:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
        if active then
            if not fovApplied then
                fovApplied = true
                fovOriginal = camera.FieldOfView
            end
            camera.FieldOfView = cfg.gunFov
        elseif fovApplied then
            fovApplied = false
            if fovOriginal then camera.FieldOfView = fovOriginal end
        end
    end)

    ESPX.restoreGun = function()
        pcall(function() rs:UnbindFromRenderStep("HRSH_GunFOV") end)
        if fovApplied and fovOriginal then
            local camera = ws.CurrentCamera
            if camera then camera.FieldOfView = fovOriginal end
        end
        fovApplied = false
    end
end

do
    local ragdoll = {character = nil, created = {}, motors = {}, collide = {}, failed = nil}
    local sitActive = false

    local function standUp(character)
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        local root = character:FindFirstChild("HumanoidRootPart")
        if root then
            pcall(function()
                local look = root.CFrame.LookVector
                local flat = Vector3.new(look.X, 0, look.Z)
                if flat.Magnitude < 0.1 then flat = Vector3.new(0, 0, -1) end
                local position = root.Position + Vector3.new(0, 3, 0)
                root.CFrame = CFrame.lookAt(position, position + flat.Unit)
                root.AssemblyLinearVelocity = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
            end)
        end
        if humanoid then
            humanoid.PlatformStand = false
            humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
    end

    local function startRagdoll(character)
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then return false end
        ragdoll.character = character
        ragdoll.created = {}
        ragdoll.motors = {}
        ragdoll.collide = {}

        humanoid.PlatformStand = true
        humanoid:ChangeState(Enum.HumanoidStateType.Physics)

        for _, motor in ipairs(character:GetDescendants()) do
            if motor:IsA("Motor6D") and motor.Part0 and motor.Part1
                and motor.Name ~= "RootJoint" and motor.Name ~= "Root" then
                local attachment0 = Instance.new("Attachment")
                attachment0.Name = "HRSH_RagdollA0"
                attachment0.CFrame = motor.C0
                attachment0.Parent = motor.Part0
                local attachment1 = Instance.new("Attachment")
                attachment1.Name = "HRSH_RagdollA1"
                attachment1.CFrame = motor.C1
                attachment1.Parent = motor.Part1

                local socket = Instance.new("BallSocketConstraint")
                socket.Name = "HRSH_RagdollSocket"
                socket.Attachment0 = attachment0
                socket.Attachment1 = attachment1
                socket.LimitsEnabled = true
                socket.UpperAngle = 70
                socket.TwistLimitsEnabled = true
                socket.TwistLowerAngle = -45
                socket.TwistUpperAngle = 45
                socket.Parent = motor.Part0

                local noCollide = Instance.new("NoCollisionConstraint")
                noCollide.Name = "HRSH_RagdollNoCollide"
                noCollide.Part0 = motor.Part0
                noCollide.Part1 = motor.Part1
                noCollide.Parent = motor.Part0

                ragdoll.created[#ragdoll.created + 1] = attachment0
                ragdoll.created[#ragdoll.created + 1] = attachment1
                ragdoll.created[#ragdoll.created + 1] = socket
                ragdoll.created[#ragdoll.created + 1] = noCollide

                local entry = {motor = motor, parent = motor.Parent, usedEnabled = true}
                local ok = pcall(function() motor.Enabled = false end)
                if not ok then
                    entry.usedEnabled = false
                    motor.Parent = nil
                end
                ragdoll.motors[#ragdoll.motors + 1] = entry
            end
        end

        for _, part in ipairs(character:GetChildren()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                ragdoll.collide[part] = part.CanCollide
                part.CanCollide = true
            end
        end
        return true
    end

    local function stopRagdoll(forget)
        local character = ragdoll.character
        if not character then return end
        if not forget then
            for _, instance in ipairs(ragdoll.created) do instance:Destroy() end
            for _, entry in ipairs(ragdoll.motors) do
                if entry.usedEnabled then
                    pcall(function() entry.motor.Enabled = true end)
                else
                    entry.motor.Parent = entry.parent
                end
            end
            for part, collide in pairs(ragdoll.collide) do
                if part.Parent then part.CanCollide = collide end
            end
            standUp(character)
        end
        ragdoll.character = nil
        ragdoll.created = {}
        ragdoll.motors = {}
        ragdoll.collide = {}
    end

    task.spawn(function()
        while not terminated do
            local character = lplr.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            local wantOwn = toggles.Ragdoll

            if wantOwn then
                if ragdoll.character ~= character then
                    if ragdoll.character then stopRagdoll(true) end
                    if character and ragdoll.failed ~= character then
                        if not startRagdoll(character) then ragdoll.failed = character end
                    end
                end
            elseif ragdoll.character then
                stopRagdoll(false)
                ragdoll.failed = nil
            end

            if humanoid then
                if toggles.Sit then
                    sitActive = true
                    if not humanoid.Sit then humanoid.Sit = true end
                elseif sitActive then
                    sitActive = false
                    humanoid.Sit = false
                end
            end
            task.wait(0.1)
        end
    end)

    ESPX.restoreFun = function()
        pcall(stopRagdoll, false)
        local character = lplr.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if humanoid and sitActive then humanoid.Sit = false end
        sitActive = false
    end
end

do
    local LIGHT_PROPS = {
        "Brightness", "ExposureCompensation", "GlobalShadows", "ShadowSoftness", "EnvironmentDiffuseScale",
        "EnvironmentSpecularScale", "ClockTime", "Ambient", "OutdoorAmbient",
    }
    local original = nil
    local touched = {}
    local effects = {}
    local gameEffects = {}
    local timeOverridden = false
    local vignetteGui, vignetteGradients = nil, {}

    local function snapshotLighting()
        local snap = {}
        for _, name in ipairs(LIGHT_PROPS) do
            pcall(function() snap[name] = lighting[name] end)
        end
        return snap
    end

    local function setLighting(name, value)
        local ok = pcall(function()
            if lighting[name] ~= value then lighting[name] = value end
        end)
        if ok then touched[name] = true end
    end

    local function getEffect(className, name)
        local effect = effects[name]
        if not effect or not effect.Parent then
            effect = Instance.new(className)
            effect.Name = name
            effect.Parent = lighting
            effects[name] = effect
        end
        return effect
    end

    local function updateEffects()
        local color = getEffect("ColorCorrectionEffect", "HRSH_ColorCorrection")
        color.Enabled = true
        color.Brightness = cfg.rsBrightness
        color.Contrast = cfg.rsContrast
        color.Saturation = cfg.rsSaturation
        color.TintColor = Color3.fromHSV(math.clamp(cfg.rsTintHue, 0, 360) / 360, math.clamp(cfg.rsTintStrength, 0, 1), 1)

        local bloom = getEffect("BloomEffect", "HRSH_Bloom")
        bloom.Enabled = cfg.rsBloomIntensity > 0
        bloom.Intensity = cfg.rsBloomIntensity
        bloom.Size = cfg.rsBloomSize
        bloom.Threshold = cfg.rsBloomThreshold

        local sun = getEffect("SunRaysEffect", "HRSH_SunRays")
        sun.Enabled = cfg.rsSunIntensity > 0
        sun.Intensity = cfg.rsSunIntensity
        sun.Spread = cfg.rsSunSpread
    end

    local function applyLighting(base)
        if toggles.Fullbright then return end
        if base.Brightness then
            setLighting("Brightness", math.max(0, base.Brightness + cfg.rsLightBrightness))
        end
        if base.ExposureCompensation then
            setLighting("ExposureCompensation", math.clamp(base.ExposureCompensation + cfg.rsExposure, -5, 5))
        end
        if base.GlobalShadows ~= nil then
            setLighting("GlobalShadows", (not toggles.RsNoShadows) and base.GlobalShadows)
        end
        if base.ShadowSoftness then
            setLighting("ShadowSoftness", math.clamp(base.ShadowSoftness + cfg.rsShadowSoftness, 0, 1))
        end
        if base.EnvironmentDiffuseScale then
            setLighting("EnvironmentDiffuseScale", math.clamp(base.EnvironmentDiffuseScale * cfg.rsSkylight, 0, 1))
        end
        if base.EnvironmentSpecularScale then
            setLighting("EnvironmentSpecularScale", math.clamp(base.EnvironmentSpecularScale * cfg.rsReflection, 0, 1))
        end
        local function lift(color)
            return Color3.new(
                math.clamp(color.R + cfg.rsShadowLift, 0, 1),
                math.clamp(color.G + cfg.rsShadowLift, 0, 1),
                math.clamp(color.B + cfg.rsShadowLift, 0, 1)
            )
        end
        if base.Ambient then setLighting("Ambient", lift(base.Ambient)) end
        if base.OutdoorAmbient then setLighting("OutdoorAmbient", lift(base.OutdoorAmbient)) end
        if toggles.RsTime then
            timeOverridden = true
            setLighting("ClockTime", cfg.rsClockTime)
        elseif timeOverridden then
            timeOverridden = false
            if base.ClockTime then setLighting("ClockTime", base.ClockTime) end
        end
    end

    local function disableGameEffects()
        local function scan(container)
            if not container then return end
            for _, item in ipairs(container:GetChildren()) do
                if item:IsA("PostEffect") and string.sub(item.Name, 1, 5) ~= "HRSH_" then
                    if gameEffects[item] == nil then gameEffects[item] = item.Enabled end
                    if item.Enabled then item.Enabled = false end
                end
            end
        end
        scan(lighting)
        scan(ws.CurrentCamera)
    end

    local function restoreGameEffects()
        for item, enabled in pairs(gameEffects) do
            if item.Parent then item.Enabled = enabled end
            gameEffects[item] = nil
        end
    end

    local function restoreAll()
        for _, effect in pairs(effects) do pcall(function() effect:Destroy() end) end
        effects = {}
        restoreGameEffects()
        if original then
            for name in pairs(touched) do
                if original[name] ~= nil then pcall(function() lighting[name] = original[name] end) end
                touched[name] = nil
            end
            original = nil
        end
        timeOverridden = false
    end

    local function ensureVignette()
        if vignetteGui and vignetteGui.Parent then return end
        vignetteGradients = {}
        vignetteGui = Instance.new("ScreenGui")
        vignetteGui.Name = "HRSH_Vignette"
        vignetteGui.ResetOnSpawn = false
        vignetteGui.IgnoreGuiInset = true
        vignetteGui.DisplayOrder = 999990
        vignetteGui.Parent = cg
        local function edge(size, position, anchor, rotation)
            local frame = Instance.new("Frame")
            frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
            frame.BorderSizePixel = 0
            frame.Size = size
            frame.Position = position
            frame.AnchorPoint = anchor
            local gradient = Instance.new("UIGradient")
            gradient.Rotation = rotation
            gradient.Parent = frame
            frame.Parent = vignetteGui
            vignetteGradients[#vignetteGradients + 1] = gradient
        end
        edge(UDim2.new(1, 0, 0.4, 0), UDim2.new(0, 0, 0, 0), Vector2.new(0, 0), 90)
        edge(UDim2.new(1, 0, 0.4, 0), UDim2.new(0, 0, 1, 0), Vector2.new(0, 1), 270)
        edge(UDim2.new(0.3, 0, 1, 0), UDim2.new(0, 0, 0, 0), Vector2.new(0, 0), 0)
        edge(UDim2.new(0.3, 0, 1, 0), UDim2.new(1, 0, 0, 0), Vector2.new(1, 0), 180)
    end

    local function updateVignette()
        if toggles.RsVignette then
            ensureVignette()
            vignetteGui.Enabled = true
            local strength = math.clamp(cfg.rsVignette, 0, 1)
            local sequence = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 1 - strength),
                NumberSequenceKeypoint.new(1, 1),
            })
            for _, gradient in ipairs(vignetteGradients) do gradient.Transparency = sequence end
        elseif vignetteGui and vignetteGui.Parent then
            vignetteGui.Enabled = false
        end
    end

    task.spawn(function()
        while not terminated do
            if toggles.Reshade then
                if not original then original = snapshotLighting() end
                updateEffects()
                applyLighting(original)
                if toggles.RsClean then
                    disableGameEffects()
                elseif next(gameEffects) ~= nil then
                    restoreGameEffects()
                end
            elseif original or next(effects) ~= nil or next(gameEffects) ~= nil then
                restoreAll()
            end
            updateVignette()
            task.wait(0.1)
        end
    end)

    local NEUTRAL = {
        rsBrightness = 0, rsContrast = 0, rsSaturation = 0, rsTintHue = 0, rsTintStrength = 0,
        rsBloomIntensity = 0, rsBloomSize = 24, rsBloomThreshold = 2, rsSunIntensity = 0, rsSunSpread = 0.5,
        rsExposure = 0, rsLightBrightness = 0, rsShadowLift = 0, rsShadowSoftness = 0,
        rsSkylight = 1, rsReflection = 1, rsVignette = 0,
    }
    local PRESETS = {
        Neutral = {},
        Cinematic = {
            rsContrast = 0.18, rsSaturation = 0.08, rsTintHue = 195, rsTintStrength = 0.1,
            rsBloomIntensity = 0.5, rsBloomSize = 30, rsBloomThreshold = 1.8, rsShadowLift = -0.04, rsVignette = 0.5,
        },
        ["Warm Sunset"] = {
            rsBrightness = 0.02, rsContrast = 0.12, rsSaturation = 0.18, rsTintHue = 28, rsTintStrength = 0.22,
            rsBloomIntensity = 0.7, rsBloomSize = 34, rsBloomThreshold = 1.6, rsSunIntensity = 0.2, rsSunSpread = 0.6,
            rsExposure = 0.2, rsVignette = 0.3,
        },
        ["Cold Night"] = {
            rsBrightness = -0.03, rsContrast = 0.2, rsSaturation = -0.18, rsTintHue = 215, rsTintStrength = 0.3,
            rsBloomIntensity = 0.4, rsExposure = -0.25, rsShadowLift = 0.02, rsVignette = 0.55,
        },
        Noir = {
            rsBrightness = -0.02, rsContrast = 0.4, rsSaturation = -1, rsBloomIntensity = 0.25, rsVignette = 0.6,
        },
        Vibrant = {
            rsContrast = 0.15, rsSaturation = 0.45, rsBloomIntensity = 0.45, rsSunIntensity = 0.1, rsVignette = 0.15,
        },
    }

    ESPX.applyShaderPreset = function(name)
        local preset = PRESETS[name]
        if not preset then error("Unknown preset") end
        local values = {}
        for key, value in pairs(NEUTRAL) do values[key] = value end
        for key, value in pairs(preset) do values[key] = value end
        for key, value in pairs(values) do
            local found = false
            for _, slider in ipairs(ESPX.sliders) do
                if slider.key == key then
                    slider.set(value)
                    found = true
                    break
                end
            end
            if not found then cfg[key] = value end
        end
        toggles.Reshade = true
        toggles.RsVignette = values.rsVignette > 0
        if ESPX.togglePaints.Reshade then ESPX.togglePaints.Reshade() end
        if ESPX.togglePaints.RsVignette then ESPX.togglePaints.RsVignette() end
        saveSettings()
    end

    ESPX.restoreReshade = function()
        restoreAll()
        if vignetteGui then
            vignetteGui:Destroy()
            vignetteGui = nil
        end
    end
end

do
    local STEPS = 30
    local segments = {}
    local marker = nil
    local rayParams = nil

    local function getParams()
        if not rayParams then
            rayParams = RaycastParams.new()
            rayParams.FilterType = Enum.RaycastFilterType.Exclude
        end
        rayParams.FilterDescendantsInstances = {lplr.Character}
        return rayParams
    end

    local function hideAll()
        for _, line in ipairs(segments) do line.Visible = false end
        if marker then marker.Visible = false end
    end

    ESPX.track(rs.RenderStepped:Connect(function()
        if terminated then return end
        local camera = ws.CurrentCamera
        local character = lplr.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if not toggles.ProjectilePreview or not camera or not root then
            hideAll()
            return
        end

        local params = getParams()
        local cameraCFrame = camera.CFrame
        local look = cameraCFrame.LookVector

        local aimHit = ws:Raycast(cameraCFrame.Position, look * 1000, params)
        local aimPoint = aimHit and aimHit.Position or (cameraCFrame.Position + look * 1000)

        local flat = Vector3.new(look.X, 0, look.Z)
        flat = (flat.Magnitude > 0.01) and flat.Unit or root.CFrame.LookVector
        local start = root.Position + Vector3.new(0, cfg.projHeight, 0) + flat * cfg.projForward

        local toAim = aimPoint - start
        local direction = (toAim.Magnitude > 0.5) and toAim.Unit or look
        if cfg.projPitch ~= 0 then
            local axis = direction:Cross(Vector3.yAxis)
            if axis.Magnitude > 0.01 then
                direction = CFrame.fromAxisAngle(axis.Unit, math.rad(cfg.projPitch)):VectorToWorldSpace(direction)
            end
        end

        local speed = math.max(cfg.projSpeed, 1)
        local acceleration = Vector3.new(0, -ws.Gravity * cfg.projGravity, 0)
        local stepTime = (cfg.projRange / speed) / STEPS
        local points = {start}
        local position, velocity = start, direction * speed
        local hit = nil
        for _ = 1, STEPS do
            local nextPosition = position + velocity * stepTime + acceleration * (0.5 * stepTime * stepTime)
            local result = ws:Raycast(position, nextPosition - position, params)
            if result then
                points[#points + 1] = result.Position
                hit = result
                break
            end
            points[#points + 1] = nextPosition
            position = nextPosition
            velocity = velocity + acceleration * stepTime
        end

        local previous = nil
        local used = 0
        for _, point in ipairs(points) do
            local screen = camera:WorldToViewportPoint(point)
            local current = (screen.Z > 0) and Vector2.new(screen.X, screen.Y) or nil
            if previous and current then
                used += 1
                local line = segments[used]
                if not line then
                    line = Drawing.new("Line")
                    line.Thickness = 2
                    line.Color = Color3.fromRGB(255, 170, 0)
                    segments[used] = line
                end
                line.From = previous
                line.To = current
                line.Visible = true
            end
            previous = current
        end
        for index = used + 1, #segments do segments[index].Visible = false end

        if hit then
            local screen = camera:WorldToViewportPoint(hit.Position)
            if screen.Z > 0 then
                if not marker then
                    marker = Drawing.new("Circle")
                    marker.NumSides = 24
                    marker.Radius = 8
                    marker.Thickness = 2
                    marker.Filled = false
                end
                local model = hit.Instance:FindFirstAncestorOfClass("Model")
                local onCharacter = model and model:FindFirstChildOfClass("Humanoid") ~= nil
                marker.Color = onCharacter and Color3.fromRGB(255, 40, 40) or Color3.fromRGB(255, 255, 255)
                marker.Position = Vector2.new(screen.X, screen.Y)
                marker.Visible = true
            elseif marker then
                marker.Visible = false
            end
        elseif marker then
            marker.Visible = false
        end
    end))

    ESPX.restoreProjectile = function()
        for _, line in ipairs(segments) do pcall(function() line:Remove() end) end
        segments = {}
        if marker then
            pcall(function() marker:Remove() end)
            marker = nil
        end
    end
end

do
    local CLEAN_KEYS = {
        "ESP", "EnemyHP", "PlayerESP", "SelfHP", "ItemESP", "GeneratorESP",
        "Crosshair", "HeadArrow", "ViewLine", "HitboxExtender",
    }
    local frozenTracks = {}
    local cleanSaved = nil
    local lastClean = false
    local nameOriginal = {}
    local hiddenByModel = {}
    local cursorOriginal = nil
    local barsGui, barFrames = nil, {}
    local gridGui = nil

    local function updateFreezePose()
        local character = lplr.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
        if toggles.FreezePose and animator then
            for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                if frozenTracks[track] == nil then frozenTracks[track] = track.Speed end
                if track.Speed ~= 0 then track:AdjustSpeed(0) end
            end
        elseif next(frozenTracks) ~= nil then
            for track, speed in pairs(frozenTracks) do
                pcall(function() track:AdjustSpeed(speed) end)
                frozenTracks[track] = nil
            end
        end
    end

    local function updateCleanShot()
        if toggles.CleanShot == lastClean then return end
        lastClean = toggles.CleanShot
        if lastClean then
            cleanSaved = {}
            for _, key in ipairs(CLEAN_KEYS) do
                if toggles[key] then
                    cleanSaved[#cleanSaved + 1] = key
                    local flip = ESPX.toggleFlips[key]
                    if flip then flip() end
                end
            end
        elseif cleanSaved then
            for _, key in ipairs(cleanSaved) do
                if not toggles[key] then
                    local flip = ESPX.toggleFlips[key]
                    if flip then flip() end
                end
            end
            cleanSaved = nil
        end
    end

    local function updateNametags()
        if toggles.HideNametags then
            local function hideNames(humanoid)
                if nameOriginal[humanoid] == nil then
                    nameOriginal[humanoid] = {humanoid.DisplayDistanceType, humanoid.HealthDisplayType}
                end
                humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
                humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
            end
            for _, plr in ipairs(plrs:GetPlayers()) do
                local humanoid = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
                if humanoid then pcall(hideNames, humanoid) end
            end
            for _, model in ipairs(ws:GetChildren()) do
                if model:IsA("Model") then
                    local humanoid = model:FindFirstChildOfClass("Humanoid")
                    if humanoid then pcall(hideNames, humanoid) end
                end
            end
        elseif next(nameOriginal) ~= nil then
            for humanoid, original in pairs(nameOriginal) do
                if humanoid.Parent then
                    pcall(function()
                        humanoid.DisplayDistanceType = original[1]
                        humanoid.HealthDisplayType = original[2]
                    end)
                end
                nameOriginal[humanoid] = nil
            end
        end
    end

    local function restoreModel(model)
        local saved = hiddenByModel[model]
        if not saved then return end
        for item, original in pairs(saved) do
            if item.Parent then pcall(function() item.LocalTransparencyModifier = original end) end
        end
        hiddenByModel[model] = nil
    end

    local function updateHidden()
        local wanted = {}
        if toggles.HideOthers then
            for _, plr in ipairs(plrs:GetPlayers()) do
                if plr ~= lplr and plr.Character then wanted[plr.Character] = true end
            end
        end
        if toggles.HideNPCs then
            for _, model in ipairs(ws:GetChildren()) do
                if model:IsA("Model") and model:FindFirstChildOfClass("Humanoid")
                    and not plrs:GetPlayerFromCharacter(model) then
                    wanted[model] = true
                end
            end
        end
        for model in pairs(wanted) do
            local saved = hiddenByModel[model]
            if not saved then
                saved = {}
                hiddenByModel[model] = saved
            end
            for _, item in ipairs(model:GetDescendants()) do
                if item:IsA("BasePart") or item:IsA("Decal") or item:IsA("Texture") then
                    if saved[item] == nil then
                        pcall(function() saved[item] = item.LocalTransparencyModifier end)
                    end
                    pcall(function() item.LocalTransparencyModifier = 1 end)
                end
            end
        end
        for model in pairs(hiddenByModel) do
            if not wanted[model] then restoreModel(model) end
        end
    end

    local function updateCursor()
        if toggles.HideCursor and not main.Visible then
            if cursorOriginal == nil then cursorOriginal = uis.MouseIconEnabled end
            if uis.MouseIconEnabled then uis.MouseIconEnabled = false end
        elseif cursorOriginal ~= nil then
            uis.MouseIconEnabled = cursorOriginal
            cursorOriginal = nil
        end
    end

    local function newOverlay(name, order)
        local overlay = Instance.new("ScreenGui")
        overlay.Name = name
        overlay.ResetOnSpawn = false
        overlay.IgnoreGuiInset = true
        overlay.DisplayOrder = order
        overlay.Parent = cg
        return overlay
    end

    local function updateBars()
        if toggles.CinemaBars then
            if not (barsGui and barsGui.Parent) then
                barsGui = newOverlay("HRSH_Bars", 999991)
                barFrames = {}
                for index, anchorY in ipairs({0, 1}) do
                    local bar = Instance.new("Frame")
                    bar.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
                    bar.BorderSizePixel = 0
                    bar.AnchorPoint = Vector2.new(0, anchorY)
                    bar.Position = UDim2.new(0, 0, anchorY, 0)
                    bar.Parent = barsGui
                    barFrames[index] = bar
                end
            end
            barsGui.Enabled = true
            local size = math.clamp(cfg.barSize, 0, 0.35)
            for _, bar in ipairs(barFrames) do bar.Size = UDim2.new(1, 0, size, 0) end
        elseif barsGui and barsGui.Parent then
            barsGui.Enabled = false
        end
    end

    local function updateGrid()
        if toggles.PhotoGrid then
            if not (gridGui and gridGui.Parent) then
                gridGui = newOverlay("HRSH_Grid", 999992)
                local function line(size, position)
                    local frame = Instance.new("Frame")
                    frame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                    frame.BackgroundTransparency = 0.6
                    frame.BorderSizePixel = 0
                    frame.AnchorPoint = Vector2.new(0.5, 0.5)
                    frame.Size = size
                    frame.Position = position
                    frame.Parent = gridGui
                end
                line(UDim2.new(0, 1, 1, 0), UDim2.new(1 / 3, 0, 0.5, 0))
                line(UDim2.new(0, 1, 1, 0), UDim2.new(2 / 3, 0, 0.5, 0))
                line(UDim2.new(1, 0, 0, 1), UDim2.new(0.5, 0, 1 / 3, 0))
                line(UDim2.new(1, 0, 0, 1), UDim2.new(0.5, 0, 2 / 3, 0))
            end
            gridGui.Enabled = true
        elseif gridGui and gridGui.Parent then
            gridGui.Enabled = false
        end
    end

    task.spawn(function()
        local pass = 0
        while not terminated do
            updateFreezePose()
            updateCleanShot()
            updateCursor()
            updateBars()
            updateGrid()
            if pass % 5 == 0 then
                updateNametags()
                updateHidden()
            end
            pass += 1
            task.wait(0.1)
        end
    end)

    ESPX.restorePhoto = function()
        for track, speed in pairs(frozenTracks) do
            pcall(function() track:AdjustSpeed(speed) end)
            frozenTracks[track] = nil
        end
        for humanoid, original in pairs(nameOriginal) do
            if humanoid.Parent then
                pcall(function()
                    humanoid.DisplayDistanceType = original[1]
                    humanoid.HealthDisplayType = original[2]
                end)
            end
            nameOriginal[humanoid] = nil
        end
        for model in pairs(hiddenByModel) do restoreModel(model) end
        if cursorOriginal ~= nil then
            uis.MouseIconEnabled = cursorOriginal
            cursorOriginal = nil
        end
        if barsGui then barsGui:Destroy() barsGui = nil end
        if gridGui then gridGui:Destroy() gridGui = nil end
    end
end

do
    local function getGeneratorColor()
        return Color3.fromHSV(math.clamp(cfg.genHue, 0, 360) / 360, 1, 1)
    end

    local function getGeneratorAnchor(model)
        if model.PrimaryPart then return model.PrimaryPart end
        return model:FindFirstChildWhichIsA("BasePart", true)
    end

    local PROGRESS_KEYWORDS = {"progress", "percent", "repair", "complet", "charge", "fixed", "fuel"}
    local progressSource = {}
    local progressSearched = {}

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
            if last and os.clock() - last < 5 then return nil end
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

    local function getGeneratorStatusLines(model)
        local lines = {}
        local progress = model:GetAttribute("RepairProgress")
        if type(progress) == "number" then
            local pct = (progress > 0 and progress < 1) and (progress * 100) or progress
            pct = math.clamp(math.floor(pct + 0.5), 0, 100)
            lines[#lines + 1] = (pct >= 100) and "REPAIRED" or string.format("Repair: %d%%", pct)
        else
            local fallback = getProgressText(model)
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

    local headArrows = {}

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
        piece("OuterLeft", Vector2.new(10, 3), Vector2.new(11.5, 14.5), 45)
        piece("OuterRight", Vector2.new(10, 3), Vector2.new(18.5, 14.5), -45)
        piece("InnerLeft", Vector2.new(7, 2), Vector2.new(12.5, 24.5), 45, 0.35)
        piece("InnerRight", Vector2.new(7, 2), Vector2.new(17.5, 24.5), -45, 0.35)

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
                        setArrow(npc, cfg.espFill)
                    end
                end
                for _, plr in ipairs(plrs:GetPlayers()) do
                    local char = plr.Character
                    local hum = char and char:FindFirstChildOfClass("Humanoid")
                    if plr ~= lplr and char and hum and hum.Health > 0 then
                        seen[char] = true
                        setArrow(char, ESPX.playerColor(plr))
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

    setTab("Settings")
    createSection("[ DANGER ZONE ]")
    createActionButton("Terminate", function()
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
        pcall(ESPX.restoreCinematic)
        pcall(ESPX.restoreGun)
        pcall(ESPX.restoreFun)
        pcall(ESPX.restoreReshade)
        pcall(ESPX.restorePhoto)
        pcall(ESPX.restoreProjectile)
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

        for _, connection in ipairs(ESPX.conns) do
            pcall(function() connection:Disconnect() end)
        end

        gui:Destroy()
    end)
    setTab("Main")
end
