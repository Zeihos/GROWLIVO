-- GROWLIVO / Admin utilities + filtered server notices / Alpha 0.9.14
-- StarterPlayer > StarterPlayerScripts > GrowlivoAdminUI [LocalScript]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("GROWLIVO_Remotes")
local action = remotes:WaitForChild("AdminAction")
local reply = remotes:WaitForChild("AdminReply")
local notice = remotes:WaitForChild("ServerNotice")
local gui = Instance.new("ScreenGui")
gui.Name = "GROWLIVO_AdminUI"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")
local GOLD = Color3.fromRGB(255, 204, 73)
local WHITE = Color3.fromRGB(235, 247, 255)
local BLUE = Color3.fromRGB(56, 206, 255)
local PANEL = Color3.fromRGB(16, 31, 54)
local function style(ui)
    ui.BorderSizePixel = 0
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = ui
end
local function text(parent, message, size)
    local t = Instance.new("TextLabel")
    t.BackgroundTransparency = 1
    t.Text = message
    t.TextWrapped = true
    t.TextColor3 = WHITE
    t.Font = Enum.Font.GothamBold
    t.TextSize = size or 15
    t.Parent = parent
    return t
end
local function button(parent, caption)
    local b = Instance.new("TextButton")
    b.Text = caption
    b.Font = Enum.Font.GothamBold
    b.TextSize = 15
    b.TextColor3 = PANEL
    b.BackgroundColor3 = GOLD
    b.Parent = parent
    style(b)
    return b
end
local opener = button(gui, "🛡 АДМИН")
opener.AnchorPoint = Vector2.new(1, 1)
opener.Position = UDim2.new(1, -12, 1, -140)
opener.Size = UDim2.fromOffset(123, 42)
opener.Visible = false
local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.new(0.86, 0, 0, 470)
panel.BackgroundColor3 = PANEL
panel.Visible = false
panel.Parent = gui
style(panel)
local constraint = Instance.new("UISizeConstraint")
constraint.MaxSize = Vector2.new(440, 510)
constraint.MinSize = Vector2.new(270, 320)
constraint.Parent = panel
local head = text(panel, "🛡 ПАНЕЛЬ АДМИНИСТРАТОРА", 18)
head.Position = UDim2.fromOffset(12, 10)
head.Size = UDim2.new(1, -60, 0, 33)
local close = button(panel, "✕")
close.Position = UDim2.new(1, -50, 0, 9)
close.Size = UDim2.fromOffset(37, 36)
local field = Instance.new("TextBox")
field.Name = "TargetUserId"
field.PlaceholderText = "UserId игрока в этом сервере"
field.Text = ""
field.ClearTextOnFocus = false
field.TextSize = 15
field.Font = Enum.Font.Gotham
field.BackgroundColor3 = Color3.fromRGB(37, 62, 91)
field.TextColor3 = WHITE
field.PlaceholderColor3 = Color3.fromRGB(172, 192, 206)
field.Position = UDim2.fromOffset(12, 55)
field.Size = UDim2.new(1, -24, 0, 38)
field.Parent = panel
style(field)
local inspect = button(panel, "ПРОВЕРИТЬ")
inspect.Position = UDim2.fromOffset(12, 102)
inspect.Size = UDim2.new(0.5, -18, 0, 37)
local kick = button(panel, "ИСКЛЮЧИТЬ")
kick.BackgroundColor3 = BLUE
kick.Position = UDim2.new(0.5, 6, 0, 102)
kick.Size = UDim2.new(0.5, -18, 0, 37)
local announcement = Instance.new("TextBox")
announcement.Name = "Announcement"
announcement.PlaceholderText = "Текст объявления (до 160 байт)"
announcement.Text = ""
announcement.ClearTextOnFocus = false
announcement.MultiLine = true
announcement.TextWrapped = true
announcement.TextSize = 14
announcement.Font = Enum.Font.Gotham
announcement.TextColor3 = WHITE
announcement.BackgroundColor3 = Color3.fromRGB(37, 62, 91)
announcement.Position = UDim2.fromOffset(12, 151)
announcement.Size = UDim2.new(1, -24, 0, 64)
announcement.Parent = panel
style(announcement)
local announce = button(panel, "ОТПРАВИТЬ ОБЪЯВЛЕНИЕ")
announce.Position = UDim2.fromOffset(12, 223)
announce.Size = UDim2.new(1, -24, 0, 39)
local server = button(panel, "ДАННЫЕ О СЕРВЕРЕ")
server.BackgroundColor3 = BLUE
server.Position = UDim2.fromOffset(12, 270)
server.Size = UDim2.new(1, -24, 0, 34)
local diagnostics = button(panel, "ДИАГНОСТИКА СОХРАНЕНИЙ")
diagnostics.BackgroundColor3 = BLUE
diagnostics.Position = UDim2.fromOffset(12, 311)
diagnostics.Size = UDim2.new(1, -24, 0, 34)
local telemetry = button(panel, "ИГРОВАЯ СТАТИСТИКА")
telemetry.BackgroundColor3 = BLUE
telemetry.Position = UDim2.fromOffset(12, 352)
telemetry.Size = UDim2.new(1, -24, 0, 34)
local result = text(panel, "Команды доступны только указанным UserId", 12)
result.Position = UDim2.fromOffset(12, 396)
result.Size = UDim2.new(1, -24, 0, 67)
local function updateAdmin()
    local allowed = player:GetAttribute("GrowlivoAdmin") == true
    opener.Visible = allowed
    if not allowed then panel.Visible = false end
end
player:GetAttributeChangedSignal("GrowlivoAdmin"):Connect(updateAdmin)
updateAdmin()
local function targetNumber()
    local id = tonumber(field.Text)
    if not id or id < 1 or id ~= math.floor(id) then
        result.Text = "Введите числовой UserId"
        return nil
    end
    return id
end
opener.Activated:Connect(function() panel.Visible = not panel.Visible end)
close.Activated:Connect(function() panel.Visible = false end)
inspect.Activated:Connect(function()
    local target = targetNumber()
    if target then action:FireServer("Inspect", target) end
end)
kick.Activated:Connect(function()
    local target = targetNumber()
    if target then action:FireServer("Kick", target) end
end)
announce.Activated:Connect(function() action:FireServer("Announce", announcement.Text) end)
server.Activated:Connect(function() action:FireServer("ServerInfo") end)
diagnostics.Activated:Connect(function() action:FireServer("Diagnostics") end)
telemetry.Activated:Connect(function() action:FireServer("Telemetry") end)
reply.OnClientEvent:Connect(function(message) result.Text = tostring(message) end)
local notification = Instance.new("Frame")
notification.Name = "AnnouncementBanner"
notification.AnchorPoint = Vector2.new(0.5, 0)
notification.Position = UDim2.new(0.5, 0, 0, 48)
notification.Size = UDim2.new(0.9, 0, 0, 74)
notification.BackgroundColor3 = PANEL
notification.Visible = false
notification.Parent = gui
style(notification)
local limitNotice = Instance.new("UISizeConstraint")
limitNotice.MaxSize = Vector2.new(520, 120)
limitNotice.Parent = notification
local caption = text(notification, "", 16)
caption.Size = UDim2.new(1, -16, 1, -12)
caption.Position = UDim2.fromOffset(8, 6)
local noticeNonce = 0
notice.OnClientEvent:Connect(function(filtered)
    if typeof(filtered) ~= "string" then return end
    noticeNonce += 1
    local nonce = noticeNonce
    caption.Text = "📢 GROWLIVO: " .. filtered
    notification.Visible = true
    task.delay(8, function()
        if nonce == noticeNonce then notification.Visible = false end
    end)
end)
