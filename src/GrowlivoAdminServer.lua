-- GROWLIVO / Minimal server-authoritative moderation / Alpha 0.9.14
-- ServerScriptService > GrowlivoAdminServer [Script]
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local TextService = game:GetService("TextService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("GrowlivoConfig"))
local remotes = ReplicatedStorage:WaitForChild("GROWLIVO_Remotes")
local function remote(name)
    local r = remotes:FindFirstChild(name)
    assert(not r or r:IsA("RemoteEvent"), "Unexpected remote: " .. name)
    if not r then
        r = Instance.new("RemoteEvent")
        r.Name = name
        r.Parent = remotes
    end
    return r
end
local adminAction = remote("AdminAction")
local adminReply = remote("AdminReply")
local notice = remote("ServerNotice")

local allowed = {}
for _, userId in ipairs(Config.AdminUserIds) do
    if typeof(userId) == "number" and userId >= 1 and userId == math.floor(userId) then
        allowed[userId] = true
    end
end
local function isAdmin(player)
    return player and allowed[player.UserId] == true
end
local function setAdminFlag(player)
    player:SetAttribute("GrowlivoAdmin", isAdmin(player))
end
Players.PlayerAdded:Connect(setAdminFlag)
for _, player in ipairs(Players:GetPlayers()) do setAdminFlag(player) end
local lastRequest = {}
local function respond(player, text)
    adminReply:FireClient(player, tostring(text))
end
local function audit(player, action, target)
    warn(string.format("[GROWLIVO ADMIN] user=%d action=%s target=%s", player.UserId, action, tostring(target or "none")))
end
adminAction.OnServerEvent:Connect(function(player, command, raw)
    -- The attribute and interface are cosmetic; this check is the actual permission boundary.
    if not isAdmin(player) then
        warn("[GROWLIVO ADMIN] unauthorized call user=" .. tostring(player.UserId))
        return
    end
    if typeof(command) ~= "string" or #command > 20 then return end
    local now = os.clock()
    if now - (lastRequest[player] or -100) < 2 then return end
    lastRequest[player] = now
    if command == "ServerInfo" then
        respond(player, "Игроков в сервере: " .. tostring(#Players:GetPlayers()) .. " / " .. tostring(Players.MaxPlayers))
    elseif command == "Diagnostics" then
        local data = ServerScriptService:FindFirstChild("GROWLIVO_Diagnostics")
        local ready, saving = 0, 0
        for _, current in ipairs(Players:GetPlayers()) do
            if current:GetAttribute("DataReady") == true then ready += 1 end
            if current:GetAttribute("SavingEnabled") == true then saving += 1 end
        end
        local function metric(key)
            return data and tonumber(data:GetAttribute(key)) or 0
        end
        audit(player, "diagnostics", "server")
        respond(player, string.format("Профили: %d готовы / %d запись разрешена | Load: %d | Save: %d | Lock: %d | Timeout: %d | Exit: %d | Recovery: %d | Retry: %d | Drops: %d | ms: %d/%d | в записи: %d | поздних: %d | профили отклонены: %d | новые версии: %d | запись отклонена: %d | пропуск автосохр.: %d | опасных снимков: %d",
            ready, saving, metric("LoadFailures"), metric("SaveFailures"),
            metric("LostLocks"), metric("SaveTimeouts"),
            metric("ExitSaveFailures"), metric("SaveRecoveries"),
            metric("SaveRetryBatches"), metric("RemoteDrops"),
            metric("LastSaveMs"), metric("MaxSaveMs"), metric("ActiveSaves"),
            metric("LateSaveCompletions"), metric("RejectedProfileLoads"),
            metric("FutureProfileVersions"), metric("RejectedProfileWrites"),
            metric("AutosaveBusySkips"), metric("RejectedSnapshotWrites")))
    elseif command == "Telemetry" then
        local data = ServerScriptService:FindFirstChild("GROWLIVO_Diagnostics")
        local function metric(key)
            return data and tonumber(data:GetAttribute(key)) or 0
        end
        audit(player, "telemetry", "server")
        respond(player, string.format(
            "Клики: %d | Улучшения: %d | Яйца: %d | Перерожд.: %d | Дни: %d | Недели: %d | Сохран.: %d",
            metric("AcceptedTaps"), metric("UpgradesBought"), metric("EggsOpened"),
            metric("RebirthsMade"), metric("DailyClaims"), metric("WeeklyClaims"), metric("ConfirmedSaves")))
    elseif command == "Inspect" or command == "Kick" then
        if typeof(raw) ~= "number" or raw ~= math.floor(raw) or raw < 1 then
            respond(player, "Укажите корректный числовой UserId")
            return
        end
        local target = Players:GetPlayerByUserId(raw)
        if not target then respond(player, "Игрок не найден в текущем сервере") return end
        if command == "Inspect" then
            audit(player, "inspect", raw)
            respond(player, string.format("%s | ID %d | Клики: %s | Перерождения: %s | Сохранение: %s",
                target.Name, target.UserId, tostring(target:GetAttribute("Clicks") or 0),
                tostring(target:GetAttribute("Rebirths") or 0),
                tostring(target:GetAttribute("SavingEnabled") == true)))
        else
            if target == player or isAdmin(target) then
                respond(player, "Нельзя исключить себя или другого администратора")
                return
            end
            audit(player, "kick", raw)
            respond(player, "Игрок исключён из текущего сервера")
            target:Kick("GROWLIVO: исключён администратором сервера")
        end
    elseif command == "Announce" then
        if typeof(raw) ~= "string" or #raw < 1 or #raw > 160 then
            respond(player, "Объявление: от 1 до 160 байт UTF-8")
            return
        end
        -- Roblox requires filtering even for privileged player-authored text.
        local ok, safe = pcall(function()
            local result = TextService:FilterStringAsync(raw, player.UserId)
            return result:GetNonChatStringForBroadcastAsync()
        end)
        if not ok or typeof(safe) ~= "string" or safe == "" then
            respond(player, "Объявление не отправлено: ошибка фильтрации")
            return
        end
        audit(player, "announce", "server")
        notice:FireAllClients(safe)
        respond(player, "Объявление отправлено игрокам этого сервера")
    end
end)
Players.PlayerRemoving:Connect(function(player)
    lastRequest[player] = nil
end)
print("[GROWLIVO] Admin commands loaded (configured admins: " .. tostring(#Config.AdminUserIds) .. ")")
