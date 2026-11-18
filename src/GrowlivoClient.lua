-- GROWLIVO / Mobile-friendly clicker and pet inventory UI / Alpha 0.9.28
-- StarterPlayer > StarterPlayerScripts > GrowlivoClient [LocalScript]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("GrowlivoConfig"))
local remotes = ReplicatedStorage:WaitForChild("GROWLIVO_Remotes")
local Action = remotes:WaitForChild("Action")
local Feedback = remotes:WaitForChild("Feedback")
local PetState = remotes:WaitForChild("PetState")
local OpenEggShop = remotes:WaitForChild("OpenEggShop")

local GOLD = Color3.fromRGB(255, 200, 67)
local BLUE = Color3.fromRGB(34, 202, 255)
local PANEL = Color3.fromRGB(22, 35, 60)
local DARK = Color3.fromRGB(13, 24, 44)
local WHITE = Color3.fromRGB(238, 248, 255)
local MUTED = Color3.fromRGB(172, 200, 224)

local gui = Instance.new("ScreenGui")
gui.Name = "GROWLIVO_HUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local function rounded(object, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 14)
    corner.Parent = object
    return object
end
local function outlined(object, color, width)
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = width or 2
    stroke.Transparency = 0.25
    stroke.Color = color
    stroke.Parent = object
end
local function frame(name, parent, color)
    local f = Instance.new("Frame")
    f.Name = name
    f.BorderSizePixel = 0
    f.BackgroundColor3 = color or PANEL
    f.Parent = parent
    rounded(f)
    return f
end
local function text(name, parent, value, fontSize, color)
    local label = Instance.new("TextLabel")
    label.Name = name
    label.BorderSizePixel = 0
    label.BackgroundTransparency = 1
    label.Size = UDim2.fromScale(1, 1)
    label.Font = Enum.Font.GothamBold
    label.Text = value
    label.TextColor3 = color or WHITE
    label.TextSize = fontSize or 16
    label.TextWrapped = true
    label.Parent = parent
    return label
end
local function button(name, parent, value, color)
    local b = Instance.new("TextButton")
    b.Name = name
    b.Text = value
    b.TextColor3 = DARK
    b.TextSize = 17
    b.TextWrapped = true
    b.Font = Enum.Font.GothamBold
    b.BackgroundColor3 = color or GOLD
    b.BorderSizePixel = 0
    b.AutoButtonColor = true
    b.Parent = parent
    rounded(b, 12)
    return b
end
local function pretty(value)
    value = tonumber(value) or 0
    if value >= 1e12 then return string.format("%.2fT", value / 1e12) end
    if value >= 1e9 then return string.format("%.2fB", value / 1e9) end
    if value >= 1e6 then return string.format("%.2fM", value / 1e6) end
    if value >= 1e3 then return string.format("%.1fK", value / 1e3) end
    return tostring(math.floor(value))
end
local function attr(key)
    return player:GetAttribute(key) or 0
end

local title = text("Title", gui, "👑 GROWLIVO  •  " .. string.upper(Config.Version), 22, GOLD)
title.AnchorPoint = Vector2.new(0.5, 0)
title.Position = UDim2.new(0.5, 0, 0, 7)
title.Size = UDim2.fromOffset(330, 40)
title.TextStrokeTransparency = 0.55
local tapFlash = Instance.new("BindableEvent")
tapFlash.Name = "TapFlash"
tapFlash.Parent = gui

local stats = frame("Stats", gui, PANEL)
outlined(stats, BLUE)
local statPadding = Instance.new("UIPadding")
statPadding.PaddingLeft = UDim.new(0, 12)
statPadding.PaddingRight = UDim.new(0, 6)
statPadding.PaddingTop = UDim.new(0, 8)
statPadding.Parent = stats
local statLayout = Instance.new("UIListLayout")
statLayout.SortOrder = Enum.SortOrder.LayoutOrder
statLayout.Parent = stats
local statFields = {}
for i, name in ipairs({"Clicks", "Gems", "Rebirths", "Power", "Pets"}) do
    local label = text(name, stats, "—", 15, WHITE)
    label.Size = UDim2.new(1, 0, 0, 25)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.LayoutOrder = i
    statFields[name] = label
end
local actions = frame("ActionPanel", gui, PANEL)
outlined(actions, GOLD)
local upgrade = button("Upgrade", actions, "УЛУЧШИТЬ", BLUE)
local bulkUpgrade = button("Upgrade5", actions, "⚡ ×5", BLUE)
local rebirth = button("Rebirth", actions, "ПЕРЕРОЖДЕНИЕ", GOLD)
local petsButton = button("Pets", gui, "🐾 ПИТОМЦЫ", BLUE)
local autoTapButton = button("AutoTap", gui, "🤖 АВТОКЛИК", GOLD)
autoTapButton.TextSize = 12
local menuToggle = button("CompactMenu", gui, "☰ МЕНЮ", BLUE)
menuToggle.TextSize = 13
menuToggle.Visible = false
player:SetAttribute("CompactMenuOpen", false) -- client HUD state, never trusted by the server
local clickButton = button("Click", gui, "+1 КЛИК", GOLD)
clickButton.TextSize = 29
outlined(clickButton, WHITE)

local toast = text("Toast", gui, "", 16, WHITE)
toast.AnchorPoint = Vector2.new(0.5, 1)
toast.TextStrokeTransparency = 0.2
local toastNonce = 0
local function message(value)
    toastNonce += 1
    local nonce = toastNonce
    toast.Text = tostring(value)
    task.delay(3, function()
        if nonce == toastNonce then
            toast.Text = ""
        end
    end)
end

local shade = frame("ModalBackdrop", gui, Color3.fromRGB(0, 0, 0))
shade.Size = UDim2.fromScale(1, 1)
shade.BackgroundTransparency = 0.25
shade.Visible = false
shade.ZIndex = 10
shade.Active = true
shade.ClipsDescendants = true
local modal = frame("PetsPanel", shade, PANEL)
modal.AnchorPoint = Vector2.new(0.5, 0.5)
modal.Position = UDim2.fromScale(0.5, 0.5)
modal.ZIndex = 11
outlined(modal, GOLD)
local heading = text("Heading", modal, "🐾  ПИТОМЦЫ И ЯЙЦА", 22, GOLD)
heading.Position = UDim2.fromOffset(12, 7)
heading.Size = UDim2.new(1, -72, 0, 46)
heading.ZIndex = 12
local close = button("Close", modal, "✕", GOLD)
close.AnchorPoint = Vector2.new(1, 0)
close.Position = UDim2.new(1, -12, 0, 10)
close.Size = UDim2.fromOffset(43, 38)
close.ZIndex = 12
local hatch = button("Hatch", modal, "🥚 ОТКРЫТЬ ЯЙЦО", BLUE)
hatch.Position = UDim2.new(0, 12, 0, 60)
hatch.Size = UDim2.new(0.64, -14, 0, 53)
hatch.TextSize = 15
hatch.ZIndex = 12
local hatch3 = button("Hatch3", modal, "🥚 ×3", GOLD)
hatch3.Position = UDim2.new(0.64, 4, 0, 60)
hatch3.Size = UDim2.new(0.36, -16, 0, 53)
hatch3.TextSize = 14
hatch3.ZIndex = 12
local odds = text("Odds", modal, "Шансы выпадения", 12, MUTED)
odds.Position = UDim2.new(0, 12, 0, 118)
odds.Size = UDim2.new(1, -24, 0, 37)
odds.ZIndex = 12
local inventoryTitle = text("InventoryTitle", modal, "ИНВЕНТАРЬ: 0/60   |   НАДЕТО: 0/3", 14, WHITE)
inventoryTitle.Position = UDim2.new(0, 12, 0, 160)
inventoryTitle.Size = UDim2.new(1, -24, 0, 28)
inventoryTitle.TextXAlignment = Enum.TextXAlignment.Left
inventoryTitle.ZIndex = 12
-- Dedicated tab within the existing pet window, not a second overlay.
local catalogButton = button("PetCatalog", modal, "📖 КАТАЛОГ", GOLD)
catalogButton.AnchorPoint = Vector2.new(1, 0)
catalogButton.Position = UDim2.new(1, -12, 0, 160)
catalogButton.Size = UDim2.new(0.31, -4, 0, 28)
catalogButton.TextSize = 11
catalogButton.ZIndex = 12

-- Client-side inventory tools: these never alter saved pets or the server economy.
local search = Instance.new("TextBox")
search.Name = "PetSearch"
search.Position = UDim2.new(0, 12, 0, 190)
search.Size = UDim2.new(0.49, -12, 0, 34)
search.BackgroundColor3 = DARK
search.TextColor3 = WHITE
search.PlaceholderColor3 = MUTED
search.PlaceholderText = "Поиск питомца"
search.Text = ""
search.TextSize = 12
search.Font = Enum.Font.Gotham
search.ClearTextOnFocus = false
search.BorderSizePixel = 0
search.ZIndex = 12
search.Parent = modal
rounded(search, 9)
local sortButton = button("PetSort", modal, "СИЛА ↓", BLUE)
sortButton.Position = UDim2.new(0.49, 6, 0, 190)
sortButton.Size = UDim2.new(0.255, -10, 0, 34)
sortButton.TextSize = 11
sortButton.ZIndex = 12
local equippedFilter = button("EquippedFilter", modal, "ВСЕ", GOLD)
equippedFilter.Position = UDim2.new(0.745, 2, 0, 190)
equippedFilter.Size = UDim2.new(0.255, -14, 0, 34)
equippedFilter.TextSize = 11
equippedFilter.ZIndex = 12

local scroll = Instance.new("ScrollingFrame")
scroll.Name = "Inventory"
scroll.Position = UDim2.new(0, 12, 0, 231)
scroll.Size = UDim2.new(1, -24, 1, -298)
scroll.BackgroundColor3 = DARK
scroll.BackgroundTransparency = 0.2
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 5
scroll.ScrollBarImageColor3 = BLUE
scroll.CanvasSize = UDim2.fromOffset(0, 0)
scroll.ZIndex = 12
scroll.Parent = modal
rounded(scroll, 8)
local scrollPad = Instance.new("UIPadding")
scrollPad.PaddingTop = UDim.new(0, 7)
scrollPad.PaddingLeft = UDim.new(0, 8)
scrollPad.PaddingRight = UDim.new(0, 8)
scrollPad.Parent = scroll
local list = Instance.new("UIListLayout")
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Padding = UDim.new(0, 6)
list.Parent = scroll
list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    scroll.CanvasSize = UDim2.fromOffset(0, list.AbsoluteContentSize.Y + 18)
end)
local best = button("EquipBest", modal, "⚡ НАДЕТЬ ЛУЧШИХ", GOLD)
best.AnchorPoint = Vector2.new(0, 1)
best.Position = UDim2.new(0, 12, 1, -12)
best.Size = UDim2.new(0.64, -16, 0, 47)
best.ZIndex = 12
local unequip = button("UnequipAll", modal, "СНЯТЬ ВСЕХ", BLUE)
unequip.AnchorPoint = Vector2.new(0, 1)
unequip.Position = UDim2.new(0.64, 4, 1, -12)
unequip.Size = UDim2.new(0.36, -16, 0, 47)
unequip.TextSize = 12
unequip.ZIndex = 12

local currentPets = {}
local currentEquipped = {}
local petsDirty = true
-- This is a CURRENT ownership index, not a permanent discovery log.
local petsTab = "Inventory"
local catalogWorld = 0 -- zero means all worlds
local catalogOwnedOnly = false
local pendingReleaseId = nil
local pendingReleaseButton = nil
local pendingReleaseNonce = 0
local pendingFuseSpecies = nil
local pendingFuseButton = nil
local pendingFuseNonce = 0
local sortMode = "Power" -- Power / New / Old
local equippedOnly = false
local sortNames = {Power = "СИЛА ↓", New = "НОВЫЕ", Old = "СТАРЫЕ"}
local catalogWorldNames = {"НЕБО", "КРИСТ.", "РОЩА"}
local function syncPetTabUI()
    local isCatalog = petsTab == "Catalog"
    catalogButton.Text = isCatalog and "🐾 СПИСОК" or "📖 КАТАЛОГ"
    search.PlaceholderText = isCatalog and "Поиск по каталогу" or "Поиск питомца"
    if isCatalog then
        sortButton.Text = catalogWorld == 0 and "ВСЕ 🌍" or (catalogWorldNames[catalogWorld] or "МИР")
        equippedFilter.Text = catalogOwnedOnly and "МОИ" or "ВСЕ"
    else
        sortButton.Text = sortNames[sortMode]
        equippedFilter.Text = equippedOnly and "НАДЕТЫ" or "ВСЕ"
    end
    equippedFilter.BackgroundColor3 = (isCatalog and catalogOwnedOnly)
        or (not isCatalog and equippedOnly) and BLUE or GOLD
    best.Visible = not isCatalog
    unequip.Visible = not isCatalog
end
-- Lua string.lower handles ASCII but not Cyrillic. Small explicit mapping keeps
-- Russian-name searches case-insensitive without any external dependencies.
local uppercase = {"А","Б","В","Г","Д","Е","Ё","Ж","З","И","Й","К","Л","М","Н","О","П","Р","С","Т","У","Ф","Х","Ц","Ч","Ш","Щ","Ъ","Ы","Ь","Э","Ю","Я"}
local lowercase = {"а","б","в","г","д","е","ё","ж","з","и","й","к","л","м","н","о","п","р","с","т","у","ф","х","ц","ч","ш","щ","ъ","ы","ь","э","ю","я"}
local function normalizeSearch(value)
    value = string.lower(tostring(value or ""))
    for i, letter in ipairs(uppercase) do
        value = string.gsub(value, letter, lowercase[i])
    end
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end
local function clearReleaseConfirmation()
    if pendingReleaseButton and pendingReleaseButton.Parent and pendingReleaseButton.Active then
        pendingReleaseButton.Text = "ОТПУСТИТЬ"
    end
    pendingReleaseId = nil
    pendingReleaseButton = nil
    pendingReleaseNonce += 1
end
local function clearFuseConfirmation()
    if pendingFuseButton and pendingFuseButton.Parent then
        pendingFuseButton.Text = "✨ СЛИТЬ"
    end
    pendingFuseSpecies = nil
    pendingFuseButton = nil
    pendingFuseNonce += 1
end

-- Catalog derives its information from the shared world/egg definitions and
-- the server-published current inventory. No reward or persistence requests.
local function repaintPetCatalog()
    local owned = {}
    for _, pet in ipairs(currentPets) do
        if Config.FindPet(pet.Species) then
            owned[pet.Species] = (owned[pet.Species] or 0) + 1
        end
    end
    local unique = 0
    for _ in pairs(owned) do unique += 1 end
    inventoryTitle.Text = modal.Size.X.Offset < 420
        and string.format("В НАЛИЧИИ: %d/%d", unique, #Config.Pets)
        or string.format("ВИДОВ В ИНВЕНТАРЕ: %d/%d", unique, #Config.Pets)
    local query = normalizeSearch(search.Text)
    local rowIndex = 0
    for worldIndex, world in ipairs(Config.Worlds) do
        if catalogWorld == 0 or catalogWorld == worldIndex then
            local egg = Config.Eggs[world.EggId]
            if egg then
                for _, drop in ipairs(egg.Drops) do
                    local info = Config.FindPet(drop.Species)
                    local quantity = owned[drop.Species] or 0
                    if info and (not catalogOwnedOnly or quantity > 0) then
                        local searchable = normalizeSearch(info.Name .. " " .. info.Rarity
                            .. " " .. info.Id .. " " .. world.Name .. " " .. egg.Name)
                        if query == "" or string.find(searchable, query, 1, true) then
                            rowIndex += 1
                            local row = frame("Catalog_" .. info.Id, scroll, PANEL)
                            row.Size = UDim2.new(1, -4, 0, 89)
                            row.LayoutOrder = rowIndex
                            row.ZIndex = 13
                            local name = text("Name", row, info.Name
                                .. (quantity > 0 and " ✓" or ""), 14, info.Color)
                            name.Position = UDim2.fromOffset(9, 3)
                            name.Size = UDim2.new(1, -18, 0, 25)
                            name.TextXAlignment = Enum.TextXAlignment.Left
                            name.ZIndex = 14
                            local detail = text("Details", row, info.Rarity .. "  •  +"
                                .. info.Bonus .. "%  •  " .. world.Name, 11, MUTED)
                            detail.Position = UDim2.fromOffset(9, 27)
                            detail.Size = UDim2.new(1, -18, 0, 28)
                            detail.TextXAlignment = Enum.TextXAlignment.Left
                            detail.ZIndex = 14
                            local source = text("Drop", row, "🥚 " .. egg.Name .. "  •  "
                                .. drop.Chance .. "%  •  "
                                .. (quantity > 0 and "Есть: " .. quantity or "Пока нет"),
                                11, quantity > 0 and BLUE or MUTED)
                            source.Position = UDim2.fromOffset(9, 53)
                            source.Size = UDim2.new(1, -18, 0, 31)
                            source.TextXAlignment = Enum.TextXAlignment.Left
                            source.ZIndex = 14
                        end
                    end
                end
            end
        end
    end
    if rowIndex == 0 then
        local empty = frame("CatalogEmpty", scroll, DARK)
        empty.Size = UDim2.new(1, -4, 0, 58)
        empty.ZIndex = 13
        local hint = text("Hint", empty, "По этим фильтрам питомцев нет", 13, MUTED)
        hint.ZIndex = 14
    end
end

local function repaintPets()
    petsDirty = false
    clearReleaseConfirmation() -- destroyed row buttons must not retain confirmations
    clearFuseConfirmation()
    for _, child in ipairs(scroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    if petsTab == "Catalog" then
        repaintPetCatalog()
        return
    end
    local marked = {}
    for _, id in ipairs(currentEquipped) do marked[id] = true end
    local availableBySpecies = {}
    for _, item in ipairs(currentPets) do
        if not marked[item.Id] then
            availableBySpecies[item.Species] = (availableBySpecies[item.Species] or 0) + 1
        end
    end
    local query = normalizeSearch(search.Text)
    local visiblePets = {}
    for _, item in ipairs(currentPets) do
        local definition = Config.FindPet(item.Species)
        if definition and (not equippedOnly or marked[item.Id]) then
            local words = normalizeSearch(definition.Name .. " " .. definition.Rarity .. " " .. item.Species .. " " .. tostring(item.Id))
            if query == "" or string.find(words, query, 1, true) then
                table.insert(visiblePets, item)
            end
        end
    end
    table.sort(visiblePets, function(a, b)
        if sortMode == "New" then return a.Id > b.Id end
        if sortMode == "Old" then return a.Id < b.Id end
        local petA, petB = Config.FindPet(a.Species), Config.FindPet(b.Species)
        local powerA, powerB = petA and petA.Bonus or 0, petB and petB.Bonus or 0
        if powerA == powerB then return a.Id < b.Id end
        return powerA > powerB
    end)
    inventoryTitle.Text = modal.Size.X.Offset < 420
        and string.format("🐾 %d/%d • %d/%d", #currentPets, Config.MaxPetInventory,
            #currentEquipped, Config.MaxEquippedPets)
        or string.format("ИНВЕНТАРЬ: %d/%d | НАДЕТО: %d/%d",
            #currentPets, Config.MaxPetInventory, #currentEquipped, Config.MaxEquippedPets)
    if #visiblePets == 0 then
        local empty = frame("Empty", scroll, DARK)
        empty.Size = UDim2.new(1, -4, 0, 55)
        empty.ZIndex = 13
        local info = text("Info", empty, #currentPets == 0 and "Пока нет питомцев. Открой яйцо!" or "По запросу питомцев не найдено", 13, MUTED)
        info.ZIndex = 14
        return
    end
    for index, item in ipairs(visiblePets) do
        local definition = Config.FindPet(item.Species)
        if definition then
            local row = frame("Pet_" .. tostring(item.Id), scroll, PANEL)
            row.Size = UDim2.new(1, -4, 0, 115)
            row.LayoutOrder = index
            row.ZIndex = 13
            local name = text("PetName", row, definition.Name .. "  •  +" .. tostring(definition.Bonus) .. "%", 14, definition.Color)
            name.Position = UDim2.fromOffset(9, 4)
            name.Size = UDim2.new(1, -18, 0, 25)
            name.TextXAlignment = Enum.TextXAlignment.Left
            name.ZIndex = 14
            local target = Config.FusionResult(item.Species)
            local count = availableBySpecies[item.Species] or 0
            local detail = definition.Rarity .. "  |  #" .. tostring(item.Id)
            if target then
                detail ..= "  |  Слияние " .. count .. "/" .. Config.FusionRequired .. " → " .. target.Name
            end
            local rarity = text("Rarity", row, detail, 11, MUTED)
            rarity.Position = UDim2.fromOffset(9, 30)
            rarity.Size = UDim2.new(1, -18, 0, 41)
            rarity.TextXAlignment = Enum.TextXAlignment.Left
            rarity.ZIndex = 14
            local toggle = button("Toggle", row, marked[item.Id] and "СНЯТЬ" or "НАДЕТЬ", marked[item.Id] and GOLD or BLUE)
            toggle.Position = UDim2.new(0, 8, 1, -42)
            toggle.Size = UDim2.new(0.31, -6, 0, 35)
            toggle.TextSize = 10
            toggle.ZIndex = 14
            toggle.Activated:Connect(function()
                clearReleaseConfirmation()
                clearFuseConfirmation()
                Action:FireServer("ToggleEquip", item.Id)
            end)
            local canFuse = target ~= nil and count >= Config.FusionRequired
            local fuse = button("Fuse", row, target and "✨ СЛИТЬ" or "МАКС.", GOLD)
            fuse.Position = UDim2.new(0.32, 0, 1, -42)
            fuse.Size = UDim2.new(0.35, -4, 0, 35)
            fuse.TextSize = 10
            fuse.ZIndex = 14
            fuse.Active = canFuse
            fuse.AutoButtonColor = canFuse
            fuse.BackgroundTransparency = canFuse and 0 or 0.6
            fuse.Activated:Connect(function()
                if not canFuse or not fuse.Active or player:GetAttribute("DataReady") ~= true
                    or player:GetAttribute("DataStatus") ~= "Ready" then return end
                if pendingFuseButton == fuse and pendingFuseSpecies == item.Species then
                    clearFuseConfirmation()
                    Action:FireServer("FusePets", item.Species)
                    fuse.Text = "..."
                    fuse.Active = false
                else
                    clearReleaseConfirmation()
                    clearFuseConfirmation()
                    pendingFuseButton = fuse
                    pendingFuseSpecies = item.Species
                    fuse.Text = "ТОЧНО?"
                    local nonce = pendingFuseNonce
                    task.delay(4, function()
                        if pendingFuseNonce == nonce and pendingFuseButton == fuse then
                            clearFuseConfirmation()
                        end
                    end)
                end
            end)
            local release = button("Release", row,
                marked[item.Id] and "НАДЕТ" or "ОТПУСТИТЬ", Color3.fromRGB(232, 124, 115))
            release.Position = UDim2.new(0.67, 0, 1, -42)
            release.Size = UDim2.new(0.33, -8, 0, 35)
            release.TextSize = 9
            release.ZIndex = 14
            release.Active = not marked[item.Id]
            release.AutoButtonColor = not marked[item.Id]
            release.BackgroundTransparency = marked[item.Id] and 0.5 or 0
            release.Activated:Connect(function()
                if player:GetAttribute("DataReady") ~= true or player:GetAttribute("DataStatus") ~= "Ready"
                    or marked[item.Id] or not release.Active then return end
                if pendingReleaseId == item.Id and pendingReleaseButton == release then
                    clearReleaseConfirmation()
                    Action:FireServer("ReleasePet", item.Id)
                    release.Text = "..."
                    release.Active = false
                else
                    clearFuseConfirmation()
                    clearReleaseConfirmation()
                    pendingReleaseId = item.Id
                    pendingReleaseButton = release
                    release.Text = "ТОЧНО?"
                    local nonce = pendingReleaseNonce
                    task.delay(4, function()
                        if pendingReleaseNonce == nonce and pendingReleaseId == item.Id then
                            clearReleaseConfirmation()
                            if release.Parent then release.Text = "ОТПУСТИТЬ" end
                        end
                    end)
                end
            end)
        end
    end
end

local function refreshEgg()
    local egg = Config.EggForWorld(player:GetAttribute("World") or "SkyCrown")
    if not egg then return end
    hatch.Text = "🥚 " .. egg.Name .. "\n" .. pretty(egg.Price)
    hatch3.Text = "🥚 ×3\n" .. pretty(egg.Price * Config.MaxHatchBatch)
    local pieces = {}
    for _, drop in ipairs(egg.Drops) do
        local pet = Config.FindPet(drop.Species)
        if pet then table.insert(pieces, pet.Name .. " " .. drop.Chance .. "%") end
    end
    odds.Text = table.concat(pieces, "  ·  ")
end

local function update()
    refreshEgg()
    statFields.Clicks.Text = "👆 Клики: " .. pretty(attr("Clicks"))
    statFields.Gems.Text = "💎 Кристаллы: " .. pretty(attr("Gems"))
    statFields.Rebirths.Text = "🔄 Перерождения: " .. pretty(attr("Rebirths"))
    statFields.Power.Text = "⚡ Сила клика: +" .. pretty(attr("ClickPower"))
    statFields.Pets.Text = "🐾 Питомцы: " .. pretty(attr("PetCount")) .. "  |  бонус +" .. pretty(attr("PetBonus")) .. "%"
    local cost = Config.UpgradeCost(attr("TapLevel"))
    upgrade.Text = cost and ("⚡ УЛУЧШИТЬ\n" .. pretty(cost) .. " кликов") or "МАКС. УРОВЕНЬ"
    local total, levels = Config.UpgradeBundleCost(attr("TapLevel"), Config.BulkUpgradeCount)
    bulkUpgrade.Text = total and ("⚡ ×" .. levels .. "\n" .. pretty(total)) or "МАКС."
    bulkUpgrade.BackgroundColor3 = total and attr("Clicks") >= total and BLUE or MUTED
    local costR = Config.RebirthCost(attr("Rebirths"))
    rebirth.Text = costR and ("🔄 ПЕРЕРОДИТЬСЯ\n" .. pretty(costR) .. " кликов") or "МАКС. ПЕРЕРОЖДЕНИЯ"
    clickButton.Text = "+" .. pretty(attr("ClickPower")) .. " КЛИК"
    local unlocked = player:GetAttribute("AutoTapUnlocked") == true
    local enabled = player:GetAttribute("AutoTapEnabled") == true
    if not unlocked then
        autoTapButton.Text = "🔒 АВТОКЛИК • " .. Config.AutoTap.UnlockRebirths .. " 🔄"
        autoTapButton.BackgroundColor3 = MUTED
    elseif enabled and player:GetAttribute("DataStatus") ~= "Ready" then
        autoTapButton.Text = "🤖 АВТОКЛИК • ПАУЗА"
        autoTapButton.BackgroundColor3 = MUTED
    else
        autoTapButton.Text = enabled and "🤖 АВТОКЛИК • ВКЛ" or "🤖 АВТОКЛИК • ВЫКЛ"
        autoTapButton.BackgroundColor3 = enabled and BLUE or GOLD
    end
    if player:GetAttribute("DataStatus") == "SaveRetry" then
        toast.Text = "Сохранение недоступно: действия приостановлены"
    elseif player:GetAttribute("DataStatus") == "Ready"
        and toast.Text == "Сохранение недоступно: действия приостановлены" then
        toast.Text = ""
    end
end

local function resize()
    local camera = workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize or Vector2.new(1024, 768)
    local w, h = viewport.X, viewport.Y
    local mobile = w < 700
    local landscapeMenu = mobile and h < 500
    local menuOpen = player:GetAttribute("CompactMenuOpen") == true
    menuToggle.Visible = landscapeMenu
    if landscapeMenu then
        menuToggle.Position = UDim2.new(1, -106, 0, 5)
        menuToggle.Size = UDim2.fromOffset(96, 36)
        menuToggle.Text = menuOpen and "✕ ЗАКРЫТЬ" or "☰ МЕНЮ"
    end
    petsButton.Visible = not landscapeMenu or menuOpen
    autoTapButton.Visible = petsButton.Visible
    clickButton.Visible = not landscapeMenu or not menuOpen
    actions.Visible = not landscapeMenu or not menuOpen
    if mobile then
        title.TextSize = 19
        if landscapeMenu then
            title.AnchorPoint = Vector2.new(0, 0)
            title.Position = UDim2.fromOffset(10, 7)
            title.Size = UDim2.new(1, -120, 0, 36)
            title.TextXAlignment = Enum.TextXAlignment.Left
        else
            title.AnchorPoint = Vector2.new(0.5, 0)
            title.Position = UDim2.new(0.5, 0, 0, 7)
            title.Size = UDim2.new(1, -20, 0, 36)
            title.TextXAlignment = Enum.TextXAlignment.Center
        end
        local compact = h < 650
        stats.Position = UDim2.fromOffset(12, 48)
        stats.Size = UDim2.new(1, -24, 0, compact and 110 or 134)
        for _, field in pairs(statFields) do field.Size = UDim2.new(1, 0, 0, compact and 20 or 25) end
        actions.AnchorPoint = Vector2.new(0, 1)
        actions.Position = UDim2.new(0, 12, 1, -10)
        actions.Size = UDim2.new(1, -24, 0, 66)
        upgrade.Position = UDim2.new(0, 7, 0, 7)
        upgrade.Size = UDim2.new(0.30, -5, 1, -14)
        bulkUpgrade.Position = UDim2.new(0.30, 2, 0, 7)
        bulkUpgrade.Size = UDim2.new(0.20, -5, 1, -14)
        rebirth.Position = UDim2.new(0.5, 3, 0, 7)
        rebirth.Size = UDim2.new(0.5, -10, 1, -14)
        upgrade.TextSize, bulkUpgrade.TextSize, rebirth.TextSize = 10, 10, 12
        petsButton.Position = UDim2.new(1, -12, 0, compact and 163 or 187)
        petsButton.AnchorPoint = Vector2.new(1, 0)
        petsButton.Size = UDim2.fromOffset(math.min(w - 24, 162), 43)
        autoTapButton.AnchorPoint = Vector2.new(1, 0)
        autoTapButton.Position = UDim2.new(1, -12, 0, compact and 211 or 235)
        autoTapButton.Size = UDim2.fromOffset(math.min(w - 24, 162), 36)
        autoTapButton.TextSize = 11
        clickButton.AnchorPoint = Vector2.new(0.5, 1)
        clickButton.Position = UDim2.new(0.5, 0, 1, -94)
        clickButton.Size = UDim2.fromOffset(math.min(w - 32, 238), 73)
        toast.Position = UDim2.new(0.5, 0, 1, -171)
        toast.Size = UDim2.new(1, -20, 0, 42)
        modal.Size = UDim2.new(1, -24, 0, math.min(h - 28, 570))
        heading.TextSize = 18
        hatch.TextSize = 13
        search.TextSize = 11
        sortButton.TextSize = 10
        equippedFilter.TextSize = 10
        inventoryTitle.TextSize = 12
        best.TextSize = 12
        unequip.TextSize = 10
    else
        title.AnchorPoint = Vector2.new(0.5, 0)
        title.Position = UDim2.new(0.5, 0, 0, 7)
        title.TextXAlignment = Enum.TextXAlignment.Center
        title.TextSize = 22
        title.Size = UDim2.fromOffset(330, 40)
        stats.Position = UDim2.fromOffset(18, 58)
        stats.Size = UDim2.fromOffset(275, 137)
        for _, field in pairs(statFields) do field.Size = UDim2.new(1, 0, 0, 25) end
        actions.AnchorPoint = Vector2.new(1, 0)
        actions.Position = UDim2.new(1, -18, 0, 58)
        actions.Size = UDim2.fromOffset(245, 171)
        upgrade.Position = UDim2.fromOffset(9, 9)
        upgrade.Size = UDim2.new(0.62, -11, 0, 72)
        bulkUpgrade.Position = UDim2.new(0.62, 0, 0, 9)
        bulkUpgrade.Size = UDim2.new(0.38, -9, 0, 72)
        rebirth.Position = UDim2.fromOffset(9, 90)
        rebirth.Size = UDim2.new(1, -18, 0, 72)
        upgrade.TextSize, bulkUpgrade.TextSize, rebirth.TextSize = 13, 12, 15
        petsButton.AnchorPoint = Vector2.new(1, 0)
        petsButton.Position = UDim2.new(1, -18, 0, 239)
        petsButton.Size = UDim2.fromOffset(245, 50)
        autoTapButton.AnchorPoint = Vector2.new(1, 0)
        autoTapButton.Position = UDim2.new(1, -18, 0, 297)
        autoTapButton.Size = UDim2.fromOffset(245, 45)
        autoTapButton.TextSize = 13
        clickButton.AnchorPoint = Vector2.new(0.5, 1)
        clickButton.Position = UDim2.new(0.5, 0, 1, -20)
        clickButton.Size = UDim2.fromOffset(285, 85)
        toast.Position = UDim2.new(0.5, 0, 1, -115)
        toast.Size = UDim2.fromOffset(440, 42)
        modal.Size = UDim2.fromOffset(math.min(w - 90, 560), math.min(h - 80, 590))
        heading.TextSize = 22
        hatch.TextSize = 16
        search.TextSize = 12
        sortButton.TextSize = 11
        equippedFilter.TextSize = 11
        inventoryTitle.TextSize = 14
        best.TextSize = 16
        unequip.TextSize = 12
    end
    local compactPets = modal.Size.Y.Offset < 450
    if compactPets then
        odds.Visible = false
        inventoryTitle.Position = UDim2.fromOffset(12, 113)
        catalogButton.Position = UDim2.new(1, -12, 0, 113)
        search.Position = UDim2.new(0, 12, 0, 145)
        sortButton.Position = UDim2.new(0.49, 6, 0, 145)
        equippedFilter.Position = UDim2.new(0.745, 2, 0, 145)
        scroll.Position = UDim2.new(0, 12, 0, 185)
        scroll.Size = UDim2.new(1, -24, 1, -252)
    else
        odds.Visible = true
        inventoryTitle.Position = UDim2.fromOffset(12, 160)
        catalogButton.Position = UDim2.new(1, -12, 0, 160)
        search.Position = UDim2.new(0, 12, 0, 190)
        sortButton.Position = UDim2.new(0.49, 6, 0, 190)
        equippedFilter.Position = UDim2.new(0.745, 2, 0, 190)
        scroll.Position = UDim2.new(0, 12, 0, 231)
        scroll.Size = UDim2.new(1, -24, 1, -298)
    end
    inventoryTitle.Size = UDim2.new(0.69, -12, 0, 28)
    catalogButton.TextSize = modal.Size.X.Offset < 420 and 10 or 11
    -- The catalog has no equip controls at the bottom.
    if petsTab == "Catalog" then
        scroll.Size = UDim2.new(1, -24, 1, compactPets and -194 or -240)
    end
end

local function ready()
    return player:GetAttribute("DataReady") == true
        and player:GetAttribute("DataStatus") == "Ready"
end
local lastTap = -100
local function click()
    if not ready() or shade.Visible or player:GetAttribute("SettingsOpen") == true
        or player:GetAttribute("CompactMenuOpen") == true then return end
    local now = os.clock()
    if now - lastTap < (1 / Config.MaxClicksPerSecond) then return end
    lastTap = now
    Action:FireServer("Click")
    tapFlash:Fire(attr("ClickPower"))
end
clickButton.Activated:Connect(click)
autoTapButton.Activated:Connect(function()
    if ready() then
        Action:FireServer("ToggleAutoTap")
    end
end)
menuToggle.Activated:Connect(function()
    player:SetAttribute("CompactMenuOpen", player:GetAttribute("CompactMenuOpen") ~= true)
end)
player:GetAttributeChangedSignal("CompactMenuOpen"):Connect(resize)
UserInputService.InputBegan:Connect(function(input, handled)
    if not handled and not UserInputService:GetFocusedTextBox()
        and input.KeyCode == Enum.KeyCode.Space then click() end
end)
upgrade.Activated:Connect(function()
    if ready() then Action:FireServer("Upgrade") end
end)
bulkUpgrade.Activated:Connect(function()
    if ready() then Action:FireServer("Upgrade5") end
end)
rebirth.Activated:Connect(function()
    if ready() then Action:FireServer("Rebirth") end
end)
local function openPets()
    player:SetAttribute("CompactMenuOpen", false)
    shade.Visible = true
    syncPetTabUI()
    if petsDirty then repaintPets() end
    if ready() then Action:FireServer("GetPets") end
end
petsButton.Activated:Connect(openPets)
OpenEggShop.OnClientEvent:Connect(openPets)
close.Activated:Connect(function()
    clearReleaseConfirmation()
    clearFuseConfirmation()
    shade.Visible = false
end)
hatch.Activated:Connect(function()
    if ready() then Action:FireServer("Hatch") end
end)
hatch3.Activated:Connect(function()
    if ready() then Action:FireServer("Hatch3") end
end)
best.Activated:Connect(function()
    if ready() then Action:FireServer("EquipBest") end
end)
unequip.Activated:Connect(function()
    clearReleaseConfirmation()
    clearFuseConfirmation()
    if ready() and #currentEquipped > 0 then Action:FireServer("UnequipAll") end
end)
local function updateFilter()
    clearReleaseConfirmation()
    clearFuseConfirmation()
    scroll.CanvasPosition = Vector2.new(0, 0)
    petsDirty = true
    if shade.Visible then repaintPets() end
end
search:GetPropertyChangedSignal("Text"):Connect(updateFilter)
catalogButton.Activated:Connect(function()
    petsTab = petsTab == "Inventory" and "Catalog" or "Inventory"
    search.Text = ""
    syncPetTabUI()
    resize()
    updateFilter()
end)
sortButton.Activated:Connect(function()
    if petsTab == "Catalog" then
        catalogWorld = (catalogWorld + 1) % (#Config.Worlds + 1)
    else
        sortMode = sortMode == "Power" and "New" or (sortMode == "New" and "Old" or "Power")
    end
    syncPetTabUI()
    updateFilter()
end)
equippedFilter.Activated:Connect(function()
    if petsTab == "Catalog" then
        catalogOwnedOnly = not catalogOwnedOnly
    else
        equippedOnly = not equippedOnly
    end
    syncPetTabUI()
    updateFilter()
end)
Feedback.OnClientEvent:Connect(function(info)
    if typeof(info) == "string" then message(info) end
end)
PetState.OnClientEvent:Connect(function(inventory, equipped)
    if typeof(inventory) ~= "table" or typeof(equipped) ~= "table" then return end
    clearReleaseConfirmation()
    currentPets = inventory
    currentEquipped = equipped
    petsDirty = true
    if shade.Visible then repaintPets() end
end)

-- Several attributes change during one server sync. Redraw HUD only once
-- in the next scheduler slice instead of rebuilding labels for every field.
local updateQueued = false
local function scheduleUpdate()
    if updateQueued then return end
    updateQueued = true
    task.defer(function()
        updateQueued = false
        if gui.Parent then update() end
    end)
end
for _, key in ipairs({"Clicks", "Gems", "Rebirths", "TapLevel", "ClickPower", "PetBonus", "PetCount", "DataReady", "SavingEnabled", "DataStatus", "World", "AutoTapEnabled", "AutoTapUnlocked"}) do
    player:GetAttributeChangedSignal(key):Connect(scheduleUpdate)
end
player:GetAttributeChangedSignal("DataReady"):Connect(function()
    if ready() then Action:FireServer("GetPets") end
end)
resize()
update()
if ready() then Action:FireServer("GetPets") end
local viewportConnection
local function cameraChanged()
    if viewportConnection then viewportConnection:Disconnect() end
    viewportConnection = nil
    resize()
    local camera = workspace.CurrentCamera
    if camera then
        viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(resize)
    end
end
cameraChanged()
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(cameraChanged)

-- Alpha 0.9.26: display server-confirmed manual tap streak without client rewards.
local comboHud = Instance.new("TextLabel")
comboHud.Name = "TapCombo"
comboHud.AnchorPoint = Vector2.new(0.5, 0)
comboHud.Position = UDim2.new(0.5, 0, 0, 160)
comboHud.Size = UDim2.fromOffset(280, 32)
comboHud.BackgroundColor3 = PANEL
comboHud.BackgroundTransparency = 0.12
comboHud.BorderSizePixel = 0
comboHud.Font = Enum.Font.GothamBold
comboHud.TextColor3 = GOLD
comboHud.TextSize = 13
comboHud.TextWrapped = true
comboHud.Visible = false
comboHud.Parent = gui
rounded(comboHud, 10)
outlined(comboHud, GOLD, 1)
local function refreshCombo()
    local count = tonumber(player:GetAttribute("TapComboCount")) or 0
    local multiplier = tonumber(player:GetAttribute("TapComboMultiplier")) or 1
    local expiry = tonumber(player:GetAttribute("TapComboExpiresAt")) or 0
    local remain = math.max(0, expiry - workspace:GetServerTimeNow())
    comboHud.Visible = player:GetAttribute("DataReady") == true and count > 0 and remain > 0
    if not comboHud.Visible then return end
    local camera = workspace.CurrentCamera
    local w = camera and camera.ViewportSize.X or 900
    comboHud.Size = UDim2.fromOffset(math.min(280, math.max(180, w - 24)), 32)
    comboHud.Text = "⚡ КОМБО " .. count .. " ×" .. string.format("%.2f", multiplier)
        .. " • " .. string.format("%.1f", remain) .. " с"
end
for _, field in ipairs({"TapComboCount", "TapComboMultiplier", "TapComboExpiresAt", "DataReady"}) do
    player:GetAttributeChangedSignal(field):Connect(refreshCombo)
end
task.spawn(function()
    while gui.Parent do
        refreshCombo()
        task.wait(comboHud.Visible and 0.15 or 0.5)
    end
end)
refreshCombo()
