-- GROWLIVO / Daily chest compass / Alpha 0.9.25
-- StarterPlayerScripts > GrowlivoChestUI [LocalScript]
-- Client-only navigation. All rewards, distances and claims are verified by the server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("GrowlivoConfig"))
local playerGui = player:WaitForChild("PlayerGui")

local previous = playerGui:FindFirstChild("GROWLIVO_ChestUI")
if previous then previous:Destroy() end
local oldWaypoint = playerGui:FindFirstChild("GROWLIVO_ChestWaypoint")
if oldWaypoint then oldWaypoint:Destroy() end

local GOLD = Color3.fromRGB(255, 219, 114)
local MUTED = Color3.fromRGB(185, 204, 220)
local NAVY = Color3.fromRGB(16, 32, 57)
local gui = Instance.new("ScreenGui")
gui.Name = "GROWLIVO_ChestUI"
gui.ResetOnSpawn = false
gui.DisplayOrder = 2
gui.IgnoreGuiInset = false
gui.Parent = playerGui

local function label(name, y, height, color)
    local item = Instance.new("TextLabel")
    item.Name = name
    item.AnchorPoint = Vector2.new(0.5, 0)
    item.Position = UDim2.new(0.5, 0, 0, y)
    item.Size = UDim2.fromOffset(315, height)
    item.BackgroundColor3 = NAVY
    item.BackgroundTransparency = 0.15
    item.BorderSizePixel = 0
    item.TextColor3 = color
    item.TextSize = 13
    item.TextWrapped = true
    item.Font = Enum.Font.GothamBold
    item.Visible = false
    item.Parent = gui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = item
    local stroke = Instance.new("UIStroke")
    stroke.Color = color
    stroke.Thickness = 1
    stroke.Transparency = 0.45
    stroke.Parent = item
    return item
end

local panel = label("DailyChestStatus", 84, 37, GOLD)
local navigation = label("ChestDirection", 124, 29, MUTED)

-- The marker is parented to PlayerGui, not Workspace: no shared objects are
-- changed and another player cannot see our personal navigation.
local marker = Instance.new("BillboardGui")
marker.Name = "GROWLIVO_ChestWaypoint"
marker.Size = UDim2.fromOffset(180, 42)
marker.StudsOffsetWorldSpace = Vector3.new(0, 9, 0)
marker.AlwaysOnTop = true
marker.MaxDistance = 600
marker.Enabled = false
marker.Parent = playerGui
local markerText = Instance.new("TextLabel")
markerText.Size = UDim2.fromScale(1, 1)
markerText.BackgroundColor3 = NAVY
markerText.BackgroundTransparency = 0.16
markerText.BorderSizePixel = 0
markerText.TextColor3 = GOLD
markerText.TextSize = 13
markerText.Font = Enum.Font.GothamBold
markerText.TextWrapped = true
markerText.Parent = marker
local markerCorner = Instance.new("UICorner")
markerCorner.CornerRadius = UDim.new(0, 10)
markerCorner.Parent = markerText

local function claimedToday()
    if player:GetAttribute("ChestClaimed") ~= true then return false end
    local day = player:GetAttribute("ChestDay")
    return typeof(day) == "string" and day >= os.date("!%Y-%m-%d")
end

local function findChest(worldId)
    local world = workspace:FindFirstChild("GROWLIVO_World")
    local group = world and world:FindFirstChild("11_WORLD_CHESTS")
    if not group then return nil end
    for _, item in ipairs(group:GetChildren()) do
        if item:IsA("BasePart") and item.Name == "WorldTreasureChest"
            and item:GetAttribute("ChestWorld") == worldId then
            return item
        end
    end
    return nil
end

local function update()
    local worldId = player:GetAttribute("World")
    local reward = Config.WorldChests[worldId]
    local ready = player:GetAttribute("DataReady") == true and reward ~= nil
    panel.Visible = ready
    navigation.Visible = false
    marker.Enabled = false
    marker.Adornee = nil
    if not ready then return end

    local camera = workspace.CurrentCamera
    local width = camera and camera.ViewportSize.X or 900
    width = math.min(315, math.max(205, width - 24))
    panel.Size = UDim2.fromOffset(width, 37)
    navigation.Size = UDim2.fromOffset(width, 29)

    if claimedToday() then
        panel.Text = "🎁 Сундук дня получен • обновление в 00:00 UTC"
        panel.TextColor3 = MUTED
        return
    end

    panel.Text = "🎁 Сундук: +" .. reward.Clicks .. " кликов, +" .. reward.Gems .. " 💎"
    panel.TextColor3 = GOLD
    navigation.Visible = true

    local chest = findChest(worldId)
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not chest or not root then
        navigation.Text = "📍 Сундук загружается • проверь локацию"
        return
    end

    local distance = (root.Position - chest.Position).Magnitude
    local studs = math.floor(distance + 0.5)
    if distance <= 12 then
        navigation.Text = "✨ Ты у сундука • взаимодействуй с ним"
    else
        navigation.Text = "📍 До сундука: " .. studs .. " студ. • следуй за меткой"
        marker.Adornee = chest
        marker.Enabled = true
        markerText.Text = "🎁 СУНДУК ДНЯ\n" .. studs .. " студ."
    end
end

for _, attribute in ipairs({"DataReady", "World", "ChestDay", "ChestClaimed"}) do
    player:GetAttributeChangedSignal(attribute):Connect(update)
end
player.CharacterAdded:Connect(update)
task.spawn(function()
    while gui.Parent do
        update()
        task.wait(0.75)
    end
    marker:Destroy()
end)
update()
