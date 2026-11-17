-- GROWLIVO / Global top-10 panel / Alpha 0.9.14
-- StarterPlayer > StarterPlayerScripts > GrowlivoLeaderboardUI [LocalScript]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("GROWLIVO_Remotes")
local request = remotes:WaitForChild("RequestBoards")
local boardState = remotes:WaitForChild("BoardState")
local GOLD, BLUE, WHITE = Color3.fromRGB(255, 207, 73), Color3.fromRGB(56, 207, 255), Color3.fromRGB(237, 247, 255)
local PANEL = Color3.fromRGB(18, 31, 58)
local gui = Instance.new("ScreenGui")
gui.Name = "GROWLIVO_LeaderboardUI"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")
local function round(target)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 12)
    c.Parent = target
end
local function label(parent, content, size, color)
    local t = Instance.new("TextLabel")
    t.Size = UDim2.fromScale(1, 1)
    t.BackgroundTransparency = 1
    t.TextColor3 = color or WHITE
    t.Font = Enum.Font.GothamBold
    t.TextSize = size or 16
    t.TextWrapped = true
    t.Text = content
    t.Parent = parent
    return t
end
local function button(parent, name, value, color)
    local b = Instance.new("TextButton")
    b.Name = name
    b.Text = value
    b.TextSize = 15
    b.TextColor3 = PANEL
    b.Font = Enum.Font.GothamBold
    b.BackgroundColor3 = color or GOLD
    b.Parent = parent
    round(b)
    return b
end
local opener = button(gui, "OpenGlobalTop", "🏆 ТОП", GOLD)
opener.Position = UDim2.fromOffset(12, 292)
opener.Size = UDim2.fromOffset(110, 42)
local function compactNavigationVisible(w, h)
    return w >= 700 or h >= 500 or player:GetAttribute("CompactMenuOpen") == true
end
local function positionOpener()
    local camera = workspace.CurrentCamera
    local w = camera and camera.ViewportSize.X or 900
    local h = camera and camera.ViewportSize.Y or 700
    opener.Visible = compactNavigationVisible(w, h)
    if w < 700 then
        local navY = h < 650 and 163 or 187
        opener.Position = UDim2.fromOffset(12, navY + 98)
        opener.Size = UDim2.fromOffset(math.floor(w / 2) - 19, 43)
    else
        opener.Position = UDim2.fromOffset(18, 436)
        opener.Size = UDim2.fromOffset(245, 45)
    end
end
local viewportConnection
local function attachCamera()
    if viewportConnection then viewportConnection:Disconnect() end
    positionOpener()
    local camera = workspace.CurrentCamera
    if camera then
        viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(positionOpener)
    end
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(attachCamera)
attachCamera()
local panel = Instance.new("Frame")
panel.Name = "GlobalTopPanel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.new(0.9, 0, 0.78, 0)
panel.BackgroundColor3 = PANEL
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = gui
round(panel)
local limit = Instance.new("UISizeConstraint")
limit.MaxSize = Vector2.new(520, 540)
limit.MinSize = Vector2.new(270, 300)
limit.Parent = panel
local heading = label(panel, "🏆 РЕКОРДЫ GROWLIVO", 21, GOLD)
heading.Position = UDim2.fromOffset(12, 10)
heading.Size = UDim2.new(1, -66, 0, 36)
local close = button(panel, "Close", "✕", BLUE)
close.AnchorPoint = Vector2.new(1, 0)
close.Position = UDim2.new(1, -12, 0, 12)
close.Size = UDim2.fromOffset(38, 33)
local totalTab = button(panel, "TotalClicks", "ВСЕ КЛИКИ", GOLD)
totalTab.Position = UDim2.new(0, 12, 0, 55)
totalTab.Size = UDim2.new(0.5, -18, 0, 40)
local rebirthTab = button(panel, "Rebirths", "ПЕРЕРОЖДЕНИЯ", BLUE)
rebirthTab.Position = UDim2.new(0.5, 6, 0, 55)
rebirthTab.Size = UDim2.new(0.5, -18, 0, 40)
local scroll = Instance.new("ScrollingFrame")
scroll.Name = "TopEntries"
scroll.Position = UDim2.fromOffset(12, 106)
scroll.Size = UDim2.new(1, -24, 1, -149)
scroll.BackgroundTransparency = 1
scroll.ScrollBarThickness = 5
scroll.BorderSizePixel = 0
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.CanvasSize = UDim2.fromOffset(0, 0)
scroll.Parent = panel
local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 5)
layout.Parent = scroll
local status = label(panel, "Загрузка результатов…", 12, BLUE)
status.Position = UDim2.new(0, 12, 1, -38)
status.Size = UDim2.new(1, -24, 0, 28)
local currentTab = "TotalClicks"
local data = nil
local function pretty(v)
    if v >= 1e12 then return string.format("%.2fT", v / 1e12) end
    if v >= 1e9 then return string.format("%.2fB", v / 1e9) end
    if v >= 1e6 then return string.format("%.2fM", v / 1e6) end
    return tostring(math.floor(v))
end
local function redraw()
    for _, child in ipairs(scroll:GetChildren()) do
        if child:IsA("TextLabel") then child:Destroy() end
    end
    local entries = data and data[currentTab]
    if typeof(entries) ~= "table" or #entries == 0 then
        local empty = label(scroll, "Пока нет сохранённых рекордов", 15, WHITE)
        empty.Size = UDim2.new(1, -6, 0, 48)
        empty.LayoutOrder = 1
    else
        for i, entry in ipairs(entries) do
            local row = label(scroll, string.format("%d. %s   •   %s", i, tostring(entry.Name), pretty(tonumber(entry.Value) or 0)), 14, i <= 3 and GOLD or WHITE)
            row.Size = UDim2.new(1, -7, 0, 32)
            row.TextXAlignment = Enum.TextXAlignment.Left
            row.LayoutOrder = i
        end
    end
    local stamp = data and tonumber(data.UpdatedAt) or 0
    if data and data.Available == false then
        status.Text = "Данные временно недоступны · показан последний снимок"
    elseif stamp > 0 then
        status.Text = "Обновлено: " .. os.date("!%H:%M UTC", stamp)
    else
        status.Text = "Рейтинг обновится после первого сохранения"
    end
    totalTab.BackgroundColor3 = currentTab == "TotalClicks" and GOLD or BLUE
    rebirthTab.BackgroundColor3 = currentTab == "Rebirths" and GOLD or BLUE
end
boardState.OnClientEvent:Connect(function(payload)
    if typeof(payload) ~= "table" then return end
    data = payload
    redraw()
end)
totalTab.Activated:Connect(function() currentTab = "TotalClicks"; redraw() end)
rebirthTab.Activated:Connect(function() currentTab = "Rebirths"; redraw() end)
close.Activated:Connect(function() panel.Visible = false end)
opener.Activated:Connect(function()
    panel.Visible = not panel.Visible
    if panel.Visible then request:FireServer(); redraw() end
end)
request:FireServer()

player:GetAttributeChangedSignal("CompactMenuOpen"):Connect(positionOpener)
