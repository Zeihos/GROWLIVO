-- GROWLIVO / Player preferences / Alpha 0.9.14
-- StarterPlayer > StarterPlayerScripts > GrowlivoSettingsUI [LocalScript]
-- Toggles persist on the server; only known boolean options are accepted.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local action = RS:WaitForChild("GROWLIVO_Remotes"):WaitForChild("Action")
local gui = Instance.new("ScreenGui")
gui.Name = "GROWLIVO_SettingsUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.DisplayOrder = 30
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local NAVY = Color3.fromRGB(18, 34, 60)
local DARK = Color3.fromRGB(9, 19, 36)
local GOLD = Color3.fromRGB(255, 202, 68)
local CYAN = Color3.fromRGB(60, 209, 255)
local WHITE = Color3.fromRGB(242, 250, 255)
local function round(target, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 12)
    corner.Parent = target
end
local function makeFrame(name, parent, tint, z)
    local obj = Instance.new("Frame")
    obj.Name = name
    obj.BackgroundColor3 = tint
    obj.BorderSizePixel = 0
    obj.ZIndex = z or 1
    obj.Parent = parent
    round(obj)
    return obj
end
local function makeButton(name, parent, label, tint, z)
    local obj = Instance.new("TextButton")
    obj.Name = name
    obj.Text = label
    obj.Font = Enum.Font.GothamBold
    obj.TextSize = 15
    obj.TextColor3 = DARK
    obj.TextWrapped = true
    obj.AutoButtonColor = true
    obj.BackgroundColor3 = tint
    obj.BorderSizePixel = 0
    obj.ZIndex = z or 1
    obj.Parent = parent
    round(obj, 10)
    return obj
end
local function makeText(name, parent, label, fontSize, tint, z)
    local obj = Instance.new("TextLabel")
    obj.Name = name
    obj.Text = label
    obj.Font = Enum.Font.GothamBold
    obj.TextSize = fontSize
    obj.TextWrapped = true
    obj.TextColor3 = tint
    obj.BackgroundTransparency = 1
    obj.TextXAlignment = Enum.TextXAlignment.Left
    obj.ZIndex = z or 1
    obj.Parent = parent
    return obj
end

local open = makeButton("SettingsButton", gui, "⚙ НАСТРОЙКИ", CYAN)
local overlay = makeFrame("Overlay", gui, Color3.fromRGB(0, 0, 0), 10)
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundTransparency = 0.25
overlay.Active = true
overlay.Visible = false
local modal = makeFrame("SettingsPanel", overlay, NAVY, 11)
modal.AnchorPoint = Vector2.new(0.5, 0.5)
modal.Position = UDim2.fromScale(0.5, 0.5)
local modalScale = Instance.new("UIScale")
modalScale.Scale = 1
modalScale.Parent = modal
local rim = Instance.new("UIStroke")
rim.Color = GOLD
rim.Thickness = 2
rim.Parent = modal
local heading = makeText("Heading", modal, "⚙ НАСТРОЙКИ GROWLIVO", 20, GOLD, 12)
heading.Position = UDim2.fromOffset(16, 12)
heading.Size = UDim2.new(1, -78, 0, 42)
local close = makeButton("Close", modal, "✕", GOLD, 12)
close.AnchorPoint = Vector2.new(1, 0)
close.Position = UDim2.new(1, -13, 0, 14)
close.Size = UDim2.fromOffset(42, 38)
local subtitle = makeText("Subtitle", modal, "Настройки сохраняются в профиле", 13, WHITE, 12)
subtitle.Position = UDim2.fromOffset(18, 58)
subtitle.Size = UDim2.new(1, -36, 0, 25)

local entries = {
    {Key = "ShowPets", Name = "Показывать питомцев", Info = "Скрыть 3D-модели рядом с героем"},
    {Key = "Effects", Name = "Эффекты и частицы", Info = "Анимации кликов и конфетти"},
    {Key = "ReducedMotion", Name = "Уменьшить движение", Info = "Без тряски и вспышек при яйцах"},
    {Key = "Sounds", Name = "Звуковые эффекты", Info = "Звук кликов и игровых наград"},
}
local toggles = {}
for i, item in ipairs(entries) do
    local row = makeFrame(item.Key .. "Row", modal, DARK, 12)
    row.Position = UDim2.fromOffset(16, 96 + (i - 1) * 86)
    row.Size = UDim2.new(1, -32, 0, 76)
    local title = makeText("Name", row, item.Name, 14, WHITE, 13)
    title.Position = UDim2.fromOffset(12, 9)
    title.Size = UDim2.new(1, -125, 0, 31)
    local desc = makeText("Info", row, item.Info, 11, Color3.fromRGB(174, 200, 220), 13)
    desc.Position = UDim2.fromOffset(12, 39)
    desc.Size = UDim2.new(1, -128, 0, 29)
    local toggle = makeButton("Toggle", row, "", CYAN, 13)
    toggle.AnchorPoint = Vector2.new(1, 0.5)
    toggle.Position = UDim2.new(1, -9, 0.5, 0)
    toggle.Size = UDim2.fromOffset(91, 43)
    toggles[item.Key] = toggle
    toggle.Activated:Connect(function()
        if player:GetAttribute("DataReady") ~= true then return end
        local current = player:GetAttribute("Setting" .. item.Key)
        if typeof(current) ~= "boolean" then return end
        action:FireServer("SetSetting", {Key = item.Key, Value = not current})
    end)
end
local status = makeText("Status", modal, "", 12, WHITE, 12)
status.Position = UDim2.fromOffset(18, 439)
status.Size = UDim2.new(1, -36, 0, 27)

local function refresh()
    for _, item in ipairs(entries) do
        local value = player:GetAttribute("Setting" .. item.Key)
        local control = toggles[item.Key]
        control.Text = value == true and "ВКЛ" or "ВЫКЛ"
        control.BackgroundColor3 = value == true and GOLD or CYAN
    end
    status.Text = player:GetAttribute("SavingEnabled") == false
        and "⚠ Сейчас сохранение недоступно" or "Изменения сохраняются вместе с прогрессом"
end
local function setOpen(value)
    overlay.Visible = value
    -- Client-side attribute for HUD input suppression only; never trusted by server.
    player:SetAttribute("SettingsOpen", value)
    if value then refresh() end
end
open.Activated:Connect(function() setOpen(true) end)
close.Activated:Connect(function() setOpen(false) end)
UserInputService.InputBegan:Connect(function(input, handled)
    if not handled and input.KeyCode == Enum.KeyCode.Escape and overlay.Visible then
        setOpen(false)
    end
end)
for _, entry in ipairs(entries) do
    player:GetAttributeChangedSignal("Setting" .. entry.Key):Connect(refresh)
end
player:GetAttributeChangedSignal("SavingEnabled"):Connect(refresh)
local function compactNavigationVisible(w, h)
    return w >= 700 or h >= 500 or player:GetAttribute("CompactMenuOpen") == true
end
local function resize()
    local camera = workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize or Vector2.new(1000, 700)
    open.Visible = compactNavigationVisible(viewport.X, viewport.Y)
    modalScale.Scale = math.min(1, math.max(0.68, (viewport.Y - 22) / 490))
    if viewport.X < 700 then
        local navY = viewport.Y < 650 and 163 or 187
        open.Position = UDim2.fromOffset(math.floor(viewport.X / 2) + 5, navY + 98)
        open.Size = UDim2.fromOffset(math.floor(viewport.X / 2) - 17, 43)
        modal.Size = UDim2.fromOffset(math.max(270, math.min(430, (viewport.X - 22) / modalScale.Scale)), 490)
        heading.TextSize = 17
    else
        open.Position = UDim2.fromOffset(18, 378)
        open.Size = UDim2.fromOffset(175, 45)
        modal.Size = UDim2.fromOffset(460, 490)
        heading.TextSize = 20
    end
end
local cameraConnection
local function cameraChanged()
    if cameraConnection then cameraConnection:Disconnect() end
    resize()
    if workspace.CurrentCamera then
        cameraConnection = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resize)
    end
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(cameraChanged)
cameraChanged()
refresh()

player:GetAttributeChangedSignal("CompactMenuOpen"):Connect(resize)
