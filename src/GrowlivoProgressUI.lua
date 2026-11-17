-- GROWLIVO / Worlds, quests, daily rewards, achievements / Alpha 0.9.14
-- StarterPlayer > StarterPlayerScripts > GrowlivoProgressUI [LocalScript]
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local Config = require(RS:WaitForChild("GrowlivoConfig"))
local remotes = RS:WaitForChild("GROWLIVO_Remotes")
local Action = remotes:WaitForChild("Action")
local ProgressState = remotes:WaitForChild("ProgressState")
local OpenWorldMenu = remotes:WaitForChild("OpenWorldMenu")

local GOLD, BLUE = Color3.fromRGB(255, 201, 68), Color3.fromRGB(48, 211, 253)
local DARK, PANEL = Color3.fromRGB(11, 25, 46), Color3.fromRGB(25, 41, 70)
local WHITE, MUTED = Color3.fromRGB(238, 249, 255), Color3.fromRGB(169, 199, 221)
local gui = Instance.new("ScreenGui")
gui.Name = "GROWLIVO_ProgressUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 0
gui.Parent = player:WaitForChild("PlayerGui")

local function corner(element, amount)
    local child = Instance.new("UICorner")
    child.CornerRadius = UDim.new(0, amount or 12)
    child.Parent = element
end
local function makeFrame(name, parent, background, z)
    local element = Instance.new("Frame")
    element.Name = name
    element.BackgroundColor3 = background or PANEL
    element.BorderSizePixel = 0
    element.ZIndex = z or 1
    element.Parent = parent
    corner(element)
    return element
end
local function makeText(name, parent, caption, size, color, z)
    local label = Instance.new("TextLabel")
    label.Name = name
    label.BackgroundTransparency = 1
    label.Text = caption
    label.Font = Enum.Font.GothamBold
    label.TextSize = size or 14
    label.TextWrapped = true
    label.TextColor3 = color or WHITE
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.ZIndex = z or 1
    label.Parent = parent
    return label
end
local function makeButton(name, parent, caption, color, z)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Text = caption
    button.Font = Enum.Font.GothamBold
    button.TextSize = 14
    button.TextWrapped = true
    button.TextColor3 = DARK
    button.BackgroundColor3 = color or BLUE
    button.BorderSizePixel = 0
    button.ZIndex = z or 1
    button.Parent = parent
    corner(button, 10)
    return button
end
local function nice(n)
    n = tonumber(n) or 0
    if n >= 1000000 then return string.format("%.1fM", n / 1000000) end
    if n >= 1000 then return string.format("%.1fK", n / 1000) end
    return tostring(math.floor(n))
end
local function send(name, arg)
    if player:GetAttribute("DataReady") then Action:FireServer(name, arg) end
end

local worldButton = makeButton("Worlds", gui, "🌍 МИРЫ", BLUE)
local questButton = makeButton("Quests", gui, "📜 ЗАДАНИЯ", GOLD)
local badgesButton = makeButton("Achievements", gui, "🏆 НАГРАДЫ", BLUE)

local shade = makeFrame("Shade", gui, Color3.new(0, 0, 0), 20)
shade.BackgroundTransparency = 0.25
shade.Size = UDim2.fromScale(1, 1)
shade.Visible = false
shade.Active = true
local modal = makeFrame("Panel", shade, PANEL, 21)
modal.AnchorPoint = Vector2.new(0.5, 0.5)
modal.Position = UDim2.fromScale(0.5, 0.5)
local rim = Instance.new("UIStroke")
rim.Color = GOLD
rim.Thickness = 2
rim.Parent = modal
local heading = makeText("Heading", modal, "", 22, GOLD, 22)
heading.Position = UDim2.fromOffset(16, 8)
heading.Size = UDim2.new(1, -86, 0, 45)
local close = makeButton("Close", modal, "✕", GOLD, 22)
close.AnchorPoint = Vector2.new(1, 0)
close.Position = UDim2.new(1, -10, 0, 10)
close.Size = UDim2.fromOffset(43, 37)

local scroll = Instance.new("ScrollingFrame")
scroll.Name = "Entries"
scroll.Position = UDim2.new(0, 12, 0, 62)
scroll.Size = UDim2.new(1, -24, 1, -75)
scroll.CanvasSize = UDim2.fromOffset(0, 0)
scroll.ScrollBarThickness = 5
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ZIndex = 22
scroll.Parent = modal
local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 4)
padding.PaddingBottom = UDim.new(0, 6)
padding.PaddingRight = UDim.new(0, 6)
padding.Parent = scroll
local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 9)
layout.Parent = scroll
layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    scroll.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 20)
end)

local state = nil
local page = "worlds"
local function row(name, label, details, buttonCaption, action, index)
    local card = makeFrame(name, scroll, DARK, 23)
    card.Size = UDim2.new(1, -4, 0, 103)
    card.LayoutOrder = index
    local top = makeText("Name", card, label, 15, GOLD, 24)
    top.Position = UDim2.fromOffset(12, 7)
    top.Size = UDim2.new(1, -24, 0, 32)
    local bottom = makeText("Details", card, details, 12, MUTED, 24)
    bottom.Position = UDim2.fromOffset(12, 42)
    bottom.Size = UDim2.new(0.61, -12, 0, 53)
    if buttonCaption then
        local execute = makeButton("Action", card, buttonCaption, BLUE, 24)
        execute.AnchorPoint = Vector2.new(1, 0.5)
        execute.Position = UDim2.new(1, -9, 0.66, 0)
        execute.Size = UDim2.new(0.34, 0, 0, 43)
        execute.TextSize = 12
        execute.Activated:Connect(action)
    end
    return card
end
local function repaint()
    if not shade.Visible then return end
    for _, child in ipairs(scroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    if not state then
        heading.Text = "ЗАГРУЗКА..."
        row("Wait", "Ожидаем профиль", "Если нет сохранений, игра запустится во временном режиме.", nil, nil, 1)
        return
    end
    if page == "worlds" then
        heading.Text = "🌍 МИРЫ GROWLIVO"
        for i, world in ipairs(Config.Worlds) do
            local unlocked = world.Id == "SkyCrown" or state.UnlockedWorlds[world.Id] == true
            local current = state.World == world.Id
            local details
            if not unlocked then
                details = "Требуется: " .. world.UnlockRebirths .. " перерожд. и " .. world.UnlockGems .. " 💎"
            else
                details = current and "Ты находишься в этом мире" or "Открыт • Можно переместиться"
            end
            local actionLabel = nil
            if not current then actionLabel = unlocked and "ПЕРЕЙТИ" or "ОТКРЫТЬ" end
            row(world.Id, world.Name .. "  •  клики x" .. world.Multiplier, details, actionLabel, function()
                send(unlocked and "Travel" or "UnlockWorld", world.Id)
            end, i)
        end
    elseif page == "quests" then
        heading.Text = "📜 ЗАДАНИЯ / " .. state.Day
        row("Daily", "🎁 Подарок за вход", "+" .. nice(Config.DailyReward.Clicks) .. " кликов и +" .. Config.DailyReward.Gems .. " 💎\nРаз в сутки (UTC)",
            not state.DailyClaimed and "ПОЛУЧИТЬ" or nil, function() send("ClaimDaily") end, 0)
        for i, quest in ipairs(Config.Quests) do
            local entry = state.Quests[quest.Id] or {Progress = 0, Claimed = false}
            row(quest.Id, quest.Name, nice(entry.Progress) .. "/" .. nice(quest.Goal) .. "  •  +" .. quest.Gems .. " 💎" .. (entry.Claimed and "\nВыполнено" or ""),
                (entry.Progress >= quest.Goal and not entry.Claimed) and "ЗАБРАТЬ" or nil,
                function() send("ClaimQuest", quest.Id) end, i)
        end
        row("WeekHeader", "📅 НЕДЕЛЯ / с " .. tostring(state.WeeklyWeek or "—"),
            "Новый набор с понедельника, 00:00 UTC", nil, nil, #Config.Quests + 1)
        for i, quest in ipairs(Config.WeeklyQuests) do
            local entry = (state.WeeklyQuests or {})[quest.Id] or {Progress = 0, Claimed = false}
            row(quest.Id, quest.Name,
                nice(entry.Progress) .. "/" .. nice(quest.Goal) .. "  •  +" .. quest.Gems .. " 💎"
                    .. (entry.Claimed and "\nПолучено" or ""),
                (entry.Progress >= quest.Goal and not entry.Claimed) and "ЗАБРАТЬ" or nil,
                function() send("ClaimWeeklyQuest", quest.Id) end, #Config.Quests + i + 1)
        end
    else
        heading.Text = "🏆 ДОСТИЖЕНИЯ"
        for i, item in ipairs(Config.Achievements) do
            local current = math.floor(tonumber(state[item.Stat]) or 0)
            local collected = state.Achievements[item.Id] == true
            row(item.Id, item.Name, nice(math.min(item.Goal, current)) .. "/" .. nice(item.Goal) .. "  •  +" .. item.Gems .. " 💎" .. (collected and "\nПолучено" or ""),
                (current >= item.Goal and not collected) and "ЗАБРАТЬ" or nil,
                function() send("ClaimAchievement", item.Id) end, i)
        end
    end
end
local function open(which)
    player:SetAttribute("CompactMenuOpen", false)
    page = which
    shade.Visible = true
    gui.DisplayOrder = 10
    send("GetProgress")
    repaint()
end
local function compactNavigationVisible(w, h)
    return w >= 700 or h >= 500 or player:GetAttribute("CompactMenuOpen") == true
end
local function petInventoryOpen()
    local hud = player:FindFirstChild("PlayerGui")
    local main = hud and hud:FindFirstChild("GROWLIVO_HUD")
    local backdrop = main and main:FindFirstChild("ModalBackdrop")
    return backdrop ~= nil and backdrop.Visible == true
end
local function resize()
    local camera = workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize or Vector2.new(1024, 768)
    local w, h = viewport.X, viewport.Y
    local visible = compactNavigationVisible(w, h) and not petInventoryOpen()
    worldButton.Visible = visible
    questButton.Visible = visible
    badgesButton.Visible = visible
    if w < 700 then
        local half = (w - 36) / 2
        local navY = h < 650 and 163 or 187
        worldButton.Position = UDim2.fromOffset(12, navY)
        worldButton.Size = UDim2.fromOffset(math.min(half, w - 24 - math.min(w - 24, 162)), 43)
        questButton.Position = UDim2.fromOffset(12, navY + 49)
        questButton.Size = UDim2.fromOffset(half, 43)
        badgesButton.Position = UDim2.fromOffset(24 + half, navY + 49)
        badgesButton.Size = UDim2.fromOffset(half, 43)
        modal.Size = UDim2.new(1, -24, 0, math.min(h - 24, 590))
        heading.TextSize = 17
    else
        for i, button in ipairs({worldButton, questButton, badgesButton}) do
            button.Position = UDim2.fromOffset(18, 204 + (i - 1) * 58)
            button.Size = UDim2.fromOffset(245, 49)
        end
        modal.Size = UDim2.fromOffset(math.min(w - 90, 550), math.min(h - 80, 610))
        heading.TextSize = 22
    end
end
worldButton.Activated:Connect(function() open("worlds") end)
questButton.Activated:Connect(function() open("quests") end)
badgesButton.Activated:Connect(function() open("badges") end)
OpenWorldMenu.OnClientEvent:Connect(function() open("worlds") end)
close.Activated:Connect(function()
    shade.Visible = false
    gui.DisplayOrder = 0
end)
ProgressState.OnClientEvent:Connect(function(payload)
    if typeof(payload) ~= "table" then return end
    if typeof(payload.Quests) ~= "table" or typeof(payload.UnlockedWorlds) ~= "table" then return end
    state = payload
    repaint()
end)
player:GetAttributeChangedSignal("DataReady"):Connect(function()
    if player:GetAttribute("DataReady") then send("GetProgress") end
end)
resize()
if player:GetAttribute("DataReady") then send("GetProgress") end
local viewportConnection
local function attachCamera()
    if viewportConnection then viewportConnection:Disconnect() end
    viewportConnection = nil
    resize()
    local camera = workspace.CurrentCamera
    if camera then
        viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(resize)
    end
end
attachCamera()
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(attachCamera)
-- Avoid blocking the pet inventory GUI when the separate HUD's modal is open.
task.spawn(function()
    local hud = player:WaitForChild("PlayerGui"):WaitForChild("GROWLIVO_HUD", 30)
    if not hud then return end
    local petsBackdrop = hud:WaitForChild("ModalBackdrop", 30)
    if not petsBackdrop then return end
    local function checkPetModal()
        if petsBackdrop.Visible then
            shade.Visible = false
            gui.DisplayOrder = 0
        end
        -- Respect both the compact-menu state and the pet inventory overlay.
        resize()
    end
    petsBackdrop:GetPropertyChangedSignal("Visible"):Connect(checkPetModal)
    checkPetModal()
end)

player:GetAttributeChangedSignal("CompactMenuOpen"):Connect(resize)
