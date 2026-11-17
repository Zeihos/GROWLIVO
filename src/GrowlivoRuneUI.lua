-- GROWLIVO / Rune compass & expedition HUD / Alpha 0.9.22
-- Passive client UI; all eligibility, world selection, and rune rewards remain server-authoritative.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("GrowlivoConfig"))
local trial = Config.RuneTrial
local gui = Instance.new("ScreenGui")
gui.Name = "GROWLIVO_RuneUI"
gui.ResetOnSpawn = false
gui.DisplayOrder = 3
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local NAVY = Color3.fromRGB(15, 31, 54)
local TEAL = Color3.fromRGB(108, 237, 206)
local PALE = Color3.fromRGB(236, 250, 255)
local MUTED = Color3.fromRGB(166, 190, 207)
local panel = Instance.new("Frame")
panel.Name = "RuneStatus"
panel.AnchorPoint = Vector2.new(0.5, 1)
panel.BackgroundColor3 = NAVY
panel.BackgroundTransparency = 0.08
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = gui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = panel
local rim = Instance.new("UIStroke")
rim.Color = TEAL
rim.Thickness = 1
rim.Parent = panel

local heading = Instance.new("TextLabel")
heading.Name = "Heading"
heading.BackgroundTransparency = 1
heading.Font = Enum.Font.GothamBold
heading.TextSize = 14
heading.TextColor3 = PALE
heading.TextXAlignment = Enum.TextXAlignment.Left
heading.Position = UDim2.fromOffset(11, 5)
heading.Size = UDim2.new(1, -42, 0, 20)
heading.Parent = panel

local toggle = Instance.new("TextButton")
toggle.Name = "ToggleCompass"
toggle.AnchorPoint = Vector2.new(1, 0)
toggle.Position = UDim2.new(1, -5, 0, 5)
toggle.Size = UDim2.fromOffset(31, 25)
toggle.BackgroundTransparency = 1
toggle.TextColor3 = TEAL
toggle.Font = Enum.Font.GothamBold
toggle.TextSize = 19
toggle.Parent = panel

local details = Instance.new("TextLabel")
details.Name = "RuneProgress"
details.BackgroundTransparency = 1
details.Font = Enum.Font.GothamMedium
details.TextSize = 13
details.TextColor3 = MUTED
details.TextXAlignment = Enum.TextXAlignment.Left
details.TextWrapped = true
details.Position = UDim2.fromOffset(11, 28)
details.Size = UDim2.new(1, -22, 0, 41)
details.Parent = panel

-- World-space marker is a client-only BillboardGui; it never modifies the shrine.
local marker = Instance.new("BillboardGui")
marker.Name = "RuneWaypoint"
marker.Size = UDim2.fromOffset(148, 41)
marker.StudsOffsetWorldSpace = Vector3.new(0, 7, 0)
marker.AlwaysOnTop = true
marker.MaxDistance = 120
marker.Enabled = false
marker.Parent = gui
local markerLabel = Instance.new("TextLabel")
markerLabel.Size = UDim2.fromScale(1, 1)
markerLabel.BackgroundColor3 = NAVY
markerLabel.BackgroundTransparency = 0.1
markerLabel.Font = Enum.Font.GothamBold
markerLabel.TextSize = 13
markerLabel.TextColor3 = TEAL
markerLabel.TextStrokeTransparency = 0.65
markerLabel.Parent = marker
local markerCorner = Instance.new("UICorner")
markerCorner.CornerRadius = UDim.new(0, 9)
markerCorner.Parent = markerLabel

local expanded = true
local viewHeight = 600
local viewWidth = 900
local function resize()
    local camera = workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize or Vector2.new(900, 600)
    viewWidth, viewHeight = viewport.X, viewport.Y
    local narrow = viewWidth < 500
    local width = math.min(narrow and 246 or 295, math.max(175, viewWidth - 20))
    panel.Size = UDim2.fromOffset(width, expanded and 73 or 34)
    -- Keep clear of the bottom-center click button, including on shorter screens.
    panel.Position = UDim2.new(0.5, 0, 1, viewHeight < 550 and -191 or -235)
    details.Visible = expanded
    toggle.Text = expanded and "⌃" or "⌄"
end

toggle.Activated:Connect(function()
    expanded = not expanded
    resize()
end)

local function wasCollected(mask, index)
    return math.floor(mask / (2 ^ (index - 1))) % 2 == 1
end

local shrineGroup = nil
local shrineMap = {}
local function findShrines()
    local model = workspace:FindFirstChild("GROWLIVO_World")
    local group = model and model:FindFirstChild("09_RUNE_EXPEDITIONS")
    if group == shrineGroup then return end
    shrineGroup = group
    table.clear(shrineMap)
    if not group then return end
    for _, pedestal in ipairs(group:GetChildren()) do
        if pedestal:IsA("BasePart") and pedestal.Name == "RunePedestal" then
            local id, index = pedestal:GetAttribute("RuneWorld"), pedestal:GetAttribute("RuneIndex")
            if type(id) == "string" and type(index) == "number" and index >= 1 and index <= trial.Required then
                shrineMap[id] = shrineMap[id] or {}
                shrineMap[id][index] = pedestal
            end
        end
    end
end

local function update()
    if player:GetAttribute("DataReady") ~= true then
        panel.Visible = false
        marker.Enabled = false
        marker.Adornee = nil
        return
    end
    local worldId = player:GetAttribute("World")
    local worldConfig = Config.FindWorld(worldId)
    if not worldConfig then
        panel.Visible = false
        marker.Enabled = false
        marker.Adornee = nil
        return
    end
    panel.Visible = true
    local now = workspace:GetServerTimeNow()
    local boostUntil = tonumber(player:GetAttribute("RuneBoostUntil")) or 0
    local cooldownUntil = tonumber(player:GetAttribute("RuneCooldownUntil")) or 0
    local boostMultiplier = tonumber(player:GetAttribute("RuneBoostMultiplier")) or 1
    local count = math.clamp(tonumber(player:GetAttribute("RuneCount")) or 0, 0, trial.Required)
    local mask = math.clamp(math.floor(tonumber(player:GetAttribute("RuneMask")) or 0), 0, 2 ^ trial.Required - 1)
    local boostActive = boostUntil > now and boostMultiplier > 1
    local cooling = cooldownUntil > now
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    findShrines()
    local target, nearestDistance, nearestIndex
    if not cooling and root then
        for index = 1, trial.Required do
            local pedestal = shrineMap[worldId] and shrineMap[worldId][index]
            if pedestal and pedestal.Parent and not wasCollected(mask, index) then
                local distance = (root.Position - pedestal.Position).Magnitude
                if not nearestDistance or distance < nearestDistance then
                    target, nearestIndex, nearestDistance = pedestal, index, distance
                end
            end
        end
    end
    marker.Enabled = target ~= nil and expanded and player:GetAttribute("SettingEffects") ~= false
    marker.Adornee = marker.Enabled and target or nil
    if marker.Enabled then
        markerLabel.Text = string.format("◆ РУНА %d • %d м", nearestIndex, math.floor(nearestDistance + 0.5))
    end
    if boostActive then
        heading.Text = string.format("✦ РУНЫ ×%d • %d сек.", boostMultiplier, math.ceil(boostUntil - now))
    elseif cooling then
        heading.Text = "◆ Руны • отдых " .. math.ceil(cooldownUntil - now) .. " сек."
    else
        heading.Text = "◆ Руны • " .. worldConfig.Name
    end
    local icons = {}
    for index = 1, trial.Required do
        table.insert(icons, wasCollected(mask, index) and "✓" or "◇")
    end
    local indicator = table.concat(icons, "   ")
    if boostActive then
        details.Text = indicator .. "  •  бонус активен\nМир: " .. worldConfig.Name
    elseif cooling then
        details.Text = indicator .. "  •  испытание завершено\nСледующая попытка после восстановления"
    elseif nearestDistance then
        details.Text = string.format("%s  •  собрано %d/%d\nК руне %d: %d м (клавиша E)", indicator, count, trial.Required, nearestIndex, math.floor(nearestDistance + 0.5))
    else
        details.Text = indicator .. "  •  исследуй остров\nАктивируй три разные руны"
    end
end

for _, name in ipairs({"RuneMask", "RuneCount", "RuneBoostUntil", "RuneBoostMultiplier", "RuneCooldownUntil", "DataReady", "World", "SettingEffects"}) do
    player:GetAttributeChangedSignal(name):Connect(update)
end
resize()
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(resize)
-- Low-cost refresh: no RenderStepped loop and only nine possible shrines.
task.spawn(function()
    local lastSizeCheck = 0
    while gui.Parent do
        update()
        if os.clock() - lastSizeCheck > 2 then
            resize()
            lastSizeCheck = os.clock()
        end
        task.wait(0.5)
    end
end)
