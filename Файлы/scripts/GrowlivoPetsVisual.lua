-- GROWLIVO / Nine distinctive low-poly pet follower silhouettes / Alpha 0.9.14
-- StarterPlayer > StarterPlayerScripts > GrowlivoPetsVisual [LocalScript]
-- All pets are cosmetic client-only models. The server calculates game bonuses.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("GrowlivoConfig"))
local remotes = ReplicatedStorage:WaitForChild("GROWLIVO_Remotes")
local petState = remotes:WaitForChild("PetState")
local action = remotes:WaitForChild("Action")
local models = {}
local folder = Instance.new("Folder")
folder.Name = "GROWLIVO_LocalPets"
folder.Parent = workspace
local function setVisibility()
    local show = player:GetAttribute("SettingShowPets") ~= false
    folder.Parent = show and workspace or nil
end
player:GetAttributeChangedSignal("SettingShowPets"):Connect(setVisibility)
setVisibility()

local INK = Color3.fromRGB(14, 28, 47)
local PALE = Color3.fromRGB(249, 250, 255)
local GOLD = Color3.fromRGB(255, 208, 83)
local function piece(parent, name, size, offset, color, shape, material)
    local p = Instance.new("Part")
    p.Name = name
    p.Size = size
    p.CFrame = CFrame.new(offset)
    p.Shape = shape or Enum.PartType.Ball
    p.Material = material or Enum.Material.SmoothPlastic
    p.Color = color
    p.Anchored = true
    p.CanCollide = false
    p.CanTouch = false
    p.CanQuery = false
    p.CastShadow = false
    p.Parent = parent
    return p
end
local function ornament(model, species, primary)
    local c = primary
    local function shape(name, size, pos, color, typ)
        return piece(model, name, size, pos, color or c, typ)
    end
    if species == "CloudBunny" then
        shape("LongEarL", Vector3.new(0.85, 2.6, 0.8), Vector3.new(-0.88, 2.25, -0.15))
        shape("LongEarR", Vector3.new(0.85, 2.6, 0.8), Vector3.new(0.88, 2.25, -0.15))
        shape("CloudTail", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, -0.3, 1.5), PALE)
    elseif species == "SunFox" then
        shape("FoxEarL", Vector3.new(1.05, 1.4, 1.05), Vector3.new(-1.1, 1.55, -0.1))
        shape("FoxEarR", Vector3.new(1.05, 1.4, 1.05), Vector3.new(1.1, 1.55, -0.1))
        shape("FoxMuzzle", Vector3.new(1.3, 0.7, 0.8), Vector3.new(0, -0.25, -1.52), PALE)
        shape("FoxTail", Vector3.new(2.7, 1.2, 1.2), Vector3.new(1.35, -0.8, 1.6))
        shape("FoxTailTip", Vector3.new(1, 1, 1), Vector3.new(2.5, -0.8, 1.8), PALE)
    elseif species == "SkyOwl" then
        shape("OwlWingL", Vector3.new(1.8, 2.3, 0.75), Vector3.new(-2.1, -0.25, 0.3))
        shape("OwlWingR", Vector3.new(1.8, 2.3, 0.75), Vector3.new(2.1, -0.25, 0.3))
        shape("OwlBeak", Vector3.new(0.65, 0.7, 0.75), Vector3.new(0, -0.2, -1.8), GOLD)
        shape("OwlBrowL", Vector3.new(1.0, 0.35, 0.4), Vector3.new(-0.8, 0.95, -1.55), PALE)
        shape("OwlBrowR", Vector3.new(1.0, 0.35, 0.4), Vector3.new(0.8, 0.95, -1.55), PALE)
    elseif species == "CrystalCat" then
        shape("CatEarL", Vector3.new(0.8, 1.7, 0.9), Vector3.new(-1, 1.85, 0))
        shape("CatEarR", Vector3.new(0.8, 1.7, 0.9), Vector3.new(1, 1.85, 0))
        shape("CatGem", Vector3.new(0.75, 0.85, 0.6), Vector3.new(0, 0.92, -1.6), GOLD)
        shape("CatTail", Vector3.new(0.9, 2.6, 0.9), Vector3.new(1.5, -0.1, 1.2))
    elseif species == "CrownDragon" then
        shape("DragonWingL", Vector3.new(2.3, 2.4, 0.45), Vector3.new(-2.2, 0.15, 0.5))
        shape("DragonWingR", Vector3.new(2.3, 2.4, 0.45), Vector3.new(2.2, 0.15, 0.5))
        for _, x in ipairs({-1, 0, 1}) do
            shape("CrownSpike", Vector3.new(0.7, x == 0 and 1.7 or 1.2, 0.7), Vector3.new(x, 1.85, -0.2), GOLD)
        end
        shape("DragonNose", Vector3.new(1.3, 0.8, 1.1), Vector3.new(0, -0.25, -1.65))
    elseif species == "GemSlime" then
        local halo = shape("SlimeHalo", Vector3.new(4.1, 4.1, 4.1), Vector3.new(0, 0, 0), PALE)
        halo.Transparency = 0.86
        shape("SlimeCrownGem", Vector3.new(1.1, 1.7, 1.1), Vector3.new(0, 1.9, 0), GOLD)
    elseif species == "PrismDeer" then
        shape("DeerNose", Vector3.new(0.95, 0.7, 0.85), Vector3.new(0, -0.1, -1.67), PALE)
        for _, x in ipairs({-1, 1}) do
            shape("AntlerStem", Vector3.new(0.5, 2.7, 0.6), Vector3.new(x * 0.95, 2.25, 0.2), GOLD)
            shape("AntlerBranch", Vector3.new(1.25, 0.4, 0.55), Vector3.new(x * 1.52, 2.8, 0), GOLD)
        end
    elseif species == "AzurePhoenix" then
        shape("PhoenixWingL", Vector3.new(3.0, 2.1, 0.6), Vector3.new(-2.25, 0.25, 0))
        shape("PhoenixWingR", Vector3.new(3.0, 2.1, 0.6), Vector3.new(2.25, 0.25, 0))
        shape("PhoenixPlume", Vector3.new(0.9, 2.4, 0.9), Vector3.new(0, 2.2, 0), GOLD)
        shape("PhoenixTailL", Vector3.new(0.7, 2.2, 0.7), Vector3.new(-0.75, -1.65, 1.0))
        shape("PhoenixTailR", Vector3.new(0.7, 2.2, 0.7), Vector3.new(0.75, -1.65, 1.0))
    elseif species == "DiamondWyrm" then
        for i = 1, 3 do
            shape("WyrmTail_" .. i, Vector3.new(1.65 - i * 0.25, 1.65 - i * 0.25, 1.65 - i * 0.25), Vector3.new(0, -i * 0.37, 1.2 + i * 0.95))
        end
        shape("WyrmHornL", Vector3.new(0.7, 1.8, 0.7), Vector3.new(-0.95, 1.8, 0), GOLD)
        shape("WyrmHornR", Vector3.new(0.7, 1.8, 0.7), Vector3.new(0.95, 1.8, 0), GOLD)
    elseif species == "AuroraMoth" then
        shape("MothWingL", Vector3.new(2.5, 3.1, 0.35), Vector3.new(-2.05, 0.4, 0.6), PALE)
        shape("MothWingR", Vector3.new(2.5, 3.1, 0.35), Vector3.new(2.05, 0.4, 0.6), PALE)
        shape("MothAntennaL", Vector3.new(0.25, 1.7, 0.25), Vector3.new(-0.65, 2.05, -0.6), GOLD)
        shape("MothAntennaR", Vector3.new(0.25, 1.7, 0.25), Vector3.new(0.65, 2.05, -0.6), GOLD)
    elseif species == "DuskWolf" then
        shape("WolfEarL", Vector3.new(0.85, 1.65, 0.75), Vector3.new(-1.1, 1.9, 0))
        shape("WolfEarR", Vector3.new(0.85, 1.65, 0.75), Vector3.new(1.1, 1.9, 0))
        shape("WolfSnout", Vector3.new(1.4, 0.8, 1.2), Vector3.new(0, -0.4, -1.65), PALE)
        shape("WolfTail", Vector3.new(1.25, 1.5, 1.65), Vector3.new(1.35, -0.65, 1.65))
    elseif species == "RuneStag" then
        for _, direction in ipairs({-1, 1}) do
            shape("RuneAntlerStem", Vector3.new(0.48, 3.0, 0.5), Vector3.new(direction * 0.85, 2.4, 0), GOLD)
            shape("RuneAntlerTip", Vector3.new(1.1, 0.45, 0.6), Vector3.new(direction * 1.42, 3.1, -0.15), PALE)
        end
        shape("RuneForehead", Vector3.new(0.85, 1, 0.4), Vector3.new(0, 0.95, -1.55), GOLD)
    elseif species == "DawnGriffin" then
        shape("GriffinWingL", Vector3.new(3, 2.6, 0.65), Vector3.new(-2.3, 0.25, 0.7), GOLD)
        shape("GriffinWingR", Vector3.new(3, 2.6, 0.65), Vector3.new(2.3, 0.25, 0.7), GOLD)
        shape("GriffinBeak", Vector3.new(1.05, 0.85, 1.2), Vector3.new(0, -0.15, -1.9), PALE)
        shape("GriffinCrest", Vector3.new(1, 1.75, 0.85), Vector3.new(0, 1.95, -0.45), GOLD)
        shape("GriffinTail", Vector3.new(0.85, 2.2, 0.85), Vector3.new(0.85, -1.4, 1.5))
    end
end
local function makePet(item)
    local def = Config.FindPet(item.Species)
    if not def then return nil end
    local m = Instance.new("Model")
    m.Name = "Pet_" .. tostring(item.Id)
    m.Parent = folder
    local body = piece(m, "Body", Vector3.new(3.25, 3, 3.25), Vector3.zero, def.Color)
    m.PrimaryPart = body
    m:SetAttribute("PetId", item.Id)
    m:SetAttribute("Species", item.Species)
    ornament(m, def.Id, def.Color)
    for _, x in ipairs({-0.69, 0.69}) do
        piece(m, "Eye", Vector3.new(0.42, 0.52, 0.34), Vector3.new(x, 0.25, -1.56), INK)
        piece(m, "EyeShine", Vector3.new(0.16, 0.16, 0.14), Vector3.new(x - 0.08, 0.39, -1.78), PALE)
    end
    local nameGui = Instance.new("BillboardGui")
    nameGui.Name = "NameTag"
    nameGui.Adornee = body
    nameGui.Size = UDim2.fromOffset(160, 28)
    nameGui.StudsOffsetWorldSpace = Vector3.new(0, 3.8, 0)
    nameGui.MaxDistance = 70
    nameGui.Parent = body
    local text = Instance.new("TextLabel")
    text.Size = UDim2.fromScale(1, 1)
    text.BackgroundTransparency = 1
    text.Font = Enum.Font.GothamBold
    text.Text = def.Name
    text.TextScaled = true
    text.TextColor3 = def.Color
    text.TextStrokeTransparency = 0.14
    text.Parent = nameGui
    return m
end

local function refresh(inventory, equipped)
    if typeof(inventory) ~= "table" or typeof(equipped) ~= "table" then return end
    local lookup = {}
    for _, item in ipairs(inventory) do
        if typeof(item) == "table" and typeof(item.Id) == "number" then lookup[item.Id] = item end
    end
    -- Reuse unchanged 3D followers rather than destroy/recreate all their Parts.
    -- PetState can be broadcast after many independent profile actions.
    local byId = {}
    for _, model in ipairs(models) do
        local id = model:GetAttribute("PetId")
        if typeof(id) == "number" then byId[id] = model else model:Destroy() end
    end
    local updated = {}
    for i = 1, math.min(#equipped, Config.MaxEquippedPets) do
        local item = lookup[equipped[i]]
        if item then
            local pet = byId[item.Id]
            if pet and pet:GetAttribute("Species") ~= item.Species then
                pet:Destroy()
                pet = nil
            end
            if not pet then pet = makePet(item) end
            byId[item.Id] = nil
            if pet then table.insert(updated, pet) end
        end
    end
    for _, obsolete in pairs(byId) do obsolete:Destroy() end
    models = updated
end
petState.OnClientEvent:Connect(refresh)
local function request()
    if player:GetAttribute("DataReady") == true then action:FireServer("GetPets") end
end
player:GetAttributeChangedSignal("DataReady"):Connect(request)
task.delay(1, request)

-- Low-overhead follower tick: avoids rebuilding transforms at display refresh rate.
local UserInputService = game:GetService("UserInputService")
local elapsed = 0
RunService.Heartbeat:Connect(function(delta)
    if player:GetAttribute("SettingShowPets") == false or #models == 0 then
        elapsed = 0
        return
    end
    elapsed += math.min(delta, 0.2)
    -- Mobile/low-motion get a smaller animation budget; the game economy is unaffected.
    local interval = UserInputService.TouchEnabled and (1 / 15) or (1 / 30)
    if player:GetAttribute("SettingReducedMotion") == true then interval = 1 / 12 end
    if elapsed < interval then return end
    local step = elapsed
    elapsed = 0
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local camera = workspace.CurrentCamera
    -- Avoid 3D transforms while viewing a distant world from a cinematic camera.
    if camera and (camera.CFrame.Position - root.Position).Magnitude > 140 then return end
    local reduced = player:GetAttribute("SettingReducedMotion") == true
    local t = os.clock()
    for i, pet in ipairs(models) do
        if pet.Parent and pet.PrimaryPart then
            local x = (i - 2) * 4.2
            local z = 4.8 + math.abs(i - 2) * 1.5
            local bob = reduced and 0 or math.sin(t * 2.8 + i) * 0.3
            local target = root.CFrame * CFrame.new(x, 0.5 + bob, z)
            local current = pet:GetPivot()
            local distance = (current.Position - target.Position).Magnitude
            if distance > 30 then
                pet:PivotTo(target)
            elseif distance > 0.04 or current.LookVector:Dot(target.LookVector) < 0.999 then
                pet:PivotTo(current:Lerp(target, math.clamp(step * 8, 0, 1)))
            end
        end
    end
end)
