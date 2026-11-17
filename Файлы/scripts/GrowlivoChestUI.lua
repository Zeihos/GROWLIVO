-- GROWLIVO / Daily chest status / Alpha 0.9.24
-- StarterPlayerScripts > GrowlivoChestUI [LocalScript]
-- Server-published player attributes, never used for reward decisions.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("GrowlivoConfig"))
local gui = Instance.new("ScreenGui")
gui.Name = "GROWLIVO_ChestUI"
gui.ResetOnSpawn = false
gui.DisplayOrder = 2
gui.Parent = player:WaitForChild("PlayerGui")
local panel = Instance.new("TextLabel")
panel.Name = "DailyChestStatus"
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.Position = UDim2.new(0.5, 0, 0, 84)
panel.Size = UDim2.fromOffset(315, 37)
panel.BackgroundColor3 = Color3.fromRGB(16, 32, 57)
panel.BackgroundTransparency = 0.15
panel.BorderSizePixel = 0
panel.TextColor3 = Color3.fromRGB(255, 219, 114)
panel.Font = Enum.Font.GothamBold
panel.TextSize = 13
panel.TextWrapped = true
panel.Visible = false
panel.Parent = gui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 11)
corner.Parent = panel
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(255, 196, 58)
stroke.Thickness = 1
stroke.Parent = panel

local function update()
    local world = player:GetAttribute("World")
    local reward = Config.WorldChests[world]
    panel.Visible = player:GetAttribute("DataReady") == true and reward ~= nil
    if not reward then return end
    local day = player:GetAttribute("ChestDay")
    local claimed = player:GetAttribute("ChestClaimed") == true
    if claimed and typeof(day) == "string" then
        -- Display is advisory; server independently determines UTC rollover.
        local now = os.date("!*t", os.time())
        local today = string.format("%04d-%02d-%02d", now.year, now.month, now.day)
        if today > day then claimed = false end
    end
    if claimed then
        panel.Text = "🎁 Сундук дня получен • обновление в 00:00 UTC"
        panel.TextColor3 = Color3.fromRGB(185, 204, 220)
    else
        panel.Text = "🎁 Сундук: +" .. reward.Clicks .. " кликов, +" .. reward.Gems .. " 💎 • найди в мире"
        panel.TextColor3 = Color3.fromRGB(255, 219, 114)
    end
    local camera = workspace.CurrentCamera
    if camera then
        panel.Size = UDim2.fromOffset(math.min(315, math.max(205, camera.ViewportSize.X - 24)), 37)
    end
end
for _, attribute in ipairs({"DataReady", "World", "ChestDay", "ChestClaimed"}) do
    player:GetAttributeChangedSignal(attribute):Connect(update)
end
task.spawn(function()
    while gui.Parent do
        update()
        task.wait(20)
    end
end)
update()
