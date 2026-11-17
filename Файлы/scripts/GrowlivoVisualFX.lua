-- GROWLIVO / Local visual-only tap & reward effects / Alpha 0.9.14
-- StarterPlayer > StarterPlayerScripts > GrowlivoVisualFX [LocalScript]
-- Never grants currency: only reacts to a local tap signal and server-authored rewards.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("GrowlivoConfig"))
local remotes = ReplicatedStorage:WaitForChild("GROWLIVO_Remotes")
local visuals = remotes:WaitForChild("VisualEvent")
local hud = player:WaitForChild("PlayerGui"):WaitForChild("GROWLIVO_HUD")
local tap = hud:WaitForChild("Click")
local tapFlash = hud:WaitForChild("TapFlash")
local GOLD = Color3.fromRGB(255, 209, 66)
local SKY = Color3.fromRGB(38, 203, 255)
local NAVY = Color3.fromRGB(13, 28, 51)
local WHITE = Color3.fromRGB(245, 249, 255)

local gui = Instance.new("ScreenGui")
gui.Name = "GROWLIVO_VisualFX"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 50
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local scale = Instance.new("UIScale")
scale.Name = "ClickPulse"
scale.Scale = 1
scale.Parent = tap
local pulses, floating = 0, 0
local function effectsEnabled()
    return player:GetAttribute("SettingEffects") ~= false
end
local function reducedMotion()
    return player:GetAttribute("SettingReducedMotion") == true or GuiService.ReducedMotionEnabled
end
local function floatTap(amount)
    if floating >= 12 or not effectsEnabled() or reducedMotion() then return end
    floating += 1
    local center = tap.AbsolutePosition + tap.AbsoluteSize / 2
    local label = Instance.new("TextLabel")
    label.Name = "FloatingTap"
    label.BackgroundTransparency = 1
    label.AnchorPoint = Vector2.new(0.5, 0.5)
    label.Position = UDim2.fromOffset(center.X + math.random(-24, 24), center.Y - 42)
    label.Size = UDim2.fromOffset(190, 48)
    label.Text = "+" .. tostring(math.floor(tonumber(amount) or 1))
    label.Font = Enum.Font.GothamBlack
    label.TextColor3 = GOLD
    label.TextStrokeTransparency = 0.25
    label.TextSize = 29
    label.ZIndex = 4
    label.Parent = gui
    local tween = TweenService:Create(label, TweenInfo.new(0.65, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
        Position = label.Position - UDim2.fromOffset(0, 65),
        TextTransparency = 1,
        TextStrokeTransparency = 1,
    })
    tween:Play()
    task.delay(0.7, function()
        label:Destroy()
        floating -= 1
    end)
end
local function pulse()
    if not effectsEnabled() or reducedMotion() then return end
    pulses += 1
    local stamp = pulses
    TweenService:Create(scale, TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 0.93}):Play()
    task.delay(0.07, function()
        if stamp ~= pulses then return end
        TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
    end)
end
tapFlash.Event:Connect(function(amount)
    pulse()
    floatTap(amount)
end)

local activeCard = nil
local pendingCards = {}
local activeSerial = 0
local function rewardCard(title, caption, tint)
    if activeCard then
        if #pendingCards < 3 then table.insert(pendingCards, {title, caption, tint}) end
        return
    end
    activeSerial += 1
    local serial = activeSerial
    if activeCard then activeCard:Destroy() end
    local size = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1000, 700)
    local width = math.max(240, math.min(410, size.X - 38))
    local card = Instance.new("Frame")
    card.Name = "RewardCard"
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.Position = UDim2.fromScale(0.5, 0.39)
    card.Size = UDim2.fromOffset(width, 190)
    card.BackgroundColor3 = NAVY
    card.BorderSizePixel = 0
    card.ZIndex = 20
    card.Parent = gui
    activeCard = card
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 24)
    corner.Parent = card
    local outline = Instance.new("UIStroke")
    outline.Thickness = 3
    outline.Color = tint
    outline.Parent = card
    local gradient = Instance.new("UIGradient")
    gradient.Rotation = 28
    gradient.Color = ColorSequence.new(NAVY, Color3.fromRGB(27, 66, 105))
    gradient.Parent = card
    local cardScale = Instance.new("UIScale")
    cardScale.Scale = 0.65
    cardScale.Parent = card
    local heading = Instance.new("TextLabel")
    heading.BackgroundTransparency = 1
    heading.Position = UDim2.new(0, 15, 0, 24)
    heading.Size = UDim2.new(1, -30, 0, 62)
    heading.Text = title
    heading.TextColor3 = tint
    heading.TextWrapped = true
    heading.TextSize = 25
    heading.Font = Enum.Font.GothamBlack
    heading.ZIndex = 21
    heading.Parent = card
    local detail = Instance.new("TextLabel")
    detail.BackgroundTransparency = 1
    detail.Position = UDim2.new(0, 16, 0, 96)
    detail.Size = UDim2.new(1, -32, 0, 67)
    detail.Text = caption
    detail.TextColor3 = WHITE
    detail.TextWrapped = true
    detail.TextSize = 16
    detail.Font = Enum.Font.GothamBold
    detail.ZIndex = 21
    detail.Parent = card
    if effectsEnabled() and not reducedMotion() then
        TweenService:Create(cardScale, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
    else
        cardScale.Scale = 1
    end
    for i = 1, (effectsEnabled() and not reducedMotion()) and 14 or 0 do
        local confetti = Instance.new("Frame")
        confetti.Name = "Confetti"
        confetti.AnchorPoint = Vector2.new(0.5, 0.5)
        confetti.Size = UDim2.fromOffset(math.random(5, 12), math.random(7, 17))
        confetti.Position = UDim2.fromScale(0.5, 0.39)
        confetti.Rotation = math.random(0, 180)
        confetti.BorderSizePixel = 0
        confetti.BackgroundColor3 = i % 2 == 0 and tint or SKY
        confetti.ZIndex = 22
        confetti.Parent = gui
        local mx = math.random(-190, 190)
        local my = math.random(-170, 125)
        TweenService:Create(confetti, TweenInfo.new(0.95, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            Position = UDim2.new(0.5, mx, 0.39, my),
            Rotation = confetti.Rotation + math.random(100, 330),
            BackgroundTransparency = 1,
        }):Play()
        task.delay(1.05, function() confetti:Destroy() end)
    end
    task.delay(2.4, function()
        if serial ~= activeSerial or activeCard ~= card then return end
        TweenService:Create(cardScale, TweenInfo.new(0.23, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Scale = 0.78}):Play()
        TweenService:Create(card, TweenInfo.new(0.23), {BackgroundTransparency = 1}):Play()
        task.delay(0.25, function()
            if activeCard == card then activeCard = nil end
            card:Destroy()
            local nextCard = table.remove(pendingCards, 1)
            if nextCard then rewardCard(nextCard[1], nextCard[2], nextCard[3]) end
        end)
    end)
end

visuals.OnClientEvent:Connect(function(event)
    if typeof(event) ~= "table" or typeof(event.Type) ~= "string" then return end
    if event.Type == "EventReward" then
        rewardCard("✦ ЗВЁЗДНЫЙ ДОЖДЬ!", "+500 кликов и +20 кристаллов. Награда получена!", SKY)
    elseif event.Type == "WeeklyReward" then
        rewardCard("📅 НЕДЕЛЬНОЕ ЗАДАНИЕ!", "Кристаллы за недельный прогресс получены!", GOLD)
    elseif event.Type == "WorldChest" then
        local reward = Config.WorldChests[event.World]
        if reward then
            rewardCard("🎁 СУНДУК МИРА!", "+" .. reward.Clicks .. " кликов и +" .. reward.Gems .. " кристаллов!", GOLD)
        end
    elseif event.Type == "RuneComplete" then
        rewardCard("🔮 ИСПЫТАНИЕ РУН!", "Сила кликов ×2 на 75 секунд!", SKY)
    elseif event.Type == "Fusion" then
        local pet = Config.FindPet(event.Species)
        if pet then
            rewardCard("✨ СЛИЯНИЕ ПИТОМЦЕВ!", "Получен: " .. pet.Name .. " • бонус +" .. pet.Bonus .. "%", pet.Color)
        end
    elseif event.Type == "Rebirth" then
        rewardCard("🔄 ПЕРЕРОЖДЕНИЕ!", "Новая ступень силы. Получены кристаллы!", GOLD)
    elseif event.Type == "WorldUnlock" then
        local world = Config.FindWorld(event.World)
        if world then rewardCard("🌍 МИР ОТКРЫТ!", world.Name .. " • Клики x" .. world.Multiplier, SKY) end
    elseif event.Type == "TutorialStep" and event.Step == 4 then
        rewardCard("👑 ОБУЧЕНИЕ ПРОЙДЕНО!", "+200 кликов и +5 кристаллов. Добро пожаловать в GROWLIVO!", GOLD)
    end
end)
