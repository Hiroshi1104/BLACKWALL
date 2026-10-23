local ws = game:GetService("Workspace")
local rs = game:GetService("RunService")
local uis = game:GetService("UserInputService")
local pps = game:GetService("ProximityPromptService")
local plrs = game:GetService("Players")
local lighting = game:GetService("Lighting")
local cg = game:GetService("CoreGui")

local cam = ws.CurrentCamera
local lplr = plrs.LocalPlayer

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
    Crosshair = false,
    Fly = false,
    Noclip = false,
    Hitboxes = false,
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
}

local hitboxCfg = {
    enabled = true,
    part = "Head",
    size = Vector3.new(2, 2, 2),
    show = true,
    color = BrickColor.new("Bright red"),
    trans = 0.7,
    refreshRate = 1
}

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
if type(loadedSettings.hitboxSize) == "number" then
    local v = math.clamp(loadedSettings.hitboxSize, 1, 20)
    hitboxCfg.size = Vector3.new(v, v, v)
end
if type(loadedSettings.flySpeed) == "number" then flySpeed = math.clamp(loadedSettings.flySpeed, 1, 200) end

local function saveSettings()
    if type(writefile) ~= "function" then return false end

    -- JSONEncode cannot serialize Color3 / other Roblox datatypes in cfg.
    -- Save only the numeric config fields that this menu actually edits.
    local numericCfg = {
        aimStrength = cfg.aimStrength,
        fov = cfg.fov,
        speed = cfg.speed,
        gatherDistance = cfg.gatherDistance,
    }
    local payload = {
        toggles = toggles,
        cfg = numericCfg,
        hitboxSize = hitboxCfg.size.X,
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

local function corner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 2)
    c.Parent = parent
    return c
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

local main = Instance.new("Frame")
main.Name = "main"
main.Parent = gui
main.BackgroundColor3 = C.bg
main.BorderSizePixel = 0
main.Position = UDim2.new(0.035, 0, 0.12, 0)
main.Size = UDim2.new(0, 390, 0, 560)
main.Active = true
main.Draggable = true
main.ClipsDescendants = true
corner(main, 2)
stroke(main, C.outline, 0.05, 1)
local sizeConstraint = Instance.new("UISizeConstraint")
sizeConstraint.Parent = main
sizeConstraint.MinSize = Vector2.new(320, 360)
sizeConstraint.MaxSize = Vector2.new(460, 760)

local topAccent = Instance.new("Frame")
topAccent.Parent = main
topAccent.Size = UDim2.new(1, 0, 0, 2)
topAccent.BackgroundColor3 = C.outline
topAccent.BorderSizePixel = 0

local header = Instance.new("Frame")
header.Parent = main
header.BackgroundColor3 = C.panel
header.BorderSizePixel = 0
header.Position = UDim2.new(0, 0, 0, 3)
header.Size = UDim2.new(1, 0, 0, 58)

local logo = Instance.new("Frame")
logo.Parent = header
logo.Position = UDim2.new(0, 12, 0, 12)
logo.Size = UDim2.new(0, 32, 0, 32)
logo.BackgroundColor3 = C.accent
logo.BorderSizePixel = 0
corner(logo, 2)
local logoText = Instance.new("TextLabel")
logoText.Parent = logo
logoText.BackgroundTransparency = 1
logoText.Size = UDim2.new(1, 0, 1, 0)
logoText.Font = Enum.Font.GothamBlack
logoText.Text = "☣"
logoText.TextColor3 = C.text
logoText.TextSize = 19

local title = Instance.new("TextLabel")
title.Parent = header
title.BackgroundTransparency = 1
title.Position = UDim2.new(0, 54, 0, 10)
title.Size = UDim2.new(1, -70, 0, 22)
title.Font = Enum.Font.Code
title.Text = "BLACKWALL  //  MAIN SYSTEM"
title.TextColor3 = C.text
title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left
local subtitle = Instance.new("TextLabel")
subtitle.Parent = header
subtitle.BackgroundTransparency = 1
subtitle.Position = UDim2.new(0, 54, 0, 33)
subtitle.Size = UDim2.new(1, -70, 0, 14)
subtitle.Font = Enum.Font.Code
subtitle.Text = "UNAUTHORIZED ACCESS  •  RightCTRL Default"
subtitle.TextColor3 = C.muted
subtitle.TextSize = 9
subtitle.TextXAlignment = Enum.TextXAlignment.Left

-- Category tabs: horizontally scrollable so every category remains reachable.
local tabBar = Instance.new("ScrollingFrame")
tabBar.Name = "CategoryTabs"
tabBar.Parent = main
tabBar.BackgroundColor3 = C.bg
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

local tabPages = {}
local tabButtons = {}
local activeTab = "Main"
local scroll, layout
local function setTab(name)
    activeTab = name
    for tabName, page in pairs(tabPages) do
        page.Visible = (tabName == name)
    end
    for tabName, button in pairs(tabButtons) do
        local selected = tabName == name
        button.BackgroundColor3 = selected and C.panel2 or C.panel
        button.TextColor3 = selected and C.accent or C.muted
    end
    scroll = tabPages[name]
    layout = scroll and scroll:FindFirstChildOfClass("UIListLayout")
end

for order, name in ipairs({"Main", "Movement", "Teleport", "Spectate", "Gun", "Settings"}) do
    local page = Instance.new("ScrollingFrame")
    page.Name = name .. "Page"
    page.Parent = main
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.Position = UDim2.new(0, 0, 0, 103)
    page.Size = UDim2.new(1, 0, 1, -109)
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.ScrollBarThickness = 5
    page.ScrollBarImageColor3 = C.accent
    page.ScrollBarImageTransparency = 0.15
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
    local tabWidths = {Main = 48, Movement = 64, Teleport = 60, Spectate = 60, Gun = 42, Settings = 56}
    button.Size = UDim2.new(0, tabWidths[name] or 60, 1, 0)
    button.BackgroundColor3 = C.panel
    button.BorderSizePixel = 0
    button.AutoButtonColor = false
    button.Font = Enum.Font.Code
    button.Text = string.upper(name)
    button.TextSize = 10
    button.TextColor3 = C.muted
    button.ZIndex = 9
    corner(button, 2)
    stroke(button, C.outline, 0.25, 1)
    button.MouseButton1Click:Connect(function() setTab(name) end)
    tabPages[name] = page
    tabButtons[name] = button
end
setTab("Main")

local function createSection(name)
    local wrap = Instance.new("Frame")
    wrap.Parent = scroll
    wrap.BackgroundTransparency = 1
    wrap.Size = UDim2.new(1, -20, 0, 24)
    wrap.BorderSizePixel = 0
    local line = Instance.new("Frame")
    line.Parent = wrap
    line.BackgroundColor3 = C.accent
    line.BorderSizePixel = 0
    line.Position = UDim2.new(0, 1, 0, 7)
    line.Size = UDim2.new(0, 3, 0, 13)
    corner(line, 2)
    local lbl = Instance.new("TextLabel")
    lbl.Parent = wrap
    lbl.BackgroundTransparency = 1
    lbl.Position = UDim2.new(0, 11, 0, 0)
    lbl.Size = UDim2.new(1, -11, 1, 0)
    lbl.Font = Enum.Font.Code
    lbl.Text = string.upper(name)
    lbl.TextColor3 = C.muted
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
end

local function createActionButton(name, callback)
    local b = Instance.new("TextButton")
    b.Parent = scroll
    b.BackgroundColor3 = C.panel
    b.Size = UDim2.new(1, -20, 0, 36)
    b.Font = Enum.Font.Code
    b.Text = name
    b.TextColor3 = C.text
    b.TextSize = 12
    b.BorderSizePixel = 0
    b.ZIndex = 7
    b.AutoButtonColor = false
    corner(b, 2)
    local edge = stroke(b, C.outline, 0.12, 1)
    b.MouseEnter:Connect(function()
        b.BackgroundColor3 = C.panel2
        edge.Color = C.accent
    end)
    b.MouseLeave:Connect(function()
        b.BackgroundColor3 = C.panel
        edge.Color = C.outline
    end)
    b.MouseButton1Click:Connect(function()
        local ok, message = pcall(callback)
        b.Text = ok and (name .. "  [DONE]") or (name .. "  [ERROR]")
        if not ok then warn("[BLACKWALL] " .. tostring(message)) end
        task.delay(1.5, function()
            if b and b.Parent then b.Text = name end
        end)
    end)
    return b
end

local function getPlayerTools()
    local found, seen = {}, {}
    local function scan(container)
        if not container then return end
        for _, item in ipairs(container:GetChildren()) do
            if item:IsA("Tool") and not seen[item] then
                seen[item] = true
                table.insert(found, item)
            end
        end
    end
    scan(lplr:FindFirstChildOfClass("Backpack"))
    scan(lplr.Character)
    return found
end

local function setAmmoAttribute(attributeName, requestedValue)
    local tools = getPlayerTools()
    if #tools == 0 then error("No weapons/tools found in Backpack or Character") end
    local applied, failed = 0, 0
    for _, tool in ipairs(tools) do
        local ok = pcall(function()
            tool:SetAttribute(attributeName, requestedValue)
        end)
        if ok then
            applied += 1
        else
            failed += 1
        end
    end
    if applied == 0 then error("Could not set the ammo attribute") end
    return applied, failed
end

local function createToggle(name, key)
    local b = Instance.new("TextButton")
    b.Parent = scroll
    b.BackgroundColor3 = C.panel
    b.Size = UDim2.new(1, -20, 0, 34)
    b.Font = Enum.Font.GothamMedium
    b.Text = ""
    b.TextColor3 = C.text
    b.TextSize = 12
    b.BorderSizePixel = 0
    b.ZIndex = 7
    b.AutoButtonColor = false
    corner(b, 2)
    local edge = stroke(b, C.outline, 0.2, 1)
    local label = Instance.new("TextLabel")
    label.Parent = b
    label.BackgroundTransparency = 1
    label.Position = UDim2.new(0, 12, 0, 0)
    label.Size = UDim2.new(1, -72, 1, 0)
    label.Font = Enum.Font.Code
    label.Text = name
    label.TextColor3 = C.text
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    local pill = Instance.new("Frame")
    pill.Parent = b
    pill.AnchorPoint = Vector2.new(1, 0.5)
    pill.Position = UDim2.new(1, -10, 0.5, 0)
    pill.Size = UDim2.new(0, 36, 0, 18)
    pill.BorderSizePixel = 0
    corner(pill, 11)
    local dot = Instance.new("Frame")
    dot.Parent = pill
    dot.Size = UDim2.new(0, 12, 0, 12)
    dot.Position = UDim2.new(0, 3, 0.5, -6)
    dot.BorderSizePixel = 0
    dot.BackgroundColor3 = C.text
    corner(dot, 7)
    local function paint()
        local on = toggles[key]
        pill.BackgroundColor3 = on and C.trueState or C.off
        dot.Position = on and UDim2.new(1, -15, 0.5, -6) or UDim2.new(0, 3, 0.5, -6)
        dot.BackgroundColor3 = on and C.bg or Color3.fromRGB(255, 245, 245)
        b.BackgroundColor3 = C.panel
        edge.Color = C.outline
        edge.Color = on and C.trueState or C.outline
        edge.Transparency = on and 0.05 or 0.12
    end
    paint()
    b.MouseEnter:Connect(function() if not toggles[key] then b.BackgroundColor3 = C.panel2 end end)
    b.MouseLeave:Connect(paint)
    b.MouseButton1Click:Connect(function()
        toggles[key] = not toggles[key]
        saveSettings()
        paint()
        if key == "ESP" and not toggles.ESP then
            for _, v in ipairs(ws:GetDescendants()) do
                if v.Name == "NPCHighlight" then v:Destroy() end
            end
        end
    end)
end

-- Slider controls: click anywhere on the track, drag smoothly, with a live value and thumb.
local function createSlider(name, minV, maxV, def, cb)
    local container = Instance.new("Frame")
    container.Parent = scroll
    container.BackgroundColor3 = C.panel
    container.Size = UDim2.new(1, -20, 0, 60)
    container.BorderSizePixel = 0
    container.ZIndex = 6
    corner(container, 2)
    stroke(container, C.outline, 0.15, 1)

    local lbl = Instance.new("TextLabel")
    lbl.Parent = container
    lbl.BackgroundTransparency = 1
    lbl.Position = UDim2.new(0, 12, 0, 7)
    lbl.Size = UDim2.new(1, -88, 0, 19)
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
    valueBox.BackgroundColor3 = C.panel2
    valueBox.BorderSizePixel = 0
    valueBox.Font = Enum.Font.Code
    valueBox.TextColor3 = C.accent
    valueBox.TextSize = 11
    valueBox.Text = tostring(def)
    valueBox.ZIndex = 8
    corner(valueBox, 5)

    local back = Instance.new("TextButton")
    back.Parent = container
    back.AutoButtonColor = false
    back.Text = ""
    back.BackgroundColor3 = C.off
    back.Position = UDim2.new(0, 12, 0, 36)
    back.Size = UDim2.new(1, -24, 0, 6)
    back.BorderSizePixel = 0
    back.ZIndex = 7
    corner(back, 4)

    local fill = Instance.new("Frame")
    fill.Parent = back
    fill.BackgroundColor3 = C.accent
    fill.Size = UDim2.new(math.clamp((def - minV) / (maxV - minV), 0, 1), 0, 1, 0)
    fill.BorderSizePixel = 0
    fill.ZIndex = 8
    corner(fill, 4)

    local thumb = Instance.new("Frame")
    thumb.Parent = back
    thumb.AnchorPoint = Vector2.new(0.5, 0.5)
    thumb.Position = UDim2.new(math.clamp((def - minV) / (maxV - minV), 0, 1), 0, 0.5, 0)
    thumb.Size = UDim2.new(0, 12, 0, 12)
    thumb.BackgroundColor3 = C.text
    thumb.BorderSizePixel = 0
    thumb.ZIndex = 9
    corner(thumb, 8)
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
        saveSettings()
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
    uis.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
    uis.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateFromX(input.Position.X)
        end
    end)
end

-- Main: ESP, targeting, hitboxes, and other visual/utility controls.
setTab("Main")
createSection("[ VISUALS & UTILITY ]")
createToggle("Aim Assist", "AimAssist")
createToggle("NPC ESP", "ESP")
createToggle("Enemy HP", "EnemyHP")
createToggle("Player ESP", "PlayerESP")
createToggle("My HP", "SelfHP")
createToggle("Item ESP", "ItemESP")
createToggle("Crosshair", "Crosshair")
createToggle("Big Hitboxes", "Hitboxes")
createToggle("Fullbright", "Fullbright")
createToggle("Instant Interact", "InstantInteract")
createToggle("Del Corpses", "DelCorpses")
createToggle("Gather NPCs", "GatherNPCs")
createSection("[ AIM / HITBOX SETTINGS ]")
createSlider("Aim Strength", 0.01, 1.0, cfg.aimStrength, function(v) cfg.aimStrength = v end)
createSlider("FOV", 10, 300, cfg.fov, function(v) cfg.fov = v end)
createSlider("Hitbox Size", 1, 20, hitboxCfg.size.X, function(v) hitboxCfg.size = Vector3.new(v, v, v) end)
createSlider("Gather Distance", 1, 30, cfg.gatherDistance, function(v) cfg.gatherDistance = v end)

-- Movement: movement toggles and speed controls.
setTab("Movement")
createSection("[ MOVEMENT ]")
createToggle("Noclip", "Noclip")
createToggle("Fly", "Fly")
createToggle("Speed Modifier", "Speed")

createSection("[ MOVEMENT SETTINGS ]")
createSlider("Walk Speed", 1, 100, cfg.speed, function(v) cfg.speed = v end)
createSlider("Fly Speed", 1, 200, 55, function(v) flySpeed = v end)

-- Dedicated Teleport tab with a visible, refreshable player list.
setTab("Teleport")
createSection("[ SELECT PLAYER ]")
local selectedTeleportPlayer = nil
local teleportPlayerList = Instance.new("Frame")
teleportPlayerList.Name = "TeleportPlayerList"
teleportPlayerList.Parent = scroll
teleportPlayerList.BackgroundColor3 = C.panel
teleportPlayerList.BorderSizePixel = 0
teleportPlayerList.Size = UDim2.new(1, -20, 0, 180)
teleportPlayerList.ZIndex = 7
corner(teleportPlayerList, 2)
stroke(teleportPlayerList, C.outline, 0.12, 1)

local playerListScroll = Instance.new("ScrollingFrame")
playerListScroll.Name = "Players"
playerListScroll.Parent = teleportPlayerList
playerListScroll.BackgroundTransparency = 1
playerListScroll.BorderSizePixel = 0
playerListScroll.Position = UDim2.new(0, 4, 0, 4)
playerListScroll.Size = UDim2.new(1, -8, 1, -8)
playerListScroll.ScrollBarThickness = 4
playerListScroll.ScrollBarImageColor3 = C.accent
playerListScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
playerListScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
playerListScroll.ScrollingDirection = Enum.ScrollingDirection.Y
playerListScroll.ZIndex = 8
local playerListLayout = Instance.new("UIListLayout")
playerListLayout.Parent = playerListScroll
playerListLayout.Padding = UDim.new(0, 3)
playerListLayout.SortOrder = Enum.SortOrder.Name

local function getTeleportTargets()
    local targets = {}
    for _, player in ipairs(plrs:GetPlayers()) do
        if player ~= lplr and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            table.insert(targets, player)
        end
    end
    table.sort(targets, function(a, b) return a.Name:lower() < b.Name:lower() end)
    return targets
end

local function refreshTeleportPlayers()
    for _, child in ipairs(playerListScroll:GetChildren()) do
        if child:IsA("TextButton") or child:IsA("TextLabel") then child:Destroy() end
    end
    local targets = getTeleportTargets()
    if #targets == 0 then
        local empty = Instance.new("TextLabel")
        empty.Parent = playerListScroll
        empty.Size = UDim2.new(1, -4, 0, 30)
        empty.BackgroundTransparency = 1
        empty.Font = Enum.Font.Code
        empty.Text = "NO PLAYERS AVAILABLE"
        empty.TextColor3 = C.muted
        empty.TextSize = 12
        empty.ZIndex = 9
        selectedTeleportPlayer = nil
        return
    end
    local selectionStillValid = false
    for _, player in ipairs(targets) do
        if player == selectedTeleportPlayer then selectionStillValid = true end
        local item = Instance.new("TextButton")
        item.Name = "Player_" .. player.UserId
        item.Parent = playerListScroll
        item.Size = UDim2.new(1, -4, 0, 30)
        item.BackgroundColor3 = player == selectedTeleportPlayer and C.panel2 or C.bg
        item.BorderSizePixel = 0
        item.AutoButtonColor = false
        item.Font = Enum.Font.Code
        item.Text = (player == selectedTeleportPlayer and ">  " or "   ") .. player.Name .. "  (@" .. player.DisplayName .. ")"
        item.TextColor3 = player == selectedTeleportPlayer and C.trueState or C.text
        item.TextSize = 11
        item.TextXAlignment = Enum.TextXAlignment.Left
        item.ZIndex = 9
        corner(item, 2)
        item.MouseButton1Click:Connect(function()
            selectedTeleportPlayer = player
            refreshTeleportPlayers()
        end)
    end
    if not selectionStillValid then selectedTeleportPlayer = nil end
end

local refreshPlayersButton = createActionButton("Refresh Player List", refreshTeleportPlayers)
refreshPlayersButton.LayoutOrder = 2
refreshTeleportPlayers()
plrs.PlayerAdded:Connect(refreshTeleportPlayers)
plrs.PlayerRemoving:Connect(function(player)
    if player == selectedTeleportPlayer then selectedTeleportPlayer = nil end
    refreshTeleportPlayers()
end)

createActionButton("Teleport to Selected Player", function()
    if not selectedTeleportPlayer or selectedTeleportPlayer.Parent ~= plrs then
        error("Select a player from the list first")
    end
    local targetCharacter = selectedTeleportPlayer.Character
    local targetRoot = targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart")
    local character = lplr.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not targetRoot then error("Target character is unavailable") end
    if not root or not humanoid or humanoid.Health <= 0 then error("Your character is unavailable") end
    root.CFrame = targetRoot.CFrame * CFrame.new(3, 0, 0)
end)

-- Spectate tab: refreshable player list and a Scriptable camera that does not
-- run Roblox's normal camera collision checks, so walls do not push the view away.
setTab("Spectate")
createSection("[ SPECTATE PLAYER ]")

local selectedSpectatePlayer = nil
local spectateTargetPlayer = nil
local spectateRenderConnection = nil
local spectatePlayerList = Instance.new("Frame")
spectatePlayerList.Name = "SpectatePlayerList"
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
    spectateMouseDeltaConnection = uis.InputChanged:Connect(function(input)
        if spectateMouseLook and input.UserInputType == Enum.UserInputType.MouseMovement then
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

createActionButton("Refresh Spectate List", refreshSpectatePlayers)
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
plrs.PlayerAdded:Connect(refreshSpectatePlayers)
plrs.PlayerRemoving:Connect(function(player)
    if player == selectedSpectatePlayer then
        selectedSpectatePlayer = nil
        updateSpectateInfo(nil)
    end
    if player == spectateTargetPlayer then stopSpectating() end
    refreshSpectatePlayers()
end)
lplr.CharacterAdded:Connect(function()
    -- Keep the camera local after respawning if the spectate target vanished.
    if not spectateTargetPlayer then
        task.defer(stopSpectating)
    end
end)

-- Gun: one-shot ammo attribute actions for tools currently in Backpack/Character.
-- math.huge is attempted first; if Roblox rejects non-finite attribute values,
-- fall back to a very large finite number.
setTab("Gun")
createSection("[ AMMO ]")
createActionButton("Infinite Ammo In Gun", function()
    local value = math.huge
    local ok = pcall(function()
        local tools = getPlayerTools()
        if #tools == 0 then error("No weapons/tools found") end
        local applied = 0
        for _, tool in ipairs(tools) do
            local setOk = pcall(function() tool:SetAttribute("ACSClientAmmoInGun", value) end)
            if not setOk then
                tool:SetAttribute("ACSClientAmmoInGun", 9e15)
            end
            applied += 1
        end
        if applied == 0 then error("No ammo attributes applied") end
    end)
    if not ok then
        setAmmoAttribute("ACSClientAmmoInGun", 9e15)
    end
end)
createActionButton("Infinite Reserve Ammo", function()
    local tools = getPlayerTools()
    if #tools == 0 then error("No weapons/tools found") end
    local applied = 0
    for _, tool in ipairs(tools) do
        local ok = pcall(function() tool:SetAttribute("ACSClientStoredAmmo", math.huge) end)
        if not ok then
            tool:SetAttribute("ACSClientStoredAmmo", 9e15)
        end
        applied += 1
    end
    if applied == 0 then error("No reserve ammo attributes applied") end
end)

-- Fire type: set the client-side ACS shoot-type attribute on carried/equipped tools.
-- Value 3 matches the ShootType = 3 configuration shown by the user.
createSection("[ FIRE TYPE ]")
createActionButton("Set Fire Type (ShootType 3)", function()
    local tools = getPlayerTools()
    if #tools == 0 then error("No weapons/tools found") end

    local applied = 0
    for _, tool in ipairs(tools) do
        tool:SetAttribute("ACSClientShootType", 3)
        applied += 1
    end
    if applied == 0 then error("No fire-type attributes applied") end
end)

createSection("[ NOTES ]")
createSection("Applies once to tools in Backpack and Character")

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
setTab("Main")

uis.InputBegan:Connect(function(input, gpe)
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
end)

-- Speed modifier
local lastSpeed = false

uis.InputBegan:Connect(function(input, gpe)
    if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
        if toggles.Speed then
            local hum = lplr.Character and lplr.Character:FindFirstChildOfClass("Humanoid")
            if hum then hum.WalkSpeed = 16 end
        end
    end
end)

uis.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
        if toggles.Speed then
            local hum = lplr.Character and lplr.Character:FindFirstChildOfClass("Humanoid")
            if hum then hum.WalkSpeed = cfg.speed end
        end
    end
end)

rs.Heartbeat:Connect(function()
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
end)

-- Instant Interact
local validTargets = {}

pps.PromptShown:Connect(function(prompt)
    if toggles.InstantInteract then
        prompt.HoldDuration = 0
    end
end)

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
    hl.FillTransparency = cfg.fillTrans
    hl.OutlineTransparency = cfg.outTrans
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
        hl.FillTransparency = 0.5
        hl.OutlineTransparency = 0
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Parent = char
    end
    hl.Adornee = char
    hl.Enabled = true

    local function getTeamKey(player)
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

    local myTeam, playerTeam = getTeamKey(lplr), getTeamKey(plr)
    if myTeam and playerTeam then
        hl.FillColor = myTeam == playerTeam and Color3.fromRGB(0, 120, 255) or Color3.fromRGB(220, 50, 50)
    else
        hl.FillColor = Color3.fromRGB(0, 200, 80)
    end

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
    infoGui.Enabled = true

    local label = infoGui:FindFirstChild("Info")
    if not label then return end
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
plrs.PlayerAdded:Connect(function(plr)
    watchPlayer(plr)
    if toggles.PlayerESP and plr.Character then addPlayerInfoESP(plr, plr.Character) end
end)

local lastPlayerESP = false
local lastEnemyHP = false
local enemyHPUpdateTimer = 0
local playerESPUpdateTimer = 0

rs.Heartbeat:Connect(function(dt)
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
end)

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
lplr.CharacterAdded:Connect(function()
    if toggles.SelfHP then
        task.wait(0.25)
        setupSelfHP()
    end
end)

-- Watch the toggle without touching the existing GUI/event structure.
task.spawn(function()
    local last = toggles.SelfHP

    while true do
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
        for _, obj in ipairs(char:GetDescendants()) do
            if obj:IsA("BasePart") then
                if noclipOriginal[obj] == nil then
                    noclipOriginal[obj] = obj.CanCollide
                end

                obj.CanCollide = false
            end
        end
    else
        for part, original in pairs(noclipOriginal) do
            if part and part.Parent then
                part.CanCollide = original
            end

            noclipOriginal[part] = nil
        end
    end
end

lplr.CharacterAdded:Connect(function()
    task.wait(0.25)

    if toggles.Noclip then
        setNoclip(true)
    end
end)

-- Keep collision disabled while Noclip is enabled.
rs.Stepped:Connect(function()
    if toggles.Noclip then
        setNoclip(true)
    end
end)

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
        if direction.Magnitude > 0 then direction = direction.Unit * flySpeed end
        flyVelocity.Velocity = direction
        flyGyro.CFrame = CFrame.lookAt(flyRoot.Position, flyRoot.Position + camera.CFrame.LookVector)
    end)
end

local lastFlyState = false
rs.Heartbeat:Connect(function()
    if toggles.Fly ~= lastFlyState then
        lastFlyState = toggles.Fly
        if toggles.Fly then startFly() else
            stopFly()
            local character = lplr.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            if humanoid then humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end
        end
    end
end)

lplr.CharacterAdded:Connect(function()
    task.wait(0.35)
    if toggles.Fly then startFly() end
end)

-- Item scanner
-- Runs after the Item ESP functions have been declared.
-- It scans direct Workspace children, so ProximityPrompt activation range
-- does not control whether an item is detected.
task.spawn(function()
    while true do
        if toggles.ItemESP then
            updateItemESP()
        else
            clearItemESP()
        end

        task.wait(0.15)
    end
end)

ws.ChildAdded:Connect(function(obj)
    if toggles.ItemESP then
        task.defer(function()
            if obj and obj.Parent == ws then
                addItemESP(obj)
            end
        end)
    end
end)

ws.ChildRemoved:Connect(function(obj)
    removeItemESP(obj)
end)

-- Crosshair
local crossX = Drawing.new("Line")
local crossY = Drawing.new("Line")
crossX.Visible, crossY.Visible = toggles.Crosshair, toggles.Crosshair
crossX.Thickness, crossY.Thickness = 2, 2
crossX.Color, crossY.Color = Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 255, 255)

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
    while true do
        local dt = task.wait(0.015)
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
                    local candidates = {}
                    for _, obj in ipairs(ws:GetDescendants()) do
                        if obj:IsA("Model")
                            and obj ~= character
                            and not isNestedInsideAnotherHumanoidModel(obj)
                            and not isGatherExcluded(obj)
                            and not plrs:GetPlayerFromCharacter(obj) then
                            local hum = obj:FindFirstChildOfClass("Humanoid")
                            local root = getGatherRoot(obj)
                            if hum and hum.Health > 0 and root then
                                candidates[#candidates + 1] = {model = obj, root = root, humanoid = hum}
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
    while true do
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
    while true do
        refreshTargets()
        task.wait(cfg.scanRate)
    end
end)

-- Aim assist + crosshair
rs.RenderStepped:Connect(function(dt)
    local center = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)

    -- Crosshair can now be toggled independently of Aim Assist.
    crossX.Visible = toggles.Crosshair
    crossY.Visible = toggles.Crosshair

    if toggles.Crosshair then
        crossX.From = Vector2.new(center.X - 10, center.Y)
        crossX.To = Vector2.new(center.X + 10, center.Y)
        crossY.From = Vector2.new(center.X, center.Y - 10)
        crossY.To = Vector2.new(center.X, center.Y + 10)
    end

    if not toggles.AimAssist then
        if toggles.Crosshair then
            crossX.Color, crossY.Color = Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 255, 255)
        end
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
        crossX.Color, crossY.Color = Color3.fromRGB(255, 0, 0), Color3.fromRGB(255, 0, 0)
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
    else
        crossX.Color, crossY.Color = Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 255, 255)
    end
end)

-- Hitboxes
task.spawn(function()
    while true do
        for _, obj in ipairs(ws:GetChildren()) do
            if obj.Name == "MI28_Aim" then
                local aimPart = obj:FindFirstChild(hitboxCfg.part, true)
                if aimPart and aimPart:GetAttribute("OrigSize") then
                    aimPart.Size = aimPart:GetAttribute("OrigSize")
                    aimPart.Transparency = aimPart:GetAttribute("OrigTrans")
                    aimPart.BrickColor = BrickColor.new(aimPart:GetAttribute("OrigColor"))
                    aimPart:SetAttribute("OrigSize", nil)
                    aimPart:SetAttribute("OrigTrans", nil)
                    aimPart:SetAttribute("OrigColor", nil)
                end
                continue
            end
            if plrs:GetPlayerFromCharacter(obj) then continue end
            if obj:IsA("Model") then
                local hum = obj:FindFirstChildOfClass("Humanoid")
                local tPart = obj:FindFirstChild(hitboxCfg.part, true)
                local isMI28 = obj.Name:lower():find("mi28", 1, true) ~= nil
                if not tPart and isMI28 then
                    tPart = obj:FindFirstChild("HumanoidRootPart", true)
                        or obj.PrimaryPart
                        or obj:FindFirstChild("30MMBody", true)
                        or obj:FindFirstChildWhichIsA("BasePart", true)
                end
                local isValidTarget = (hum and hum.Health > 0) or isMI28

                if tPart then
                    if toggles.Hitboxes and isValidTarget then
                        if not tPart:GetAttribute("OrigSize") then
                            tPart:SetAttribute("OrigSize", tPart.Size)
                            tPart:SetAttribute("OrigTrans", tPart.Transparency)
                            tPart:SetAttribute("OrigColor", tPart.BrickColor.Name)
                        end
                        if tPart.Size ~= hitboxCfg.size then
                            tPart.Size = hitboxCfg.size
                            tPart.CanCollide = false
                            tPart.Massless = true
                            if hitboxCfg.show then
                                tPart.Transparency = hitboxCfg.trans
                                tPart.BrickColor = hitboxCfg.color
                            end
                        end
                    elseif not toggles.Hitboxes then
                        if tPart:GetAttribute("OrigSize") and tPart.Size ~= tPart:GetAttribute("OrigSize") then
                            tPart.Size = tPart:GetAttribute("OrigSize")
                            tPart.Transparency = tPart:GetAttribute("OrigTrans")
                            tPart.BrickColor = BrickColor.new(tPart:GetAttribute("OrigColor"))
                        end
                    end
                end
            end
        end
        task.wait(hitboxCfg.refreshRate)
    end
end)

-- Fullbright
lighting.Changed:Connect(function()
    if not toggles.Fullbright then return end
    lighting.Brightness = 2
    lighting.ClockTime = 14
    lighting.FogEnd = 100000
    lighting.GlobalShadows = false
    lighting.Ambient = Color3.fromRGB(178, 178, 178)
    lighting.OutdoorAmbient = Color3.fromRGB(178, 178, 178)
end)

-- AI State Disabler
task.spawn(function()
    local bannedStates = {
        Enum.HumanoidStateType.Climbing,
        Enum.HumanoidStateType.Swimming,
        Enum.HumanoidStateType.FallingDown,
        Enum.HumanoidStateType.Ragdoll
    }
    while true do
        task.wait(2)
        local i = 0
        for _, obj in ipairs(ws:GetDescendants()) do
            if obj:IsA("Humanoid") and not plrs:GetPlayerFromCharacter(obj.Parent) then
                if obj.Health > 0 then
                    for _, state in ipairs(bannedStates) do
                        obj:SetStateEnabled(state, false)
                    end
                end
            end
            i += 1
            if i % 50 == 0 then task.wait() end
        end
    end
end)

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

rs.Heartbeat:Connect(function()
    if toggles.LowVisuals ~= lastLowVisuals then
        lastLowVisuals = toggles.LowVisuals
        applyLowVisuals(toggles.LowVisuals)
    end
end)

-- Instance Optimizer
task.spawn(function()
    while true do
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
rs.Heartbeat:Connect(function()
    if toggles.ParticleCap ~= lastParticleCap then
        lastParticleCap = toggles.ParticleCap
        applyParticleCap(toggles.ParticleCap)
    end
end)

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
rs.Heartbeat:Connect(function()
    if toggles.UltraPotato ~= lastUltraPotato then
        lastUltraPotato = toggles.UltraPotato
        applyUltraPotato(toggles.UltraPotato)
    end
end)

-- F1 Deep Clean
uis.InputBegan:Connect(function(input, gpe)
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
end)
