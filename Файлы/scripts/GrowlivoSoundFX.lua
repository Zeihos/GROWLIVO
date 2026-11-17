-- GROWLIVO / Optional local UI sounds / Alpha 0.9.14
-- StarterPlayer > StarterPlayerScripts > GrowlivoSoundFX [LocalScript]
-- Uses bundled Roblox UI cues. Failed/unavailable assets only produce silence.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local player = Players.LocalPlayer
local remotes = RS:WaitForChild("GROWLIVO_Remotes")
local visuals = remotes:WaitForChild("VisualEvent")
local feedback = remotes:WaitForChild("Feedback")
local playerGui = player:WaitForChild("PlayerGui")
local hud = playerGui:WaitForChild("GROWLIVO_HUD")
local tapFlash = hud:WaitForChild("TapFlash")

-- Short cues only. No copyrighted music, autoplay ambience or external audio IDs.
local cues = {
    Tap = {Id = "rbxasset://sounds/button.wav", Volume = 0.14, Speed = 1.3},
    Reward = {Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.32, Speed = 1},
    Hatch = {Id = "rbxasset://sounds/switch.wav", Volume = 0.24, Speed = 1.05},
    Error = {Id = "rbxasset://sounds/snap.wav", Volume = 0.12, Speed = 0.9},
}
local folder = Instance.new("Folder")
folder.Name = "GROWLIVO_LocalSounds"
folder.Parent = SoundService
local sounds = {}
for name, info in pairs(cues) do
    local cue = Instance.new("Sound")
    cue.Name = name
    cue.SoundId = info.Id
    cue.Volume = info.Volume
    cue.PlaybackSpeed = info.Speed
    cue.Looped = false
    cue.Parent = folder
    sounds[name] = cue
end
local lastPlayed = {}
local function play(name, cooldown)
    if player:GetAttribute("SettingSounds") == false then return end
    local now = os.clock()
    if now - (lastPlayed[name] or -100) < (cooldown or 0.1) then return end
    lastPlayed[name] = now
    local cue = sounds[name]
    if cue then
        cue.TimePosition = 0
        cue:Play()
    end
end
-- The main HUD already rate-limits manual taps before firing TapFlash.
tapFlash.Event:Connect(function()
    play("Tap", 0.12)
end)
visuals.OnClientEvent:Connect(function(data)
    if typeof(data) ~= "table" then return end
    if data.Type == "Hatch" then
        play("Hatch", 0.25)
    elseif data.Type == "Fusion" or data.Type == "Rebirth" or data.Type == "EventReward"
        or data.Type == "WorldUnlock" or data.Type == "WeeklyReward"
        or data.Type == "TutorialStep" then
        play("Reward", 0.3)
    end
end)
feedback.OnClientEvent:Connect(function(message)
    if typeof(message) ~= "string" then return end
    if string.find(message, "Не хватает", 1, true) or string.find(message, "Недостаточно", 1, true) then
        play("Error", 0.6)
    elseif string.find(message, "Задание выполнено", 1, true)
        or string.find(message, "Достижение!", 1, true) then
        play("Reward", 0.3)
    end
end)
