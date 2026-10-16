repeat task.wait() until game:IsLoaded()


local User = getgenv().Config or {}

local FILE = User.File or "Wanda4X/recorder.lua"
local CLICK_OFFSET_X = User.ClickOffsetX or -10
local CLICK_OFFSET_Y = User.ClickOffsetY or 0

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local VIM = game:GetService("VirtualInputManager")
local GuiService = game:GetService("GuiService")


local CATS = { "ModeVote", "TowerAdd", "TowerUpgrade", "TowerSell", "WaveSkip", "PlayAgain", "AutoSkip" }
local TOL = 0.09   -- how close the model pivot must be to the placed position

local function sec(t)
    local m, s = tostring(t):match("(%d+):(%d+)")
    return m and tonumber(m) * 60 + tonumber(s)
end

local function gettime()
    local ok, r = pcall(function()
        return Players.LocalPlayer.PlayerGui.TopbarStandard.Holders.Left.Widget
            .IconButton.Menu.IconSpot.Contents.IconLabelContainer.IconLabel.Text
    end)
    return ok and tostring(r) or nil
end

---------------------------------------------------------------------
-- PARSER (also reads old logs with broken quotes)
---------------------------------------------------------------------
local function nums(s)
    local t = {}
    for n in s:gmatch("[^,{}%s]+") do t[#t + 1] = tonumber(n) end
    return t
end

local function parseLine(line)
    local cat
    for _, c in ipairs(CATS) do
        if line:find(c .. "%s*{") then cat = c break end
    end
    if not cat then return end

    local time = line:match('Time = "(%d+:%d+)')
    if not time then return end

    local d = { Category = cat, Time = time, Sec = sec(time) }

    if cat == "TowerAdd" then
        d.Name   = line:match('Name = "(.-)"')
        d.UnitId = line:match('UnitId = "(.-)"')
        d.Index  = tonumber(line:match("Index = (%d+)"))
        local pos = line:match("Pos = (%b{})")
        local cf  = line:match("CFrame = (%b{})")
        if not (d.Name and d.UnitId and pos and cf) then return end
        d.Pos, d.CFrame = nums(pos), nums(cf)

    elseif cat == "TowerUpgrade" or cat == "TowerSell" then
        d.Id = line:match('Id = "([%w%-]+)') or line:match('Name = "([%w%-]+)')
        local n = tonumber(line:match("Tower = (%d+)"))
        d.Index = (n and n > 0) and n or nil

    elseif cat == "ModeVote" then
        d.Value = line:match('Value = "([^"]-)"') or line:match('{%s*"([%w ]+)')

    elseif cat == "AutoSkip" then
        d.Value = line:match('Value = "(%a+)"') == "true"
    end

    return d
end

---------------------------------------------------------------------
-- READ + PARSE ONCE
---------------------------------------------------------------------
local lines, votes = {}, {}
local placed = 0
local free = {}          -- old logs only: towers without a recorded id yet
local idToIndex = {}     -- old logs only: recorded id -> placement number

for _, line in ipairs(readfile(FILE):split("\n")) do
    local d = parseLine(line)
    if d then
        if d.Category == "ModeVote" then
            table.insert(votes, d)
        else
            if d.Category == "TowerAdd" then
                placed += 1
                d.Index = d.Index or placed
                table.insert(free, d.Index)

            elseif d.Id and not d.Index then
                -- old log (no "Tower = N"): guess from placement order
                if not idToIndex[d.Id] and #free > 0 then
                    idToIndex[d.Id] = table.remove(free)
                end
                d.Index = idToIndex[d.Id]
            end
            table.insert(lines, d)
        end
    end
end

print("Loaded", #lines, "actions,", #votes, "votes,", placed, "towers")

---------------------------------------------------------------------
-- REMOTES
---------------------------------------------------------------------
local cache = {}
local function getRemote(name)
    if cache[name] then return cache[name] end
    for _, v in ipairs(RS:GetDescendants()) do
        if v.Name == name and (v:IsA("RemoteEvent") or v:IsA("RemoteFunction")) then
            cache[name] = v
            return v
        end
    end
    error("Remote not found: " .. name)
end

local function send(name, ...)
    local r = getRemote(name)
    if r:IsA("RemoteFunction") then
        return r:InvokeServer(...)
    end
    r:FireServer(...)
end

---------------------------------------------------------------------
-- FIND THE NEW ID OF A TOWER (match model pivot to the placed CFrame)
---------------------------------------------------------------------
local function isGuid(name)
    return name:match("^%x+%-%x+%-%x+%-%x+%-%x+$") ~= nil
end

local NewIds = {}   -- placement number -> id in THIS match
local Used = {}     -- ids already assigned

local function waitForNewId(cf)
    local t0 = os.clock()
    while os.clock() - t0 < 3 do
        for _, v in ipairs(workspace:GetDescendants()) do
            if v:IsA("Model") and isGuid(v.Name) and not Used[v.Name] then
                local ok, pivot = pcall(function() return v:GetPivot() end)
                if ok and (pivot.Position - cf.Position).Magnitude < TOL then
                    Used[v.Name] = true
                    return v.Name
                end
            end
        end
        task.wait(0.1)
    end
end

-- wait until the tower's new id is known (so upgrades don't skip too early)
local function getId(index)
    local t0 = os.clock()
    while index and not NewIds[index] and os.clock() - t0 < 2 do
        task.wait(0.1)
    end
    return index and NewIds[index]
end

---------------------------------------------------------------------
-- AUTOSKIP UI
---------------------------------------------------------------------
local function getAutoSkip()
    local ok, btn = pcall(function()
        return Players.LocalPlayer.PlayerGui.GameUI.Stats.AutoSkip.Button
    end)
    if ok and btn then return btn, btn:FindFirstChild("UI2") end
end


local function clickGui(btn)
    local center = btn.AbsolutePosition + btn.AbsoluteSize / 2
    local gui = btn:FindFirstAncestorOfClass("ScreenGui")
    local inset = (gui and gui.IgnoreGuiInset) and Vector2.zero or GuiService:GetGuiInset()

    local x = center.X + inset.X + CLICK_OFFSET_X
    local y = center.Y + inset.Y + CLICK_OFFSET_Y

    VIM:SendMouseButtonEvent(x, y, 0, true, game, 0)
    task.wait(0.05)
    VIM:SendMouseButtonEvent(x, y, 0, false, game, 0)
end

---------------------------------------------------------------------
-- ACTIONS
---------------------------------------------------------------------
local actions = {}

actions.TowerAdd = function(d)
    local cf = CFrame.new(table.unpack(d.CFrame))

    send("TowerAdd", {
        Name = d.Name,
        UnitId = d.UnitId,
        Pos = Vector3.new(table.unpack(d.Pos)),
        CFrame = cf,
    })

    local newId = waitForNewId(cf)
    if newId then
        NewIds[d.Index] = newId
        print("  tower", d.Index, "->", newId)
    else
        warn("  could not find the new id for tower", d.Index)
    end
end

actions.TowerUpgrade = function(d)
    local id = getId(d.Index)
    if not id then
        warn("  no id for tower", d.Index, "- upgrade skipped")
        return
    end
    send("TowerUpgrade", { Id = id })
end

actions.TowerSell = function(d)
    local id = getId(d.Index)
    if not id then
        warn("  no id for tower", d.Index, "- sell skipped")
        return
    end
    send("TowerSell", { Id = id })
end

actions.WaveSkip  = function() send("WaveSkip") end
actions.PlayAgain = function() send("PlayAgain") end

actions.AutoSkip = function(d)
    local btn, ui2 = getAutoSkip()
    if not (btn and ui2) then
        warn("  AutoSkip UI not found")
        return
    end

    for _ = 1, 4 do
        if ui2.Visible == d.Value then
            print("  AutoSkip is", d.Value)
            return
        end
        clickGui(btn)       -- state differs: click
        task.wait(0.4)      -- then check again; click again if still wrong
    end
    warn("  AutoSkip still not", d.Value)
end

---------------------------------------------------------------------
-- RUN
---------------------------------------------------------------------
local Running = true
getgenv().StopPlayback = function() Running = false end

-- votes happen in the lobby (00:00), so fire them right away
for _, d in ipairs(votes) do
    local ok, err = pcall(send, "ModeVote", d.Value)
    print(ok and "Played" or "FAILED", "ModeVote", d.Value, ok and "" or err)
end

local i = 1
while Running and i <= #lines do
    local d = lines[i]
    local label = gettime()
    local now = label and sec(label)

    if now and now >= d.Sec then
        local ok, err = pcall(actions[d.Category], d)
        print(ok and "Played" or "FAILED", d.Category, d.Time, ok and "" or err)
        i += 1
        task.wait(.1)   -- small gap between actions at the same second
    else
        task.wait(.1)
    end
end

print("Playback finished")
