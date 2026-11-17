-- GROWLIVO / Persistent save-state indicator / Alpha 0.9.17
-- StarterPlayerScripts / LocalScript. Visual only; no currency operations.
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "GROWLIVO_SessionUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.DisplayOrder = 80
-- A recoverable save failure blocks input until a confirmed retry.
gui.Parent = player:WaitForChild("PlayerGui")
local backdrop = Instance.new("Frame")
backdrop.Name = "SaveStatusBackdrop"
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3 = Color3.fromRGB(8, 16, 33)
backdrop.BackgroundTransparency = 0.25
backdrop.BorderSizePixel = 0
backdrop.Active = true
backdrop.Parent = gui
local panel = Instance.new("Frame")
panel.Name = "StatusPanel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.new(1, -28, 0, 164)
panel.BackgroundColor3 = Color3.fromRGB(18, 34, 64)
panel.BorderSizePixel = 0
panel.Parent = backdrop
local limit = Instance.new("UISizeConstraint")
limit.MaxSize = Vector2.new(440, 164)
limit.MinSize = Vector2.new(230, 140)
limit.Parent = panel
local round = Instance.new("UICorner")
round.CornerRadius = UDim.new(0, 16)
round.Parent = panel
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(255, 205, 83)
stroke.Thickness = 2
stroke.Parent = panel
local heading = Instance.new("TextLabel")
heading.Name = "Heading"
heading.Position = UDim2.fromOffset(14, 14)
heading.Size = UDim2.new(1, -28, 0, 49)
heading.TextColor3 = Color3.fromRGB(255, 209, 84)
heading.BackgroundTransparency = 1
heading.Font = Enum.Font.GothamBold
heading.TextSize = 21
heading.TextWrapped = true
heading.Parent = panel
local details = Instance.new("TextLabel")
details.Name = "Details"
details.Position = UDim2.fromOffset(18, 66)
details.Size = UDim2.new(1, -36, 0, 80)
details.TextColor3 = Color3.fromRGB(232, 244, 255)
details.BackgroundTransparency = 1
details.Font = Enum.Font.Gotham
details.TextSize = 15
details.TextWrapped = true
details.Parent = panel
-- Compact persistence acknowledgement, shown only when the profile is
-- usable. Status Ready is not the same as "latest actions were saved".
local saveBadge = Instance.new("TextLabel")
saveBadge.Name = "PersistenceBadge"
saveBadge.AnchorPoint = Vector2.new(1, 0)
saveBadge.Position = UDim2.new(1, -10, 0, 46)
saveBadge.Size = UDim2.fromOffset(188, 31)
saveBadge.BackgroundColor3 = Color3.fromRGB(18, 34, 64)
saveBadge.BackgroundTransparency = 0.12
saveBadge.TextColor3 = Color3.fromRGB(232, 244, 255)
saveBadge.Font = Enum.Font.GothamBold
saveBadge.TextSize = 12
saveBadge.ZIndex = 5
saveBadge.Visible = false
saveBadge.Parent = gui
local badgeCorner = Instance.new("UICorner")
badgeCorner.CornerRadius = UDim.new(0, 9)
badgeCorner.Parent = saveBadge
local function refresh()
    local status = player:GetAttribute("DataStatus") or "Loading"
    local ready = player:GetAttribute("DataReady") == true
    backdrop.Visible = status ~= "Ready" or not ready
    saveBadge.Visible = status == "Ready" and ready
    if saveBadge.Visible then
        if player:GetAttribute("DataMode") == "StudioTemporary" then
            saveBadge.Text = "⚠ ТЕСТ · без сохранения"
            saveBadge.TextColor3 = Color3.fromRGB(255, 207, 95)
        elseif player:GetAttribute("UnsavedChanges") == true then
            saveBadge.Text = "◷ Ожидает сохранения"
            saveBadge.TextColor3 = Color3.fromRGB(255, 207, 95)
        elseif (player:GetAttribute("LastConfirmedSaveAt") or 0) > 0 then
            saveBadge.Text = "✓ Сохранено сервером"
            saveBadge.TextColor3 = Color3.fromRGB(135, 239, 191)
        else
            -- Successfully read from DataStore; there was no write this session.
            saveBadge.Text = "✓ Профиль загружен"
            saveBadge.TextColor3 = Color3.fromRGB(135, 239, 191)
        end
    end
    if status == "Closing" then
        heading.Text = "👑 ЗАВЕРШЕНИЕ СЕССИИ"
        details.Text = "Игра завершает сохранение и освобождает профиль. Новые действия временно недоступны."
    elseif status == "SaveRetry" then
        heading.Text = "⚠ ПРОБЛЕМА СОХРАНЕНИЯ"
        details.Text = "Действия приостановлены для защиты прогресса. Повторные попытки выполняются с увеличением интервала (до примерно минуты). Выход до восстановления может привести к потере последних действий."
    elseif status == "Conflict" then
        heading.Text = "⚠ КОНФЛИКТ ПРОФИЛЯ"
        details.Text = "Данные открыты другим сервером. Подключитесь повторно позже."
    elseif status == "Unavailable" then
        heading.Text = "⚠ ПРОГРЕСС НЕДОСТУПЕН"
        details.Text = "Загрузка не удалась. Вход отменён, чтобы не потерять достижения."
    else
        heading.Text = "👑 GROWLIVO"
        details.Text = "Безопасная загрузка игрового прогресса…"
    end
end
player:GetAttributeChangedSignal("DataMode"):Connect(refresh)
player:GetAttributeChangedSignal("DataStatus"):Connect(refresh)
player:GetAttributeChangedSignal("DataReady"):Connect(refresh)
player:GetAttributeChangedSignal("UnsavedChanges"):Connect(refresh)
player:GetAttributeChangedSignal("LastConfirmedSaveAt"):Connect(refresh)
refresh()
