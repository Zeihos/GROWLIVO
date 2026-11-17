-- GROWLIVO / Persistent three-step beginner guide / Alpha 0.9.14
-- StarterPlayer > StarterPlayerScripts > GrowlivoTutorial [LocalScript]
-- Read-only UI. Tutorial progress and completion rewards belong to the server.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "GROWLIVO_Tutorial"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.DisplayOrder = 2
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")
local DARK = Color3.fromRGB(12, 29, 52)
local PANEL = Color3.fromRGB(22, 44, 76)
local GOLD = Color3.fromRGB(255, 202, 73)
local CYAN = Color3.fromRGB(45, 208, 255)
local WHITE = Color3.fromRGB(239, 249, 255)
local MUTED = Color3.fromRGB(180, 205, 226)

local panel = Instance.new("Frame")
panel.Name = "TutorialCard"
panel.BackgroundColor3 = PANEL
panel.BorderSizePixel = 0
panel.Parent = gui
local round = Instance.new("UICorner")
round.CornerRadius = UDim.new(0, 14)
round.Parent = panel
local stroke = Instance.new("UIStroke")
stroke.Color = GOLD
stroke.Thickness = 1.8
stroke.Transparency = 0.15
stroke.Parent = panel
local function label(name, caption, font, size, color)
    local obj = Instance.new("TextLabel")
    obj.Name = name
    obj.BackgroundTransparency = 1
    obj.Text = caption
    obj.Font = font
    obj.TextSize = size
    obj.TextColor3 = color
    obj.TextXAlignment = Enum.TextXAlignment.Left
    obj.TextWrapped = true
    obj.Parent = panel
    return obj
end
local heading = label("Heading", "👑 ОБУЧЕНИЕ", Enum.Font.GothamBlack, 15, GOLD)
local hint = label("Hint", "", Enum.Font.Gotham, 13, WHITE)
local progress = label("Progress", "", Enum.Font.GothamBold, 12, MUTED)
local bar = Instance.new("Frame")
bar.Name = "ProgressTrack"
bar.BackgroundColor3 = DARK
bar.BorderSizePixel = 0
bar.Parent = panel
local barCorner = Instance.new("UICorner")
barCorner.CornerRadius = UDim.new(1, 0)
barCorner.Parent = bar
local fill = Instance.new("Frame")
fill.Name = "Fill"
fill.Size = UDim2.fromScale(0, 1)
fill.BackgroundColor3 = CYAN
fill.BorderSizePixel = 0
fill.Parent = bar
local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(1, 0)
fillCorner.Parent = fill
local toggle = Instance.new("TextButton")
toggle.Name = "Toggle"
toggle.BackgroundColor3 = DARK
local toggleCorner = Instance.new("UICorner")
toggleCorner.CornerRadius = UDim.new(0, 8)
toggleCorner.Parent = toggle
toggle.Text = "−"
toggle.TextColor3 = GOLD
toggle.TextSize = 22
toggle.Font = Enum.Font.GothamBold
toggle.BorderSizePixel = 0
toggle.Parent = panel
-- Mobile guide starts as a button so it cannot hide quests/settings.
local collapsed = false
local firstLayout = true
local viewportCompact = false
local viewportTooShort = false

local function currentStage()
    return tonumber(player:GetAttribute("TutorialStep")) or 1
end
local function layout()
    local camera = workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize or Vector2.new(1000, 700)
    local w, h = viewport.X, viewport.Y
    local mobile = w < 700
    if firstLayout then
        collapsed = mobile
        firstLayout = false
    end
    viewportCompact = mobile and h < 440
    viewportTooShort = mobile and h < 390
    local small = collapsed or viewportCompact
    if mobile then
        if small then
            local navY = h < 650 and 163 or 187
            panel.AnchorPoint = Vector2.new(0, 0)
            panel.Position = UDim2.fromOffset(math.floor(w / 2) + 5, navY + 147)
            panel.Size = UDim2.fromOffset(math.floor(w / 2) - 17, 43)
            panel.ZIndex = 2
            gui.DisplayOrder = 2
        else
            -- Expanded on demand, above other HUD elements, closes via the + button.
            panel.AnchorPoint = Vector2.new(0.5, 0.5)
            panel.Position = UDim2.fromScale(0.5, 0.5)
            panel.Size = UDim2.new(1, -24, 0, 135)
            panel.ZIndex = 20
            gui.DisplayOrder = 40
        end
    else
        panel.AnchorPoint = Vector2.new(0, 0)
        panel.Position = UDim2.new(1, -328, 0, 304)
        panel.Size = UDim2.fromOffset(308, small and 43 or 136)
        panel.ZIndex = 2
        gui.DisplayOrder = 2
    end
    heading.Position = UDim2.fromOffset(12, 5)
    heading.TextSize = small and 12 or 15
    heading.Size = UDim2.new(1, -58, 0, 30)
    hint.Position = UDim2.fromOffset(13, 37)
    hint.Size = UDim2.new(1, -26, 0, mobile and 38 or 49)
    progress.Position = UDim2.fromOffset(13, mobile and 76 or 88)
    progress.Size = UDim2.new(1, -26, 0, 20)
    bar.Position = UDim2.new(0, 13, 1, -13)
    bar.Size = UDim2.new(1, -26, 0, 6)
    toggle.Position = UDim2.new(1, -37, 0, 6)
    toggle.Size = UDim2.fromOffset(29, 28)
    toggle.Text = small and "+" or "−"
    hint.Visible = not small
    progress.Visible = not small
    bar.Visible = not small
    -- The compact menu controls collapsed visibility on short screens.
end
local function update()
    local ready = player:GetAttribute("DataReady") == true
    local step = currentStage()
    local camera = workspace.CurrentCamera
    local size = camera and camera.ViewportSize or Vector2.new(1000, 700)
    local compactNav = size.X < 700 and size.Y < 500
    panel.Visible = ready and step < 4
        and (not compactNav or player:GetAttribute("CompactMenuOpen") == true)
    if not panel.Visible then return end
    local taps = math.min(20, math.floor(tonumber(player:GetAttribute("TutorialClicks")) or 0))
    if step == 1 then
        heading.Text = "👆 1/3 • ПЕРВЫЕ КЛИКИ"
        hint.Text = "Нажми большую золотую кнопку 20 раз. На ПК также можно нажимать пробел."
        progress.Text = string.format("Нажатия: %d / 20", taps)
    elseif step == 2 then
        heading.Text = "⚡ 2/3 • УЛУЧШЕНИЕ"
        hint.Text = "Накопи клики и купи улучшение силы клика в игровом меню."
        progress.Text = "Действие: купить одно улучшение"
    else
        heading.Text = "🥚 3/3 • ПЕРВОЕ ЯЙЦО"
        hint.Text = "Открой ПИТОМЦЫ, накопи 150 кликов и купи яйцо. Питомец усилит каждый клик."
        progress.Text = "Награда: +200 кликов и +5 💎"
    end
    local percentage = step == 1 and (taps / 20) or step == 2 and (1 / 3) or (2 / 3)
    if GuiService.ReducedMotionEnabled or player:GetAttribute("SettingReducedMotion") == true then
        fill.Size = UDim2.fromScale(percentage, 1)
    else
        TweenService:Create(fill, TweenInfo.new(0.22), {Size = UDim2.fromScale(percentage, 1)}):Play()
    end
end
toggle.Activated:Connect(function()
    collapsed = not collapsed
    layout()
    update()
end)
for _, attribute in ipairs({"DataReady", "TutorialStep", "TutorialClicks"}) do
    player:GetAttributeChangedSignal(attribute):Connect(update)
end
local function cameraChanged()
    layout()
    update()
    local camera = workspace.CurrentCamera
    if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
        layout()
        update()
    end) end
end
cameraChanged()
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(cameraChanged)
update()

player:GetAttributeChangedSignal("CompactMenuOpen"):Connect(function()
    layout()
    update()
end)

player:GetAttributeChangedSignal("CompactMenuOpen"):Connect(function()
    layout()
    update()
end)
