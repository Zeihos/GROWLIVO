-- GROWLIVO / UTC Starfall event HUD / Alpha 0.9.14
-- StarterPlayer > StarterPlayerScripts > GrowlivoEventUI [LocalScript]
-- Displays only state supplied by the server. Does not grant rewards or modify currency.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("GROWLIVO_Remotes")
local action = remotes:WaitForChild("Action")
local eventState = remotes:WaitForChild("EventState")
local GOLD = Color3.fromRGB(255, 207, 77)
local SKY = Color3.fromRGB(73, 206, 255)
local NAVY = Color3.fromRGB(17, 32, 57)
local DARK = Color3.fromRGB(9, 19, 37)
local WHITE = Color3.fromRGB(242, 248, 255)
local MUTED = Color3.fromRGB(170, 193, 216)
local gui = Instance.new("ScreenGui")
gui.Name = "GROWLIVO_Starfall"
gui.ResetOnSpawn = false
gui.DisplayOrder = 11
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")
local function round(frame, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 12)
    corner.Parent = frame
end
local function label(parent, caption, size, color)
    local result = Instance.new("TextLabel")
    result.Text = caption
    result.BackgroundTransparency = 1
    result.Font = Enum.Font.GothamBold
    result.TextSize = size
    result.TextWrapped = true
    result.TextColor3 = color or WHITE
    result.Parent = parent
    return result
end
local function button(parent, text, background)
    local result = Instance.new("TextButton")
    result.Text = text
    result.TextWrapped = true
    result.Font = Enum.Font.GothamBold
    result.TextColor3 = DARK
    result.TextSize = 14
    result.BackgroundColor3 = background or GOLD
    result.BorderSizePixel = 0
    result.Parent = parent
    round(result, 12)
    return result
end
local opener = button(gui, "✦ СОБЫТИЕ", SKY)
opener.Name = "StarfallButton"
opener.Size = UDim2.fromOffset(155, 43)
opener.Visible = false

local backdrop = Instance.new("Frame")
backdrop.Name = "Backdrop"
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
backdrop.BackgroundTransparency = 0.36
backdrop.Active = true
backdrop.Visible = false
backdrop.Parent = gui
local panel = Instance.new("Frame")
panel.Name = "StarfallPanel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.new(1, -24, 0, 345)
panel.BackgroundColor3 = NAVY
panel.BorderSizePixel = 0
panel.Parent = backdrop
round(panel, 18)
local constraint = Instance.new("UISizeConstraint")
constraint.MaxSize = Vector2.new(465, 365)
constraint.MinSize = Vector2.new(255, 265)
constraint.Parent = panel
local panelScale = Instance.new("UIScale")
panelScale.Scale = 1
panelScale.Parent = panel
local stroke = Instance.new("UIStroke")
stroke.Color = GOLD
stroke.Thickness = 2
stroke.Parent = panel
local title = label(panel, "✦ ЗВЁЗДНЫЙ ДОЖДЬ", 21, GOLD)
title.Position = UDim2.fromOffset(15, 13)
title.Size = UDim2.new(1, -70, 0, 40)
local close = button(panel, "✕", GOLD)
close.Position = UDim2.new(1, -52, 0, 12)
close.Size = UDim2.fromOffset(38, 36)
local description = label(panel, "", 14, WHITE)
description.Position = UDim2.fromOffset(17, 63)
description.Size = UDim2.new(1, -34, 0, 66)
local timerLabel = label(panel, "", 18, SKY)
timerLabel.Position = UDim2.fromOffset(17, 133)
timerLabel.Size = UDim2.new(1, -34, 0, 38)
local barBack = Instance.new("Frame")
barBack.Position = UDim2.fromOffset(17, 185)
barBack.Size = UDim2.new(1, -34, 0, 19)
barBack.BackgroundColor3 = Color3.fromRGB(39, 58, 80)
barBack.BorderSizePixel = 0
barBack.Parent = panel
round(barBack, 8)
local barFill = Instance.new("Frame")
barFill.Size = UDim2.fromScale(0, 1)
barFill.BackgroundColor3 = GOLD
barFill.BorderSizePixel = 0
barFill.Parent = barBack
round(barFill, 8)
local progressLabel = label(panel, "", 15, WHITE)
progressLabel.Position = UDim2.fromOffset(17, 214)
progressLabel.Size = UDim2.new(1, -34, 0, 32)
local claim = button(panel, "ЗАБРАТЬ НАГРАДУ", GOLD)
claim.Position = UDim2.fromOffset(17, 261)
claim.Size = UDim2.new(1, -34, 0, 48)
local foot = label(panel, "Прогресс события сбрасывается в 00:00 UTC", 11, MUTED)
foot.Position = UDim2.fromOffset(17, 317)
foot.Size = UDim2.new(1, -34, 0, 19)

local latest = nil
local receivedAt = 0
local function clock(seconds)
    local left = math.max(0, math.floor(seconds))
    return string.format("%02d:%02d", math.floor(left / 60), left % 60)
end
local function draw()
    if not latest then return end
    local secondsLeft = math.max(0, latest.SecondsLeft - (os.clock() - receivedAt))
    -- Server is authoritative; ask for fresh state when the local estimate expires.
    local active = latest.Active and secondsLeft > 0
    local progress = math.clamp(latest.Progress or 0, 0, latest.Goal or 60)
    local goal = math.max(1, latest.Goal or 60)
    local ready = progress >= goal and not latest.Claimed
    opener.Text = ready and "✦ ЗАБРАТЬ ПРИЗ" or (active and ("✦ БОНУС x" .. tostring(latest.Multiplier)) or "✦ СОБЫТИЕ")
    if active then
        description.Text = "Пока идёт событие, каждый принятый сервером клик приносит в "
            .. tostring(latest.Multiplier) .. " раза больше очков!"
        timerLabel.Text = "До окончания: " .. clock(secondsLeft)
    else
        description.Text = "Во время события сделай " .. tostring(goal) .. " кликов и получи награду."
        timerLabel.Text = "До начала: " .. clock(secondsLeft)
    end
    progressLabel.Text = string.format("Прогресс: %d / %d  •  +%d кликов и +%d 💎",
        progress, goal, latest.RewardClicks or 0, latest.RewardGems or 0)
    barFill.Size = UDim2.fromScale(progress / goal, 1)
    claim.Visible = true
    claim.Active = ready
    claim.AutoButtonColor = ready
    claim.BackgroundColor3 = ready and GOLD or Color3.fromRGB(90, 108, 126)
    claim.Text = latest.Claimed and "НАГРАДА ПОЛУЧЕНА" or (ready and "ЗАБРАТЬ НАГРАДУ" or "ПРОДОЛЖАЙ ИГРАТЬ")
end
local function request()
    if player:GetAttribute("DataReady") == true then
        action:FireServer("GetEvent")
    end
end
eventState.OnClientEvent:Connect(function(payload)
    if typeof(payload) ~= "table" then return end
    if typeof(payload.Active) ~= "boolean" or typeof(payload.SecondsLeft) ~= "number"
        or typeof(payload.Goal) ~= "number" or typeof(payload.Progress) ~= "number"
        or typeof(payload.Claimed) ~= "boolean" then return end
    if payload.Goal < 1 or payload.Goal > 100000 or payload.SecondsLeft < 0 then return end
    latest = payload
    receivedAt = os.clock()
    -- The layout owns opener visibility: don't resurrect it while the
    -- compact landscape navigation menu is closed.
    draw()
end)
opener.Activated:Connect(function()
    backdrop.Visible = not backdrop.Visible
    if backdrop.Visible then request() end
    draw()
end)
close.Activated:Connect(function() backdrop.Visible = false end)
claim.Activated:Connect(function()
    if latest and latest.Progress >= latest.Goal and not latest.Claimed then
        claim.Active = false
        action:FireServer("ClaimEvent")
        task.delay(0.8, request)
    end
end)
local function compactNavigationVisible(w, h)
    return w >= 700 or h >= 500 or player:GetAttribute("CompactMenuOpen") == true
end
local function layout()
    local camera = workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize or Vector2.new(1100, 720)
    local w, h = viewport.X, viewport.Y
    opener.Visible = compactNavigationVisible(w, h)
    panelScale.Scale = h < 395 and math.clamp((h - 25) / 345, 0.67, 1) or 1
    if w < 700 then
        local navY = h < 650 and 163 or 187
        opener.Position = UDim2.fromOffset(12, navY + 147)
        opener.Size = UDim2.fromOffset(math.min(155, math.max(115, w / 2 - 24)), 40)
        panel.Size = UDim2.new(1, -24, 0, 345)
        title.TextSize = 17
    else
        opener.Position = UDim2.fromOffset(18, 494)
        opener.Size = UDim2.fromOffset(185, 45)
        panel.Size = UDim2.fromOffset(465, 345)
        title.TextSize = 21
    end
end
layout()
local viewportConnection
local function attachCamera()
    if viewportConnection then viewportConnection:Disconnect() end
    viewportConnection = nil
    layout()
    local camera = workspace.CurrentCamera
    if camera then
        viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
    end
end
attachCamera()
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(attachCamera)
player:GetAttributeChangedSignal("DataReady"):Connect(request)
if player:GetAttribute("DataReady") == true then request() end
-- Render locally at one Hz and resync after clock boundary/server packet loss.
task.spawn(function()
    local tickCount = 0
    while gui.Parent do
        task.wait(1)
        tickCount += 1
        if latest then draw() end
        if tickCount % 25 == 0 or (latest and os.clock() - receivedAt > latest.SecondsLeft) then
            request()
        end
    end
end)

player:GetAttributeChangedSignal("CompactMenuOpen"):Connect(layout)
