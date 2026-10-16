local User = getgenv().Config or {}

local FOLDER = "Wanda4X"
local FILE = FOLDER .. "/" .. (User.FileName or "recorder.lua")
local TOL = 0.09   -- how close the model pivot must be to the placed position

if not isfolder(FOLDER) then
    makefolder(FOLDER)
end
writefile(FILE, "")

local function append(line)
    appendfile(FILE, line .. "\n")
    print(line)
end

local gen = {}
local TowerCount = 0
local IdToIndex = {}   -- game's id (model name) -> tower number

local function gettime()
    local ok, r = pcall(function()
        return game.Players.LocalPlayer.PlayerGui.TopbarStandard.Holders.Left.Widget
            .IconButton.Menu.IconSpot.Contents.IconLabelContainer.IconLabel.Text
    end)
    return ok and tostring(r) or "00:00"
end

-- find the model at the placed position and remember its name -> index (NO rename)
local function trackNewTower(cf, index)
    local done = false
    local conn

    local function check(v)
        if done or not v:IsA("Model") then return end

        local ok, pivot = pcall(function() return v:GetPivot() end)
        if not ok then return end

        if (pivot.Position - cf.Position).Magnitude < TOL then
            -- skip models already claimed by another tower
            if IdToIndex[v.Name] then return end

            done = true
            if conn then conn:Disconnect() end
            IdToIndex[v.Name] = index
            print("Tower", index, "=", v.Name)
        end
    end

    -- model may appear after the remote fires
    conn = workspace.DescendantAdded:Connect(function(v)
        task.defer(check, v)
    end)

    -- or it may already exist: scan once shortly after
    task.delay(0.3, function()
        if done then return end
        for _, v in ipairs(workspace:GetDescendants()) do
            check(v)
        end
    end)

    -- give up
    task.delay(4, function()
        if not done then
            done = true
            if conn then conn:Disconnect() end
            warn("No model matched tower", index)
        end
    end)
end

gen["TowerAdd"] = function(Args, Time)
    local data = Args[1]
    if type(data) ~= "table" then return end

    TowerCount += 1
    local index = TowerCount

    local cf = data.CFrame or (data.Pos and CFrame.new(data.Pos))
    if cf then trackNewTower(cf, index) end

    append(`TowerAdd \{ Index = {index}, Name = "{data.Name}", UnitId = "{data.UnitId}", Pos = \{{data.Pos}}, CFrame = \{{data.CFrame}}, Time = "{Time}"}`)
end

gen["TowerUpgrade"] = function(Args, Time)
    local data = Args[1]
    if type(data) ~= "table" then return end

    local tower = IdToIndex[data.Id] or 0
    append(`TowerUpgrade \{ Tower = {tower}, Id = "{data.Id}", Time = "{Time}"}`)
end

gen["TowerSell"] = function(Args, Time)
    local data = Args[1]
    if type(data) ~= "table" then return end

    local tower = IdToIndex[data.Id] or 0
    append(`TowerSell \{ Tower = {tower}, Id = "{data.Id}", Time = "{Time}"}`)
end

gen["TowerTarget"] = function(Args, Time)
    local data = Args[1]
    if type(data) ~= "table" then return end

    local tower = IdToIndex[data.Id] or 0
    append(`TowerTarget \{ Tower = {tower}, Id = "{data.Id}", Time = "{Time}"}`)
end

gen["WaveSkip"] = function(Args, Time)
    append(`WaveSkip \{ Time = "{Time}"}`)
end

gen["PlayAgain"] = function(Args, Time)
    append(`PlayAgain \{ Time = "{Time}"}`)
end

gen["ModeVote"] = function(Args, Time)
    append(`ModeVote \{ Value = "{Args[1]}", Time = "{Time}"}`)
end

-- AutoSkip: log UI2.Visible whenever it changes
task.spawn(function()
    local ok, ui2 = pcall(function()
        return game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
            :WaitForChild("GameUI"):WaitForChild("Stats")
            :WaitForChild("AutoSkip"):WaitForChild("Button"):WaitForChild("UI2")
    end)
    if not ok or not ui2 then
        return warn("AutoSkip UI2 not found")
    end

    local last = nil
    local function log()
        local v = ui2.Visible
        if v == last then return end
        last = v
        append(`AutoSkip \{ Value = "{tostring(v)}", Time = "{gettime()}"}`)
    end

    log()   -- record the starting state
    ui2:GetPropertyChangedSignal("Visible"):Connect(log)
end)

local OldNamecall
OldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    if getnamecallmethod() == "FireServer"
        and typeof(self) == "Instance"
        and self.ClassName == "RemoteEvent"
        and not checkcaller()
    then
        local handler = gen[self.Name]
        if handler then
            local args = table.pack(...)
            local time = gettime()
            task.spawn(pcall, handler, args, time)
        end
    end

    return OldNamecall(self, ...)
end))

print("WandaSploit recorder loaded")
