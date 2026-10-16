local ws = game:GetService("Workspace")
local rs = game:GetService("RunService")
local uis = game:GetService("UserInputService")
local pps = game:GetService("ProximityPromptService")
local plrs = game:GetService("Players")
local lighting = game:GetService("Lighting")
local cg = game:GetService("CoreGui")

local cam = ws.CurrentCamera
local lplr = plrs.LocalPlayer

local toggles = {
    AimAssist = false,
    ESP = false,
    EnemyHP = false,
    PlayerESP = false,
    ItemESP = false,
    Crosshair = true,
    Noclip = false,
    Hitboxes = false,
    Fullbright = false,
    InstantInteract = false,
    DelCorpses = false,
    Speed = false,
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

-- GUI Setup
local oldGui = cg:FindFirstChild("OmniMenu")
if oldGui then
    oldGui:Destroy()
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
main.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
main.BorderSizePixel = 0
main.Position = UDim2.new(0.05, 0, 0.2, 0)
main.Size = UDim2.new(0.2, 0, 0.6, 0)
main.Active = true
main.Draggable = true
main.ClipsDescendants = true

local sizeConstraint = Instance.new("UISizeConstraint")
sizeConstraint.Parent = main
sizeConstraint.MinSize = Vector2.new(150, 250)
sizeConstraint.MaxSize = Vector2.new(250, 600)

local title = Instance.new("TextLabel")
title.Parent = main
title.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
title.Size = UDim2.new(1, 0, 0, 30)
title.Font = Enum.Font.GothamBold
title.Text = "HRSH"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextSize = 14
title.ZIndex = 20

local minBtn = Instance.new("TextButton")
minBtn.Parent = main
minBtn.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
minBtn.Position = UDim2.new(1, -30, 0, 0)
minBtn.Size = UDim2.new(0, 30, 0, 30)
minBtn.Font = Enum.Font.GothamBold
minBtn.Text = "-"
minBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
minBtn.TextSize = 16
minBtn.BorderSizePixel = 0
minBtn.ZIndex = 30
minBtn.AutoButtonColor = true

local scroll = Instance.new("ScrollingFrame")
scroll.Name = "Scroll"
scroll.Parent = main
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.Position = UDim2.new(0, 0, 0, 35)
scroll.Size = UDim2.new(1, 0, 1, -35)
scroll.CanvasSize = UDim2.new(0, 0, 0, 950)
scroll.ScrollBarThickness = 3
scroll.ScrollBarImageTransparency = 0.15
scroll.ScrollingEnabled = true
scroll.ZIndex = 5

local layout = Instance.new("UIListLayout")
layout.Parent = scroll
layout.Padding = UDim.new(0, 5)
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.FillDirection = Enum.FillDirection.Vertical

local isMin = false
local origSize = main.Size

minBtn.MouseButton1Click:Connect(function()
    isMin = not isMin
    if isMin then
        origSize = main.Size
        scroll.Visible = false
        title.Visible = false
        main.BackgroundTransparency = 1
        main.ClipsDescendants = false
        main.Size = UDim2.new(0, 30, 0, 30)
        main.Active = false
        minBtn.Text = "+"
        minBtn.BackgroundColor3 = Color3.fromRGB(40, 150, 40)
    else
        main.Size = origSize
        scroll.Visible = true
        title.Visible = true
        main.BackgroundTransparency = 0
        main.ClipsDescendants = true
        main.Active = true
        minBtn.Position = UDim2.new(1, -30, 0, 0)
        minBtn.Text = "-"
        minBtn.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
    end
end)

-- Section label
local function createSection(name)
    local lbl = Instance.new("TextLabel")
    lbl.Parent = scroll
    lbl.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    lbl.Size = UDim2.new(0.9, 0, 0, 24)
    lbl.Font = Enum.Font.GothamBold
    lbl.Text = "— " .. name .. " —"
    lbl.TextColor3 = Color3.fromRGB(180, 180, 180)
    lbl.TextSize = 10
    lbl.BorderSizePixel = 0
    lbl.ZIndex = 6
end

local function createToggle(name, key)
    local b = Instance.new("TextButton")
    b.Parent = scroll
    b.BackgroundColor3 = toggles[key] and Color3.fromRGB(40, 150, 40) or Color3.fromRGB(150, 40, 40)
    b.Size = UDim2.new(0.9, 0, 0, 35)
    b.Font = Enum.Font.Gotham
    b.Text = name .. (toggles[key] and ": ON" or ": OFF")
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.TextSize = 12
    b.BorderSizePixel = 0
    b.ZIndex = 7
    b.AutoButtonColor = true

    b.MouseButton1Click:Connect(function()
        toggles[key] = not toggles[key]
        b.Text = name .. (toggles[key] and ": ON" or ": OFF")
        b.BackgroundColor3 = toggles[key] and Color3.fromRGB(40, 150, 40) or Color3.fromRGB(150, 40, 40)

        if key == "ESP" and not toggles.ESP then
            for _, v in ipairs(ws:GetDescendants()) do
                if v.Name == "NPCHighlight" then v:Destroy() end
            end
        end
    end)
end

local function createSlider(name, minV, maxV, def, cb)
    local container = Instance.new("Frame")
    container.Parent = scroll
    container.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    container.Size = UDim2.new(0.9, 0, 0, 45)
    container.BorderSizePixel = 0
    container.ZIndex = 6

    local lbl = Instance.new("TextLabel")
    lbl.Parent = container
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(1, 0, 0.5, 0)
    lbl.Font = Enum.Font.Gotham
    lbl.Text = name .. ": " .. tostring(def)
    lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    lbl.TextSize = 10
    lbl.ZIndex = 7

    local back = Instance.new("Frame")
    back.Parent = container
    back.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    back.Position = UDim2.new(0.1, 0, 0.6, 0)
    back.Size = UDim2.new(0.8, 0, 0, 8)
    back.BorderSizePixel = 0
    back.ZIndex = 7

    local fill = Instance.new("Frame")
    fill.Parent = back
    fill.BackgroundColor3 = Color3.fromRGB(40, 150, 40)
    fill.Size = UDim2.new((def - minV) / (maxV - minV), 0, 1, 0)
    fill.BorderSizePixel = 0
    fill.ZIndex = 8

    local dragging = false
    local function update(input)
        local pos = math.clamp((input.Position.X - back.AbsolutePosition.X) / back.AbsoluteSize.X, 0, 1)
        fill.Size = UDim2.new(pos, 0, 1, 0)
        local val = minV + (maxV - minV) * pos
        val = math.floor(val * 100) / 100
        lbl.Text = name .. ": " .. tostring(val)
        if cb then cb(val) end
    end

    back.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            update(input)
        end
    end)

    uis.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    uis.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            update(input)
        end
    end)
end

-- General section
createSection("General")
createToggle("Aim Assist", "AimAssist")
createToggle("NPC ESP", "ESP")
createToggle("Enemy HP", "EnemyHP")
createToggle("Player ESP", "PlayerESP")
createToggle("My HP", "SelfHP")
createToggle("Noclip", "Noclip")
createToggle("Item ESP", "ItemESP")
createToggle("Crosshair", "Crosshair")
createToggle("Big Hitboxes", "Hitboxes")
createToggle("Fullbright", "Fullbright")
createToggle("Instant Interact", "InstantInteract")
createToggle("Del Corpses", "DelCorpses")
createToggle("Speed Modifier", "Speed")

-- Sliders
createSection("Settings")
createSlider("Aim Strength", 0.01, 1.0, cfg.aimStrength, function(v) cfg.aimStrength = v end)
createSlider("FOV", 10, 300, cfg.fov, function(v) cfg.fov = v end)
createSlider("Hitbox Size", 1, 20, hitboxCfg.size.X, function(v) hitboxCfg.size = Vector3.new(v, v, v) end)
createSlider("Walk Speed", 1, 100, cfg.speed, function(v) cfg.speed = v end)

-- Optimization section
createSection("Optimization")
createToggle("Low Visuals", "LowVisuals")
createToggle("Instance Optimizer", "InstanceOptimizer")
createToggle("Particle Cap", "ParticleCap")
createToggle("Ultra Potato", "UltraPotato")

-- Explicit canvas height avoids executor/UIListLayout differences.
task.defer(function()
    local contentHeight = layout.AbsoluteContentSize.Y
    scroll.CanvasSize = UDim2.new(0, 0, 0, math.max(950, contentHeight + 10))
end)

-- Toggle menu visibility
uis.InputBegan:Connect(function(input, gpe)
    if not gpe and input.KeyCode == Enum.KeyCode.RightControl then
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
local function addPlayerInfoESP(plr, char)
    if not char then return end

    -- Keep the existing player highlight exactly as-is.
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

    -- Team colors:
    -- BLUE = teammate, RED = enemy, GREEN = neutral/unknown.
    -- Some games do not use Roblox Player.Team, so also check TeamColor
    -- and common custom team/faction attributes.
    local function getTeamKey(player)
        if player.Team then
            return "team:" .. player.Team:GetFullName()
        end

        if player.TeamColor and player.TeamColor ~= BrickColor.new("Medium stone grey") then
            return "color:" .. player.TeamColor.Name
        end

        local attrs = {"Team", "team", "Faction", "faction", "Role", "role"}
        for _, attrName in ipairs(attrs) do
            local value = player:GetAttribute(attrName)
            if value ~= nil then
                return attrName:lower() .. ":" .. tostring(value):lower()
            end
        end

        return nil
    end

    local myTeam = getTeamKey(lplr)
    local playerTeam = getTeamKey(plr)

    if myTeam and playerTeam then
        if myTeam == playerTeam then
            hl.FillColor = Color3.fromRGB(0, 120, 255) -- teammate
        else
            hl.FillColor = Color3.fromRGB(220, 50, 50) -- enemy
        end
    else
        hl.FillColor = Color3.fromRGB(0, 200, 80) -- neutral/unknown
    end

    local head = char:FindFirstChild("Head")
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not head or not hum or not root then return end

    local infoGui = head:FindFirstChild("PlayerInfoESP")
    if not infoGui then
        infoGui = Instance.new("BillboardGui")
        infoGui.Name = "PlayerInfoESP"
        infoGui.Size = UDim2.new(0, 220, 0, 42)
        infoGui.StudsOffset = Vector3.new(0, 3, 0)
        infoGui.AlwaysOnTop = true
        infoGui.MaxDistance = 2000
        infoGui.Parent = head

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

    local label = infoGui:FindFirstChild("Info")
    if not label then return end

    local myChar = lplr.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")

    local distance = 0
    if myRoot then
        distance = math.floor((myRoot.Position - root.Position).Magnitude + 0.5)
    end

    local hp = math.max(0, hum.Health)
    local maxHp = math.max(1, hum.MaxHealth)

    -- Only the requested player information: name, health, distance.
    label.Text = string.format(
        "%s\nHP: %d/%d  |  %d studs",
        plr.Name,
        math.floor(hp + 0.5),
        math.floor(maxHp + 0.5),
        distance
    )
end

local function removePlayerESP(char)
    if not char then return end

    local hl = char:FindFirstChild("PlayerHighlight")
    if hl then hl:Destroy() end

    local head = char:FindFirstChild("Head")
    if head then
        local infoGui = head:FindFirstChild("PlayerInfoESP")
        if infoGui then infoGui:Destroy() end
    end
end

local function applyPlayerESP(state)
    for _, plr in ipairs(plrs:GetPlayers()) do
        if plr == lplr then continue end
        local char = plr.Character
        if not char then continue end

        if state then
            addPlayerInfoESP(plr, char)
        else
            removePlayerESP(char)
        end
    end
end

plrs.PlayerAdded:Connect(function(plr)
    plr.CharacterAdded:Connect(function(char)
        if not toggles.PlayerESP then return end
        task.wait(0.5)
        addPlayerInfoESP(plr, char)
    end)
end)

local lastPlayerESP = false
local lastEnemyHP = false
local enemyHPUpdateTimer = 0

rs.Heartbeat:Connect(function(dt)
    if toggles.PlayerESP ~= lastPlayerESP then
        lastPlayerESP = toggles.PlayerESP
        applyPlayerESP(toggles.PlayerESP)
    end

    if toggles.PlayerESP then
        for _, plr in ipairs(plrs:GetPlayers()) do
            if plr ~= lplr and plr.Character then
                addPlayerInfoESP(plr, plr.Character)
            end
        end
    end

    if toggles.EnemyHP ~= lastEnemyHP then
        lastEnemyHP = toggles.EnemyHP
        if not toggles.EnemyHP then
            for _, npc in ipairs(ws:GetDescendants()) do
                if npc:IsA("Model") then
                    removeEnemyHPESP(npc)
                end
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
        local torso = npc:FindFirstChild(cfg.targetPart)
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
