-- GROWLIVO / Three styled floating worlds, rune expeditions and daily chests / Alpha 0.9.24
-- ServerScriptService > GrowlivoWorld [Script]
-- Only replaces a model that is explicitly called GROWLIVO_World.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("GrowlivoConfig"))

local previous = workspace:FindFirstChild("GROWLIVO_World")
if previous then previous:Destroy() end
local world = Instance.new("Model")
world.Name = "GROWLIVO_World"
world.Parent = workspace

local GOLD = Color3.fromRGB(255, 196, 58)
local CYAN = Color3.fromRGB(34, 202, 255)
local DEEP = Color3.fromRGB(24, 42, 72)
local STONE = Color3.fromRGB(105, 128, 156)
local LEAVES = Color3.fromRGB(55, 183, 113)
local GRASS = Color3.fromRGB(84, 200, 100)
local WHITE = Color3.fromRGB(240, 250, 255)

local function part(name, size, position, color, material, parent)
    local p = Instance.new("Part")
    p.Name = name
    p.Anchored = true
    p.Size = size
    p.Position = position
    p.Material = material or Enum.Material.SmoothPlastic
    p.Color = color
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Parent = parent or world
    return p
end

local function ball(name, radius, position, color, parent)
    local p = part(name, Vector3.new(radius, radius, radius), position, color, Enum.Material.SmoothPlastic, parent)
    p.Shape = Enum.PartType.Ball
    return p
end

local function billboard(object, caption, color, height, width)
    local gui = Instance.new("BillboardGui")
    gui.Name = "WorldCaption"
    gui.Adornee = object
    gui.AlwaysOnTop = true
    gui.MaxDistance = 150
    gui.Size = UDim2.fromOffset(width or 240, 56)
    gui.StudsOffsetWorldSpace = Vector3.new(0, height or 8, 0)
    gui.Parent = object
    local text = Instance.new("TextLabel")
    text.BackgroundTransparency = 1
    text.Size = UDim2.fromScale(1, 1)
    text.Font = Enum.Font.GothamBlack
    text.Text = caption
    text.TextScaled = true
    text.TextColor3 = color
    text.TextStrokeTransparency = 0.18
    text.Parent = gui
end

local function island(name, x, z, width, depth)
    local m = Instance.new("Model")
    m.Name = name
    m.Parent = world
    part("FloatingStone", Vector3.new(width + 4, 11, depth + 4), Vector3.new(x, -7, z), STONE, Enum.Material.Slate, m)
    part("Grass", Vector3.new(width, 2, depth), Vector3.new(x, 0, z), GRASS, Enum.Material.Grass, m)
    local lip = part("GoldRim", Vector3.new(width + 1, 0.7, depth + 1), Vector3.new(x, -1.3, z), GOLD, Enum.Material.Metal, m)
    lip.CanCollide = false
    for i = 1, 4 do
        local sx = i % 2 == 0 and 1 or -1
        local sz = i <= 2 and 1 or -1
        local c = part("CornerCrystal", Vector3.new(3, 10, 3), Vector3.new(x + sx * (width/2 - 6), 6, z + sz * (depth/2 - 6)), CYAN, Enum.Material.Neon, m)
        c.CanCollide = false
    end
    return m
end

local function tree(x, z)
    part("TreeTrunk", Vector3.new(3, 12, 3), Vector3.new(x, 7, z), Color3.fromRGB(110, 75, 46), Enum.Material.Wood)
    ball("TreeLeaves", 15, Vector3.new(x, 15, z), LEAVES)
    ball("TreeLeaves", 10, Vector3.new(x - 5, 13, z + 2), LEAVES)
end

local function column(x, z, title, color)
    local base = part("Pedestal", Vector3.new(12, 4, 9), Vector3.new(x, 3, z), DEEP, Enum.Material.Metal)
    part("Trim", Vector3.new(13, 1, 10), Vector3.new(x, 5.3, z), GOLD, Enum.Material.Neon)
    billboard(base, title, color or WHITE, 9, 310)
    return base
end

island("01_SKY_CROWN", 0, 0, 120, 120)
island("02_EGGS", -102, 0, 42, 44)
island("03_UPGRADES", 102, 0, 42, 44)
island("04_PORTALS", 0, -102, 44, 42)

local function bridge(name, size, pos)
    local b = part(name, size, pos, Color3.fromRGB(161, 113, 61), Enum.Material.WoodPlanks)
    part(name .. "_Stripe", Vector3.new(size.X, 0.2, math.min(1, size.Z)), pos + Vector3.new(0, 1.12, 0), GOLD, Enum.Material.Metal)
    return b
end
bridge("BridgeEggs", Vector3.new(26, 2, 13), Vector3.new(-74, 0, 0))
bridge("BridgeUpgrades", Vector3.new(26, 2, 13), Vector3.new(74, 0, 0))
bridge("BridgePortals", Vector3.new(13, 2, 26), Vector3.new(0, 0, -74))

local spawn = Instance.new("SpawnLocation")
spawn.Name = "GROWLIVO_Spawn"
spawn.Size = Vector3.new(11, 1, 11)
spawn.Position = Vector3.new(0, 2.5, 29)
spawn.Anchored = true
spawn.Neutral = true
spawn.Material = Enum.Material.Neon
spawn.Color = CYAN
spawn.Transparency = 0.2
spawn.Parent = world

-- Monogram G built from separate physical beams, with an illuminated crown.
part("MonumentPillar", Vector3.new(19, 12, 15), Vector3.new(0, 7, -25), DEEP, Enum.Material.Metal)
part("MonumentTop", Vector3.new(23, 2, 19), Vector3.new(0, 14, -25), GOLD, Enum.Material.Metal)
local center = Vector3.new(0, 22, -25)
part("G_Left", Vector3.new(3, 13, 2), center + Vector3.new(-5, 0, 0), GOLD, Enum.Material.Neon)
part("G_Top", Vector3.new(13, 3, 2), center + Vector3.new(0, 5, 0), GOLD, Enum.Material.Neon)
part("G_Bottom", Vector3.new(13, 3, 2), center + Vector3.new(0, -5, 0), GOLD, Enum.Material.Neon)
part("G_Right", Vector3.new(3, 7, 2), center + Vector3.new(5, -3, 0), GOLD, Enum.Material.Neon)
part("G_Middle", Vector3.new(7, 3, 2), center + Vector3.new(3, 0, 0), GOLD, Enum.Material.Neon)
local crown = part("Crown", Vector3.new(16, 3, 2.5), Vector3.new(0, 32, -25), GOLD, Enum.Material.Metal)
for _, x in ipairs({-6, 0, 6}) do
    ball("CrownJewel", 3.7, Vector3.new(x, 35, -25), CYAN)
end
billboard(crown, "GROWLIVO  •  SKY CROWN", GOLD, 9, 420)

for i = 1, 12 do
    local a = i * math.pi / 6
    local x, z = math.cos(a) * 48, math.sin(a) * 48
    local crystal = part("Crystal_" .. i, Vector3.new(3, 5 + i % 4 * 2, 3), Vector3.new(x, 5, z), CYAN, Enum.Material.Neon)
    crystal.CanCollide = false
end
for _, position in ipairs({Vector2.new(-40, 37), Vector2.new(43, 37), Vector2.new(-43, -38), Vector2.new(43, -38)}) do
    tree(position.X, position.Y)
end
column(-30, 29, "КЛИКАЙ • УЛУЧШАЙСЯ", CYAN)
column(30, 29, "ПЕРЕРОЖДЕНИЯ В МЕНЮ", GOLD)

local eggStand = column(-102, 0, "НЕБЕСНОЕ ЯЙЦО  •  150", GOLD)
local egg = ball("SkyEgg", 10, Vector3.new(-102, 13, -4), CYAN)
egg.Shape = Enum.PartType.Ball
part("EggHalo", Vector3.new(14, 0.5, 14), Vector3.new(-102, 7, -4), GOLD, Enum.Material.Neon)
local prompt = Instance.new("ProximityPrompt")
prompt.Name = "OpenEggShop"
prompt.ActionText = "Открыть яйца"
prompt.ObjectText = "Небесное яйцо"
prompt.KeyboardKeyCode = Enum.KeyCode.E
prompt.HoldDuration = 0
prompt.MaxActivationDistance = 14
prompt.RequiresLineOfSight = false
prompt.Parent = eggStand

task.spawn(function()
    local folder = ReplicatedStorage:WaitForChild("GROWLIVO_Remotes", 30)
    if not folder then return end
    local openShop = folder:WaitForChild("OpenEggShop", 30)
    if not openShop then return end
    prompt.Triggered:Connect(function(player)
        openShop:FireClient(player)
    end)
end)

column(102, 0, "УЛУЧШЕНИЯ • В МЕНЮ", CYAN)
local left = part("PortalLeft", Vector3.new(4, 15, 4), Vector3.new(-10, 8, -103), CYAN, Enum.Material.Neon)
part("PortalRight", Vector3.new(4, 15, 4), Vector3.new(10, 8, -103), CYAN, Enum.Material.Neon)
part("PortalTop", Vector3.new(24, 4, 4), Vector3.new(0, 17, -103), GOLD, Enum.Material.Neon)
billboard(left, "ПОРТАЛ В НОВЫЕ МИРЫ", GOLD, 18, 315)


-- Second world: separate island to the east, reachable via the worlds panel.
local VIOLET = Color3.fromRGB(150, 105, 255)
local ICE = Color3.fromRGB(99, 221, 255)
local CRYSTAL_STONE = Color3.fromRGB(53, 62, 113)
local W2_X = 355
local crystalWorld = island("05_CRYSTAL_VALE", W2_X, 0, 112, 108)
local crystalFloor = part("CrystalFloor", Vector3.new(90, 1.2, 91), Vector3.new(W2_X, 1.6, 0), CRYSTAL_STONE, Enum.Material.Metal, crystalWorld)
crystalFloor.CanCollide = true
local crystalSpawn = part("CrystalArrival", Vector3.new(13, 1, 13), Vector3.new(W2_X, 2.5, 22), ICE, Enum.Material.Neon, crystalWorld)
crystalSpawn.Transparency = 0.25
local function obelisk(x, z, height, tint)
    local base = part("CrystalBase", Vector3.new(8, 3, 8), Vector3.new(x, 3, z), CRYSTAL_STONE, Enum.Material.Metal, crystalWorld)
    local column = part("CrystalObelisk", Vector3.new(5, height, 5), Vector3.new(x, 4 + height / 2, z), tint, Enum.Material.Neon, crystalWorld)
    column.Orientation = Vector3.new(0, 45, 0)
    column.CanCollide = false
    base.CanCollide = true
    local tip = ball("CrystalTip", 5, Vector3.new(x, 5 + height, z), tint, crystalWorld)
    tip.CanCollide = false
end
for i = 1, 12 do
    local theta = i * math.pi / 6
    local radius = (i % 2 == 0) and 44 or 36
    obelisk(W2_X + math.cos(theta) * radius, math.sin(theta) * radius, 9 + (i % 4) * 4, i % 2 == 0 and ICE or VIOLET)
end
local w2Crown = column(W2_X, -26, "CRYSTAL VALE  •  КЛИКИ x2", ICE)
part("CrystalGateLeft", Vector3.new(4, 16, 5), Vector3.new(W2_X - 11, 10, -30), VIOLET, Enum.Material.Neon, crystalWorld)
part("CrystalGateRight", Vector3.new(4, 16, 5), Vector3.new(W2_X + 11, 10, -30), VIOLET, Enum.Material.Neon, crystalWorld)
part("CrystalGateTop", Vector3.new(26, 3, 5), Vector3.new(W2_X, 19, -30), GOLD, Enum.Material.Neon, crystalWorld)
local crystalEggBase = part("CrystalEggStand", Vector3.new(16, 5, 12), Vector3.new(W2_X - 25, 5, 3), DEEP, Enum.Material.Metal, crystalWorld)
local crystalEggModel = ball("CrystalEgg", 10, Vector3.new(W2_X - 25, 14, 3), VIOLET, crystalWorld)
crystalEggModel.CanCollide = false
billboard(crystalEggBase, "КРИСТАЛЬНОЕ ЯЙЦО  •  2500", ICE, 10, 300)
local crystalEggPrompt = Instance.new("ProximityPrompt")
crystalEggPrompt.ActionText = "Открыть яйца"
crystalEggPrompt.ObjectText = "Кристальное яйцо"
crystalEggPrompt.HoldDuration = 0
crystalEggPrompt.MaxActivationDistance = 13
crystalEggPrompt.RequiresLineOfSight = false
crystalEggPrompt.Parent = crystalEggBase
local worldPromptBase = part("WorldPortalConsole", Vector3.new(10, 4, 10), Vector3.new(0, 5, -107), DEEP, Enum.Material.Metal, world)
local worldPrompt = Instance.new("ProximityPrompt")
worldPrompt.ActionText = "Открыть миры"
worldPrompt.ObjectText = "Межмировой портал"
worldPrompt.HoldDuration = 0
worldPrompt.MaxActivationDistance = 13
worldPrompt.RequiresLineOfSight = false
worldPrompt.Parent = worldPromptBase
local returnPortal = part("ReturnPortal", Vector3.new(11, 4, 10), Vector3.new(W2_X + 28, 5, 3), DEEP, Enum.Material.Metal, crystalWorld)
billboard(returnPortal, "ПОРТАЛ • ВЫБОР МИРА", GOLD, 9, 240)
local returnPrompt = Instance.new("ProximityPrompt")
returnPrompt.ActionText = "Выбрать мир"
returnPrompt.ObjectText = "Обратный портал"
returnPrompt.HoldDuration = 0
returnPrompt.MaxActivationDistance = 13
returnPrompt.RequiresLineOfSight = false
returnPrompt.Parent = returnPortal
-- World scripts only open UI. Teleport, unlock and egg payments are validated on the server.
task.spawn(function()
    local folder = ReplicatedStorage:WaitForChild("GROWLIVO_Remotes", 30)
    if not folder then return end
    local eggRemote = folder:WaitForChild("OpenEggShop", 30)
    local worldRemote = folder:WaitForChild("OpenWorldMenu", 30)
    if eggRemote then
        crystalEggPrompt.Triggered:Connect(function(player)
            -- Avoid offering the second-world egg to players who are elsewhere.
            if player:GetAttribute("World") == "CrystalVale" then eggRemote:FireClient(player) end
        end)
    end
    if worldRemote then
        worldPrompt.Triggered:Connect(function(player) worldRemote:FireClient(player) end)
        returnPrompt.Triggered:Connect(function(player) worldRemote:FireClient(player) end)
    end
end)


-- Alpha 0.9.20: AURORA GROVE. Independent third island, green aurora beams,
-- giant luminous tree, an egg sanctuary and a return portal.
-- Gameplay unlocks and hatch costs are still decided by GrowlivoServer.
local W3_X = -355
local MINT = Color3.fromRGB(109, 255, 190)
local PINK = Color3.fromRGB(255, 152, 231)
local GROVE_STONE = Color3.fromRGB(52, 84, 91)
local GROVE_GRASS = Color3.fromRGB(45, 133, 110)
local grove = Instance.new("Model")
grove.Name = "08_AURORA_GROVE"
grove.Parent = world
part("GroveFloatingRock", Vector3.new(120, 12, 115), Vector3.new(W3_X, -7, 0), GROVE_STONE, Enum.Material.Slate, grove)
part("GroveMoss", Vector3.new(116, 2, 111), Vector3.new(W3_X, 0, 0), GROVE_GRASS, Enum.Material.Grass, grove)
local groveRim = part("GroveRim", Vector3.new(119, 0.65, 114), Vector3.new(W3_X, -1.3, 0), MINT, Enum.Material.Neon, grove)
groveRim.CanCollide = false
local arrival = part("AuroraArrival", Vector3.new(13, 1, 13), Vector3.new(W3_X, 2.5, 25), MINT, Enum.Material.Neon, grove)
arrival.Transparency = 0.28
for i = 1, 12 do
    local theta = i * math.pi / 6
    local x, z = W3_X + math.cos(theta) * 44, math.sin(theta) * 42
    local stump = part("AuroraTrunk", Vector3.new(3.5, 12, 3.5), Vector3.new(x, 7, z), GROVE_STONE, Enum.Material.Wood, grove)
    local canopy = ball("AuroraCanopy", i % 3 == 0 and 13 or 10, Vector3.new(x, 15, z), i % 2 == 0 and MINT or PINK, grove)
    canopy.Material = Enum.Material.Neon
    canopy.Transparency = 0.34
    stump.CanCollide = false
    canopy.CanCollide = false
end
-- Central landmark tree; trunk is intentionally away from the arrival pad.
local ancientTrunk = part("AncientAuroraTree", Vector3.new(11, 34, 11), Vector3.new(W3_X, 19, -25), GROVE_STONE, Enum.Material.Wood, grove)
local ancientCrown = ball("AuroraTreeCrown", 28, Vector3.new(W3_X, 40, -25), MINT, grove)
ancientCrown.Material = Enum.Material.Glass
ancientCrown.Transparency = 0.18
ancientCrown.CanCollide = false
billboard(ancientTrunk, "AURORA GROVE  •  КЛИКИ x4", MINT, 27, 330)
local glowTree = Instance.new("PointLight")
glowTree.Name = "AuroraTreeLight"
glowTree.Color = MINT
glowTree.Brightness = 1.5
glowTree.Range = 40
glowTree.Shadows = false
glowTree.Parent = ancientCrown
for i = 1, 10 do
    local theta = 2 * math.pi * i / 10
    local shard = part("AuroraRune", Vector3.new(2.8, 9 + (i % 3) * 3, 2.8),
        Vector3.new(W3_X + math.cos(theta) * 31, 5.6, -15 + math.sin(theta) * 28),
        i % 2 == 0 and MINT or PINK, Enum.Material.Neon, grove)
    shard.Orientation = Vector3.new(0, 45, 18)
    shard.CanCollide = false
end
local groveEggBase = part("AuroraEggStand", Vector3.new(15, 5, 12), Vector3.new(W3_X - 25, 5, 6), GROVE_STONE, Enum.Material.Metal, grove)
local groveEgg = ball("AuroraEgg", 10, Vector3.new(W3_X - 25, 14, 6), PINK, grove)
groveEgg.Material = Enum.Material.Neon
groveEgg.CanCollide = false
billboard(groveEggBase, "ЯЙЦО СИЯНИЯ  •  15000", MINT, 10, 320)
local groveEggPrompt = Instance.new("ProximityPrompt")
groveEggPrompt.Name = "OpenAuroraEgg"
groveEggPrompt.ActionText = "Открыть яйца"
groveEggPrompt.ObjectText = "Яйцо сияния"
groveEggPrompt.KeyboardKeyCode = Enum.KeyCode.E
groveEggPrompt.MaxActivationDistance = 13
groveEggPrompt.HoldDuration = 0
groveEggPrompt.RequiresLineOfSight = false
groveEggPrompt.Parent = groveEggBase
local grovePortal = part("AuroraReturnPortal", Vector3.new(11, 4, 10), Vector3.new(W3_X + 29, 5, 6), GROVE_STONE, Enum.Material.Metal, grove)
billboard(grovePortal, "ПОРТАЛ • ВЫБОР МИРА", MINT, 9, 260)
local grovePrompt = Instance.new("ProximityPrompt")
grovePrompt.Name = "OpenWorlds"
grovePrompt.ActionText = "Выбрать мир"
grovePrompt.ObjectText = "Портал Рощи сияния"
grovePrompt.MaxActivationDistance = 13
grovePrompt.HoldDuration = 0
grovePrompt.RequiresLineOfSight = false
grovePrompt.Parent = grovePortal
for z = 0, 23, 6 do
    local tile = part("AuroraPath", Vector3.new(9, 0.2, 5.4), Vector3.new(W3_X, 1.16, z), PINK, Enum.Material.Glass, grove)
    tile.CanCollide = false
    tile.Transparency = 0.25
end
-- Prompts open an existing UI; they never grant worlds, currencies or pets.
task.spawn(function()
    local folder = ReplicatedStorage:WaitForChild("GROWLIVO_Remotes", 30)
    if not folder then return end
    local eggsEvent = folder:WaitForChild("OpenEggShop", 30)
    local worldsEvent = folder:WaitForChild("OpenWorldMenu", 30)
    if eggsEvent then
        groveEggPrompt.Triggered:Connect(function(player)
            if player:GetAttribute("World") == "AuroraGrove" then
                eggsEvent:FireClient(player)
            end
        end)
    end
    if worldsEvent then
        grovePrompt.Triggered:Connect(function(player)
            if player:GetAttribute("World") == "AuroraGrove" then
                worldsEvent:FireClient(player)
            end
        end)
    end
end)

-- Alpha 0.9.14: polished landmarks and low-cost, asset-free visual dressing.
-- All props stay inside GROWLIVO_World and disappear when the world regenerates.
local function decoration(name, size, where, tint, material, parent)
    local result = part(name, size, where, tint, material, parent)
    result.CanCollide = false
    result.CanTouch = false
    result.CanQuery = false
    return result
end
local function glow(object, tint, range, brightness)
    local light = Instance.new("PointLight")
    light.Name = "RoyalGlow"
    light.Color = tint
    light.Range = range or 15
    light.Brightness = brightness or 0.75
    light.Shadows = false
    light.Parent = object
end
local function shimmer(object, tint, rate)
    local emit = Instance.new("ParticleEmitter")
    emit.Name = "CrystalShimmer"
    emit.Rate = rate or 2
    emit.Lifetime = NumberRange.new(0.6, 1.5)
    emit.Speed = NumberRange.new(0.5, 1.6)
    emit.SpreadAngle = Vector2.new(35, 35)
    emit.LightEmission = 0.7
    emit.Color = ColorSequence.new(tint, WHITE)
    emit.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 0)})
    emit.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1)})
    emit.Parent = object
end
local decor = Instance.new("Model")
decor.Name = "06_ROYAL_DECOR"
decor.Parent = world

-- Crown-ring silhouette: luminous ring behind the central G landmark.
local radius = 18
for i = 1, 28 do
    local angleA = (i - 1) * 2 * math.pi / 28
    local angleB = i * 2 * math.pi / 28
    local from = Vector3.new(math.cos(angleA) * radius, 24 + math.sin(angleA) * radius, -32)
    local to = Vector3.new(math.cos(angleB) * radius, 24 + math.sin(angleB) * radius, -32)
    local beam = decoration("MonumentHaloSegment", Vector3.new(1.25, 1.25, (to - from).Magnitude + 0.2), (from + to) / 2, i % 5 == 0 and CYAN or GOLD, Enum.Material.Neon, decor)
    beam.CFrame = CFrame.lookAt((from + to) / 2, to)
end

-- Landmark arch deliberately leaves the middle of the walking path clear.
for _, x in ipairs({-19, 19}) do
    decoration("ArrivalArchColumn", Vector3.new(3.5, 18, 3.5), Vector3.new(x, 10, 12), DEEP, Enum.Material.Metal, decor)
    local cap = decoration("ArrivalArchGem", Vector3.new(5, 5, 5), Vector3.new(x, 20.5, 12), CYAN, Enum.Material.Neon, decor)
    cap.Shape = Enum.PartType.Ball
    glow(cap, CYAN, 16, 0.6)
end
decoration("ArrivalArchLintel", Vector3.new(42, 2.8, 4), Vector3.new(0, 21.5, 12), GOLD, Enum.Material.Metal, decor)
decoration("ArrivalArchInlay", Vector3.new(40, 0.7, 4.2), Vector3.new(0, 23.2, 12), CYAN, Enum.Material.Neon, decor)

-- Four compact fountain plinths, with shimmering magical cores.
for _, position in ipairs({Vector2.new(-35, 4), Vector2.new(35, 4), Vector2.new(-35, -20), Vector2.new(35, -20)}) do
    local x, z = position.X, position.Y
    decoration("FountainBase", Vector3.new(10, 2, 10), Vector3.new(x, 2, z), DEEP, Enum.Material.Marble, decor)
    local bowl = decoration("FountainWater", Vector3.new(8, 0.5, 8), Vector3.new(x, 3.25, z), CYAN, Enum.Material.Neon, decor)
    bowl.Transparency = 0.22
    local gem = decoration("FountainCrystal", Vector3.new(3, 7, 3), Vector3.new(x, 8, z), GOLD, Enum.Material.Neon, decor)
    gem.Orientation = Vector3.new(0, 45, 23)
    shimmer(gem, GOLD, 3)
end

-- Sky waterfalls dropping past the edge: decorative, zero collision.
for _, x in ipairs({-31, 31}) do
    local waterfall = decoration("SkyWaterfall", Vector3.new(9, 30, 0.8), Vector3.new(x, -13, 60.9), CYAN, Enum.Material.Neon, decor)
    waterfall.Transparency = 0.4
    shimmer(waterfall, CYAN, 4)
end

-- Soft suspended clouds under and between islands (purely atmospheric).
for i = 1, 18 do
    local theta = i * 2.399963229728653
    local distance = 78 + (i % 5) * 24
    local x, z = math.cos(theta) * distance, math.sin(theta) * distance
    local cloud = decoration("CloudBank", Vector3.new(20 + i % 4 * 6, 6 + i % 3 * 2, 14 + i % 4 * 4), Vector3.new(x, -18 - i % 3 * 5, z), WHITE, Enum.Material.SmoothPlastic, decor)
    cloud.Shape = Enum.PartType.Ball
    cloud.Transparency = 0.45
end

-- Egg islands receive larger glowing egg pedestals and navigational beacons.
for _, spec in ipairs({
    {Pos = Vector3.new(-102, 12, -4), Color = GOLD},
    {Pos = Vector3.new(W2_X - 25, 14, 3), Color = VIOLET},
}) do
    local shell = decoration("EggGlaze", Vector3.new(7, 9, 7), spec.Pos + Vector3.new(0, 0.5, 0), spec.Color, Enum.Material.Glass, decor)
    shell.Shape = Enum.PartType.Ball
    shell.Transparency = 0.45
    shimmer(shell, spec.Color, 2)
    glow(shell, spec.Color, 18, 0.9)
end

-- A dedicated quest and trophy spot helps players orient without duplicating game UI.
local questsSign = decoration("QuestMonolith", Vector3.new(11, 13, 4), Vector3.new(-27, 7.5, 47), DEEP, Enum.Material.Metal, decor)
decoration("QuestMonolithInlay", Vector3.new(9, 8, 0.4), Vector3.new(-27, 9.5, 44.8), GOLD, Enum.Material.Neon, decor)
billboard(questsSign, "ЗАДАНИЯ • ОТКРОЙ МЕНЮ", WHITE, 12, 270)
local trophySign = decoration("TrophyMonolith", Vector3.new(11, 13, 4), Vector3.new(27, 7.5, 47), DEEP, Enum.Material.Metal, decor)
decoration("TrophyMonolithInlay", Vector3.new(9, 8, 0.4), Vector3.new(27, 9.5, 44.8), CYAN, Enum.Material.Neon, decor)
billboard(trophySign, "ДОСТИЖЕНИЯ • МЕНЮ", WHITE, 12, 270)

-- Decorative spires in Crystal Vale, spaced away from its main paths.
for i = 1, 8 do
    local a = i * math.pi / 4
    local x, z = W2_X + math.cos(a) * 40, math.sin(a) * 40
    local shard = decoration("ValleyShard", Vector3.new(3.5, 11 + (i % 3) * 4, 3.5), Vector3.new(x, 8, z), i % 2 == 0 and ICE or VIOLET, Enum.Material.Glass, decor)
    shard.Orientation = Vector3.new(0, 45, i % 3 * 8)
    shimmer(shard, i % 2 == 0 and ICE or VIOLET, 2)
end

-- Alpha 0.9.14: navigable royal cobblestones and signature lanterns.
-- Decorative pieces deliberately have no collision and don't block avatars.
local royalPath = Instance.new("Model")
royalPath.Name = "07_ROYAL_PATHS"
royalPath.Parent = world
for z = -12, 39, 6 do
    local tile = decoration("CrownWalkway", Vector3.new(12, 0.15, 5.6), Vector3.new(0, 1.13, z), DEEP, Enum.Material.Slate, royalPath)
    tile.Transparency = 0.06
    for _, x in ipairs({-5.4, 5.4}) do
        local stripe = decoration("GoldenWalkwayEdge", Vector3.new(0.5, 0.18, 5.3), Vector3.new(x, 1.22, z), GOLD, Enum.Material.Metal, royalPath)
        stripe.Reflectance = 0.08
    end
end
for _, x in ipairs({-8, 8}) do
    for _, z in ipairs({-18, 2, 22, 42}) do
        local column = decoration("RoyalLanternPost", Vector3.new(0.7, 5, 0.7), Vector3.new(x, 3.7, z), DEEP, Enum.Material.Metal, royalPath)
        column.CanCollide = false
        local orb = decoration("RoyalLanternOrb", Vector3.new(2.1, 2.1, 2.1), Vector3.new(x, 6.4, z), CYAN, Enum.Material.Neon, royalPath)
        orb.Shape = Enum.PartType.Ball
        glow(orb, CYAN, 9, 0.35)
        decoration("RoyalLanternCrown", Vector3.new(2.5, 0.35, 2.5), Vector3.new(x, 7.6, z), GOLD, Enum.Material.Metal, royalPath)
    end
end
-- Crystal Vale has its own welcoming pathway and a glowing landmark.
for z = -12, 28, 8 do
    decoration("CrystalPath", Vector3.new(9, 0.18, 7), Vector3.new(W2_X, 2.35, z), VIOLET, Enum.Material.Glass, royalPath).Transparency = 0.4
end
local valeOrb = decoration("ValeBeacon", Vector3.new(8, 8, 8), Vector3.new(W2_X, 15, -26), ICE, Enum.Material.Glass, royalPath)
valeOrb.Shape = Enum.PartType.Ball
valeOrb.Transparency = 0.18
glow(valeOrb, ICE, 23, 1.1)
shimmer(valeOrb, ICE, 5)

-- Alpha 0.9.21: three rune shrines in each world (server-handled Prompts).
-- All runes are cosmetic and non-collidable; the core platform remains walkable.
local runeModel = Instance.new("Model")
runeModel.Name = "09_RUNE_EXPEDITIONS"
runeModel.Parent = world

local function buildRune(worldId, runeIndex, x, z, groundY, tint)
    local y = groundY + 1.8
    local base = decoration("RunePedestal", Vector3.new(6, 2, 6), Vector3.new(x, y, z), DEEP, Enum.Material.Metal, runeModel)
    base.CanCollide = false
    local ornament = decoration("RuneCore", Vector3.new(3.2, 5.2, 2.0), Vector3.new(x, y + 3.8, z), tint, Enum.Material.Neon, runeModel)
    ornament.Orientation = Vector3.new(0, 45, 25)
    ornament.CanCollide = false
    ornament.Transparency = 0.13
    local halo = decoration("RuneHalo", Vector3.new(7.2, 0.25, 7.2), Vector3.new(x, groundY + 0.65, z), tint, Enum.Material.Neon, runeModel)
    halo.Transparency = 0.28
    halo.CanCollide = false
    glow(ornament, tint, 12, 0.65)
    billboard(ornament, "РУНА " .. runeIndex .. "/3  •  E", tint, 6.5, 178)
    -- Attributes are set by the world builder, never supplied by the client.
    base:SetAttribute("RuneWorld", worldId)
    base:SetAttribute("RuneIndex", runeIndex)
    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = "GrowlivoRunePrompt"
    prompt.ActionText = "Активировать руну"
    prompt.ObjectText = "Руна " .. runeIndex .. "/3"
    prompt.KeyboardKeyCode = Enum.KeyCode.E
    prompt.MaxActivationDistance = 12
    prompt.HoldDuration = 0.35
    prompt.RequiresLineOfSight = false
    prompt.Parent = base
end

for _, row in ipairs({
    {"SkyCrown", 1, -36, -6, 1, GOLD},
    {"SkyCrown", 2, 36, 8, 1, CYAN},
    {"SkyCrown", 3, 0, 48, 1, GOLD},
    {"CrystalVale", 1, W2_X - 29, -20, 2.2, ICE},
    {"CrystalVale", 2, W2_X + 30, -5, 2.2, VIOLET},
    {"CrystalVale", 3, W2_X + 6, 33, 2.2, ICE},
    {"AuroraGrove", 1, W3_X - 34, -13, 1, MINT},
    {"AuroraGrove", 2, W3_X + 34, -13, 1, PINK},
    {"AuroraGrove", 3, W3_X + 4, 38, 1, MINT},
}) do
    buildRune(row[1], row[2], row[3], row[4], row[5], row[6])
end

-- Each world receives restrained landmark accents and an accessible path.
local accentModel = Instance.new("Model")
accentModel.Name = "10_WORLD_ACCENTS"
accentModel.Parent = world
for _, x in ipairs({-12, 12}) do
    for _, z in ipairs({-48, -32, -15}) do
        local pennant = decoration("SkyBanner", Vector3.new(1.6, 8, 0.35), Vector3.new(x, 7, z), GOLD, Enum.Material.Metal, accentModel)
        pennant.CanCollide = false
        local jewel = decoration("BannerGem", Vector3.new(1, 1, 1), Vector3.new(x, 10, z - 0.25), CYAN, Enum.Material.Neon, accentModel)
        jewel.Shape = Enum.PartType.Ball
        jewel.CanCollide = false
    end
end
for _, dx in ipairs({-23, 23}) do
    for _, z in ipairs({-36, 12, 36}) do
        local crystalAccent = decoration("ValePrism", Vector3.new(2, 6.5, 2), Vector3.new(W2_X + dx, 5.4, z), VIOLET, Enum.Material.Glass, accentModel)
        crystalAccent.Orientation = Vector3.new(0, 45, 17)
        crystalAccent.CanCollide = false
    end
end
for z = -10, 35, 5 do
    local tile = decoration("GroveTrail", Vector3.new(9.2, 0.18, 4.3), Vector3.new(W3_X, 1.18, z), PINK, Enum.Material.Glass, accentModel)
    tile.Transparency = 0.58
    tile.CanCollide = false
end


-- Alpha 0.9.24: three daily treasure chests, one for each world.
-- Visual-only map objects. Rewards and per-player claims are server-validated.
local chestGroup = Instance.new("Model")
chestGroup.Name = "11_WORLD_CHESTS"
chestGroup.Parent = world
local function makeChest(worldId, x, z, groundY, accent)
    local p = Vector3.new(x, groundY + 2.2, z)
    local body = part("WorldTreasureChest", Vector3.new(7, 4.4, 5), p, DEEP, Enum.Material.WoodPlanks, chestGroup)
    body:SetAttribute("ChestWorld", worldId)
    part("TreasureLid", Vector3.new(7.8, 1.1, 5.5), p + Vector3.new(0, 2.6, 0), GOLD, Enum.Material.Metal, chestGroup)
    local lock = part("TreasureLock", Vector3.new(1.7, 1.7, 0.45), p + Vector3.new(0, 0.5, -2.7), accent, Enum.Material.Neon, chestGroup)
    lock.CanCollide = false
    local highlight = Instance.new("PointLight")
    highlight.Brightness = 0.7
    highlight.Range = 14
    highlight.Color = accent
    highlight.Parent = lock
    billboard(body, "СУНДУК ДНЯ  •  E", accent, 7, 240)
    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = "GrowlivoChestPrompt"
    prompt.ActionText = "Забрать награду"
    prompt.ObjectText = "Ежедневный сундук"
    prompt.KeyboardKeyCode = Enum.KeyCode.E
    prompt.HoldDuration = 0.5
    prompt.MaxActivationDistance = 12
    prompt.RequiresLineOfSight = false
    prompt.Parent = body
end
makeChest("SkyCrown", 32, 32, 1, CYAN)
makeChest("CrystalVale", W2_X + 30, 30, 2.2, ICE)
makeChest("AuroraGrove", W3_X + 28, 31, 1, PINK)

for _, name in ipairs({"GROWLIVO_Bloom", "GROWLIVO_Atmosphere", "GROWLIVO_SunRays"}) do
    local effect = Lighting:FindFirstChild(name)
    if effect then effect:Destroy() end
end
local bloom = Instance.new("BloomEffect")
bloom.Name = "GROWLIVO_Bloom"
bloom.Intensity = 0.38
bloom.Size = 24
bloom.Threshold = 1.25
bloom.Parent = Lighting
local atmosphere = Instance.new("Atmosphere")
atmosphere.Name = "GROWLIVO_Atmosphere"
atmosphere.Density = 0.26
atmosphere.Offset = 0.1
atmosphere.Color = Color3.fromRGB(173, 221, 255)
atmosphere.Decay = Color3.fromRGB(74, 119, 174)
atmosphere.Parent = Lighting
local rays = Instance.new("SunRaysEffect")
rays.Name = "GROWLIVO_SunRays"
rays.Intensity = 0.055
rays.Spread = 0.8
rays.Parent = Lighting

Lighting.ClockTime = 13.5
Lighting.Brightness = 2.5
Lighting.Ambient = Color3.fromRGB(116, 143, 196)
Lighting.OutdoorAmbient = Color3.fromRGB(135, 176, 215)
world:SetAttribute("WorldReady", true)
print("[GROWLIVO] World built: Sky Crown + Crystal Vale + Aurora Grove + Royal Decor / " .. Config.Version)
