local Globals = getgenv()

if shared.TDSTable then
    return shared.TDSTable
end

-- // Services
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PathfindingService = game:GetService("PathfindingService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local mouse = LocalPlayer:GetMouse()
local RemoteFunc = ReplicatedStorage:WaitForChild("RemoteFunction")
local RemoteEvent = ReplicatedStorage:WaitForChild("RemoteEvent")

local platform = UserInputService:GetPlatform()
local IsMobile = (platform == Enum.Platform.IOS or platform == Enum.Platform.Android)

-- // File & Config
local FileName = "ADS_Config.json"

-- // State Variables
local Window
local Logger
local StartBackToLobby

local BackToLobbyRunning = false
local AutoPickupsRunning = false
local AutoSkipRunning = false
local AutoClaimRewards = false
local AntiLagRunning = false
local AutoChainRunning = false
local AutoDjRunning = false
local AutoNecroRunning = false
local TimeScaleRunning = false
local TimeScaleNoTicketsWarned = false
local AutoMercenaryBaseRunning = false
local AutoMilitaryBaseRunning = false
local SellFarmsRunning = false
local AutoGatlingRunning = false
local GatlingExecuted = false
local GatlifyRunning = false
local GatlifyExecuted = false
local IsCurrentlyLoading = false
local LastLoadTime = 0
local AutoPremiumRunning = false
local StackerErrorShown = false
local PremiumLoaded = false
local EasyModeRunning = false
local AutoReadyRunning = false

local MaxPathDistance = 300
local MilMarker = nil
local MercMarker = nil
local MaxLenght = nil

local CurrentEquippedTowers = {"None"}
local StackEnabled = false
local SelectedTower = nil
local StackSphere = nil

local executed_actions = {}
local UpgradeHistory = {}

-- // Item Names
local ItemNames = {
    ["17447507910"] = "Timescale Ticket(s)",
    ["17438486690"] = "Range Flag(s)",
    ["17438486138"] = "Damage Flag(s)",
    ["17438487774"] = "Cooldown Flag(s)",
    ["17429537022"] = "Blizzard(s)",
    ["17448596749"] = "Napalm Strike(s)",
    ["18493073533"] = "Spin Ticket(s)",
    ["17429548305"] = "Supply Drop(s)",
    ["18443277308"] = "Low Grade Consumable Crate(s)",
    ["136180382135048"] = "Santa Radio(s)",
    ["18443277106"] = "Mid Grade Consumable Crate(s)",
    ["18443277591"] = "High Grade Consumable Crate(s)",
    ["132155797622156"] = "Christmas Tree(s)",
    ["124065875200929"] = "Fruit Cake(s)",
    ["17429541513"] = "Barricade(s)",
    ["110415073436604"] = "Holy Hand Grenade(s)",
    ["17429533728"] = "Frag Grenade(s)",
    ["17437703262"] = "Molotov(s)",
    ["139414922355803"] = "Present Clusters(s)"
}

-- // Modifiers & Crate Lists
local AllModifiers = {
    "HiddenEnemies", "Glass", "ExplodingEnemies", "Limitation",
    "Committed", "HealthyEnemies", "Fog", "FlyingEnemies",
    "Broke", "SpeedyEnemies", "Quarantine", "JailedTowers", "Inflation"
}

local CrateList = {
    "All", "Basic", "Premium", "Deluxe", "Golden", "Bunny", "Halloween 2019",
    "Party", "Toy", "Valentines", "Xmas 2019", "Spooky", "Pumpkin", "Frost",
    "Lovely", "Cold Front", "Ducky", "Vigilante", "Pirate", "Phantom",
    "Halloween", "Jolly", "Lunar", "Lovestruck", "UglyCrate", "Coin Crate",
    "Banned", "Christmas 2025", "Showtime", "Valentines 2026", "Shamrock",
    "Low Grade", "Mid Grade", "High Grade"
}

local TimeScaleValues = {0.5, 1, 1.5, 2}

-- // Default Settings
local DefaultSettings = {
    PathVisuals = false,
    MilitaryPath = false,
    MercenaryPath = false,
    AutoSkip = false,
    AutoOpenCrates = false,
    SelectedCrate = "All",
    AutoReady = false,
    AutoChain = false,
    AutoGatling = false,
    Gatlify = false,
    AutoPremium = false,
    SupportCaravan = false,
    AutoDJ = false,
    DJCustomSongID = "",
    AutoNecro = false,
    AutoRejoin = true,
    AutoRestart = true,
    PrivateCode = "",
    TimeScaleEnabled = false,
    TimeScaleValue = 2,
    SellFarms = false,
    AutoMercenary = false,
    AutoMilitary = false,
    Frost = false,
    Fallen = false,
    Easy = false,
    AntiLag = false,
    Disable3DRendering = false,
    AutoPickups = false,
    ClaimRewards = false,
    SendWebhook = false,
    NoRecoil = false,
    SellFarmsWave = 1,
    WebhookURL = "",
    PickupMethod = "Pathfinding",
    StreamerMode = false,
    HideUsername = false,
    StreamerName = "",
    tagName = "None",
    Modifiers = {},
    AutoProgressionMode = "None",
    AutoProgressionEnabled = false,
    ProgressionWebhookURL = "",
    SendProgressionWebhook = false,
    AutoProgressionStatus = "Status: waiting... | Mode: None",
    GitHubBaseURL = "",
    GitHubIndexPath = "index.json",
    GitHubMapsFolder = "Maps",
    GitHubModesFolder = "Modes",
    GitHubAutoFetch = true,
    GitHubFallbackToMode = true,
    GitHubCacheStrategies = true,
    GitHubDebug = false,
    MultiMapEnabled = false,
    PreferredMaps = {},
    AutoLoadStrat = false,
    SendMapWebhook = false,
    MapWebhookURL = "",
    MultiMapEnabled = false,
    PreferredMaps = {},
    AutoLoadStrat = false,
    SendMapWebhook = false,
    MapWebhookURL = ""
}

-- // Tower Management Core
TDS = {
    PlacedTowers = {},
    ActiveStrat = true,
    MatchmakingMap = {
        ["PizzaParty"] = "halloween",
        ["Badlands"] = "badlands",
        ["PollutedWasteland"] = "polluted",
        ["DuckyEasy"] = "ducky2025",
        ["DuckyHard"] = "ducky2025"
    }
}
TDS["placed_towers"] = TDS.PlacedTowers
TDS["active_strat"] = TDS.ActiveStrat
TDS["matchmaking_map"] = TDS.MatchmakingMap

shared.TDSTable = TDS
shared["TDS_Table"] = TDS

-- // Currency Tracking
local StartCoins, CurrentTotalCoins, StartGems, CurrentTotalGems = 0, 0, 0, 0

-- // HTTP Request
local SendRequest = request or http_request or httprequest
    or GetDevice and GetDevice().request

if not SendRequest then
    warn("failure: no http function")
    return
end

-- // Helper Functions
local function NormalizeTimeScaleValue(val)
    val = tonumber(val)
    if not val then return nil end
    for _, v in ipairs(TimeScaleValues) do
        if v == val then return v end
    end
    return nil
end

local function CoerceTimeScaleValue(val, fallback)
    return NormalizeTimeScaleValue(val) or fallback
end

local function GetTimescaleFrame()
    local hotbar = PlayerGui:FindFirstChild("ReactUniversalHotbar")
    local frame = hotbar and hotbar:FindFirstChild("Frame")
    return frame and frame:FindFirstChild("timescale")
end

-- // Settings Save/Load
local function SaveSettings()
    local DataToSave = {}
    for key, _ in pairs(DefaultSettings) do
        DataToSave[key] = Globals[key]
    end
    writefile(FileName, HttpService:JSONEncode(DataToSave))
end

local function LoadSettings()
    local data = {}
    if isfile(FileName) then
        pcall(function()
            data = HttpService:JSONDecode(readfile(FileName))
        end)
    end
    for key, DefaultVal in pairs(DefaultSettings) do
        if Globals[key] == nil then
            if data[key] ~= nil then
                Globals[key] = data[key]
            else
                Globals[key] = DefaultVal
            end
        end
    end
    SaveSettings()
end

local function SetSetting(name, value)
    if DefaultSettings[name] ~= nil then
        if name == "TimeScaleValue" then
            value = CoerceTimeScaleValue(value, Globals.TimeScaleValue or 2)
        end
        Globals[name] = value
        SaveSettings()
    end
end

-- // Game State Detection
local function IdentifyGameState()
    local players = game:GetService("Players")
    local TempPlayer = players.LocalPlayer or players.PlayerAdded:Wait()
    local TempGui = TempPlayer:WaitForChild("PlayerGui")
    while true do
        if TempGui:FindFirstChild("ReactLobbyHud") then
            return "LOBBY"
        elseif TempGui:FindFirstChild("ReactUniversalHotbar") then
            return "GAME"
        end
        task.wait(1)
    end
end

local GameState = IdentifyGameState()

-- // Dynamic GameState updater
local function GetCurrentGameState()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return GameState end
    if pg:FindFirstChild("ReactLobbyHud") then return "LOBBY" end
    if pg:FindFirstChild("ReactUniversalHotbar") then return "GAME" end
    return GameState
end

-- Update GameState periodically
task.spawn(function()
    while true do
        local newState = GetCurrentGameState()
        if newState ~= GameState then
            GameState = newState
            if Logger then Logger:Log("[State] GameState changed to: " .. GameState) end
        end
        task.wait(2)
    end
end)

-- // Teleport & Anti-Stuck
local function SmartTeleportToLobby()
    local lobbyId = 3260590327
    pcall(function()
        local platform = UserInputService:GetPlatform()
        local IsMobile = (platform == Enum.Platform.IOS or platform == Enum.Platform.Android)
        if not IsMobile and Globals.PrivateCode and Globals.PrivateCode ~= "" then
            game:GetService("ExperienceService"):LaunchExperience({
                placeId = lobbyId,
                linkCode = Globals.PrivateCode
            })
        else
            TeleportService:Teleport(lobbyId)
        end
    end)

    task.spawn(function()
        task.wait(10)
        if Window then
            Window:Notify({
                Title = "Teleport Failed",
                Desc = "It looks like you're stuck! If you are using Delta, please ensure that 'Verify Teleports' is disabled in your settings.",
                Time = 9999,
                Type = "error"
            })
            task.wait(5)
            Window:Notify({
                Title = "Fixing Delta Teleport Issues",
                Desc = "1. Disconnect from the game\n" ..
                       "2. Completely empty your 'autoexecute' folder\n" ..
                       "3. Reopen Roblox and join the game\n" ..
                       "4. Go to Delta settings and disable 'Verify Teleports'\n" ..
                       "5. Disconnect and rejoin to confirm 'Verify Teleports' remains OFF\n" ..
                       "6. Once verified, restore your files to 'autoexecute' and rejoin",
                Time = 9999,
                Type = "normal"
            })
        end
    end)
end

local function Reconnect()
    local initialCode = GuiService:GetErrorCode()
    if initialCode and initialCode ~= Enum.ConnectionError.OK then
        task.wait(5)
        if GuiService:GetErrorCode() == initialCode then
            pcall(function()
                TeleportService:TeleportReconnect()
            end)
        end
    end
end

local function AntiStuck()
    task.spawn(function()
        local secondsStuck = 0
        while true do
            task.wait(1)
            local attrLoading = LocalPlayer:GetAttribute("Loading") == true
            local attrTeleporting = LocalPlayer:GetAttribute("Teleporting") == true
            local pg = LocalPlayer:FindFirstChild("PlayerGui")
            local loadScreen = pg and pg:FindFirstChild("LoadingScreen")
            local loadContent = loadScreen and loadScreen:FindFirstChild("content")
            local isLoadVisible = loadContent and loadContent.Visible == true
            local countScreen = pg and pg:FindFirstChild("PlayerCountdown")
            local countFrame = countScreen and countScreen:FindFirstChild("Frame")
            local isCountVisible = countFrame and countFrame.Visible == true

            if attrLoading or attrTeleporting or isLoadVisible or isCountVisible then
                secondsStuck = secondsStuck + 1
                if secondsStuck >= 60 then
                    pcall(SmartTeleportToLobby)
                    secondsStuck = 0
                end
            else
                secondsStuck = 0
            end
        end
    end)
end

AntiStuck()
task.spawn(Reconnect)
GuiService.ErrorMessageChanged:Connect(Reconnect)

if not game:IsLoaded() then game.Loaded:Wait() end

-- // Anti-AFK
local function StartAntiAfk()
    task.spawn(function()
        local LobbyTimer = 0
        while GameState == "LOBBY" do
            task.wait(1)
            LobbyTimer = LobbyTimer + 1
            if LobbyTimer >= 600 then
                SmartTeleportToLobby()
                break
            end
        end
    end)
end
StartAntiAfk()

-- // Idle Handler
task.spawn(function()
    LocalPlayer.Idled:Connect(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new(0, 0))
    end)
end)

-- // Nametag Settings
task.spawn(function()
    pcall(function()
        RemoteFunc:InvokeServer("Settings", "Update", "Show Nametags", false)
    end)
end)

-- // 3D Rendering
local function Apply3dRendering()
    if Globals.Disable3DRendering then
        game:GetService("RunService"):Set3dRenderingEnabled(false)
    else
        RunService:Set3dRenderingEnabled(true)
    end
    local PlayerGui = LocalPlayer:FindFirstChild("PlayerGui")
    local gui = PlayerGui and PlayerGui:FindFirstChild("ADS_BlackScreen")
    if Globals.Disable3DRendering then
        if PlayerGui and not gui then
            gui = Instance.new("ScreenGui")
            gui.Name = "ADS_BlackScreen"
            gui.IgnoreGuiInset = true
            gui.ResetOnSpawn = false
            gui.DisplayOrder = -1000
            gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
            gui.Parent = PlayerGui
            local frame = Instance.new("Frame")
            frame.Name = "Cover"
            frame.BackgroundColor3 = Color3.new(0, 0, 0)
            frame.BorderSizePixel = 0
            frame.Size = UDim2.fromScale(1, 1)
            frame.ZIndex = 0
            frame.Parent = gui
        end
        if gui then gui.Enabled = true end
    else
        if gui then gui.Enabled = false end
    end
end

LoadSettings()
Globals.TimeScaleValue = CoerceTimeScaleValue(Globals.TimeScaleValue, 2)
Apply3dRendering()

-- // Tag Changer
local isTagChangerRunning = false
local tagChangerConn = nil
local tagChangerTag = nil
local tagChangerOrig = nil

local function collectTagOptions()
    local list = {}
    local seen = {}
    local function addFolder(folder)
        if not folder then return end
        for _, child in ipairs(folder:GetChildren()) do
            local childName = child.Name
            if childName and not seen[childName] then
                seen[childName] = true
                list[#list + 1] = childName
            end
        end
    end
    local content = ReplicatedStorage:FindFirstChild("Content")
    if content then
        local nametag = content:FindFirstChild("Nametag")
        if nametag then
            addFolder(nametag:FindFirstChild("Basic"))
            addFolder(nametag:FindFirstChild("Exclusive"))
        end
    end
    table.sort(list)
    table.insert(list, 1, "None")
    return list
end

local function stopTagChanger()
    if tagChangerConn then
        tagChangerConn:Disconnect()
        tagChangerConn = nil
    end
    if tagChangerTag and tagChangerTag.Parent and tagChangerOrig ~= nil then
        pcall(function() tagChangerTag.Value = tagChangerOrig end)
    end
    tagChangerTag = nil
    tagChangerOrig = nil
end

local function startTagChanger()
    if isTagChangerRunning then return end
    isTagChangerRunning = true
    task.spawn(function()
        while Globals.tagName and Globals.tagName ~= "" and Globals.tagName ~= "None" do
            local tag = LocalPlayer:FindFirstChild("Tag")
            if tag then
                if tagChangerTag ~= tag then
                    if tagChangerConn then
                        tagChangerConn:Disconnect()
                        tagChangerConn = nil
                    end
                    tagChangerTag = tag
                    if tagChangerOrig == nil then
                        tagChangerOrig = tag.Value
                    end
                end
                if tag.Value ~= Globals.tagName then
                    tag.Value = Globals.tagName
                end
                if not tagChangerConn then
                    tagChangerConn = tag:GetPropertyChangedSignal("Value"):Connect(function()
                        if Globals.tagName and Globals.tagName ~= "" and Globals.tagName ~= "None" then
                            if tag.Value ~= Globals.tagName then
                                tag.Value = Globals.tagName
                            end
                        end
                    end)
                end
            end
            task.wait(0.5)
        end
        isTagChangerRunning = false
    end)
end

if Globals.tagName and Globals.tagName ~= "" and Globals.tagName ~= "None" then
    startTagChanger()
end

-- // Privacy / Streamer Mode
local OriginalDisplayName = LocalPlayer.DisplayName
local OriginalUserName = LocalPlayer.Name
local SpoofTextCache = setmetatable({}, {__mode = "k"})
local PrivacyRunning = false
local LastSpoofName = nil
local PrivacyConns = {}
local PrivacyTextNodes = setmetatable({}, {__mode = "k"})
local StreamerTag = nil
local StreamerTagOrig = nil
local StreamerTagConn = nil

local function AddPrivacyConn(conn)
    if conn then PrivacyConns[#PrivacyConns + 1] = conn end
end

local function ClearPrivacyConns()
    for _, c in ipairs(PrivacyConns) do
        pcall(function() c:Disconnect() end)
    end
    PrivacyConns = {}
    for inst in pairs(PrivacyTextNodes) do
        PrivacyTextNodes[inst] = nil
    end
end

local function MakeSpoofName()
    return "BelowNatural"
end

local function EnsureSpoofName()
    local nm = Globals.StreamerName
    if not nm or nm == "" then
        nm = MakeSpoofName()
        SetSetting("StreamerName", nm)
    end
    return nm
end

local function IsTagChangerActive()
    return Globals.tagName and Globals.tagName ~= "" and Globals.tagName ~= "None"
end

local function SetLocalDisplayName(nm)
    if not nm or nm == "" then return end
    pcall(function() LocalPlayer.DisplayName = nm end)
end

local function ReplacePlain(str, old, new)
    if not str or str == "" or not old or old == "" or old == new then return str, false end
    local start = 1
    local out = {}
    local changed = false
    while true do
        local i, j = string.find(str, old, start, true)
        if not i then
            out[#out + 1] = string.sub(str, start)
            break
        end
        changed = true
        out[#out + 1] = string.sub(str, start, i - 1)
        out[#out + 1] = new
        start = j + 1
    end
    if changed then return table.concat(out), true end
    return str, false
end

local function ApplySpoofToInstance(inst, OldA, OldB, NewName)
    if not inst then return end
    if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
        local txt = inst.Text
        if type(txt) == "string" and txt ~= "" then
            local HasA = OldA and OldA ~= "" and string.find(txt, OldA, 1, true)
            local HasB = OldB and OldB ~= "" and string.find(txt, OldB, 1, true)
            if not HasA and not HasB then return end
            local t = txt
            local changed = false
            local ch
            if OldA and OldA ~= "" then
                t, ch = ReplacePlain(t, OldA, NewName)
                if ch then changed = true end
            end
            if OldB and OldB ~= "" then
                t, ch = ReplacePlain(t, OldB, NewName)
                if ch then changed = true end
            end
            if changed then
                if SpoofTextCache[inst] == nil then
                    SpoofTextCache[inst] = txt
                end
                inst.Text = t
            end
        end
    end
end

local function RestoreSpoofText()
    for inst, txt in pairs(SpoofTextCache) do
        if inst and inst.Parent then
            pcall(function() inst.Text = txt end)
        end
        SpoofTextCache[inst] = nil
    end
end

local function GetPrivacyName()
    if Globals.StreamerMode then return EnsureSpoofName() end
    if Globals.HideUsername then return "████████" end
    return nil
end

local function AddPrivacyNode(inst)
    if not (inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox")) then return end
    PrivacyTextNodes[inst] = true
    local nm = GetPrivacyName()
    if nm then ApplySpoofToInstance(inst, OriginalDisplayName, OriginalUserName, nm) end
end

local function HookPrivacyRoot(root)
    if not root then return end
    for _, inst in ipairs(root:GetDescendants()) do
        AddPrivacyNode(inst)
    end
    AddPrivacyConn(root.DescendantAdded:Connect(function(inst)
        if GetPrivacyName() then AddPrivacyNode(inst) end
    end))
end

local function SweepPrivacyText(nm)
    for inst in pairs(PrivacyTextNodes) do
        if inst and inst.Parent then
            ApplySpoofToInstance(inst, OriginalDisplayName, OriginalUserName, nm)
        else
            PrivacyTextNodes[inst] = nil
        end
    end
end

local function ApplyStreamerTag()
    if IsTagChangerActive() then
        if StreamerTagConn then
            StreamerTagConn:Disconnect()
            StreamerTagConn = nil
        end
        StreamerTag = nil
        StreamerTagOrig = nil
        return
    end
    local nm = EnsureSpoofName()
    local tag = LocalPlayer:FindFirstChild("Tag")
    if not tag then return end
    if StreamerTag and StreamerTag ~= tag then
        if StreamerTagConn then
            StreamerTagConn:Disconnect()
            StreamerTagConn = nil
        end
    end
    if StreamerTag ~= tag then
        StreamerTag = tag
        StreamerTagOrig = tag.Value
    end
    if tag.Value ~= nm then tag.Value = nm end
    if StreamerTagConn then
        StreamerTagConn:Disconnect()
        StreamerTagConn = nil
    end
    StreamerTagConn = tag:GetPropertyChangedSignal("Value"):Connect(function()
        if not Globals.StreamerMode then return end
        if IsTagChangerActive() then return end
        local nm2 = EnsureSpoofName()
        if tag.Value ~= nm2 then tag.Value = nm2 end
    end)
end

local function RestoreStreamerTag()
    if StreamerTagConn then
        StreamerTagConn:Disconnect()
        StreamerTagConn = nil
    end
    if IsTagChangerActive() then
        StreamerTag = nil
        StreamerTagOrig = nil
        return
    end
    if StreamerTag and StreamerTag.Parent and StreamerTagOrig ~= nil then
        pcall(function() StreamerTag.Value = StreamerTagOrig end)
    end
    StreamerTag = nil
    StreamerTagOrig = nil
end

local function ApplyPrivacyOnce()
    local nm = GetPrivacyName()
    if not nm then return end
    if LastSpoofName and LastSpoofName ~= nm then RestoreSpoofText() end
    if Globals.StreamerMode then ApplyStreamerTag() else RestoreStreamerTag() end
    SetLocalDisplayName(nm)
    SweepPrivacyText(nm)
    LastSpoofName = nm
end

local function StopPrivacyMode()
    ClearPrivacyConns()
    RestoreSpoofText()
    LastSpoofName = nil
    RestoreStreamerTag()
    SetLocalDisplayName(OriginalDisplayName)
    PrivacyRunning = false
end

local function StartPrivacyMode()
    if PrivacyRunning then return end
    PrivacyRunning = true
    ClearPrivacyConns()
    ApplyPrivacyOnce()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if pg then HookPrivacyRoot(pg) end
    local CoreGui = game:GetService("CoreGui")
    if CoreGui then HookPrivacyRoot(CoreGui) end
    local TagsRoot = workspace:FindFirstChild("Nametags")
    if TagsRoot then HookPrivacyRoot(TagsRoot) end
    local ch = LocalPlayer.Character
    if ch then HookPrivacyRoot(ch) end
    AddPrivacyConn(LocalPlayer.CharacterAdded:Connect(function(NewChar)
        if GetPrivacyName() then
            HookPrivacyRoot(NewChar)
            ApplyPrivacyOnce()
        end
    end))
    AddPrivacyConn(workspace.ChildAdded:Connect(function(inst)
        if GetPrivacyName() and inst.Name == "Nametags" then
            HookPrivacyRoot(inst)
            ApplyPrivacyOnce()
        end
    end))
    local function step()
        if not GetPrivacyName() then StopPrivacyMode() return end
        ApplyPrivacyOnce()
        task.delay(0.5, step)
    end
    task.defer(step)
end

local function UpdatePrivacyState()
    if GetPrivacyName() then
        if not PrivacyRunning then StartPrivacyMode() else ApplyPrivacyOnce() end
    else
        if PrivacyRunning then StopPrivacyMode() end
    end
end

UpdatePrivacyState()

-- // Pathfinding Utilities
local function FindPath()
    local MapFolder = workspace:FindFirstChild("Map")
    if not MapFolder then return nil end
    local PathsFolder = MapFolder:FindFirstChild("Paths")
    if not PathsFolder then return nil end
    local PathFolder = PathsFolder:GetChildren()[1]
    if not PathFolder then return nil end
    local PathNodes = {}
    for _, node in ipairs(PathFolder:GetChildren()) do
        if node:IsA("BasePart") then
            table.insert(PathNodes, node)
        end
    end
    table.sort(PathNodes, function(a, b)
        local NumA = tonumber(a.Name:match("%d+"))
        local NumB = tonumber(b.Name:match("%d+"))
        if NumA and NumB then return NumA < NumB end
        return a.Name < b.Name
    end)
    return PathNodes
end

local function TotalLength(PathNodes)
    local TotalLength = 0
    for i = 1, #PathNodes - 1 do
        TotalLength = TotalLength + (PathNodes[i + 1].Position - PathNodes[i].Position).Magnitude
    end
    return TotalLength
end

local MercenarySlider
local MilitarySlider

local function CalcLength()
    local map = workspace:FindFirstChild("Map")
    if GameState == "GAME" and map then
        local PathNodes = FindPath()
        if PathNodes and #PathNodes > 0 then
            MaxPathDistance = TotalLength(PathNodes)
            if MercenarySlider then MercenarySlider:SetMax(MaxPathDistance) end
            if MilitarySlider then MilitarySlider:SetMax(MaxPathDistance) end
            if MaxLenght then MaxLenght = MaxPathDistance end
            return true
        end
    end
    return false
end

local function GetPointAtDistance(PathNodes, distance)
    if not PathNodes or #PathNodes < 2 then return nil end
    local CurrentDist = 0
    for i = 1, #PathNodes - 1 do
        local StartPos = PathNodes[i].Position
        local EndPos = PathNodes[i+1].Position
        local SegmentLen = (EndPos - StartPos).Magnitude
        if CurrentDist + SegmentLen >= distance then
            local remaining = distance - CurrentDist
            local direction = (EndPos - StartPos).Unit
            return StartPos + (direction * remaining)
        end
        CurrentDist = CurrentDist + SegmentLen
    end
    return PathNodes[#PathNodes].Position
end

local function UpdatePathVisuals()
    if not Globals.PathVisuals then
        if MilMarker then MilMarker:Destroy() MilMarker = nil end
        if MercMarker then MercMarker:Destroy() MercMarker = nil end
        return
    end
    local PathNodes = FindPath()
    if not PathNodes then return end
    if not MilMarker then
        MilMarker = Instance.new("Part")
        MilMarker.Name = "MilVisual"
        MilMarker.Shape = Enum.PartType.Cylinder
        MilMarker.Size = Vector3.new(0.3, 3, 3)
        MilMarker.Color = Color3.fromRGB(0, 255, 0)
        MilMarker.Material = Enum.Material.Plastic
        MilMarker.Anchored = true
        MilMarker.CanCollide = false
        MilMarker.Orientation = Vector3.new(0, 0, 90)
        MilMarker.Parent = workspace
    end
    if not MercMarker then
        MercMarker = MilMarker:Clone()
        MercMarker.Name = "MercVisual"
        MercMarker.Color = Color3.fromRGB(255, 0, 0)
        MercMarker.Parent = workspace
    end
    local MilPos = GetPointAtDistance(PathNodes, Globals.MilitaryPath or 0)
    local MercPos = GetPointAtDistance(PathNodes, Globals.MercenaryPath or 0)
    if MilPos then
        MilMarker.Position = MilPos + Vector3.new(0, 0.2, 0)
        MilMarker.Transparency = 0.7
    end
    if MercPos then
        MercMarker.Position = MercPos + Vector3.new(0, 0.2, 0)
        MercMarker.Transparency = 0.7
    end
end

-- // Missions UI Fix
local function MissionsUIFix()
    task.spawn(function()
        while task.wait(1) do
            pcall(function()
                local MissionsScrollingFrame = game:GetService("Players").LocalPlayer.PlayerGui.ReactLobbyQuests.quests.missions.scrollingFrame
                local MissionsListLayout = MissionsScrollingFrame.listLayout
                local MissionFrame = MissionsScrollingFrame["1"]
                if MissionFrame.AbsoluteSize.Y > 0 then
                    local UIScaleRatio = MissionFrame.AbsoluteSize.Y / MissionFrame.Size.Y.Offset
                    local CurrentCanvasSize = MissionsScrollingFrame.CanvasSize
                    local CanvasHeight = (MissionsListLayout.AbsoluteContentSize.Y / UIScaleRatio) + 25
                    MissionsScrollingFrame.CanvasSize = UDim2.new(CurrentCanvasSize.X.Scale, CurrentCanvasSize.X.Offset, CurrentCanvasSize.Y.Scale, CanvasHeight)
                end
            end)
        end
    end)
end

-- // Premium Addons Loader
function TDS:Addons(SkipGameState)
    if GameState == "LOBBY" and not SkipGameState then return false end
    if PremiumLoaded then return true end
    while IsCurrentlyLoading or (os.clock() - LastLoadTime < 5) do task.wait(0.1) end
    local originalPlace = self.Place
    IsCurrentlyLoading = true
    local url = "https://api.jnkie.com/api/v1/luascripts/public/57fe397f76043ce06afad24f07528c9f93e97730930242f57134d0b60a2d250b/download"
    local success, code
    repeat
        success, code = pcall(game.HttpGet, game, url)
        if not success or not code then task.wait(1) end
    until success and code
    local func = loadstring(code)
    if not func then
        IsCurrentlyLoading = false
        LastLoadTime = os.clock()
        return false
    end
    pcall(func)
    while self.Place == originalPlace do task.wait(0.1) end
    PremiumLoaded = true
    IsCurrentlyLoading = false
    LastLoadTime = os.clock()
    return true
end

-- // Equipped Towers
local function GetEquippedTowers()
    local towers = {}
    local StateReplicators = ReplicatedStorage:FindFirstChild("StateReplicators")
    if StateReplicators then
        for _, folder in ipairs(StateReplicators:GetChildren()) do
            if folder.Name == "PlayerReplicator" and folder:GetAttribute("UserId") == LocalPlayer.UserId then
                local equipped = folder:GetAttribute("EquippedTowers")
                if type(equipped) == "string" then
                    local CleanedJson = equipped:match("%[.*%]")
                    local success, TowerTable = pcall(function()
                        return HttpService:JSONDecode(CleanedJson)
                    end)
                    if success and type(TowerTable) == "table" then
                        for i = 1, 5 do
                            if TowerTable[i] then table.insert(towers, TowerTable[i]) end
                        end
                    end
                end
            end
        end
    end
    return #towers > 0 and towers or {"None"}
end

CurrentEquippedTowers = GetEquippedTowers()

-- // Auto Open Crates
local AutoOpenRunning = false
local function StartAutoOpenCrates()
    if AutoOpenRunning or not Globals.AutoOpenCrates then return end
    AutoOpenRunning = true
    for _, crateName in ipairs(CrateList) do
        if crateName == "All" then continue end
        task.spawn(function()
            while Globals.AutoOpenCrates do
                if Globals.SelectedCrate == "All" or Globals.SelectedCrate == crateName then
                    local success, res = pcall(function()
                        return RemoteFunc:InvokeServer("Inventory", "Open", "Crate", crateName)
                    end)
                    if success and type(res) == "table" then
                        task.wait(0.1)
                    else
                        task.wait(5)
                    end
                else
                    task.wait(1)
                end
            end
        end)
    end
    task.spawn(function()
        repeat task.wait(1) until not Globals.AutoOpenCrates
        AutoOpenRunning = false
    end)
end

-- // Voting & Map Selection
local function RunVoteSkip()
    while true do
        local success = pcall(function()
            RemoteFunc:InvokeServer("Voting", "Skip")
        end)
        if success then break end
        task.wait(0.1)
    end
end

local function StartAutoReady()
    if AutoReadyRunning or not Globals.AutoReady or GameState ~= "GAME" then return end
    AutoReadyRunning = true
    task.spawn(function()
        local voteReplicator = ReplicatedStorage:WaitForChild("StateReplicators"):WaitForChild("VoteReplicator")
        repeat task.wait(0.1) until voteReplicator:GetAttribute("Enabled") == true and voteReplicator:GetAttribute("Title") == "Ready?"
        RunVoteSkip()
        repeat task.wait(0.1) until voteReplicator:GetAttribute("Enabled") == false
        AutoReadyRunning = false
    end)
end

-- // Easy Mode
local function StartEasyMode()
    if EasyModeRunning or not Globals.Easy then return end
    EasyModeRunning = true
    task.spawn(function()
        local content = nil
        while Globals.Easy and content == nil do
            local success, res = pcall(function()
                return game:HttpGet("https://raw.githubusercontent.com/DuxiiT/auto-strat/refs/heads/main/Strategies/Easy.lua")
            end)
            if success and type(res) == "string" then
                content = res
            else
                task.wait(1)
            end
        end
        if content then
            while not (TDS and TDS.Loadout) do task.wait(0.5) end
            local func = loadstring(content)
            if func then
                pcall(func)
                Window:Notify({Title = "ADS", Desc = "Running...", Time = 3})
            end
        end
        repeat task.wait(2) until not Globals.Easy or (GameState == "GAME" and not game:IsLoaded())
        EasyModeRunning = false
    end)
end

-- // DJ Booth Auto Song
local function AutoSetDJSong(tower)
    task.spawn(function()
        local replicator = tower:WaitForChild("TowerReplicator", 10)
        if not replicator then return end
        if replicator:GetAttribute("Name") ~= "DJ Booth" then return end
        if replicator:GetAttribute("OwnerId") ~= LocalPlayer.UserId then return end
        local songIdNum = tonumber(Globals.DJCustomSongID)
        if not songIdNum then return end
        pcall(function()
            RemoteFunc:InvokeServer("Troops", "Execute", {
                Data = { songIdNum },
                Name = "Music",
                Tower = tower
            })
        end)
    end)
end

task.spawn(function()
    local Towers = workspace:WaitForChild("Towers", 10)
    if not Towers then return end
    Towers.ChildAdded:Connect(AutoSetDJSong)
    for _, tower in ipairs(Towers:GetChildren()) do
        AutoSetDJSong(tower)
    end
end)

-- // UI Setup
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/DuxiiT/auto-strat/refs/heads/main/Sources/UI.lua"))()

Window = Library:Window({
    Title = "Aether Hub",
    Desc = "your #1 hub",
    Theme = "Default",
    DiscordLink = "https://discord.gg/aetherhub",
    Icon = 99432006374500,
    Config = {
        Keybind = Enum.KeyCode.LeftControl,
        Size = UDim2.new(0, 500, 0, 400)
    }
})

task.spawn(function()
    local retries = 0
    while retries < 10 do
        local success, inGroup = pcall(LocalPlayer.IsInGroup, LocalPlayer, 4914494)
        if success then
            if not inGroup then
                Window:Notify({
                    Title = "Warning",
                    Desc = "Please consider joining the Paradoxum Group. Otherwise, strategies may not work for you.",
                    Time = 25,
                    Type = "error"
                })
            end
            break
        end
        retries += 1
        task.wait(1)
    end
end)

-- // Automation Tab
local Automation = Window:Tab({Title = "Automation", Icon = "bot"}) do
    Automation:Section({Title = "Match Progression"})

    Automation:Toggle({
        Title = "Auto Rejoin",
        Desc = "Turn this ON if you are running a WIN strat",
        Value = Globals.AutoRejoin,
        Callback = function(v)
            SetSetting("AutoRejoin", v)
            if isfile("ADS_LastStrat.lua") then pcall(delfile, "ADS_LastStrat.lua") end
            if v and GameState == "GAME" then
                if #executed_actions > 0 then
                    local content = "local TDS = shared.TDSTable or loadstring(game:HttpGet(\"https://raw.githubusercontent.com/DuxiiT/auto-strat/refs/heads/main/Library.lua\"))()\n\n"
                    content = content .. table.concat(executed_actions, "\n")
                    writefile("ADS_LastStrat.lua", content)
                end
                if not BackToLobbyRunning then StartBackToLobby() end
            end
        end
    })

    Automation:Toggle({
        Title = "Auto Restart",
        Desc = "Turn this ON if you are running a LOSE strat",
        Value = Globals.AutoRestart,
        Callback = function(v)
            SetSetting("AutoRestart", v)
            if isfile("ADS_LastStrat.lua") then pcall(delfile, "ADS_LastStrat.lua") end
            if v and GameState == "GAME" then
                if #executed_actions > 0 then
                    local content = "local TDS = shared.TDSTable or loadstring(game:HttpGet(\"https://raw.githubusercontent.com/DuxiiT/auto-strat/refs/heads/main/Library.lua\"))()\n\n"
                    content = content .. table.concat(executed_actions, "\n")
                    writefile("ADS_LastStrat.lua", content)
                end
                if not BackToLobbyRunning then StartBackToLobby() end
            end
        end
    })

    if not IsMobile then
        Automation:Textbox({
            Title = "Private Server Code",
            Desc = "Paste your Private Server Code here to always join your private server",
            Placeholder = "Example: 16055572089259659857100802598629",
            Value = Globals.PrivateCode or "",
            ClearTextOnFocus = false,
            Callback = function(text)
                local validated = text
                if text ~= "" and not text:match("^%d+$") then validated = "" end
                Globals.PrivateCode = validated
                SetSetting("PrivateCode", validated)
            end
        })
    end

    Automation:Toggle({
        Title = "Auto Ready Up",
        Desc = "Automatically readies up when starting a match",
        Value = Globals.AutoReady,
        Callback = function(v)
            Globals.AutoReady = v
            SetSetting("AutoReady", v)
            if v then StartAutoReady() end
        end
    })

    Automation:Toggle({
        Title = "Auto Skip Waves",
        Desc = "Skips all Waves",
        Value = Globals.AutoSkip,
        Callback = function(v)
            SetSetting("AutoSkip", v)
        end
    })

    Automation:Dropdown({
        Title = "Modifiers:",
        Desc = "Selected modifiers must already be unlocked via trials!",
        List = AllModifiers,
        Value = Globals.Modifiers,
        Multi = true,
        Callback = function(choice)
            SetSetting("Modifiers", choice)
        end
    })

    Automation:Section({Title = "Auto-Abilities"})

    Automation:Toggle({
        Title = "Auto Chain",
        Desc = "Chains Commander Ability",
        Value = Globals.AutoChain,
        Callback = function(v)
            SetSetting("AutoChain", v)
        end
    })

    Automation:Toggle({
        Title = "Support Caravan",
        Desc = "Uses Commander Support Caravan",
        Value = Globals.SupportCaravan,
        Callback = function(v)
            SetSetting("SupportCaravan", v)
        end
    })

    Automation:Toggle({
        Title = "Auto DJ Booth",
        Desc = "Uses DJ Booth Ability",
        Value = Globals.AutoDJ,
        Callback = function(v)
            SetSetting("AutoDJ", v)
        end
    })

    Automation:Textbox({
        Title = "DJ Custom Music",
        Desc = "Custom audio ID for your DJ Booth (Requires Gamepass)",
        Placeholder = "Audio ID",
        Value = Globals.DJCustomSongID or "",
        ClearTextOnFocus = false,
        Callback = function(value)
            SetSetting("DJCustomSongID", value or "")
            if not tonumber(value) then return end
            task.spawn(function()
                local TowersFolder = workspace:FindFirstChild("Towers")
                if not TowersFolder then return end
                for _, tower in ipairs(TowersFolder:GetChildren()) do
                    AutoSetDJSong(tower)
                end
            end)
        end
    })

    Automation:Toggle({
        Title = "Auto Necro",
        Desc = "Uses Necromancer Ability",
        Value = Globals.AutoNecro,
        Callback = function(v)
            SetSetting("AutoNecro", v)
        end
    })

    Automation:Section({Title = "Unit Spawners"})

    Automation:Toggle({
        Title = "Enable Path Distance Marker",
        Desc = "Red = Mercenary Base, Green = Military Base",
        Value = Globals.PathVisuals,
        Callback = function(v)
            SetSetting("PathVisuals", v)
        end
    })

    Automation:Toggle({
        Title = "Auto Mercenary Base",
        Desc = "Uses Air-Drop Ability",
        Value = Globals.AutoMercenary,
        Callback = function(v)
            SetSetting("AutoMercenary", v)
        end
    })

    MercenarySlider = Automation:Slider({
        Title = "Path Distance",
        Min = 0,
        Max = 300,
        Rounding = 0,
        Value = Globals.MercenaryPath,
        Callback = function(val)
            SetSetting("MercenaryPath", val)
        end
    })

    Automation:Toggle({
        Title = "Auto Military Base",
        Desc = "Uses Airstrike Ability",
        Value = Globals.AutoMilitary,
        Callback = function(v)
            SetSetting("AutoMilitary", v)
        end
    })

    MilitarySlider = Automation:Slider({
        Title = "Path Distance",
        Min = 0,
        Max = 300,
        Rounding = 0,
        Value = Globals.MilitaryPath,
        Callback = function(val)
            SetSetting("MilitaryPath", val)
        end
    })

    task.spawn(function()
        while true do
            local success = CalcLength()
            if success then break end
            task.wait(3)
        end
    end)

    Automation:Section({Title = "Inventory Management"})

    Automation:Toggle({
        Title = "Auto Open Crates",
        Desc = "Periodically attempts to open selected crates.",
        Value = Globals.AutoOpenCrates or false,
        Callback = function(v)
            Globals.AutoOpenCrates = v
            SetSetting("AutoOpenCrates", v)
            if v then StartAutoOpenCrates() end
        end
    })

    Automation:Dropdown({
        Title = "Target Crate:",
        List = CrateList,
        Value = Globals.SelectedCrate or "All",
        Callback = function(choice)
            Globals.SelectedCrate = choice
            SetSetting("SelectedCrate", choice)
        end
    })

    Automation:Section({Title = "Economy & Farming"})

    Automation:Toggle({
        Title = "Sell Farms",
        Desc = "Sells all your farms on the specified wave",
        Value = Globals.SellFarms,
        Callback = function(v)
            SetSetting("SellFarms", v)
        end
    })

    Automation:Textbox({
        Title = "Wave:",
        Desc = "Wave to sell farms",
        Placeholder = "40",
        Value = tostring(Globals.SellFarmsWave),
        ClearTextOnFocus = false,
        Callback = function(text)
            local number = tonumber(text)
            if number then
                SetSetting("SellFarmsWave", number)
            else
                Window:Notify({Title = "ADS", Desc = "Invalid number entered!", Time = 3, Type = "error"})
            end
        end
    })


    Automation:Section({Title = "GitHub Strategy Loader"})

    Automation:Label({
        Title = "Repo: " .. (ADS_Config.Repo or "Not Set"),
        Desc = "Branch: " .. GitHubBranch .. " | Mode: " .. FallbackMode
    })

    Automation:Toggle({
        Title = "Enable Auto-Load",
        Desc = "Auto-detect maps, vote, and load strategy from GitHub",
        Value = Globals.MultiMapEnabled or false,
        Callback = function(v)
            Globals.MultiMapEnabled = v
            SetSetting("MultiMapEnabled", v)
        end
    })

    Automation:Textbox({
        Title = "Preferred Maps",
        Desc = "Priority list (comma-separated). Checked before GitHub match.",
        Placeholder = "Simplicity, Crossroads, Farm",
        Value = table.concat(Globals.PreferredMaps or {}, ", "),
        ClearTextOnFocus = false,
        Callback = function(text)
            local maps = {}
            for map in text:gmatch("([^,]+)") do
                local trimmed = map:match("^%s*(.-)%s*$")
                if trimmed ~= "" then table.insert(maps, trimmed) end
            end
            Globals.PreferredMaps = maps
            SetSetting("PreferredMaps", maps)
        end
    })

    Automation:Button({
        Title = "Refresh / Clear Cache",
        Desc = "Clears cached strategies and re-fetches from GitHub",
        Callback = function()
            TDS:ClearStrategyCache()
            Window:Notify({Title = "ADS", Desc = "Strategy cache cleared!", Time = 3, Type = "normal"})
        end
    })

    Automation:Button({
        Title = "Detect Current Maps",
        Desc = "Scans available maps in voting",
        Callback = function()
            local maps = TDS:GetDetectedMaps()
            if #maps > 0 then
                local msg = "Maps: " .. table.concat(maps, ", ")
                Logger:Log(msg)
                Window:Notify({Title = "Map Detector", Desc = msg, Time = 5, Type = "normal"})
            else
                Window:Notify({Title = "Map Detector", Desc = "No maps detected", Time = 3, Type = "error"})
            end
        end
    })

    Automation:Button({
        Title = "Load Current Strategy",
        Desc = "Shows which strategy is currently loaded",
        Callback = function()
            local strat = TDS:GetCurrentStrategy()
            if strat then
                Window:Notify({Title = "ADS", Desc = "Loaded: " .. strat, Time = 3, Type = "normal"})
            else
                Window:Notify({Title = "ADS", Desc = "No strategy loaded yet", Time = 3, Type = "error"})
            end
        end
    })

    Automation:Section({Title = "Map Webhook"})

    Automation:Toggle({
        Title = "Send Map Detection Webhook",
        Desc = "Sends available maps + strategy availability to Discord",
        Value = Globals.SendMapWebhook or false,
        Callback = function(v)
            Globals.SendMapWebhook = v
            SetSetting("SendMapWebhook", v)
        end
    })

    Automation:Textbox({
        Title = "Map Webhook URL",
        Desc = "Discord webhook for map notifications",
        Placeholder = "https://discord.com/api/webhooks/...",
        Value = Globals.MapWebhookURL or "",
        ClearTextOnFocus = true,
        Callback = function(value)
            Globals.MapWebhookURL = value
            SetSetting("MapWebhookURL", value)
        end
    })

    Automation:Section({Title = "Utilities"})

    Automation:Toggle({
        Title = "Auto Gatling",
        Desc = "Loads external Auto Gatling (credits to DeadSignalFound on GitHub)",
        Value = Globals.AutoGatling,
        Callback = function(v)
            SetSetting("AutoGatling", v)
        end
    })

    Automation:Toggle({
        Title = "Gatlify",
        Desc = "Gatling gun script but better, more stable, with fixed lags and more features than Railgun (includes a key system)",
        Value = Globals.Gatlify,
        Callback = function(v)
            SetSetting("Gatlify", v)
        end
    })

    Automation:Toggle({
        Title = "Auto Collect Pickups",
        Desc = "Collects Logbooks + Event currency",
        Value = Globals.AutoPickups,
        Callback = function(v)
            SetSetting("AutoPickups", v)
        end
    })

    Automation:Dropdown({
        Title = "Pickup Method",
        Desc = "",
        List = {"Pathfinding", "Instant"},
        Value = Globals.PickupMethod or "Pathfinding",
        Callback = function(choice)
            local selected = type(choice) == "table" and choice[1] or choice
            if not selected or selected == "" then selected = "Pathfinding" end
            SetSetting("PickupMethod", selected)
        end
    })

    Automation:Toggle({
        Title = "Claim Rewards",
        Desc = "Claims your playtime and uses spin tickets in Lobby",
        Value = Globals.ClaimRewards,
        Callback = function(v)
            SetSetting("ClaimRewards", v)
        end
    })
end

Window:Line()

-- // Interactive Tab
local Interactive = Window:Tab({Title = "Interactive", Icon = "mouse-pointer-click"}) do
    Interactive:Section({Title = "Tower Controls"})

    local TowerDropdown = Interactive:Dropdown({
        Title = "Tower:",
        List = CurrentEquippedTowers,
        Value = CurrentEquippedTowers[1],
        Callback = function(choice)
            SelectedTower = choice
        end
    })

    local function RefreshDropdown()
        local NewTowers = GetEquippedTowers()
        if table.concat(NewTowers, ",") ~= table.concat(CurrentEquippedTowers, ",") then
            TowerDropdown:Clear()
            for _, TowerName in ipairs(NewTowers) do
                TowerDropdown:Add(TowerName)
            end
            CurrentEquippedTowers = NewTowers
        end
    end

    task.spawn(function()
        while task.wait(2) do
            RefreshDropdown()
        end
    end)

    Interactive:Toggle({
        Title = "Stack Tower",
        Desc = "Enables Stacking placement",
        Value = false,
        Callback = function(v)
            StackEnabled = v
            Globals.StackEnabled = v
            if StackEnabled then
                Window:Notify({
                    Title = "ADS",
                    Desc = "Make sure not to equip the tower, only select it and then place where you want to!",
                    Time = 5,
                    Type = "normal"
                })
            end
        end
    })

    Interactive:Button({
        Title = "Open Inventory",
        Desc = "Place initial towers, then click this to swap loadout before readying up (bypasses 5-tower limit).\nNote: Does not work on low sUNC executors like Solara/Xeno",
        Callback = function()
            pcall(function()
                require(game:GetService("ReplicatedStorage").Client.Interfaces.LegacyInterface.Controllers.ViewController):setView("Inventory")
            end)
        end
    })

    Interactive:Button({
        Title = "Upgrade Selected",
        Desc = "",
        Callback = function()
            if SelectedTower then
                for _, v in pairs(workspace.Towers:GetChildren()) do
                    if v:FindFirstChild("TowerReplicator") and v.TowerReplicator:GetAttribute("Name") == SelectedTower and v.TowerReplicator:GetAttribute("OwnerId") == LocalPlayer.UserId then
                        RemoteFunc:InvokeServer("Troops", "Upgrade", "Set", {Troop = v})
                    end
                end
                Window:Notify({Title = "ADS", Desc = "Attempted to upgrade all the selected towers!", Time = 3, Type = "normal"})
            end
        end
    })

    Interactive:Button({
        Title = "Sell Selected",
        Desc = "",
        Callback = function()
            if SelectedTower then
                for _, v in pairs(workspace.Towers:GetChildren()) do
                    if v:FindFirstChild("TowerReplicator") and v.TowerReplicator:GetAttribute("Name") == SelectedTower and v.TowerReplicator:GetAttribute("OwnerId") == LocalPlayer.UserId then
                        RemoteFunc:InvokeServer("Troops", "Sell", {Troop = v})
                    end
                end
                Window:Notify({Title = "ADS", Desc = "Attempted to sell all the selected towers!", Time = 3, Type = "normal"})
            end
        end
    })

    Interactive:Button({
        Title = "Upgrade All",
        Desc = "",
        Callback = function()
            for _, v in pairs(workspace.Towers:GetChildren()) do
                if v:FindFirstChild("Owner") and v.Owner.Value == LocalPlayer.UserId then
                    RemoteFunc:InvokeServer("Troops", "Upgrade", "Set", {Troop = v})
                end
            end
            Window:Notify({Title = "ADS", Desc = "Attempted to upgrade all the towers!", Time = 3, Type = "normal"})
        end
    })

    Interactive:Button({
        Title = "Sell All",
        Desc = "",
        Callback = function()
            Window:Dialog({
                Title = "Do you want to sell all the towers?",
                Button1 = {
                    Title = "Confirm",
                    Color = Color3.fromRGB(226, 39, 6),
                    Callback = function()
                        for _, v in pairs(workspace.Towers:GetChildren()) do
                            if v:FindFirstChild("Owner") and v.Owner.Value == LocalPlayer.UserId then
                                RemoteFunc:InvokeServer("Troops", "Sell", {Troop = v})
                            end
                        end
                        Window:Notify({Title = "ADS", Desc = "Attempted to sell all the towers!", Time = 3, Type = "normal"})
                    end
                },
                Button2 = {
                    Title = "Cancel",
                    Color = Color3.fromRGB(0, 188, 0)
                }
            })
        end
    })

    Interactive:Section({Title = "TimeScale Management"})

    Interactive:Toggle({
        Title = "Enable TimeScale",
        Desc = "Unlocks and sets game speed using tickets",
        Value = Globals.TimeScaleEnabled,
        Callback = function(v)
            SetSetting("TimeScaleEnabled", v)
            if v then StartTimeScale() end
        end
    })

    Interactive:Dropdown({
        Title = "TimeScale Speed",
        Desc = "Choose: 0.5, 1, 1.5, 2",
        List = {"0.5", "1", "1.5", "2"},
        Value = tostring(Globals.TimeScaleValue or 2),
        Callback = function(choice)
            local selected = type(choice) == "table" and choice[1] or choice
            local value = CoerceTimeScaleValue(selected, Globals.TimeScaleValue or 2)
            SetSetting("TimeScaleValue", value)
            if Globals.TimeScaleEnabled then ApplyTimeScaleOnce() end
        end
    })

    Interactive:Section({Title = "Premium"})

    Interactive:Toggle({
        Title = "Auto Load Premium (In-Game)",
        Desc = "Automatically loads the key system when you join a match.",
        Value = Globals.AutoPremium,
        Callback = function(v)
            SetSetting("AutoPremium", v)
        end
    })

    local UnlockBtn = Interactive:Button({
        Title = "Unlock Premium Features",
        Desc = "Required Key System to access Premium features",
        Callback = function()
            task.spawn(function()
                Window:Notify({Title = "ADS", Desc = "Loading Key System...", Time = 3})
                local success = TDS:Addons()
                if success then
                    Window:Notify({Title = "ADS", Desc = "Premium Unlocked!", Time = 5, Type = "normal"})
                end
            end)
        end
    })

    Interactive:Section({Title = "Player Statistics"})

    local CoinsLabel = Interactive:Label({Title = "Coins: 0", Desc = ""})
    local GemsLabel = Interactive:Label({Title = "Gems: 0", Desc = ""})
    local TicketsLabel = Interactive:Label({Title = "Timescale Tickets: 0", Desc = ""})
    local LevelLabel = Interactive:Label({Title = "Level: 0", Desc = ""})
    local WinsLabel = Interactive:Label({Title = "Wins: 0", Desc = ""})
    local LosesLabel = Interactive:Label({Title = "Loses: 0", Desc = ""})
    local ExpLabel = Interactive:Label({Title = "Experience: 0 / 0", Desc = ""})
    local ExpSlider = Interactive:Slider({
        Title = "EXP",
        Desc = "",
        Min = 0,
        Max = 100,
        Rounding = 0,
        Value = 0,
        Callback = function() end
    })

    local function ParseNumber(val)
        if type(val) == "number" then return val end
        if type(val) == "string" then
            local cleaned = string.gsub(val, ",", "")
            local n = tonumber(cleaned)
            if n then return n end
        end
        if type(val) == "table" and val.get then
            local ok, v = pcall(function() return val:get() end)
            if ok then return ParseNumber(v) end
        end
        return nil
    end

    local function ReadValue(obj)
        if not obj then return nil end
        local ok, v = pcall(function() return obj.Value end)
        if ok then return ParseNumber(v) end
        return nil
    end

    local function GetStatNumber(name)
        local obj = LocalPlayer:FindFirstChild(name)
        local v = ReadValue(obj)
        if v ~= nil then return v end
        local attr = LocalPlayer:GetAttribute(name)
        v = ParseNumber(attr)
        if v ~= nil then return v end
        return nil
    end

    local function PickExpMax()
        local ExpObj = LocalPlayer:FindFirstChild("Experience")
        local AttrMax = ExpObj and ParseNumber(ExpObj:GetAttribute("Max"))
        local AttrNeed = ExpObj and ParseNumber(ExpObj:GetAttribute("Required"))
        local AttrNext = ExpObj and ParseNumber(ExpObj:GetAttribute("Next"))
        return AttrMax or AttrNeed or AttrNext
            or GetStatNumber("ExperienceMax")
            or GetStatNumber("ExperienceNeeded")
            or GetStatNumber("ExperienceRequired")
            or GetStatNumber("ExperienceToNextLevel")
            or GetStatNumber("ExperienceToLevel")
            or GetStatNumber("NextLevelExp")
            or GetStatNumber("ExpToNextLevel")
            or GetStatNumber("ExpNeeded")
            or GetStatNumber("ExpRequired")
            or GetStatNumber("MaxExp")
            or GetStatNumber("MaxExperience")
            or 100
    end

    local GcExpCache = { t = nil, last = 0 }
    local function GetGcExp()
        if not getgc then return nil end
        local t = GcExpCache.t
        if t then
            local exp = ParseNumber(rawget(t, "exp") or rawget(t, "Exp") or rawget(t, "experience") or rawget(t, "Experience"))
            local MaxExp = ParseNumber(rawget(t, "maxExp") or rawget(t, "MaxExp") or rawget(t, "maxEXP") or rawget(t, "MaxEXP") or rawget(t, "maxExperience") or rawget(t, "MaxExperience"))
            local lvl = ParseNumber(rawget(t, "level") or rawget(t, "Level") or rawget(t, "lvl") or rawget(t, "Lvl"))
            if exp and MaxExp then return exp, MaxExp, lvl end
        end
        local now = os.clock()
        if now - GcExpCache.last < 3 then return nil end
        GcExpCache.last = now
        local plvl = GetStatNumber("Level")
        for _, obj in ipairs(getgc(true)) do
            if type(obj) == "table" then
                local exp = ParseNumber(rawget(obj, "exp") or rawget(obj, "Exp") or rawget(obj, "experience") or rawget(obj, "Experience"))
                local MaxExp = ParseNumber(rawget(obj, "maxExp") or rawget(obj, "MaxExp") or rawget(obj, "maxEXP") or rawget(obj, "MaxEXP") or rawget(obj, "maxExperience") or rawget(obj, "MaxExperience"))
                if exp and MaxExp then
                    local lvl = ParseNumber(rawget(obj, "level") or rawget(obj, "Level") or rawget(obj, "lvl") or rawget(obj, "Lvl"))
                    if not plvl or not lvl or lvl == plvl then
                        GcExpCache.t = obj
                        return exp, MaxExp, lvl
                    end
                end
            end
        end
        return nil
    end

    local function UpdateStats()
        local coins = GetStatNumber("Coins") or 0
        local gems = GetStatNumber("Gems") or 0
        local tickets = GetStatNumber("TimescaleTickets") or 0
        local lvl = GetStatNumber("Level") or 0
        local wins = GetStatNumber("Triumphs") or 0
        local loses = GetStatNumber("Loses") or 0
        local exp = GetStatNumber("Experience") or 0
        local MaxExp = PickExpMax()
        local GcExp, GcMax, GcLvl = GetGcExp()
        if GcExp and GcMax then
            exp = GcExp
            MaxExp = GcMax
            if GcLvl then lvl = GcLvl end
        end
        if MaxExp < 1 then MaxExp = 1 end
        if exp > MaxExp then MaxExp = exp end
        if CoinsLabel then CoinsLabel:SetTitle("Coins: " .. tostring(coins)) end
        if GemsLabel then GemsLabel:SetTitle("Gems: " .. tostring(gems)) end
        if TicketsLabel then TicketsLabel:SetTitle("Timescale Tickets: " .. tostring(tickets)) end
        if LevelLabel then LevelLabel:SetTitle("Level: " .. tostring(lvl)) end
        if WinsLabel then WinsLabel:SetTitle("Wins: " .. tostring(wins)) end
        if LosesLabel then LosesLabel:SetTitle("Loses: " .. tostring(loses)) end
        if ExpLabel then ExpLabel:SetTitle("Experience: " .. tostring(exp) .. " / " .. tostring(MaxExp)) end
        if ExpSlider then
            ExpSlider:SetMin(0)
            ExpSlider:SetMax(MaxExp)
            ExpSlider:SetValue(exp)
        end
    end

    local StatsQueued = false
    local function QueueStatsUpdate()
        if StatsQueued then return end
        StatsQueued = true
        task.delay(0.2, function()
            StatsQueued = false
            UpdateStats()
        end)
    end

    local function HookStatObj(obj)
        if not obj then return end
        if obj.Changed then obj.Changed:Connect(QueueStatsUpdate) end
        obj:GetAttributeChangedSignal("Max"):Connect(QueueStatsUpdate)
        obj:GetAttributeChangedSignal("Required"):Connect(QueueStatsUpdate)
        obj:GetAttributeChangedSignal("Next"):Connect(QueueStatsUpdate)
    end

    local StatNames = {"Coins", "Gems", "TimescaleTickets", "Level", "Triumphs", "Loses", "Experience"}
    local ExpAttrNames = {
        "ExperienceMax", "ExperienceNeeded", "ExperienceRequired", "ExperienceToNextLevel",
        "ExperienceToLevel", "NextLevelExp", "ExpToNextLevel", "ExpNeeded", "ExpRequired",
        "MaxExp", "MaxExperience"
    }

    for _, name in ipairs(StatNames) do
        HookStatObj(LocalPlayer:FindFirstChild(name))
        LocalPlayer:GetAttributeChangedSignal(name):Connect(QueueStatsUpdate)
    end
    for _, name in ipairs(ExpAttrNames) do
        LocalPlayer:GetAttributeChangedSignal(name):Connect(QueueStatsUpdate)
    end
    LocalPlayer.ChildAdded:Connect(function(child)
        if table.find(StatNames, child.Name) then
            HookStatObj(child)
            QueueStatsUpdate()
        end
    end)
    LocalPlayer.ChildRemoved:Connect(function(child)
        if table.find(StatNames, child.Name) then
            QueueStatsUpdate()
        end
    end)
    QueueStatsUpdate()
end

Window:Line()

-- // ============================================================
-- // ADS_CONFIG - Simplified GitHub Strategy Loader
-- // ============================================================

--[[
    USAGE (paste BEFORE loading script):

    getgenv().ADS_Config = {
        Repo = "Dewzhud/CLOWNTDS",     -- GitHub repo (USER/REPO)
        Branch = "main",                -- Branch name
        Mode = "Easy"                   -- Fallback mode strategy
    }

    REPO STRUCTURE:
    github.com/Dewzhud/CLOWNTDS/
    ├── Easy.lua          (or Normal.lua, Hard.lua, Molten.lua, Fallen.lua)
    ├── Simplicity.lua    (optional map-specific)
    ├── Crossroads.lua    (optional map-specific)
    └── ...
]]

-- // Parse ADS_Config
local ADS_Config = getgenv().ADS_Config or {}

local GitHubRepo = ADS_Config.Repo or ""
local GitHubBranch = ADS_Config.Branch or "main"
local FallbackMode = ADS_Config.Mode or "Easy"

-- Build raw GitHub URL
local GitHubBaseURL = ""
if GitHubRepo ~= "" then
    GitHubBaseURL = "https://raw.githubusercontent.com/" .. GitHubRepo .. "/" .. GitHubBranch
end

-- // State
local GitHubDetectorRunning = false
local DetectedMapsList = {}
local StrategyCache = {} -- cached strategy code
local CurrentLoadedStrategy = nil

-- // Helper: Build full GitHub raw URL
local function BuildGitHubURL(fileName)
    if GitHubBaseURL == "" then return nil end
    return GitHubBaseURL .. "/" .. fileName .. ".lua"
end

-- // Helper: Fetch from GitHub
local function GitHubFetch(fileName)
    local url = BuildGitHubURL(fileName)
    if not url then
        return nil
    end

    local success, result = pcall(function()
        return game:HttpGet(url)
    end)

    if success and result and result ~= "" and not result:find("404") and not result:find("Not Found") then
        return result
    else
        return nil
    end
end

-- // Scan available maps during intermission
local function ScanAvailableMaps()
    local maps = {}
    local success = pcall(function()
        for _, g in ipairs(workspace:GetDescendants()) do
            if g and g:IsA("SurfaceGui") and g.Name == "MapDisplay" then
                local t = g:FindFirstChild("Title")
                if t and t.Text and t.Text ~= "" then
                    local pos = nil
                    if g.Parent and g.Parent:IsA("BasePart") then
                        pos = g.Parent.Position
                    end
                    table.insert(maps, {
                        Name = t.Text,
                        Gui = g,
                        Position = pos
                    })
                end
            end
        end
    end)
    if not success then
        if Logger then Logger:Log("[ADS] ScanAvailableMaps error (maps not ready)") end
    end
    DetectedMapsList = maps
    return maps
end

-- // Get detected map names
function TDS:GetDetectedMaps()
    ScanAvailableMaps()
    local list = {}
    for _, m in ipairs(DetectedMapsList) do
        table.insert(list, m.Name)
    end
    return list
end

-- // Check if strategy exists on GitHub (tries to fetch)
local function StrategyExists(name)
    if StrategyCache[name] then return true end
    local code = GitHubFetch(name)
    if code then
        StrategyCache[name] = code
        return true
    end
    return false
end

-- // Download strategy
local function DownloadStrategy(name)
    if StrategyCache[name] then
        return StrategyCache[name]
    end
    local code = GitHubFetch(name)
    if code then
        StrategyCache[name] = code
    end
    return code
end

-- // Execute strategy
local function ExecuteStrategy(code, stratName)
    if not code or code == "" then return false end

    Logger:Log("[ADS] Loading strategy: " .. stratName)

    local func, err = loadstring(code)
    if not func then
        Logger:Log("[ADS] Syntax error: " .. tostring(err))
        return false
    end

    local success, result = pcall(func)
    if success then
        CurrentLoadedStrategy = stratName
        Logger:Log("[ADS] Strategy loaded: " .. stratName)
        return true
    else
        Logger:Log("[ADS] Runtime error: " .. tostring(result))
        return false
    end
end

-- // Auto vote for best matching map
function TDS:AutoVoteMap(preferredMaps)
    if GameState ~= "GAME" then return false end

    local available = ScanAvailableMaps()
    if #available == 0 then
        Logger:Log("[ADS] No maps detected, waiting...")
        return false
    end

    Logger:Log("[ADS] Maps: " .. table.concat(TDS:GetDetectedMaps(), ", "))

    -- Try preferred maps first
    if preferredMaps and type(preferredMaps) == "table" then
        for _, preferred in ipairs(preferredMaps) do
            for _, map in ipairs(available) do
                if map.Name == preferred then
                    Logger:Log("[ADS] Voting preferred: " .. preferred)
                    CastMapVote(preferred, map.Position or Vector3.new(12.59, 10.64, 52.01))
                    task.wait(1)
                    LobbyReadyUp()
                    return preferred
                end
            end
        end
    end

    -- Try to find map with strategy on GitHub
    if GitHubBaseURL ~= "" then
        for _, map in ipairs(available) do
            local cleanName = map.Name:gsub(" ", "_")
            if StrategyExists(cleanName) then
                Logger:Log("[ADS] Found strategy for: " .. map.Name)
                CastMapVote(map.Name, map.Position or Vector3.new(12.59, 10.64, 52.01))
                task.wait(1)
                LobbyReadyUp()
                return map.Name
            end
        end
    end

    -- Fallback to first available
    if #available > 0 then
        local first = available[1]
        Logger:Log("[ADS] Voting: " .. first.Name)
        CastMapVote(first.Name, first.Position or Vector3.new(12.59, 10.64, 52.01))
        task.wait(1)
        LobbyReadyUp()
        return first.Name
    end

    return false
end

-- // Load strategy for map or mode
function TDS:LoadStrategy(name)
    local cleanName = name:gsub(" ", "_")
    local code = DownloadStrategy(cleanName)
    if code then
        return ExecuteStrategy(code, cleanName)
    end
    Logger:Log("[ADS] No strategy: " .. cleanName)
    return false
end

-- // Main auto-detect flow
function TDS:AutoDetectAndLoad(preferredMaps)
    if GitHubDetectorRunning then return end
    GitHubDetectorRunning = true

    task.spawn(function()
        -- Wait for intermission (ReactGameIntermission)
        local VoteGui = nil
        local waitStart = os.clock()
        while not VoteGui do
            VoteGui = PlayerGui:FindFirstChild("ReactGameIntermission")
            if VoteGui and VoteGui.Enabled then break end
            VoteGui = nil
            if os.clock() - waitStart > 30 then
                Logger:Log("[ADS] Timeout waiting for intermission")
                GitHubDetectorRunning = false
                return
            end
            task.wait(1)
        end

        if not (VoteGui and VoteGui.Enabled) then
            GitHubDetectorRunning = false
            return
        end

        task.wait(3) -- Let maps populate

        -- Detect and vote
        local votedMap = TDS:AutoVoteMap(preferredMaps)

        if votedMap then
            task.spawn(function()
                -- Wait for game start
                local stateReplicators = ReplicatedStorage:WaitForChild("StateReplicators")
                local gameStateReplicator = stateReplicators:WaitForChild("GameStateReplicator")
                repeat task.wait(1) until gameStateReplicator:GetAttribute("GameStarted") == true

                task.wait(3)

                -- Try map strategy
                local loaded = TDS:LoadStrategy(votedMap)

                -- Fallback to mode
                if not loaded then
                    Logger:Log("[ADS] Falling back to mode: " .. FallbackMode)
                    TDS:LoadStrategy(FallbackMode)
                end
            end)
        end

        GitHubDetectorRunning = false
    end)
end

-- // Clear cache
function TDS:ClearStrategyCache()
    StrategyCache = {}
    CurrentLoadedStrategy = nil
    Logger:Log("[ADS] Strategy cache cleared")
end

-- // Get current loaded strategy
function TDS:GetCurrentStrategy()
    return CurrentLoadedStrategy
end

-- // State
local GitHubDetectorRunning = false
local DetectedMapsList = {}
local AvailableStrats = {Maps = {}, Modes = {}}
local StrategyCache = {} -- cached strategy code
local CurrentLoadedStrategy = nil

-- // Helper: Build full GitHub raw URL
local function BuildGitHubURL(path)
    local base = GitHubConfig.BaseURL
    if not base or base == "" then return nil end
    -- Remove trailing slash
    base = base:gsub("/$", "")
    return base .. "/" .. path
end

-- // Helper: Fetch from GitHub
local function GitHubFetch(path)
    local url = BuildGitHubURL(path)
    if not url then
        if GitHubConfig.Debug then Logger:Log("[GitHub] No BaseURL set!") end
        return nil
    end

    if GitHubConfig.Debug then Logger:Log("[GitHub] Fetching: " .. url) end

    local success, result = pcall(function()
        return game:HttpGet(url)
    end)

    if success and result and result ~= "" and not result:find("404") then
        if GitHubConfig.Debug then Logger:Log("[GitHub] Fetched successfully (" .. #result .. " bytes)") end
        return result
    else
        if GitHubConfig.Debug then Logger:Log("[GitHub] Failed to fetch: " .. tostring(result)) end
        return nil
    end
end

-- // Fetch strategy index from GitHub
local function FetchStrategyIndex()
    if not GitHubConfig.BaseURL or GitHubConfig.BaseURL == "" then
        Logger:Log("[GitHub] BaseURL not set. Set Globals.GitHubBaseURL")
        return false
    end

    Logger:Log("[GitHub] Fetching strategy index...")
    local data = GitHubFetch(GitHubConfig.IndexPath)
    if not data then
        -- Try to build index manually by scanning common names
        Logger:Log("[GitHub] No index.json found, building manual index...")
        AvailableStrats = {
            Maps = {},
            Modes = {}
        }
        return false
    end

    local ok, decoded = pcall(function()
        return HttpService:JSONDecode(data)
    end)

    if ok and decoded then
        AvailableStrats = decoded
        Logger:Log("[GitHub] Index loaded! Maps: " .. (decoded.Maps and #decoded.Maps or 0) .. ", Modes: " .. (decoded.Modes and #decoded.Modes or 0))
        return true
    else
        Logger:Log("[GitHub] Failed to parse index.json")
        return false
    end
end

function TDS:ResetAllStates()
    table.clear(self.PlacedTowers)
    table.clear(UpgradeHistory)
    table.clear(executed_actions)
    if Logger and Logger.Clear then
        pcall(function()
            Logger:Clear()
            Logger:Log("Restarting strategy...")
        end)
    end
end

function TDS:RunStrategy()
    if Globals.activeStrategyThread then
        pcall(task.cancel, Globals.activeStrategyThread)
        Globals.activeStrategyThread = nil
    end
    Globals.activeStrategyThread = task.spawn(function()
        Globals.tdsReplaying = true
        pcall(function()
            loadstring(readfile("ADS_LastStrat.lua"))()
        end)
        Globals.tdsReplaying = false
        Globals.activeStrategyThread = nil
    end)
end

-- // Lobby
function TDS:Mode(difficulty, code)
    self.SavedDifficulty = difficulty
    local targetCode = ""
    if IsMobile then
        if (code and code ~= "") or (Globals.PrivateCode and Globals.PrivateCode ~= "") then
            Window:Notify({
                Title = "Warning",
                Desc = "Private server codes are not supported on mobile devices.",
                Time = 25,
                Type = "error"
            })
        end
    else
        if code and code ~= "" then
            targetCode = code
        elseif Globals.PrivateCode then
            targetCode = Globals.PrivateCode
        end
    end
    self.PrivateCode = tostring(targetCode)
    if GameState ~= "LOBBY" then return false end
    if targetCode ~= "" and not MarketplaceService:UserOwnsGamePassAsync(LocalPlayer.UserId, 10518590) then
        local ServerType = game:GetService('RobloxReplicatedStorage').GetServerType:InvokeServer()
        if ServerType ~= "VIPServer" then
            game:GetService("ExperienceService"):LaunchExperience({
                placeId = game.PlaceId,
                linkCode = tostring(targetCode)
            })
            return true
        end
    end
    if difficulty == "Trial" then
        local Elevators = workspace:WaitForChild("TrialElevators")
        local Network = ReplicatedStorage:WaitForChild("Network")
        if Elevators and Network then
            local targetElevator = nil
            repeat
                for _, v in pairs(Elevators:GetChildren()) do
                    if v.Name:match("Elevator") then
                        targetElevator = v
                        break
                    end
                end
                if not targetElevator then task.wait(0.5) end
            until targetElevator
            task.spawn(function()
                local ElevatorsNet = Network:WaitForChild("Elevators")
                local EnterRemote = ElevatorsNet:WaitForChild("RF:Enter")
                local SetSizeRemote = ElevatorsNet:WaitForChild("RF:SetSize")
                local SetReadyRemote = ElevatorsNet:WaitForChild("RF:SetReady")
                pcall(function() EnterRemote:InvokeServer(targetElevator) end)
                pcall(function() SetSizeRemote:InvokeServer(1) end)
                pcall(function() SetReadyRemote:InvokeServer(true) end)
            end)
            return true
        end
    end
    local LobbyHud = PlayerGui:WaitForChild("ReactLobbyHud", 30)
    local frame = LobbyHud and LobbyHud:WaitForChild("Frame", 30)
    local MatchMaking = frame and frame:WaitForChild("matchmaking", 30)
    if MatchMaking then
        local remote = game:GetService("ReplicatedStorage"):WaitForChild("RemoteFunction")
        local success = false
        local res
        repeat
            local ok, result = pcall(function()
                local mode = TDS.MatchmakingMap[difficulty]
                local payload
                if difficulty == "Hardcore" then
                    payload = {mode = "hardcore", difficulty = "Easy", count = 1}
                elseif difficulty == "Voidcore" then
                    payload = {mode = "hardcore", difficulty = "Hard", count = 1}
                elseif mode then
                    payload = {mode = mode, count = 1}
                    if difficulty:match("Ducky") then
                        payload.difficulty = difficulty:gsub("Ducky", "")
                    end
                else
                    payload = {difficulty = difficulty, mode = "survival", count = 1}
                end
                return remote:InvokeServer("Multiplayer", "v2:start", payload)
            end)
            if ok and CheckResOk(result) then
                success = true
                res = result
            else
                task.wait(0.5)
            end
        until success
    end
    return true
end

function TDS:Loadout(...)
    if GameState ~= "GAME" then return end
    local towers = {...}
    local remote = game:GetService("ReplicatedStorage"):WaitForChild("RemoteEvent")
    local StateReplicators = ReplicatedStorage:FindFirstChild("StateReplicators")
    local CurrentlyEquipped = {}
    if StateReplicators then
        for _, folder in ipairs(StateReplicators:GetChildren()) do
            if folder.Name == "PlayerReplicator" and folder:GetAttribute("UserId") == LocalPlayer.UserId then
                local EquippedAttr = folder:GetAttribute("EquippedTowers")
                if type(EquippedAttr) == "string" then
                    local CleanedJson = EquippedAttr:match("%[.*%]")
                    local DecodeSuccess, decoded = pcall(function()
                        return HttpService:JSONDecode(CleanedJson)
                    end)
                    if DecodeSuccess and type(decoded) == "table" then
                        CurrentlyEquipped = decoded
                    end
                end
            end
        end
    end
    for _, CurrentTower in ipairs(CurrentlyEquipped) do
        if CurrentTower ~= "None" then
            local UnequipDone = false
            repeat
                local ok = pcall(function()
                    remote:FireServer("Inventory", "Unequip", "Tower", CurrentTower)
                    task.wait(0.3)
                end)
                if ok then UnequipDone = true else task.wait(0.2) end
            until UnequipDone
        end
    end
    task.wait(0.5)
    for _, TowerName in ipairs(towers) do
        if TowerName and TowerName ~= "" then
            local EquipSuccess = false
            repeat
                local ok = pcall(function()
                    remote:FireServer("Inventory", "Equip", "Tower", TowerName)
                    Logger:Log("Equipped tower: " .. TowerName)
                    task.wait(0.3)
                end)
                if ok then EquipSuccess = true else task.wait(0.2) end
            until EquipSuccess
        end
    end
    task.wait(0.5)
    return true
end

-- // Ingame
function TDS:VoteSkip(StartWave, EndWave)
    task.spawn(function()
        local CurrentWave = GetCurrentWave()
        self.LastVoteSkipTarget = self.LastVoteSkipTarget or 0
        if not StartWave then
            if self.LastVoteSkipTarget < CurrentWave then
                self.LastVoteSkipTarget = CurrentWave
            else
                self.LastVoteSkipTarget = self.LastVoteSkipTarget + 1
            end
            StartWave = self.LastVoteSkipTarget
            EndWave = StartWave
        else
            EndWave = EndWave or StartWave
            self.LastVoteSkipTarget = EndWave
        end
        for wave = StartWave, EndWave do
            while GetCurrentWave() < wave do task.wait(1) end
            local TargetNextWave = wave + 1
            while GetCurrentWave() < TargetNextWave do
                local VoteUi = PlayerGui:FindFirstChild("ReactOverridesVote")
                local VoteButton = VoteUi
                    and VoteUi:FindFirstChild("Frame")
                    and VoteUi.Frame:FindFirstChild("votes")
                    and VoteUi.Frame.votes:FindFirstChild("vote", true)
                if VoteButton and VoteButton.Position == UDim2.new(0.5, 0, 0.5, 0) then
                    pcall(function() RemoteFunc:InvokeServer("Voting", "Skip") end)
                end
                task.wait(0.5)
            end
            Logger:Log("Successfully skipped wave " .. wave)
        end
    end)
end

function TDS:GameInfo(name, list)
    if GameState ~= "GAME" then return false end
    local VoteGui = PlayerGui:WaitForChild("ReactGameIntermission", 30)
    if not (VoteGui and VoteGui.Enabled and VoteGui:WaitForChild("Frame", 5)) then return end
    local modifiers = (list and next(list)) and list or Globals.Modifiers
    CastModifierVote(modifiers)
    local stateReplicators = game:GetService("ReplicatedStorage"):WaitForChild("StateReplicators", 5)
    local gameStateReplicator = stateReplicators and stateReplicators:FindFirstChild("GameStateReplicator")
    if MarketplaceService:UserOwnsGamePassAsync(LocalPlayer.UserId, 10518590) or (gameStateReplicator and gameStateReplicator:GetAttribute("IsPrivateServer") == true) then
        SelectMapOverride(name, "vip")
        Logger:Log("Selected map: " .. name)
        repeat task.wait(1) until PlayerGui:FindFirstChild("ReactUniversalHotbar")
        return true
    elseif IsMapAvailable(name) then
        SelectMapOverride(name)
        repeat task.wait(1) until PlayerGui:FindFirstChild("ReactUniversalHotbar")
        return true
    else
        Logger:Log("Map '" .. name .. "' not available, rejoining...")
        RejoinMatch()
        repeat task.wait(9999) until false
    end
end

function TDS:UnlockTimeScale()
    UnlockSpeedTickets()
end

function TDS:TimeScale(val)
    SetGameTimescale(val)
end

function TDS:StartGame()
    LobbyReadyUp()
end

function TDS:Ready()
    if GameState ~= "GAME" then return false end
    MatchReadyUp()
end

function TDS:GetWave()
    return GetCurrentWave()
end

function TDS:WaitForWave(targetWave)
    if GameState ~= "GAME" then return false end
    while self:GetWave() < targetWave do task.wait(0.5) end
    return true
end

function TDS:RestartGame()
    TriggerRestart()
end

function TDS:Place(TName, px, py, pz, ...)
    local args = {...}
    local isStacking = args[#args] == "stack" or args[#args] == true
    if isStacking and not PremiumLoaded and GameState == "GAME" then
        Window:Notify({
            Title = "ADS",
            Desc = "Stacking requires Premium. Automatically loading key system...",
            Time = 3,
            Type = "normal"
        })
        self:Addons()
        return self:Place(TName, px, py, pz, unpack(args))
    end
    if GameState ~= "GAME" then return false end
    local existing = {}
    for _, child in ipairs(workspace.Towers:GetChildren()) do
        for _, SubChild in ipairs(child:GetChildren()) do
            if SubChild.Name == "Owner" and SubChild.Value == LocalPlayer.UserId then
                existing[child] = true
                break
            end
        end
    end
    DoPlaceTower(TName, Vector3.new(px, py, pz), unpack(args))
    local NewT
    repeat
        for _, child in ipairs(workspace.Towers:GetChildren()) do
            if not existing[child] then
                for _, SubChild in ipairs(child:GetChildren()) do
                    if SubChild.Name == "Owner" and SubChild.Value == LocalPlayer.UserId then
                        NewT = child
                        break
                    end
                end
            end
            if NewT then break end
        end
        task.wait(0.05)
    until NewT
    table.insert(self.PlacedTowers, NewT)
    return #self.PlacedTowers
end

function TDS:Upgrade(idx, PId)
    local t = self.PlacedTowers[idx]
    if t then
        DoUpgradeTower(t, PId or 1)
        Logger:Log("Upgrading tower index: " .. idx)
        UpgradeHistory[idx] = (UpgradeHistory[idx] or 0) + 1
    end
end

function TDS:SetTarget(idx, TargetType, ReqWave)
    if ReqWave then
        repeat task.wait(0.5) until GetCurrentWave() >= ReqWave
    end
    local t = self.PlacedTowers[idx]
    if not t then return end
    pcall(function()
        RemoteFunc:InvokeServer("Troops", "Target", "Set", {Troop = t, Target = TargetType})
        Logger:Log("Set target for tower index " .. idx .. " to " .. TargetType)
    end)
end

function TDS:Sell(idx, ReqWave)
    if ReqWave then
        repeat task.wait(0.5) until GetCurrentWave() >= ReqWave
    end
    local t = self.PlacedTowers[idx]
    if t and DoSellTower(t) then return true end
    return false
end

function TDS:SellAll(ReqWave)
    task.spawn(function()
        if ReqWave then
            repeat task.wait(0.5) until GetCurrentWave() >= ReqWave
        end
        local TowersCopy = {unpack(self.PlacedTowers)}
        for idx, t in ipairs(TowersCopy) do
            if DoSellTower(t) then
                for i, OrigT in ipairs(self.PlacedTowers) do
                    if OrigT == t then
                        table.remove(self.PlacedTowers, i)
                        break
                    end
                end
            end
        end
        return true
    end)
end

function TDS:Ability(idx, name, data, loop)
    local t = self.PlacedTowers[idx]
    if not t then return false end
    Logger:Log("Activating ability '" .. name .. "' for tower index: " .. idx)
    return DoActivateAbility(t, name, data, loop)
end

function TDS:AutoChain(...)
    local TowerIndices = {...}
    if #TowerIndices == 0 then return end
    local running = true
    task.spawn(function()
        local i = 1
        while running do
            local idx = TowerIndices[i]
            local tower = TDS.PlacedTowers[idx]
            if tower then
                DoActivateAbility(tower, "Call Of Arms")
            end
            local hotbar = PlayerGui.ReactUniversalHotbar.Frame
            local timescale = hotbar:FindFirstChild("timescale")
            if timescale then
                if timescale:FindFirstChild("Lock") then
                    task.wait(10.5)
                else
                    task.wait(5.5)
                end
            else
                task.wait(10.5)
            end
            i += 1
            if i > #TowerIndices then i = 1 end
        end
    end)
    return function() running = false end
end

function TDS:SetOption(idx, name, val, ReqWave)
    local t = self.PlacedTowers[idx]
    if t then
        Logger:Log("Setting option '" .. name .. "' for tower index: " .. idx)
        return DoSetOption(t, name, val, ReqWave)
    end
    return false
end

function TDS:MedicSelect(idx, val)
    local t = self.PlacedTowers[idx]
    local target = self.PlacedTowers[val]
    if t and target then
        Logger:Log("Medic: " .. idx .. " -> " .. val)
        RemoteFunc:InvokeServer("Troops", "TowerServerEvent", "ToggleSelectedTower", t, target)
        return true
    end
    return false
end

-- // Strategy Recording
local function strategyRecordingSetup()
    local originalMethods = {}
    local recordableMethods = {
        "Mode", "Place", "Upgrade", "SetTarget", "Sell", "SellAll",
        "Ability", "SetOption", "MedicSelect", "Ready", "VoteSkip",
        "WaitForWave", "UnlockTimeScale", "TimeScale"
    }
    for _, methodName in ipairs(recordableMethods) do
        originalMethods[methodName] = TDS[methodName]
        TDS[methodName] = function(self, ...)
            if not Globals.tdsReplaying and GameState == "GAME" then
                local argumentsList = {...}
                local stringifiedArguments = {}
                for _, argumentValue in ipairs(argumentsList) do
                    local argumentType = type(argumentValue)
                    if argumentType == "string" then
                        table.insert(stringifiedArguments, string.format("%q", argumentValue))
                    elseif argumentType == "number" or argumentType == "boolean" then
                        table.insert(stringifiedArguments, tostring(argumentValue))
                    elseif argumentType == "table" then
                        local parts = {}
                        for key, val in pairs(argumentValue) do
                            local keyType = type(key)
                            local formattedKey
                            if keyType == "string" then
                                formattedKey = string.format("[%q]", key)
                            elseif keyType == "number" then
                                formattedKey = string.format("[%d]", key)
                            else
                                formattedKey = string.format("[%s]", tostring(key))
                            end
                            local formattedValue = type(val) == "string" and string.format("%q", val) or tostring(val)
                            table.insert(parts, formattedKey .. " = " .. formattedValue)
                        end
                        table.insert(stringifiedArguments, "{" .. table.concat(parts, ", ") .. "}")
                    else
                        table.insert(stringifiedArguments, "nil")
                    end
                end
                if methodName == "Mode" then
                    executed_actions = {}
                else
                    local actionString = string.format("TDS:%s(%s)", methodName, table.concat(stringifiedArguments, ", "))
                    table.insert(executed_actions, actionString)
                    local strategyFileContent = "local TDS = shared.TDSTable or loadstring(game:HttpGet(\"https://raw.githubusercontent.com/DuxiiT/auto-strat/refs/heads/main/Library.lua\"))()\n\n"
                    strategyFileContent = strategyFileContent .. table.concat(executed_actions, "\n")
                    writefile("ADS_LastStrat.lua", strategyFileContent)
                end
            end
            return originalMethods[methodName](self, ...)
        end
    end
end

strategyRecordingSetup()

if GameState == "LOBBY" and Globals.AutoRejoin and isfile("ADS_LastStrat.lua") then
    pcall(delfile, "ADS_LastStrat.lua")
end

if GameState == "GAME" and Globals.AutoRejoin and isfile("ADS_LastStrat.lua") then
    task.spawn(function()
        task.wait(2)
        TDS:RunStrategy()
    end)
end

-- // Misc Utility
local function IsVoidCharm(obj)
    return math.abs(obj.Position.Y) > 999999
end

local function GetRoot()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

-- // Auto Gatling
local function StartAutoGatling()
    if AutoGatlingRunning or not Globals.AutoGatling then return end
    AutoGatlingRunning = true
    task.spawn(function()
        while Globals.AutoGatling do
            if GameState == "GAME" then
                if not GatlingExecuted then
                    GatlingExecuted = true
                    task.spawn(function()
                        pcall(function()
                            loadstring(game:HttpGet("https://raw.githubusercontent.com/avtryxz/autogutlin/refs/heads/main/autogutlin.lua"))()
                        end)
                    end)
                end
            else
                GatlingExecuted = false
            end
            task.wait(1)
        end
        AutoGatlingRunning = false
    end)
end

-- // Gatlify
local function StartGatlify()
    if GatlifyRunning or not Globals.Gatlify then return end
    GatlifyRunning = true
    task.spawn(function()
        while Globals.Gatlify do
            if GameState == "GAME" then
                if not GatlifyExecuted then
                    repeat task.wait(0.5) until not IsCurrentlyLoading and (os.clock() - LastLoadTime >= 5)
                    if not Globals.Gatlify then break end
                    if not GatlifyExecuted then
                        IsCurrentlyLoading = true
                        GatlifyExecuted = true
                        pcall(function()
                            loadstring(game:HttpGet("https://raw.githubusercontent.com/avtryxz/Gatlify/refs/heads/main/Gatlify.lua"))()
                        end)
                        IsCurrentlyLoading = false
                        LastLoadTime = os.clock()
                    end
                end
            else
                GatlifyExecuted = false
            end
            task.wait(1)
        end
        GatlifyRunning = false
    end)
end

-- // Auto Premium
local function StartAutoPremium()
    if AutoPremiumRunning or not Globals.AutoPremium or PremiumLoaded then return end
    AutoPremiumRunning = true
    task.spawn(function()
        if GameState == "GAME" then
            Window:Notify({Title = "ADS", Desc = "Loading Key System...", Time = 3, Type = "normal"})
            local success = TDS:Addons()
            if success then
                Window:Notify({Title = "ADS", Desc = "Premium Unlocked!", Time = 3, Type = "normal"})
            else
                task.wait(5)
                AutoPremiumRunning = false
            end
        else
            AutoPremiumRunning = false
        end
    end)
end

-- // Auto Pickups
local function StartAutoPickups()
    if AutoPickupsRunning or not Globals.AutoPickups then return end
    AutoPickupsRunning = true
    task.spawn(function()
        while Globals.AutoPickups do
            local folder = workspace:FindFirstChild("Pickups")
            local hrp = GetRoot()
            if folder and hrp then
                local char = hrp.Parent
                local humanoid = char and char:FindFirstChildOfClass("Humanoid")
                local function MoveToPos(TargetPos)
                    if not humanoid then return false end
                    local function MoveDirect(pos)
                        humanoid:MoveTo(pos)
                        local StartT = os.clock()
                        while os.clock() - StartT < 2 do
                            if not Globals.AutoPickups then return false end
                            if (hrp.Position - pos).Magnitude < 4 then return true end
                            task.wait(0.1)
                        end
                        return (hrp.Position - pos).Magnitude < 4
                    end
                    local path = PathfindingService:CreatePath({
                        AgentRadius = 2,
                        AgentHeight = 6,
                        AgentCanJump = true,
                        AgentJumpHeight = 7,
                        AgentMaxSlope = 45
                    })
                    local ok = pcall(function() path:ComputeAsync(hrp.Position, TargetPos) end)
                    if ok and path.Status == Enum.PathStatus.Success then
                        local waypoints = path:GetWaypoints()
                        local BlockedConn = nil
                        BlockedConn = path.Blocked:Connect(function()
                            if BlockedConn then BlockedConn:Disconnect() end
                            if Globals.AutoPickups then
                                task.spawn(function() MoveToPos(TargetPos) end)
                            end
                        end)
                        for _, wp in ipairs(waypoints) do
                            if not Globals.AutoPickups then
                                if BlockedConn then BlockedConn:Disconnect() end
                                return false
                            end
                            if wp.Action == Enum.PathWaypointAction.Jump then humanoid.Jump = true end
                            if not MoveDirect(wp.Position) then
                                if BlockedConn then BlockedConn:Disconnect() end
                                return false
                            end
                        end
                        if BlockedConn then BlockedConn:Disconnect() end
                        return true
                    end
                    return MoveDirect(TargetPos)
                end
                for _, item in ipairs(folder:GetChildren()) do
                    if not Globals.AutoPickups then break end
                    if item:IsA("MeshPart") and (item.Name == "Bunz" or item.Name == "Lorebook" or item.Name == "SnowCharm") then
                        if not IsVoidCharm(item) then
                            if Globals.PickupMethod == "Instant" then
                                hrp.CFrame = item.CFrame * CFrame.new(0, 3, 0)
                                task.wait(0.2)
                                task.wait(0.3)
                            else
                                local TargetPos = item.Position + Vector3.new(0, 3, 0)
                                MoveToPos(TargetPos)
                                task.wait(0.2)
                                task.wait(0.3)
                            end
                        end
                    end
                end
            end
            task.wait(1)
        end
        AutoPickupsRunning = false
    end)
end

-- // Auto Skip
local function StartAutoSkip()
    if AutoSkipRunning or not Globals.AutoSkip then return end
    AutoSkipRunning = true
    task.spawn(function()
        while Globals.AutoSkip do
            local SkipVisible = PlayerGui:FindFirstChild("ReactOverridesVote")
                and PlayerGui.ReactOverridesVote:FindFirstChild("Frame")
                and PlayerGui.ReactOverridesVote.Frame:FindFirstChild("votes")
                and PlayerGui.ReactOverridesVote.Frame.votes:FindFirstChild("vote")
            if SkipVisible and SkipVisible.Position == UDim2.new(0.5, 0, 0.5, 0) then
                RunVoteSkip()
            end
            task.wait(0.1)
        end
        AutoSkipRunning = false
    end)
end

-- // Claim Rewards
local function StartClaimRewards()
    if AutoClaimRewards or not Globals.ClaimRewards or GameState ~= "LOBBY" then return end
    AutoClaimRewards = true
    local player = game:GetService("Players").LocalPlayer
    local network = game:GetService("ReplicatedStorage"):WaitForChild("Network")
    local SpinTickets = player:WaitForChild("SpinTickets", 15)
    if SpinTickets and SpinTickets.Value > 0 then
        local TicketCount = SpinTickets.Value
        local DailySpin = network:WaitForChild("DailySpin", 5)
        local RedeemRemote = DailySpin and DailySpin:WaitForChild("RF:RedeemSpin", 5)
        if RedeemRemote then
            for i = 1, TicketCount do
                RedeemRemote:InvokeServer()
                task.wait(0.5)
            end
        end
    end
    for i = 1, 6 do
        local args = { i }
        network:WaitForChild("PlaytimeRewards"):WaitForChild("RF:ClaimReward"):InvokeServer(unpack(args))
        task.wait(0.5)
    end
    game:GetService("ReplicatedStorage").Network.DailySpin["RF:RedeemReward"]:InvokeServer()
    AutoClaimRewards = false
end

-- // Back To Lobby
function StartBackToLobby()
    if GameState ~= "GAME" then return end
    if BackToLobbyRunning then return end
    BackToLobbyRunning = true
    task.spawn(function()
        local stateReplicators = ReplicatedStorage:WaitForChild("StateReplicators", 30)
        local gameStateReplicator = stateReplicators and stateReplicators:WaitForChild("GameStateReplicator", 30)
        local voteReplicator = stateReplicators and stateReplicators:WaitForChild("VoteReplicator", 30)
        if not gameStateReplicator or not voteReplicator then
            while true do
                pcall(HandlePostMatch)
                task.wait(1)
            end
            return
        end
        while Globals.AutoRejoin or Globals.AutoRestart do
            local isGameOver = gameStateReplicator:GetAttribute("GameOver") == true
            if isGameOver then
                local health = gameStateReplicator:GetAttribute("Health") or 0
                if health > 0 then
                    if Globals.AutoRejoin then
                        if isfile("ADS_LastStrat.lua") then pcall(delfile, "ADS_LastStrat.lua") end
                        pcall(HandlePostMatch)
                        break
                    end
                else
                    if Globals.AutoRestart then
                        task.spawn(pcall, HandlePostMatch, true)
                        local lastVoteTime = 0
                        while Globals.AutoRestart do
                            local title = voteReplicator:GetAttribute("Title")
                            local enabled = voteReplicator:GetAttribute("Enabled")
                            if enabled == true and title == "Restart?" then
                                if os.clock() - lastVoteTime > 3 then
                                    pcall(function() RemoteFunc:InvokeServer("Voting", "Skip") end)
                                    lastVoteTime = os.clock()
                                end
                            end
                            if title == "Ready?" or gameStateReplicator:GetAttribute("GameOver") == false then
                                break
                            end
                            task.wait(0.5)
                        end
                        if not Globals.AutoRestart then break end
                        if isfile("ADS_LastStrat.lua") then
                            task.spawn(function()
                                repeat
                                    task.wait(0.1)
                                    local towersFolder = workspace:FindFirstChild("Towers")
                                until (towersFolder and #towersFolder:GetChildren() == 0) or not Globals.AutoRestart
                                if not Globals.AutoRestart then return end
                                TDS:ResetAllStates()
                                TDS:RunStrategy()
                            end)
                        end
                        repeat task.wait(1) until gameStateReplicator:GetAttribute("GameOver") == false or not Globals.AutoRestart
                    elseif Globals.AutoRejoin then
                        if isfile("ADS_LastStrat.lua") then pcall(delfile, "ADS_LastStrat.lua") end
                        pcall(HandlePostMatch)
                        break
                    end
                end
            end
            task.wait(1)
        end
        BackToLobbyRunning = false
    end)
end

-- // Anti Lag
local function StartAntiLag()
    if AntiLagRunning then return end
    AntiLagRunning = true
    local settings = settings().Rendering
    local OriginalQuality = settings.QualityLevel
    settings.QualityLevel = Enum.QualityLevel.Level01
    task.spawn(function()
        while Globals.AntiLag do
            local TowersFolder = workspace:FindFirstChild("Towers")
            local ClientUnits = workspace:FindFirstChild("ClientUnits")
            if TowersFolder then
                for _, tower in ipairs(TowersFolder:GetChildren()) do
                    local anims = tower:FindFirstChild("Animations")
                    local weapon = tower:FindFirstChild("Weapon")
                    local projectiles = tower:FindFirstChild("Projectiles")
                    if anims then anims:Destroy() end
                    if projectiles then projectiles:Destroy() end
                    if weapon then weapon:Destroy() end
                end
            end
            if ClientUnits then
                for _, unit in ipairs(ClientUnits:GetChildren()) do
                    unit:Destroy()
                end
            end
            task.wait(0.5)
        end
        AntiLagRunning = false
    end)
end

-- // Auto Chain
local function StartAutoChain()
    if AutoChainRunning or not Globals.AutoChain then return end
    AutoChainRunning = true
    task.spawn(function()
        local idx = 1
        while Globals.AutoChain do
            local commander = {}
            local TowersFolder = workspace:FindFirstChild("Towers")
            if TowersFolder then
                for _, towers in ipairs(TowersFolder:GetDescendants()) do
                    if towers:IsA("Folder") and towers.Name == "TowerReplicator"
                    and towers:GetAttribute("Name") == "Commander"
                    and towers:GetAttribute("OwnerId") == game.Players.LocalPlayer.UserId
                    and (towers:GetAttribute("Upgrade") or 0) >= 2 then
                        commander[#commander + 1] = towers.Parent
                    end
                end
            end
            if #commander >= 3 then
                if idx > #commander then idx = 1 end
                local CurrentCommander = commander[idx]
                local replicator = CurrentCommander:FindFirstChild("TowerReplicator")
                local UpgradeLevel = replicator and replicator:GetAttribute("Upgrade") or 0
                if UpgradeLevel >= 4 and Globals.SupportCaravan then
                    RemoteFunc:InvokeServer("Troops", "Abilities", "Activate", {
                        Troop = CurrentCommander, Name = "Support Caravan", Data = {}
                    })
                    task.wait(0.1)
                end
                local response = RemoteFunc:InvokeServer("Troops", "Abilities", "Activate", {
                    Troop = CurrentCommander, Name = "Call Of Arms", Data = {}
                })
                if response then
                    idx += 1
                    local hotbar = PlayerGui:FindFirstChild("ReactUniversalHotbar")
                    local TimescaleFrame = hotbar and hotbar.Frame:FindFirstChild("timescale")
                    if TimescaleFrame and TimescaleFrame.Visible then
                        if TimescaleFrame:FindFirstChild("Lock") then
                            task.wait(10.3)
                        else
                            task.wait(5.25)
                        end
                    else
                        task.wait(10.3)
                    end
                else
                    task.wait(0.5)
                end
            else
                task.wait(1)
            end
        end
        AutoChainRunning = false
    end)
end

-- // Auto DJ
local function StartAutoDjBooth()
    if AutoDjRunning or not Globals.AutoDJ then return end
    AutoDjRunning = true
    task.spawn(function()
        while Globals.AutoDJ do
            local TowersFolder = workspace:FindFirstChild("Towers")
            local DJ = nil
            if TowersFolder then
                for _, towers in ipairs(TowersFolder:GetDescendants()) do
                    if towers:IsA("Folder") and towers.Name == "TowerReplicator"
                    and towers:GetAttribute("Name") == "DJ Booth"
                    and towers:GetAttribute("OwnerId") == game.Players.LocalPlayer.UserId
                    and (towers:GetAttribute("Upgrade") or 0) >= 3 then
                        DJ = towers.Parent
                    end
                end
            end
            if DJ then
                RemoteFunc:InvokeServer("Troops", "Abilities", "Activate", {
                    Troop = DJ, Name = "Drop The Beat", Data = {}
                })
            end
            task.wait(1)
        end
        AutoDjRunning = false
    end)
end

-- // Auto Necro
local function StartAutoNecro()
    if AutoNecroRunning or not Globals.AutoNecro then return end
    AutoNecroRunning = true
    local lastActivation = 0
    local ownerId = game.Players.LocalPlayer.UserId
    local function getNecros(towersFolder)
        local list = {}
        if not towersFolder then return list end
        for _, rep in ipairs(towersFolder:GetDescendants()) do
            if rep:IsA("Folder") and rep.Name == "TowerReplicator"
            and rep:GetAttribute("Name") == "Necromancer"
            and rep:GetAttribute("OwnerId") == ownerId then
                list[#list + 1] = rep.Parent
            end
        end
        return list
    end
    local function pickMaxGraves(rep, graveStore, up)
        local maxGraves = rep and rep:GetAttribute("Max_Graves")
        if graveStore then
            local gMax = graveStore:GetAttribute("Max_Graves")
            if type(gMax) == "number" and gMax > 0 then maxGraves = gMax end
        end
        if not maxGraves or maxGraves < 2 then
            if up >= 4 then maxGraves = 9
            elseif up >= 2 then maxGraves = 6
            else maxGraves = 3 end
        end
        return maxGraves
    end
    local function countGraves(graveStore)
        if not graveStore then return 0 end
        local cnt = 0
        for k, v in pairs(graveStore:GetAttributes()) do
            if type(k) == "string" and #k > 20 then
                local isDestroy = false
                if type(v) == "table" then
                    for _, elem in pairs(v) do
                        if tostring(elem) == "Destroy" then
                            isDestroy = true
                            break
                        end
                    end
                elseif tostring(v):find("Destroy") then
                    isDestroy = true
                end
                if isDestroy then
                    graveStore:SetAttribute(k, nil)
                else
                    cnt += 1
                end
            end
        end
        return cnt
    end
    local function cleanAllGraves(list)
        for _, necro in ipairs(list) do
            local rep = necro and necro:FindFirstChild("TowerReplicator")
            local store = rep and rep:FindFirstChild("GraveStone")
            if store then countGraves(store) end
        end
    end
    task.spawn(function()
        local idx = 1
        while Globals.AutoNecro do
            local TowersFolder = workspace:FindFirstChild("Towers")
            local necromancer = getNecros(TowersFolder)
            cleanAllGraves(necromancer)
            if #necromancer >= 1 then
                if idx > #necromancer then idx = 1 end
                local CurrentNecromancer = necromancer[idx]
                local replicator = CurrentNecromancer:FindFirstChild("TowerReplicator")
                local up = replicator and (replicator:GetAttribute("Upgrade") or 0) or 0
                local graveStore = replicator and replicator:FindFirstChild("GraveStone")
                local maxGraves = pickMaxGraves(replicator, graveStore, up)
                local graveCount = countGraves(graveStore)
                local debounce = (replicator and replicator:GetAttribute("AbilityDebounce")) or 5
                local now = os.clock()
                if maxGraves and graveCount >= maxGraves and (now - lastActivation >= debounce) then
                    local response = RemoteFunc:InvokeServer("Troops", "Abilities", "Activate", {
                        Troop = CurrentNecromancer, Name = "Raise The Dead", Data = {}
                    })
                    if response then
                        lastActivation = now
                        idx += 1
                        task.wait(1)
                    else
                        task.wait(0.5)
                    end
                else
                    task.wait(0.1)
                end
            else
                task.wait(1)
            end
        end
        AutoNecroRunning = false
    end)
end

-- // Auto Mercenary
local function StartAutoMercenary()
    if not Globals.AutoMercenary and not Globals.AutoMilitary then return end
    if AutoMercenaryBaseRunning then return end
    AutoMercenaryBaseRunning = true
    task.spawn(function()
        while Globals.AutoMercenary do
            local TowersFolder = workspace:FindFirstChild("Towers")
            if TowersFolder then
                for _, towers in ipairs(TowersFolder:GetDescendants()) do
                    if towers:IsA("Folder") and towers.Name == "TowerReplicator"
                    and towers:GetAttribute("Name") == "Mercenary Base"
                    and towers:GetAttribute("OwnerId") == game.Players.LocalPlayer.UserId
                    and (towers:GetAttribute("Upgrade") or 0) >= 5 then
                        RemoteFunc:InvokeServer("Troops", "Abilities", "Activate", {
                            Troop = towers.Parent,
                            Name = "Air-Drop",
                            Data = {
                                pathName = 1,
                                directionCFrame = CFrame.new(),
                                dist = Globals.MercenaryPath or 195
                            }
                        })
                        task.wait(0.5)
                        if not Globals.AutoMercenary then break end
                    end
                end
            end
            task.wait(0.5)
        end
        AutoMercenaryBaseRunning = false
    end)
end

-- // Auto Military
local function StartAutoMilitary()
    if not Globals.AutoMilitary then return end
    if AutoMilitaryBaseRunning then return end
    AutoMilitaryBaseRunning = true
    task.spawn(function()
        while Globals.AutoMilitary do
            local TowersFolder = workspace:FindFirstChild("Towers")
            if TowersFolder then
                for _, towers in ipairs(TowersFolder:GetDescendants()) do
                    if towers:IsA("Folder") and towers.Name == "TowerReplicator"
                    and towers:GetAttribute("Name") == "Military Base"
                    and towers:GetAttribute("OwnerId") == game.Players.LocalPlayer.UserId
                    and (towers:GetAttribute("Upgrade") or 0) >= 4 then
                        RemoteFunc:InvokeServer("Troops", "Abilities", "Activate", {
                            Troop = towers.Parent,
                            Name = "Airstrike",
                            Data = {
                                pathName = 1,
                                pointToEnd = CFrame.new(),
                                dist = Globals.MilitaryPath or 195
                            }
                        })
                        task.wait(0.5)
                        if not Globals.AutoMilitary then break end
                    end
                end
            end
            task.wait(0.5)
        end
        AutoMilitaryBaseRunning = false
    end)
end

-- // Sell Farms
local function StartSellFarm()
    if SellFarmsRunning or not Globals.SellFarms then return end
    SellFarmsRunning = true
    if GameState ~= "GAME" then return false end
    task.spawn(function()
        while Globals.SellFarms do
            local CurrentWave = GetCurrentWave()
            if Globals.SellFarmsWave and CurrentWave < Globals.SellFarmsWave then
                task.wait(1)
                continue
            end
            local TowersFolder = workspace:FindFirstChild("Towers")
            if TowersFolder then
                for _, replicator in ipairs(TowersFolder:GetDescendants()) do
                    if replicator:IsA("Folder") and replicator.Name == "TowerReplicator" then
                        local IsFarm = replicator:GetAttribute("Name") == "Farm"
                        local IsMine = replicator:GetAttribute("OwnerId") == game.Players.LocalPlayer.UserId
                        if IsFarm and IsMine then
                            local TowerModel = replicator.Parent
                            RemoteFunc:InvokeServer("Troops", "Sell", {Troop = TowerModel})
                            task.wait(0.2)
                        end
                    end
                end
            end
            task.wait(1)
        end
        SellFarmsRunning = false
    end)
end

-- // Main Loop
task.spawn(function()
    while true do
        if Globals.AutoPickups and not AutoPickupsRunning then StartAutoPickups() end
        if Globals.AutoSkip and not AutoSkipRunning then StartAutoSkip() end
        if Globals.TimeScaleEnabled and not TimeScaleRunning then StartTimeScale() end
        if Globals.AutoChain and not AutoChainRunning then StartAutoChain() end
        if Globals.AutoDJ and not AutoDjRunning then StartAutoDjBooth() end
        if Globals.AutoNecro and not AutoNecroRunning then StartAutoNecro() end
        if Globals.AutoMercenary and not AutoMercenaryBaseRunning then StartAutoMercenary() end
        if Globals.AutoMilitary and not AutoMilitaryBaseRunning then StartAutoMilitary() end
        if Globals.SellFarms and not SellFarmsRunning then StartSellFarm() end
        if Globals.AntiLag and not AntiLagRunning then StartAntiLag() end
        if (Globals.AutoRejoin or Globals.AutoRestart) and not BackToLobbyRunning then StartBackToLobby() end
        if Globals.AutoGatling and not AutoGatlingRunning then StartAutoGatling() end
        if Globals.Gatlify and not GatlifyRunning then StartGatlify() end
        if Globals.AutoPremium and not AutoPremiumRunning then StartAutoPremium() end
        if Globals.AutoOpenCrates and not AutoOpenRunning then StartAutoOpenCrates() end
        if Globals.AutoReady and not AutoReadyRunning then StartAutoReady() end
        if Globals.MultiMapEnabled and not GitHubDetectorRunning then
            TDS:AutoDetectAndLoad(Globals.PreferredMaps)
        end
                if Globals.Easy and not EasyModeRunning then StartEasyMode() end
        task.wait(1)
    end
end)

if Globals.ClaimRewards and not AutoClaimRewards then
    StartClaimRewards()
end

MissionsUIFix()

return TDS
