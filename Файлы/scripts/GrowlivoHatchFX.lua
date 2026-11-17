-- GROWLIVO / Cinematic egg opening in ViewportFrame / Alpha 0.9.14
-- Local-only presentation. No rewards or currency changes happen here.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("GrowlivoConfig"))
local visual = ReplicatedStorage:WaitForChild("GROWLIVO_Remotes"):WaitForChild("VisualEvent")

local GOLD = Color3.fromRGB(255, 207, 70)
local CYAN = Color3.fromRGB(45, 207, 255)
local NAVY = Color3.fromRGB(16, 30, 57)
local WHITE = Color3.fromRGB(241, 249, 255)
local gui = Instance.new("ScreenGui")
gui.Name = "GROWLIVO_HatchFX"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 45
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local overlay = Instance.new("Frame")
overlay.Name = "HatchingOverlay"
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = Color3.fromRGB(4, 11, 23)
overlay.BackgroundTransparency = 0.18
overlay.BorderSizePixel = 0
overlay.Visible = false
overlay.Active = true
overlay.Parent = gui

local card = Instance.new("Frame")
card.Name = "HatchingCard"
card.AnchorPoint = Vector2.new(0.5, 0.5)
card.Position = UDim2.fromScale(0.5, 0.5)
card.BackgroundColor3 = NAVY
card.BorderSizePixel = 0
card.Parent = overlay
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 22)
corner.Parent = card
local rim = Instance.new("UIStroke")
rim.Thickness = 3
rim.Color = GOLD
rim.Parent = card
local scale = Instance.new("UIScale")
scale.Parent = card

local title = Instance.new("TextLabel")
title.Name = "Heading"
title.BackgroundTransparency = 1
title.Position = UDim2.new(0, 12, 0, 12)
title.Size = UDim2.new(1, -24, 0, 40)
title.Font = Enum.Font.GothamBlack
title.TextSize = 23
title.TextColor3 = GOLD
title.Parent = card

-- One egg rendered entirely from primitive Roblox Parts, without external assets.
local viewport = Instance.new("ViewportFrame")
viewport.Name = "EggViewport"
viewport.Position = UDim2.new(0, 15, 0, 55)
viewport.Size = UDim2.new(1, -30, 0, 195)
viewport.BackgroundColor3 = Color3.fromRGB(22, 46, 82)
viewport.BackgroundTransparency = 0.1
viewport.BorderSizePixel = 0
viewport.Ambient = Color3.fromRGB(168, 197, 255)
viewport.LightColor = WHITE
viewport.LightDirection = Vector3.new(-1, -2, -1)
viewport.Parent = card
local viewportCorner = Instance.new("UICorner")
viewportCorner.CornerRadius = UDim.new(0, 15)
viewportCorner.Parent = viewport
local modelWorld = Instance.new("WorldModel")
modelWorld.Parent = viewport
local camera = Instance.new("Camera")
camera.CFrame = CFrame.new(Vector3.new(0, 1, 12), Vector3.new(0, 0, 0))
camera.FieldOfView = 45
camera.Parent = viewport
viewport.CurrentCamera = camera
local egg = Instance.new("Model")
egg.Name = "RoyalEgg"
egg.Parent = modelWorld
local function piece(name, size, cf, tint, shape)
    local part = Instance.new("Part")
    part.Name = name
    part.Size = size
    part.CFrame = cf
    part.Color = tint
    part.Material = Enum.Material.SmoothPlastic
    part.Shape = shape or Enum.PartType.Ball
    part.Anchored = true
    part.CanCollide = false
    part.Parent = egg
    return part
end
local shell = piece("EggShell", Vector3.new(4.2, 5.2, 4.1), CFrame.new(), CYAN)
egg.PrimaryPart = shell
piece("GoldBand", Vector3.new(4.35, 0.55, 4.25), CFrame.new(0, -0.65, 0), GOLD)
piece("CrystalTop", Vector3.new(2.2, 0.9, 2.2), CFrame.new(0, 2.4, 0), GOLD)
for _, x in ipairs({-1, 0, 1}) do
    piece("CrownGem", Vector3.new(0.65, 0.65, 0.6), CFrame.new(x, 2.55 + (x == 0 and 0.5 or 0), -0.2), WHITE)
end

local result = Instance.new("TextLabel")
result.Name = "PetResult"
result.BackgroundTransparency = 1
result.Position = UDim2.new(0, 12, 0, 255)
result.Size = UDim2.new(1, -24, 0, 60)
result.Font = Enum.Font.GothamBlack
result.TextWrapped = true
result.TextSize = 23
result.TextColor3 = GOLD
result.Text = ""
result.Parent = card
local detail = Instance.new("TextLabel")
detail.Name = "PetDetails"
detail.BackgroundTransparency = 1
detail.Position = UDim2.new(0, 12, 0, 312)
detail.Size = UDim2.new(1, -24, 0, 33)
detail.Font = Enum.Font.GothamBold
detail.TextWrapped = true
detail.TextSize = 15
detail.TextColor3 = WHITE
detail.Text = ""
detail.Parent = card
local skip = Instance.new("TextButton")
skip.Name = "Skip"
skip.AnchorPoint = Vector2.new(0.5, 0)
skip.Position = UDim2.new(0.5, 0, 1, -49)
skip.Size = UDim2.fromOffset(180, 36)
skip.Text = "ПРОПУСТИТЬ"
skip.TextColor3 = NAVY
skip.Font = Enum.Font.GothamBold
skip.TextSize = 14
skip.BackgroundColor3 = GOLD
skip.BorderSizePixel = 0
skip.Parent = card
local skipCorner = Instance.new("UICorner")
skipCorner.CornerRadius = UDim.new(0, 10)
skipCorner.Parent = skip

local queue, playing, serial = {}, false, 0
local forceReveal = false
local function shortAnimation()
    return GuiService.ReducedMotionEnabled or player:GetAttribute("SettingReducedMotion") == true
        or player:GetAttribute("SettingEffects") == false
end
local function layout()
    local v = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(900, 700)
    local width = math.max(248, math.min(440, v.X - 28))
    local height = math.max(294, math.min(420, v.Y - 30))
    card.Size = UDim2.fromOffset(width, height)
    local previewHeight = math.max(95, height - 222)
    viewport.Size = UDim2.new(1, -30, 0, previewHeight)
    result.Position = UDim2.new(0, 12, 0, 60 + previewHeight)
    detail.Position = UDim2.new(0, 12, 0, 118 + previewHeight)
end
local cameraConnection
local function cameraChanged()
    if cameraConnection then cameraConnection:Disconnect() end
    layout()
    if workspace.CurrentCamera then
        cameraConnection = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
    end
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(cameraChanged)
cameraChanged()
skip.Activated:Connect(function() forceReveal = true end)

local function playHatch(pet)
    serial += 1
    local ticket = serial
    overlay.Visible = true
    result.Text = ""
    detail.Text = ""
    title.Text = "🥚 ОТКРЫТИЕ ЯЙЦА"
    rim.Color = pet.Color
    shell.Color = pet.Color
    egg:PivotTo(CFrame.new())
    scale.Scale = 1
    forceReveal = false
    skip.Text = "ПРОПУСТИТЬ"
    if not shortAnimation() then
        for i = 1, 5 do
            if forceReveal or ticket ~= serial then break end
            local angle = (i % 2 == 0 and 1 or -1) * math.rad(9 + i * 3)
            egg:PivotTo(CFrame.Angles(0, angle, angle / 2))
            task.wait(0.13)
        end
        if not forceReveal then
            local flicker = TweenService:Create(scale, TweenInfo.new(0.16, Enum.EasingStyle.Back), {Scale = 1.07})
            flicker:Play()
            task.wait(0.16)
        end
    end
    egg:PivotTo(CFrame.new())
    scale.Scale = 1
    -- A first tap skips the egg shake; a second tap closes the result.
    forceReveal = false
    title.Text = "✨ НОВЫЙ ПИТОМЕЦ!"
    result.Text = pet.Name
    result.TextColor3 = pet.Color
    detail.Text = pet.Rarity .. "  •  Бонус к кликам +" .. pet.Bonus .. "%"
    skip.Text = "ЗАКРЫТЬ"
    -- An explicit close remains available, while each reward still auto-dismisses.
    local waited = 0
    while waited < (shortAnimation() and 0.65 or 1.5) do
        if forceReveal then break end
        task.wait(0.05)
        waited += 0.05
    end
    overlay.Visible = false
end

local function drain()
    if playing then return end
    playing = true
    while #queue > 0 do
        local nextPet = table.remove(queue, 1)
        if nextPet then playHatch(nextPet) end
    end
    playing = false
end
visual.OnClientEvent:Connect(function(event)
    if typeof(event) ~= "table" or event.Type ~= "Hatch" then return end
    local pet = Config.FindPet(event.Species)
    if not pet then return end
    -- Bounded queue; a triple hatch cannot flood the screen with unbounded GUIs.
    if #queue < 6 then
        table.insert(queue, pet)
        task.spawn(drain)
    end
end)
