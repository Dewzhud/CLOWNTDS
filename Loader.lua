-- // ==================== ADS LOADER V8 (SCAN ALL FILES) ==================== //

local Config = getgenv().ADS_Config
if not Config then warn("[ADS] Config missing!"); return end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()

local function log(msg) print("[ADS] " .. tostring(msg)) end

local isProcessing = false

-- // ==================== WAIT FOR FULL LOAD ====================

local function waitForLoad()
    log("Waiting for game to load...")

    if not game:IsLoaded() then
        game.Loaded:wait()
    end

    local timeout = os.clock()
    while LocalPlayer:GetAttribute("Loading") == true do
        if os.clock() - timeout > 30 then
            log("Load timeout — continuing anyway")
            break
        end
        task.wait(0.5)
    end

    timeout = os.clock()
    while LocalPlayer:GetAttribute("Teleporting") == true do
        if os.clock() - timeout > 30 then
            log("Teleport timeout — continuing anyway")
            break
        end
        task.wait(0.5)
    end

    local pg = LocalPlayer:WaitForChild("PlayerGui", 30)
    if not pg then
        warn("[ADS] PlayerGui not found!")
        return nil
    end

    timeout = os.clock()
    while true do
        if pg:FindFirstChild("ReactLobbyHud") then break end
        if pg:FindFirstChild("ReactUniversalHotbar") then break end
        if os.clock() - timeout > 30 then
            log("UI timeout — continuing anyway")
            break
        end
        task.wait(0.5)
    end

    log("Game fully loaded!")
    return pg
end

-- // ==================== SCANNER ====================

local SharedDB = {}

local function extractFromCode(code, url)
    if not code or type(code) ~= "string" then return false end

    local mode = nil
    local modePatterns = {
        'TDS%s*[:%.]%s*Mode%s*%(%s*["\']([^"\']+)["\']%s*%)',
        'TDS%["Mode"%]%s*%(%s*["\']([^"\']+)["\']%s*%)',
        'TDS%[\'Mode\'%]%s*%(%s*["\']([^"\']+)["\']%s*%)',
        'Mode%s*=%s*["\']([^"\']+)["\']',
    }
    for _, p in ipairs(modePatterns) do
        mode = code:match(p)
        if mode then break end
    end

    local map = nil
    local mapPatterns = {
        'TDS%s*[:%.]%s*GameInfo%s*%(%s*["\']([^"\']+)["\']%s*,',
        'TDS%["GameInfo"%]%s*%(%s*["\']([^"\']+)["\']%s*,',
        'TDS%[\'GameInfo\'%]%s*%(%s*["\']([^"\']+)["\']%s*,',
        'GameInfo%s*%(%s*["\']([^"\']+)["\']%s*,',
    }
    for _, p in ipairs(mapPatterns) do
        map = code:match(p)
        if map then break end
    end

    if not map then
        local altMapPatterns = {
            'Map%s*=%s*["\']([^"\']+)["\']',
            'map%s*=%s*["\']([^"\']+)["\']',
            '["\']?map["\']?%s*:%s*["\']([^"\']+)["\']',
        }
        for _, p in ipairs(altMapPatterns) do
            map = code:match(p)
            if map then break end
        end
    end

    if map and mode then
        map = map:gsub("^%s+", ""):gsub("%s+$", "")
        mode = mode:gsub("^%s+", ""):gsub("%s+$", "")
        if not SharedDB[map] then SharedDB[map] = {} end
        SharedDB[map][mode] = url
        log("Registered: " .. map .. " [" .. mode .. "] -> " .. url:match("([^/]+)$"))
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
        if Config.Path and Config.Path ~= "" then
            baseURL = baseURL .. Config.Path .. "/"
        end
    end

    if baseURL == "" then warn("[ADS] No BaseURL or Repo!"); return false end
    if baseURL:sub(-1) ~= "/" then baseURL = baseURL .. "/" end

    log("Scanning from: " .. baseURL)

    local fileURLs = {}

    if Config.Repo then
        log("Using GitHub API (recursive)...")
        fileURLs = fetchGitHubContents(Config.Repo, Config.Path or "", Config.Branch or "main", baseURL)
        log("Found " .. #fileURLs .. " .lua files")
    end

    if #fileURLs == 0 then
        warn("[ADS] No files found! Check Config.Repo")
        return false
    end

    for _, fileURL in ipairs(fileURLs) do
        local code = nil
        for i = 1, 3 do
            local ok, res = pcall(function() return game:HttpGet(fileURL) end)
            if ok and type(res) == "string" and #res > 50 then
                code = res
                break
            end
            task.wait(1)
        end
        if code then extractFromCode(code, fileURL) end
    end

    return true
end

-- // ==================== GAME LOGIC ====================

local function buildPayload(mode)
    local MatchmakingMap = {
        PizzaParty        = "halloween",
        Badlands          = "badlands",
        PollutedWasteland = "polluted",
        DuckyEasy         = "ducky2025",
        DuckyHard         = "ducky2025",
    }

    if mode == "Hardcore" then
        return {mode = "hardcore", difficulty = "Easy", count = 1}
    elseif mode == "Voidcore" then
        return {mode = "hardcore", difficulty = "Hard", count = 1}
    elseif MatchmakingMap[mode] then
        local p = {mode = MatchmakingMap[mode], count = 1}
        if mode:match("Ducky") then
            p.difficulty = mode:gsub("Ducky", "")
        end
        return p
    else
        return {difficulty = mode, mode = "survival", count = 1}
    end
end

local function hop()
    log("Hopping...")
    pcall(function() TeleportService:Teleport(3260590327) end)
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

local function findInShared(mapName, modeName)
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
        local lowMode = modeName:lower()
        for k, v in pairs(modes) do
            if k:lower() == lowMode then url = v; break end
        end
    end

    if not url then
        local firstMode, firstUrl = next(modes)
        if firstUrl then
            log("Mode '" .. modeName .. "' not found, using: " .. firstMode)
            url = firstUrl
        end
    end

    return url
end

local function runStrat(url)
    if not url then return end
    log("Executing: " .. url)
    for i = 1, 10 do
        local ok, err = pcall(function()
            loadstring(game:HttpGet(url))()
        end)
        if ok then
            log("Strat running!")
            return true
        else
            log("Attempt " .. i .. "/10 failed: " .. tostring(err))
            task.wait(1)
        end
    end
    log("Failed after 10 attempts")
    return false
end

local function sendReady()
    log("Sending Ready...")
    local ok = pcall(function()
        ReplicatedStorage:WaitForChild("RemoteFunction", 10):InvokeServer("Voting", "Skip")
    end)
    if ok then log("Ready sent") else log("Ready failed") end
    return ok
end

local function sendVeto()
    log("Sending Veto...")
    local ok = pcall(function()
        ReplicatedStorage:WaitForChild("RemoteEvent", 10):FireServer("LobbyVoting", "Veto")
    end)
    if ok then log("Veto sent") else log("Veto failed") end
    return ok
end

local function startMatchmaking()
    log("Matchmaking mode: " .. Config.Mode)
    local payload = buildPayload(Config.Mode)
    log("Payload: " .. HttpService:JSONEncode(payload))

    local RemoteFunc = ReplicatedStorage:WaitForChild("RemoteFunction", 15)
    if not RemoteFunc then warn("[ADS] RemoteFunction not found!"); return end

    local attempts = 0
    repeat
        attempts = attempts + 1
        if attempts > 60 then
            warn("[ADS] Matchmaking failed after 60 attempts")
            break
        end
        local success, res = pcall(function()
            return RemoteFunc:InvokeServer("Multiplayer", "v2:start", payload)
        end)
        if success and (
            res == true or
            (type(res) == "table" and res.Success == true) or
            (type(res) == "userdata")
        ) then
            log("Matchmaking OK")
            break
        end
        task.wait(0.5)
    until false
end

-- // ==================== BUTTONS HELPER ====================

local function waitForIntermissionButtons(pg, maxWait)
    maxWait = maxWait or 60
    local t = os.clock()
    while os.clock() - t < maxWait do
        local inter = pg:FindFirstChild("ReactGameIntermission")
        if inter then
            local ok, frame = pcall(function() return inter:FindFirstChild("Frame") end)
            if ok and frame then
                local ok2, buttons = pcall(function() return frame:FindFirstChild("buttons") end)
                if ok2 and buttons then
                    return true
                end
            end
        end
        task.wait(0.5)
    end
    return false
end

-- // ==================== VALIDATOR (CLEAN LOOP) ====================

local function validateAndRun(pg)
    if isProcessing then
        log("Already processing, ignored")
        return
    end
    isProcessing = true

    local success, err = pcall(function()
        -- Already in game
        if pg:FindFirstChild("ReactUniversalHotbar") then
            local mapName = getCurrentMap()
            local modeName = getCurrentMode()
            log("In-game: map=" .. tostring(mapName) .. " mode=" .. tostring(modeName))
            local url = findInShared(mapName, modeName)
            if url then runStrat(url) else log("No strat for this map/mode") end
            return
        end

        -- Wait for buttons before anything
        log("Waiting for intermission buttons...")
        if not waitForIntermissionButtons(pg, 60) then
            log("Buttons timeout. Hopping...")
            hop()
            return
        end
        log("Buttons loaded!")

        -- Loop: check -> veto -> recheck -> hop (max 2 checks)
        local originalMap = nil
        for checkCount = 1, 2 do
            local mapName = getCurrentMap()
            local modeName = getCurrentMode()
            log("Check #" .. checkCount .. " -> map=" .. tostring(mapName) .. " mode=" .. tostring(modeName))

            local url = findInShared(mapName, modeName)
            if url then
                -- FOUND: ready -> wait game -> run -> DONE
                log("Strat found! Readying...")
                sendReady()
                log("Waiting for game start...")
                repeat task.wait(0.5) until pg:FindFirstChild("ReactUniversalHotbar")
                task.wait(2)
                runStrat(url)
                log("Done.")
                return
            end

            -- No strat
            if checkCount == 1 then
                -- First fail: veto and wait for rotation
                log("No strat. Vetoing...")
                sendVeto()
                originalMap = mapName

                local vetoStart = os.clock()
                local rotated = false

                while os.clock() - vetoStart < 20 do
                    task.wait(0.5)

                    -- Sudden game start
                    if pg:FindFirstChild("ReactUniversalHotbar") then
                        log("Game started during wait")
                        local m = getCurrentMap()
                        local md = getCurrentMode()
                        local u = findInShared(m, md)
                        if u then runStrat(u) else log("No strat for this game") end
                        return
                    end

                    -- Kicked to lobby
                    if pg:FindFirstChild("ReactLobbyHud") then
                        log("Back to lobby. Restarting matchmaking...")
                        startMatchmaking()
                        return
                    end

                    local currentMap = getCurrentMap()
                    -- Must be valid (not nil/empty) and different
                    if currentMap and currentMap ~= "" and currentMap ~= originalMap then
                        -- Double-check stability
                        task.wait(1)
                        if getCurrentMap() == currentMap then
                            log("Map rotated to: " .. currentMap)
                            rotated = true
                            break
                        end
                    end
                end

                if not rotated then
                    log("Map didn't rotate. Hopping...")
                    hop()
                    return
                end
                -- Continue to check #2
            else
                -- Second check (after veto) also failed
                log("Still no strat after veto. Hopping...")
                hop()
                return
            end
        end
    end)

    if not success then
        warn("[ADS] validateAndRun error: " .. tostring(err))
    end

    isProcessing = false
end

-- // ==================== MAIN ====================

local pg = waitForLoad()
if not pg then warn("[ADS] Failed to get PlayerGui"); return end

if not scanFiles() then warn("[ADS] Scan failed!"); return end

local mapCount, modeCount = 0, 0
for map, modes in pairs(SharedDB) do
    mapCount = mapCount + 1
    for _ in pairs(modes) do modeCount = modeCount + 1 end
end
log("Database: " .. mapCount .. " maps, " .. modeCount .. " modes")

if mapCount == 0 then
    log("No strategies found — will still matchmake but won't run any strat")
end

-- Detect state
local GameState = "UNKNOWN"
if pg:FindFirstChild("ReactLobbyHud") then
    GameState = "LOBBY"
elseif pg:FindFirstChild("ReactUniversalHotbar") then
    GameState = "GAME"
end

log("GameState: " .. GameState)

if GameState == "LOBBY" then
    startMatchmaking()

    -- If already in intermission, process now
    if pg:FindFirstChild("ReactGameIntermission") then
        task.spawn(function()
            task.wait(2)
            validateAndRun(pg)
        end)
    end

    -- Listen for future intermissions
    pg.ChildAdded:Connect(function(child)
        if child.Name == "ReactGameIntermission" then
            task.wait(2)
            validateAndRun(pg)
        end
    end)

elseif GameState == "GAME" then
    validateAndRun(pg)

else
    log("Unknown state — waiting for UI...")
    pg.ChildAdded:Connect(function(child)
        if child.Name == "ReactGameIntermission" or child.Name == "ReactUniversalHotbar" then
            task.wait(2)
            validateAndRun(pg)
        end
    end)
end

log("Initialized")
