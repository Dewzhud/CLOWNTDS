-- // ==================== ADS LOADER V9 (AETHER STYLE) ==================== //

local Config = getgenv().ADS_Config
if not Config then warn("[ADS] Config missing!"); return end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local RemoteFunc = ReplicatedStorage:WaitForChild("RemoteFunction")
local RemoteEvent = ReplicatedStorage:WaitForChild("RemoteEvent")

local function log(msg) print("[ADS] " .. tostring(msg)) end
local isProcessing = false

-- // ==================== TDS CORE (AETHER STYLE) ==================== //

local TDS = {
    PlacedTowers = {},
    ActiveStrat = true,
    MatchmakingMap = {
        ["PizzaParty"]        = "halloween",
        ["Badlands"]          = "badlands",
        ["PollutedWasteland"] = "polluted",
        ["DuckyEasy"]         = "ducky2025",
        ["DuckyHard"]         = "ducky2025",
        ["PizzaPartyEasy"]    = "halloween",
        ["PizzaPartyHard"]    = "halloween",
    }
}
shared.TDSTable = TDS
shared["TDS_Table"] = TDS

function TDS:ResetAllStates()
    table.clear(self.PlacedTowers)
    log("States reset")
end

function TDS:RunStrategy(url)
    local Globals = getgenv()

    if Globals.activeStrategyThread then
        pcall(task.cancel, Globals.activeStrategyThread)
        Globals.activeStrategyThread = nil
        log("Cancelled previous thread")
    end

    self:ResetAllStates()

    Globals.activeStrategyThread = task.spawn(function()
        Globals.tdsReplaying = true
        log("Strat thread started")

        local ok, err = pcall(function()
            local code = game:HttpGet(url)
            if not code or #code < 50 then error("Empty strat") end
            local func = loadstring(code)
            if not func then error("Compile failed") end
            func()
        end)

        if not ok then warn("[ADS] Strat error: " .. tostring(err)) end

        Globals.tdsReplaying = false
        Globals.activeStrategyThread = nil
        log("Strat thread ended")
    end)
end

-- // ==================== HELPERS ==================== //

local function CheckResOk(data)
    if data == true then return true end
    if type(data) == "table" and data.Success == true then return true end
    local ok, isModel = pcall(function() return data and data:IsA("Model") end)
    if ok and isModel then return true end
    if type(data) == "userdata" then return true end
    return false
end

local function SmartTeleportToLobby()
    local lobbyId = 3260590327
    pcall(function()
        TeleportService:Teleport(lobbyId)
    end)
    task.wait(5)
end

local function getCurrentMap()
    local state = ReplicatedStorage:FindFirstChild("State")
    if state then
        local m = state:FindFirstChild("Map")
        if m then
            local ok, v = pcall(function() return m.Value end)
            if ok and v and v ~= "" then return v end
        end
    end
    local mf = workspace:FindFirstChild("Map")
    if mf then return mf.Name end
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("SurfaceGui") and d.Name == "MapDisplay" then
            local t = d:FindFirstChild("Title")
            if t and t.Text ~= "" then return t.Text end
        end
    end
    return nil
end

local function getCurrentMode()
    local state = ReplicatedStorage:FindFirstChild("State")
    if state then
        local d = state:FindFirstChild("Difficulty")
        if d then
            local ok, v = pcall(function() return d.Value end)
            if ok and v then return v end
        end
        local m = state:FindFirstChild("Mode")
        if m then
            local ok, v = pcall(function() return m.Value end)
            if ok and v then return v end
        end
    end
    return nil
end

-- // ==================== MATCHMAKING ==================== //

local function buildPayload(mode)
    if mode == "Hardcore" then
        return {mode = "hardcore", difficulty = "Easy", count = 1}
    elseif mode == "Voidcore" then
        return {mode = "hardcore", difficulty = "Hard", count = 1}
    elseif TDS.MatchmakingMap[mode] then
        local p = {mode = TDS.MatchmakingMap[mode], count = 1}
        if mode:match("Ducky") then p.difficulty = mode:gsub("Ducky", "") end
        return p
    else
        return {difficulty = mode, mode = "survival", count = 1}
    end
end

local function startMatchmaking()
    log("Matchmaking: " .. Config.Mode)
    local payload = buildPayload(Config.Mode)
    local attempts = 0
    repeat
        attempts += 1
        if attempts > 60 then log("Matchmaking timeout"); break end
        local ok, res = pcall(function()
            return RemoteFunc:InvokeServer("Multiplayer", "v2:start", payload)
        end)
        if ok and CheckResOk(res) then log("Matchmaking OK"); break end
        task.wait(0.5)
    until false
end

-- // ==================== SCANNER ==================== //

local SharedDB = {}

local function extractFromCode(code, url)
    if not code or type(code) ~= "string" then return false end
    local mode = code:match('TDS%s*[:%.]%s*Mode%s*%(%s*["\']([^"\']+)["\']%s*%)')
        or code:match('TDS%["Mode"%]%s*%(%s*["\']([^"\']+)["\']%s*%)')
        or code:match('Mode%s*=%s*["\']([^"\']+)["\']')
    local map = code:match('TDS%s*[:%.]%s*GameInfo%s*%(%s*["\']([^"\']+)["\']%s*,')
        or code:match('GameInfo%s*%(%s*["\']([^"\']+)["\']%s*,')
        or code:match('Map%s*=%s*["\']([^"\']+)["\']')
        or code:match('map%s*=%s*["\']([^"\']+)["\']')
    if map and mode then
        map = map:gsub("^%s+", ""):gsub("%s+$", "")
        mode = mode:gsub("^%s+", ""):gsub("%s+$", "")
        if not SharedDB[map] then SharedDB[map] = {} end
        SharedDB[map][mode] = url
        log("Registered: " .. map .. " [" .. mode .. "]")
        return true
    end
    return false
end

local function fetchGitHubContents(repo, path, branch, baseURL)
    local items = {}
    local apiURL = "https://api.github.com/repos/" .. repo .. "/contents/" .. (path or "") .. "?ref=" .. (branch or "main")
    local ok, res = pcall(function() return game:HttpGet(apiURL) end)
    if not ok or not res then return items end
    local data
    ok, data = pcall(function() return HttpService:JSONDecode(res) end)
    if not ok or type(data) ~= "table" then return items end
    for _, item in ipairs(data) do
        if item.type == "file" and item.name:match("%.lua$") then
            local fileURL = baseURL .. (path and (path ~= "" and path .. "/" or "") or "") .. item.name
            fileURL = fileURL:gsub("/+", "/"):gsub(":/", "://")
            table.insert(items, fileURL)
        elseif item.type == "dir" then
            local subPath = (path and path ~= "" and (path .. "/") or "") .. item.name
            local subItems = fetchGitHubContents(repo, subPath, branch, baseURL)
            for _, subURL in ipairs(subItems) do
                table.insert(items, subURL)
            end
        end
    end
    return items
end

local function scanFiles()
    local baseURL = Config.BaseURL or ""
    if baseURL == "" and Config.Repo then
        baseURL = "https://raw.githubusercontent.com/" .. Config.Repo .. "/" .. (Config.Branch or "main") .. "/"
        if Config.Path and Config.Path ~= "" then baseURL = baseURL .. Config.Path .. "/" end
    end
    if baseURL == "" then warn("[ADS] No BaseURL or Repo!"); return false end
    if baseURL:sub(-1) ~= "/" then baseURL = baseURL .. "/" end

    local fileURLs = {}
    if Config.Repo then
        fileURLs = fetchGitHubContents(Config.Repo, Config.Path or "", Config.Branch or "main", baseURL)
    end
    if #fileURLs == 0 then warn("[ADS] No files found!"); return false end

    for _, fileURL in ipairs(fileURLs) do
        local code
        for i = 1, 3 do
            local ok, res = pcall(function() return game:HttpGet(fileURL) end)
            if ok and type(res) == "string" and #res > 50 then code = res; break end
            task.wait(1)
        end
        if code then extractFromCode(code, fileURL) end
    end
    return true
end

-- // ==================== INTERMISSION LOGIC ==================== //

local function findStrat(mapName, modeName)
    if not mapName then return nil end
    local modes = SharedDB[mapName]
    if not modes then
        local low = mapName:lower()
        for k, v in pairs(SharedDB) do
            if k:lower() == low then modes = v; break end
            if mapName:find(k) or k:find(mapName) then modes = v; break end
            if mapName:gsub("%s+", ""):lower() == k:gsub("%s+", ""):lower() then modes = v; break end
        end
    end
    if not modes then return nil end
    modeName = modeName or Config.Mode
    local url = modes[modeName]
    if not url then
        for k, v in pairs(modes) do
            if k:lower() == modeName:lower() then url = v; break end
        end
    end
    if not url then
        local firstMode, firstUrl = next(modes)
        if firstUrl then log("Fallback mode: " .. firstMode); url = firstUrl end
    end
    return url
end

local function waitForButtons(pg, maxTime)
    maxTime = maxTime or 60
    local t = os.clock()
    while os.clock() - t < maxTime do
        local inter = pg:FindFirstChild("ReactGameIntermission")
        if inter then
            local ok, frame = pcall(function() return inter:FindFirstChild("Frame") end)
            if ok and frame then
                local ok2, buttons = pcall(function() return frame:FindFirstChild("buttons") end)
                if ok2 and buttons then return true end
            end
        end
        task.wait(0.5)
    end
    return false
end

local function sendReady()
    pcall(function() RemoteFunc:InvokeServer("Voting", "Skip") end)
end

local function sendVeto()
    pcall(function() RemoteEvent:FireServer("LobbyVoting", "Veto") end)
end

local function handleIntermission(pg)
    if isProcessing then return end
    isProcessing = true

    local function done()
        isProcessing = false
    end

    -- Already in-game
    if pg:FindFirstChild("ReactUniversalHotbar") then
        local url = findStrat(getCurrentMap(), getCurrentMode())
        if url then TDS:RunStrategy(url) else log("No strat") end
        done(); return
    end

    -- Wait for buttons
    log("Waiting for buttons...")
    if not waitForButtons(pg, 60) then
        log("No buttons"); SmartTeleportToLobby(); done(); return
    end

    -- Check #1
    local map1 = getCurrentMap()
    local mode1 = getCurrentMode()
    log("Check #1: " .. tostring(map1) .. " | " .. tostring(mode1))
    local url1 = findStrat(map1, mode1)
    if url1 then
        log("Found! Readying...")
        sendReady()
        repeat task.wait(0.5) until pg:FindFirstChild("ReactUniversalHotbar")
        task.wait(2)
        TDS:RunStrategy(url1)
        done(); return
    end

    -- Veto once
    log("No strat. Vetoing...")
    sendVeto()
    local originalMap = map1

    -- Wait rotation (max 20s)
    local rotated = false
    local newMap = nil
    local startT = os.clock()

    while os.clock() - startT < 20 do
        task.wait(0.5)

        if pg:FindFirstChild("ReactUniversalHotbar") then
            local url = findStrat(getCurrentMap(), getCurrentMode())
            if url then TDS:RunStrategy(url) end
            done(); return
        end

        if pg:FindFirstChild("ReactLobbyHud") then
            startMatchmaking(); done(); return
        end

        local cur = getCurrentMap()
        if cur and cur ~= "" and cur ~= originalMap then
            task.wait(1)
            if getCurrentMap() == cur then
                newMap = cur
                rotated = true
                log("Rotated to: " .. cur)
                break
            end
        end
    end

    if not rotated then
        log("No rotation. Hopping...")
        SmartTeleportToLobby()
        done(); return
    end

    -- Check #2
    local map2 = newMap
    local mode2 = getCurrentMode()
    log("Check #2: " .. tostring(map2) .. " | " .. tostring(mode2))
    local url2 = findStrat(map2, mode2)
    if url2 then
        log("Found after veto! Readying...")
        sendReady()
        repeat task.wait(0.5) until pg:FindFirstChild("ReactUniversalHotbar")
        task.wait(2)
        TDS:RunStrategy(url2)
    else
        log("Still no strat. Hopping...")
        SmartTeleportToLobby()
    end

    done()
end

-- // ==================== MAIN ==================== //

if not game:IsLoaded() then game.Loaded:wait() end

local pg = PlayerGui

if not scanFiles() then warn("[ADS] Scan failed!") end

local mapCount = 0
for _ in pairs(SharedDB) do mapCount += 1 end
log("Database: " .. mapCount .. " maps")

-- Detect state
local inLobby = pg:FindFirstChild("ReactLobbyHud")
local inGame = pg:FindFirstChild("ReactUniversalHotbar")
local inIntermission = pg:FindFirstChild("ReactGameIntermission")

if inLobby then
    startMatchmaking()
    pg.ChildAdded:Connect(function(c)
        if c.Name == "ReactGameIntermission" then task.wait(2); handleIntermission(pg) end
    end)
elseif inGame then
    handleIntermission(pg)
elseif inIntermission then
    task.spawn(function() task.wait(2); handleIntermission(pg) end)
else
    pg.ChildAdded:Connect(function(c)
        if c.Name == "ReactGameIntermission" then task.wait(2); handleIntermission(pg) end
    end)
end

log("Initialized")
