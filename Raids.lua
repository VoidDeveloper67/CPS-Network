local WIND_UI_LOAD = 'https://github.com/Footagesus/WindUI/releases/latest/download/main.lua'
local BASE_URL = "https://raw.githubusercontent.com/VoidHubDevs/Isla/refs/heads/main/"

local RAIDS_URL = BASE_URL .. "RaidsModule.lua"
local UISET_URL = BASE_URL .. "UiSettingsModule.lua"

local DISCORD_LINK = "http://discord.gg/cpshub"
local DISCORD_ASSET = "rbxassetid://126161789124643"

local SETTINGS_FILE = "cps_network_raids_settings.json"
local UI_TOGGLE_KEY = Enum.KeyCode.V

local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local lp = Players.LocalPlayer

local function safeRead(path)
    local ok, res = pcall(function() if readfile then return readfile(path) end end)
    return ok and res or nil
end
local function safeWrite(path, txt)
    pcall(function() if writefile then writefile(path, txt) end end)
end

local Settings = {}
do
    local raw = safeRead(SETTINGS_FILE)
    if raw then
        local ok, dec = pcall(function() return HttpService:JSONDecode(raw) end)
        if ok and type(dec) == "table" then Settings = dec end
    end
end
local function SaveSettings()
    pcall(function() safeWrite(SETTINGS_FILE, HttpService:JSONEncode(Settings or {})) end)
end

-- Perfect tweening (frame-by-frame, cancellable)
local ActiveTweens = {}

local function CancelActiveTween(instance)
    if not instance then return end
    local data = ActiveTweens[instance]
    if data and data.conn then
        pcall(function() data.conn:Disconnect() end)
    end
    ActiveTweens[instance] = nil
end

local function getInstanceCFrame(instance)
    if not instance then return nil end
    if instance:IsA("BasePart") then return instance.CFrame end
    if instance:IsA("Model") and instance.PrimaryPart then return instance.PrimaryPart.CFrame end
    local ok, cf = pcall(function() return instance.CFrame end)
    if ok then return cf end
    return nil
end

local function setInstanceCFrame(instance, cf)
    if not instance or not cf then return end
    pcall(function()
        if instance:IsA("BasePart") then
            instance.CFrame = cf
        elseif instance:IsA("Model") and instance.PrimaryPart then
            instance:SetPrimaryPartCFrame(cf)
        else
            if rawget(instance, "CFrame") ~= nil then
                instance.CFrame = cf
            end
        end
    end)
end

local function PerfectTweenCFrame(instance, goalCFrame, speed, onComplete)
    if not instance or not goalCFrame then
        if type(onComplete) == "function" then pcall(onComplete) end
        return
    end
    if not instance:IsDescendantOf(game) then
        if type(onComplete) == "function" then pcall(onComplete) end
        return
    end

    speed = tonumber(speed) or 300
    CancelActiveTween(instance)

    local start = getInstanceCFrame(instance)
    if not start then if type(onComplete) == "function" then pcall(onComplete) end return end

    local dist = (start.Position - goalCFrame.Position).Magnitude
    local duration = math.max(dist / speed, 0.05)

    local elapsed = 0
    local conn
    conn = RunService.Heartbeat:Connect(function(dt)
        if not instance or not instance:IsDescendantOf(game) then
            if conn then conn:Disconnect() end
            ActiveTweens[instance] = nil
            if type(onComplete) == "function" then pcall(onComplete) end
            return
        end

        elapsed = elapsed + dt
        local alpha = math.clamp(elapsed / duration, 0, 1)
        local newCFrame = start:Lerp(goalCFrame, alpha)
        setInstanceCFrame(instance, newCFrame)

        if alpha >= 1 then
            if conn then conn:Disconnect() end
            ActiveTweens[instance] = nil
            if type(onComplete) == "function" then pcall(onComplete) end
        end
    end)

    ActiveTweens[instance] = { conn = conn }
    return conn
end

local function PerfectTeleportCharacter(character, targetCFrame, speed)
    if not character or not targetCFrame then return end
    local hrp = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
    if not hrp then return end
    PerfectTweenCFrame(hrp, targetCFrame, speed or 400)
end

-- Load WindUI (required)
local okWind, WindUI = pcall(function()
    return loadstring(game:HttpGet(WIND_UI_LOAD))()
end)
if not okWind or type(WindUI) ~= "table" then
    warn("WindUI failed to load. Ensure URL is accessible: "..tostring(WIND_UI_LOAD))
    return
end

WindUI.PerfectTweenCFrame = PerfectTweenCFrame

local function safeLoadRemote(url)
    local ok, content = pcall(function() return game:HttpGet(url) end)
    if not ok or not content then return nil end
    local ok2, result = pcall(function() return loadstring(content)() end)
    return ok2 and result or nil
end

local RaidsModule = safeLoadRemote(RAIDS_URL) or {}
local UiSettingsModule = safeLoadRemote(UISET_URL) or {}

if type(RaidsModule) == "table" then
    pcall(function() RaidsModule.PerfectTweenCFrame = PerfectTweenCFrame end)
end

-- Create WindUI window & tabs (modern icons)
local Window
do
    local ok, w = pcall(function()
        return WindUI:CreateWindow({
            Title = "CPS Network | Auto Raids",
            Icon = "rocket",
            Author = "vonplayz_real",
            Folder = "cps_network_raids",
            Size = UDim2.fromOffset(720, 520),
            Transparent = true,
            Theme = "Dark",
            Resizable = true,
            SideBarWidth = 200
        })
    end)
    if not ok or type(w) ~= "table" then
        error("WindUI:CreateWindow failed or returned invalid window object.")
    end
    Window = w
end

local Tab_home = Window:Tab({ Title = "Home", Icon = "rocket" })
local Tab_raids = Window:Tab({ Title = "Raids", Icon = "compass" })
local Tab_discord = Window:Tab({ Title = "Discord", Icon = "discord" })

-- Build UI
local homeSection = Tab_home:Section({ Title = "Information" })
homeSection:Paragraph({ Title = "Welcome", Desc = "CPS Network | Auto Raids" })
homeSection:Paragraph({ Title = "Author", Desc = "vonplayz_real" })
homeSection:Button({
    Title = "Copy Discord",
    Desc = "Copy invite to clipboard",
    Callback = function()
        pcall(function() if setclipboard then setclipboard(DISCORD_LINK) end end)
        pcall(function() WindUI:Notify({ Title = "Copied", Content = "Discord link copied", Icon = "check", Duration = 2 }) end)
    end
})

local cfgSection = Tab_raids:Section({ Title = "Raid Config" })
cfgSection:Dropdown({
    Title = "Select Chip",
    Desc = "Choose chip to buy/use",
    Values = { "Flame","Ice","Quake","Light","Dark","Spider","Rumble","Magma","Buddha","Sand","Phoenix","Dough" },
    Value = (Settings.SelectedChip and tostring(Settings.SelectedChip)) or "Flame",
    Multi = false,
    AllowNone = false,
    Callback = function(option)
        local selected = option
        if type(option) == "table" then
            selected = option[1]
        end
        if selected == nil then return end
        Settings.SelectedChip = tostring(selected); SaveSettings()
        pcall(function() if type(RaidsModule.SetSelectChip) == "function" then RaidsModule:SetSelectChip(selected) end end)
    end
})

cfgSection:Toggle({
    Title = "Buy Chip",
    Desc = "Attempt to buy the selected chip",
    Enabled = Settings.BuyChip or false,
    Callback = function(state)
        Settings.BuyChip = state; SaveSettings()
        pcall(function() if type(RaidsModule.SetBuyChip) == "function" then RaidsModule:SetBuyChip(state) end end)
    end
})

cfgSection:Toggle({
    Title = "Start Raid (Sea 2)",
    Desc = "Auto start Sea 2 raid",
    Enabled = Settings.StartRaid2 or false,
    Callback = function(state)
        Settings.StartRaid2 = state; SaveSettings()
        pcall(function() if type(RaidsModule.SetStartRaidSecond) == "function" then RaidsModule:SetStartRaidSecond(state) end end)
    end
})

cfgSection:Toggle({
    Title = "Start Raid (Sea 3)",
    Desc = "Auto start Sea 3 raid",
    Enabled = Settings.StartRaid3 or false,
    Callback = function(state)
        Settings.StartRaid3 = state; SaveSettings()
        pcall(function() if type(RaidsModule.SetStartRaidThird) == "function" then RaidsModule:SetStartRaidThird(state) end end)
    end
})

local autoSection = Tab_raids:Section({ Title = "Automation" })
autoSection:Toggle({
    Title = "Auto Raid",
    Desc = "Auto start/attack raid",
    Enabled = Settings.AutoRaid or false,
    Callback = function(state)
        Settings.AutoRaid = state; SaveSettings()
        pcall(function() if type(RaidsModule.SetAutoRaid) == "function" then RaidsModule:SetAutoRaid(state) end end)
    end
})
autoSection:Toggle({
    Title = "Auto Next Island",
    Desc = "Teleport to next island automatically",
    Enabled = Settings.NextIsland or false,
    Callback = function(state)
        Settings.NextIsland = state; SaveSettings()
        pcall(function() if type(RaidsModule.SetNextIsland) == "function" then RaidsModule:SetNextIsland(state) end end)
    end
})
autoSection:Toggle({
    Title = "Auto Awaken",
    Desc = "Auto awaken abilities",
    Enabled = Settings.AutoAwaken or false,
    Callback = function(state)
        Settings.AutoAwaken = state; SaveSettings()
        pcall(function() if type(RaidsModule.SetAutoAwaken) == "function" then RaidsModule:SetAutoAwaken(state) end end)
    end
})

local utilSection = Tab_raids:Section({ Title = "Utilities" })
utilSection:Toggle({
    Title = "Walk on Water",
    Desc = "Allow walking on water",
    Enabled = Settings.WalkWater or false,
    Callback = function(state)
        Settings.WalkWater = state; SaveSettings()
        pcall(function() if type(RaidsModule.SetWalkWater) == "function" then RaidsModule:SetWalkWater(state) end end)
    end
})
utilSection:Toggle({
    Title = "No Clip",
    Desc = "Enable noclip",
    Enabled = Settings.NoClip or false,
    Callback = function(state)
        Settings.NoClip = state; SaveSettings()
        pcall(function() if type(RaidsModule.SetNoClip) == "function" then RaidsModule:SetNoClip(state) end end)
    end
})

local tpSection = Tab_raids:Section({ Title = "Teleports" })
tpSection:Button({
    Title = "Teleport Lab (Sea 2)",
    Desc = "Smooth perfect-tween teleport",
    Callback = function()
        local target = CFrame.new(-6505.351, 255.138, -4506.073)
        pcall(function()
            local char = lp and lp.Character
            if char then PerfectTeleportCharacter(char, target, 400) end
        end)
    end
})
tpSection:Button({
    Title = "Teleport Lab (Sea 3)",
    Desc = "Smooth perfect-tween teleport",
    Callback = function()
        local target = CFrame.new(-5038.623, 322.358, -2873.446)
        pcall(function()
            local char = lp and lp.Character
            if char then PerfectTeleportCharacter(char, target, 400) end
        end)
    end
})

local discordSection = Tab_discord:Section({ Title = "Socials" })
discordSection:Paragraph({ Title = "Join CPS Hub", Desc = "Discord: "..DISCORD_LINK })
discordSection:Button({
    Title = "Copy Discord",
    Desc = "Copy invite",
    Callback = function()
        pcall(function() if setclipboard then setclipboard(DISCORD_LINK) end end)
        pcall(function() WindUI:Notify({ Title = "Copied", Content = "Discord invite copied", Icon = "check", Duration = 2 }) end)
    end
})

-- Cleanup
local function Cleanup()
    for inst, data in pairs(ActiveTweens) do
        if data and data.conn then pcall(function() data.conn:Disconnect() end) end
        ActiveTweens[inst] = nil
    end
    pcall(function()
        if Window and type(Window.Destroy) == "function" then Window:Destroy() end
        if Window and type(Window.destroy) == "function" then Window:destroy() end
    end)
end

if lp and lp.CharacterRemoving then
    lp.CharacterRemoving:Connect(function() Cleanup() end)
end

print("CPS Network | Auto Raids")