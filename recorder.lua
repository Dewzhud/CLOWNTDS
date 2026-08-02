local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteFunction = if not GameSpoof then ReplicatedStorage:WaitForChild("RemoteFunction") else SpoofEvent
local RemoteEvent = if not GameSpoof then ReplicatedStorage:WaitForChild("RemoteEvent") else SpoofEvent
local RSTimer = ReplicatedStorage:WaitForChild("State"):WaitForChild("Timer"):WaitForChild("Time") -- Current game's timer
local RSMode = ReplicatedStorage:WaitForChild("State"):WaitForChild("Mode") -- Survival or Hardcore check
local RSDifficulty = ReplicatedStorage:WaitForChild("State"):WaitForChild("Difficulty") -- Survival's gamemodes
local RSMap = ReplicatedStorage:WaitForChild("State"):WaitForChild("Map") --map's Name
local GameWave = LocalPlayer.PlayerGui:WaitForChild("ReactGameTopGameDisplay"):WaitForChild("Frame"):WaitForChild("wave"):WaitForChild("container"):WaitForChild("value") -- currennt wave you are on

getgenv().WriteFile = function(check,name,location,str)
    if not check then
        return
    end
    if type(name) == "string" then
        if not type(location) == "string" then
            location = ""
        end
        if not isfolder(location) then
            makefolder(location)
        end
        if type(str) ~= "string" then
            error("Argument 4 must be a string got " .. tostring(number))
        end
        writefile(location.."/"..name..".txt",str)
    else
        error("Argument 2 must be a string got " .. tostring(number))
    end
end
getgenv().AppendFile = function(check,name,location,str)
    if not check then
        return
    end
    if type(name) == "string" then
        if not type(location) == "string" then
            location = ""
        end
        if not isfolder(location) then
            WriteFile(check,name,location,str)
        end
        if type(str) ~= "string" then
            error("Argument 4 must be a string got " .. tostring(number))
        end
        if isfile(location.."/"..name..".txt") then
            appendfile(location.."/"..name..".txt",str)
        else
            WriteFile(check,name,location,str)
        end
    else
        error("Argument 2 must be a string got " .. tostring(number))
    end
end
local writestrat = function(...)
    local TableText = {...}
    task.spawn(function()
        if not game:GetService("Players").LocalPlayer then
            repeat task.wait() until game:GetService("Players").LocalPlayer
        end
        for i,v in next, TableText do
            if type(v) ~= "string" then
                TableText[i] = tostring(v)
            end
        end
        local Text = table.concat(TableText, " ")
        print(Text)
        return WriteFile(true,LocalPlayer.Name.."'s strat","StrategiesX/TDS/Recorder",tostring(Text).."\n")
    end)
end
local appendstrat = function(...)
    local TableText = {...}
    task.spawn(function()
        if not game:GetService("Players").LocalPlayer then
            repeat task.wait() until game:GetService("Players").LocalPlayer
        end
        for i,v in next, TableText do
            if type(v) ~= "string" then
                TableText[i] = tostring(v)
            end
        end
        local Text = table.concat(TableText, " ")
        print(Text)
        return AppendFile(true,LocalPlayer.Name.."'s strat","StrategiesX/TDS/Recorder",tostring(Text).."\n")
    end)
end
getgenv().Recorder = {
    Troops = {},
    TowersList = {},
}
getgenv().TowersList = Recorder.TowersList
local TowerCount = 0
local GetMode = nil

local UILibrary = getgenv().UILibrary or loadstring(game:HttpGet("https://raw.githubusercontent.com/Sigmanic/ROBLOX/main/ModificationWallyUi", true))()
UILibrary.options.toggledisplay = 'Fill'

local mainwindow = UILibrary:CreateWindow('Recorder')
UILibrary.container.Parent.Parent = LocalPlayer.PlayerGui
Recorder.Status = mainwindow:Section("Loading")

local timeSection = mainwindow:Section("Time Passed: ")
task.spawn(function()
    function TimeConverter(v)
        if v <= 9 then
            local conv = "0" .. v
            return conv
        else
            return v
        end
    end
    local startTime = os.time()

    while task.wait(0.1) do
        local t = os.time() - startTime
        local seconds = t % 60
        local minutes = math.floor(t / 60) % 60
        timeSection.Text = "Time Passed: " .. TimeConverter(minutes) .. ":" .. TimeConverter(seconds)
    end
end)

mainwindow:Toggle('Auto Skip', {flag = "autoskip"})
mainwindow:Section("\\/ LAST WAVE \\/")
mainwindow:Toggle('Auto Sell Farms', {default = true, flag = "autosellfarms"})

function SetStatus(string)
    Recorder.Status.Text = string
end

function ConvertTimer(number : number)
   return math.floor(number/60), number % 60
end

local TimerCheck = false
function CheckTimer(bool)
    return (bool and TimerCheck) or true
end
RSTimer.Changed:Connect(function(time)
    if time == 5 then
        TimerCheck = true
    elseif time and time > 5 then
        TimerCheck = false
    end
end)

function GetTimer()
    local currentWave = 0
    local currentTime = 0
    
    -- Safely get wave number and extract only the first digit
    if GameWave and GameWave.Text then
        -- Extract only the first number from "1 / 45" format
        local waveText = GameWave.Text:match("^(%d+)")
        currentWave = tonumber(waveText) or 0
    else
        print("WARNING: GameWave not found or no Text property")
    end
    
    -- Safely get timer value
    if RSTimer and RSTimer.Value then
        currentTime = RSTimer.Value or 0
    else
        print("WARNING: RSTimer not found or no Value property")
    end
    
    print(string.format("DEBUG GetTimer - Wave: %d, Time: %.1f", currentWave, currentTime))
    
    return {
        currentWave,
        currentTime
    }
end

local GenerateFunction = {
  Place = function(Args, Timer, RemoteCheck)
    if typeof(RemoteCheck) ~= "Instance" then
        return
    end

    local Placement = Args[3]
    local TowerName = Args[4]

    if typeof(Placement) ~= "table" then
        return
    end

    local Position = Placement.Position
    local Rotation = Placement.Rotation

    if typeof(Position) ~= "Vector3" or typeof(Rotation) ~= "CFrame" then
        return
    end

    local rx, ry, rz = Rotation:ToEulerAnglesYXZ()

    TowerCount += 1
    RemoteCheck.Name = tostring(TowerCount)

    TowersList[TowerCount] = {
        TowerName = TowerName,
        Instance = RemoteCheck,
        Position = Position,
        Rotation = Rotation,
    }

    SetStatus(("Placed %s"):format(TowerName))
    
    local wave = Timer[1]
    local time = Timer[2]
    
    appendstrat(string.format(
        'TDS:Place("%s", %.6f, %.6f, %.6f, %d, %.1f, %.6f, %.6f, %.6f)',
        TowerName,
        Position.X,
        Position.Y,
        Position.Z,
        wave,
        time,
        rx,
        ry,
        rz
    ))
end,
    Upgrade = function(Args, Timer, RemoteCheck)
        local TowerIndex = Args[4].Troop.Name;
        local PathTarget = Args[4].Path
        if RemoteCheck ~= true then
            SetStatus(`Upgraded Failed ID: {TowerIndex}`)
            print(`Upgraded Failed ID: {TowerIndex}`, RemoteCheck)
            return
        end
        SetStatus(`Upgraded ID: {TowerIndex}`)
        local wave = Timer[1]
        local time = Timer[2]
        appendstrat(string.format("TDS:Upgrade(%s, %d, %.1f, %s)", TowerIndex, wave, time, PathTarget))
    end,
    Sell = function(Args, Timer, RemoteCheck)
        local TowerIndex = Args[3].Troop.Name;
        if not RemoteCheck or TowersList[tonumber(TowerIndex)].Instance:FindFirstChild("HumanoidRootPart") then
            SetStatus(`Sell Failed ID: {TowerIndex}`)
            print(`Sell Failed ID: {TowerIndex}`, RemoteCheck)
            return
        end
        SetStatus(`Sold TowerIndex {TowerIndex}`)
        local wave = Timer[1]
        local time = Timer[2]
        appendstrat(string.format("TDS:Sell(%s, %d, %.1f)", TowerIndex, wave, time))
    end,
    Target = function(Args, Timer, RemoteCheck)
        local TowerIndex = Args[4].Troop.Name
        local Target = Args[4].Target
        if RemoteCheck ~= true then
            SetStatus(`Target Failed ID: {TowerIndex}`)
            print(`Target Failed ID: {TowerIndex}`, RemoteCheck)
        end
        SetStatus(`Changed Target ID: {TowerIndex}`)
        local wave = Timer[1]
        local time = Timer[2]
        appendstrat(string.format("TDS:Target(%s, \"%s\", %d, %.1f)", TowerIndex, Target, wave, time))
    end,
    Abilities = function(Args, Timer, RemoteCheck)
        local TowerIndex = Args[4].Troop.Name
        local AbilityName = Args[4].Name
        local Data = Args[4].Data
        if RemoteCheck ~= true then
            SetStatus(`Ability Failed ID: {TowerIndex}`)
            print(`Ability Failed ID: {TowerIndex}`, RemoteCheck)
            return
        end
        local function formatData(Data)
            local formattedData = {}
            for key, value in pairs(Data) do
                if key == "directionCFrame" then
                    table.insert(formattedData, string.format('["%s"] = CFrame.new(%s)', key, tostring(value)))
                elseif key == "position" then
                    table.insert(formattedData, string.format('["%s"] = Vector3.new(%s)', key, tostring(value)))
                else
                    table.insert(formattedData, string.format('["%s"] = %s', key, tostring(value)))
                end
            end
            return "{" .. table.concat(formattedData, ", ") .. "}"
        end
        local formattedData = formatData(Data)
        SetStatus(`Used Ability On TowerIndex {TowerIndex}`)
        local wave = Timer[1]
        local time = Timer[2]
        appendstrat(string.format("TDS:Ability(%s, \"%s\", %d, %.1f, %s)", TowerIndex, AbilityName, wave, time, formattedData))
    end,
    Option = function(Args, Timer, RemoteCheck)
        local TowerIndex = Args[4].Troop.Name;
        local OptionName = Args[4].Name
        local Value = Args[4].Value
        if RemoteCheck ~= true then
            SetStatus(`Option Failed ID; {TowerIndex}`)
            print(`Option Failed ID: {TowerIndex}`, RemoteCheck)
            return
        end
        SetStatus(`Used Option On TowerIndex {TowerIndex}`)
        local wave = Timer[1]
        local time = Timer[2]
        appendstrat(string.format("TDS:Option(%s, \"%s\", \"%s\", %d, %.1f)", TowerIndex, OptionName, Value, wave, time))
    end,
    Skip = function(Args, Timer)
        SetStatus(`Skipped Wave`)
        if not Timer or not Timer[1] or not Timer[2] then
            print("ERROR: Timer is nil or incomplete", Timer)
            return
        end
        local wave = Timer[1] or 0
        local time = Timer[2] or 0
        appendstrat(string.format("TDS:Skip(%d, %.1f)", wave, time))
    end,
    Vote = function(Args, Timer, RemoteCheck)
        local Difficulty = Args[3]
        local DiffTable = {
            ["Easy"] = "Easy",
            ["Casual"] = "Casual",
            ["Intermediate"] = "Intermediate",
            ["Molten"] = "Molten",
            ["Fallen"] = "Fallen"
        }
        GetMode = DiffTable[Difficulty] or Difficulty
        SetStatus(`Vote {GetMode}`)
    end,
}

local Skipped = false


task.spawn(function()
    GameWave:GetPropertyChangedSignal("Text"):Wait()
    local FinalWaveAtDifferentMode = {
        ["Easy"] = 25,
        ["Casual"] = 30,
        ["Intermediate"] = 30,
        ["Molten"] = 35,
        ["Fallen"] = 40,
        ["Hardcore"] = 50
    }
    local FinalWave = FinalWaveAtDifferentMode[RSDifficulty.Value]
    GameWave:GetPropertyChangedSignal("Text"):Connect(function()
        if tonumber(GameWave.Text) == FinalWave then
            repeat task.wait() until mainwindow.flags.autosellfarms
            for i,v in ipairs(game.Workspace.Towers:GetChildren()) do
                if v.Owner.Value == LocalPlayer.UserId and v:WaitForChild("TowerReplicator"):GetAttribute("Type") == "Farm" then
                    ReplicatedStorage.RemoteFunction:InvokeServer("Troops", "Sell", {["Troop"] = v})
                end
            end
            SetStatus(`Sold All Farms`)
        end
    end)
end)

-- Separate arrays for troops
local EquippedTroops = {}
local GoldenTroops = {}

local InventoryData = ReplicatedStorage.RemoteFunction:InvokeServer("Session", "Search", "Inventory.Troops")
if InventoryData then
    for TowerName, Tower in next, InventoryData do
        if Tower and Tower.Equipped then
            table.insert(EquippedTroops, TowerName)
            if Tower.GoldenPerks then
                table.insert(GoldenTroops, TowerName)
            end
        end
    end
end

-- Update Recorder for compatibility
Recorder.Troops = EquippedTroops
Recorder.Golden = GoldenTroops

writestrat("getgenv().StratCreditsAuthor = \"Optional\"")

-- Build loadout string safely
local troops_list = ""
local golden_section = "\"})"

if #EquippedTroops > 0 then
    troops_list = table.concat(EquippedTroops, "\", \"")
    if #GoldenTroops > 0 then
        local golden_troops = table.concat(GoldenTroops, "\", \"")
        golden_section = string.format("\", [\"Golden\"] = {\"%s\"})", golden_troops)
    end
else
    troops_list = ""
end

local loadout_string = string.format(
    "local TDS = loadstring(game:HttpGet(\"https://raw.githubusercontent.com/Sigmanic/Strategies-X/main/TDS/MainSource.lua\", true))()\nTDS:Map(\"%s\", true, \"%s\")\nTDS:Loadout({\"%s%s",
    RSMap.Value,
    RSMode.Value,
    troops_list,
    golden_section
)

appendstrat(loadout_string)

task.spawn(function()
    local DiffTable = {
        ["Easy"] = "Easy",
        ["Casual"] = "Casual",
        ["Intermediate"] = "Intermediate",
        ["Molten"] = "Molten",
        ["Fallen"] = "Fallen"
    }
    repeat task.wait() until GetMode ~= nil or RSDifficulty.Value ~= ""
    if GetMode then
        repeat task.wait() until GetMode == RSDifficulty.Value
        appendstrat(`TDS:Mode("{GetMode}")`)
    elseif DiffTable[RSDifficulty.Value] then
        appendstrat(`TDS:Mode("{DiffTable[RSDifficulty.Value]}")`)
    end
end)

local OldNamecall
OldNamecall = hookmetamethod(game, '__namecall', function(...)
    local Self, Args = (...), ({select(2, ...)})
    if getnamecallmethod() == "InvokeServer" and Self.name == "RemoteFunction" then
        local thread = coroutine.running()
        coroutine.wrap(function(Args)
            local Timer = GetTimer()
            local RemoteFired = Self.InvokeServer(Self, unpack(Args))
            if GenerateFunction[Args[2]] then
                GenerateFunction[Args[2]](Args, Timer, RemoteFired)
            end
            coroutine.resume(thread, RemoteFired)
        end)(Args)
        return coroutine.yield()
    end
    return OldNamecall(...,unpack(Args))
end)
