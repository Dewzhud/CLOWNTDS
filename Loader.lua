

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
    for _, g in ipairs(workspace:GetDescendants()) do
        if g:IsA("SurfaceGui") and g.Name == "MapDisplay" then
            local t = g:FindFirstChild("Title")
            if t and t.Text and t.Text ~= "" then
                table.insert(maps, {
                    Name = t.Text,
                    Gui = g,
                    Position = g.Parent and g.Parent.Position or nil
                })
            end
        end
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
        -- Wait for intermission
        local VoteGui = PlayerGui:WaitForChild("ReactGameIntermission", 30)
        if not (VoteGui and VoteGui.Enabled) then
            GitHubDetectorRunning = false
            return
        end

        task.wait(2)

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

-- // Scan available maps during intermission
local function ScanAvailableMaps()
    local maps = {}
    for _, g in ipairs(workspace:GetDescendants()) do
        if g:IsA("SurfaceGui") and g.Name == "MapDisplay" then
            local t = g:FindFirstChild("Title")
            local img = g:FindFirstChildWhichIsA("ImageLabel", true)
            if t and t.Text and t.Text ~= "" then
                table.insert(maps, {
                    Name = t.Text,
                    Gui = g,
                    Position = g.Parent and g.Parent.Position or nil,
                    Image = img and img.Image or nil
                })
            end
        end
    end
    DetectedMapsList = maps
    return maps
end

-- // Get detected map names as list
function TDS:GetDetectedMaps()
    ScanAvailableMaps()
    local list = {}
    for _, m in ipairs(DetectedMapsList) do
        table.insert(list, m.Name)
    end
    return list
end

-- // Check if a strategy exists for a map/mode
local function StrategyExists(name, category)
    category = category or "Maps"
    if not AvailableStrats[category] then return false end

    -- Exact match
    for _, stratName in ipairs(AvailableStrats[category]) do
        if stratName:lower() == name:lower() then
            return stratName -- return exact case
        end
    end

    -- Fuzzy match (remove spaces, special chars)
    local cleanName = name:gsub("[^%w]", ""):lower()
    for _, stratName in ipairs(AvailableStrats[category]) do
        local cleanStrat = stratName:gsub("[^%w]", ""):lower()
        if cleanStrat == cleanName then
            return stratName
        end
    end

    return false
end

-- // Download and cache strategy
local function DownloadStrategy(name, category)
    category = category or "Maps"
    local folder = category == "Maps" and GitHubConfig.MapsFolder or GitHubConfig.ModesFolder
    local path = folder .. "/" .. name .. ".lua"

    -- Check cache first
    if StrategyCache[path] then
        if GitHubConfig.Debug then Logger:Log("[GitHub] Using cached: " .. path) end
        return StrategyCache[path]
    end

    Logger:Log("[GitHub] Downloading strategy: " .. path)
    local code = GitHubFetch(path)

    if code then
        if GitHubConfig.CacheStrategies then
            StrategyCache[path] = code
        end
        return code
    end

    return nil
end

-- // Execute strategy code
local function ExecuteStrategy(code, stratName)
    if not code or code == "" then
        Logger:Log("[GitHub] Empty strategy code for: " .. tostring(stratName))
        return false
    end

    Logger:Log("[GitHub] Executing strategy: " .. tostring(stratName))

    local func, err = loadstring(code)
    if not func then
        Logger:Log("[GitHub] Syntax error in strategy: " .. tostring(err))
        return false
    end

    local success, result = pcall(func)
    if success then
        CurrentLoadedStrategy = stratName
        Logger:Log("[GitHub] Strategy executed successfully!")
        return true
    else
        Logger:Log("[GitHub] Runtime error: " .. tostring(result))
        return false
    end
end

-- // Auto vote for best matching map
function TDS:AutoVoteMap(preferredMaps)
    if GameState ~= "GAME" then return false end

    local available = ScanAvailableMaps()
    if #available == 0 then
        Logger:Log("[GitHub] No maps detected yet, waiting...")
        return false
    end

    Logger:Log("[GitHub] Detected " .. #available .. " maps:")
    for _, m in ipairs(available) do
        Logger:Log("  - " .. m.Name)
    end

    -- Try preferred maps in order
    if preferredMaps and type(preferredMaps) == "table" and #preferredMaps > 0 then
        for _, preferred in ipairs(preferredMaps) do
            for _, map in ipairs(available) do
                if map.Name == preferred then
                    Logger:Log("[GitHub] Voting for preferred map: " .. preferred)
                    CastMapVote(preferred, map.Position or Vector3.new(12.59, 10.64, 52.01))
                    task.wait(1)
                    LobbyReadyUp()
                    return preferred
                end
            end
        end
        Logger:Log("[GitHub] No preferred maps available. Picking best match.")
    end

    -- Try to find map with available strategy
    if next(AvailableStrats.Maps or {}) then
        for _, map in ipairs(available) do
            local stratName = StrategyExists(map.Name, "Maps")
            if stratName then
                Logger:Log("[GitHub] Found strategy for: " .. map.Name)
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
        Logger:Log("[GitHub] Voting for: " .. first.Name)
        CastMapVote(first.Name, first.Position or Vector3.new(12.59, 10.64, 52.01))
        task.wait(1)
        LobbyReadyUp()
        return first.Name
    end

    return false
end

-- // Load and execute strategy for map/mode
function TDS:LoadGitHubStrategy(name, category)
    category = category or "Maps"

    local stratName = StrategyExists(name, category)
    if not stratName then
        Logger:Log("[GitHub] No strategy found for: " .. name .. " (" .. category .. ")")
        return false
    end

    Logger:Log("[GitHub] Loading " .. category .. " strategy: " .. stratName)
    local code = DownloadStrategy(stratName, category)

    if code then
        return ExecuteStrategy(code, stratName)
    else
        Logger:Log("[GitHub] Failed to download strategy: " .. stratName)
        return false
    end
end

-- // Main auto-detect and load flow
function TDS:AutoDetectAndLoad(preferredMaps)
    if GitHubDetectorRunning then return end
    GitHubDetectorRunning = true

    task.spawn(function()
        -- Step 1: Fetch strategy index
        if GitHubConfig.AutoFetch then
            FetchStrategyIndex()
        end

        -- Step 2: Wait for intermission
        local VoteGui = PlayerGui:WaitForChild("ReactGameIntermission", 30)
        if not (VoteGui and VoteGui.Enabled) then
            Logger:Log("[GitHub] Not in intermission, aborting.")
            GitHubDetectorRunning = false
            return
        end

        task.wait(2) -- Let maps populate

        -- Step 3: Detect and vote
        local votedMap = TDS:AutoVoteMap(preferredMaps)

        if votedMap then
            -- Step 4: Wait for game to start
            task.spawn(function()
                local stateReplicators = ReplicatedStorage:WaitForChild("StateReplicators")
                local gameStateReplicator = stateReplicators:WaitForChild("GameStateReplicator")
                repeat task.wait(1) until gameStateReplicator:GetAttribute("GameStarted") == true

                task.wait(3) -- Wait for towers to be placeable

                -- Step 5: Try to load map strategy
                local loaded = TDS:LoadGitHubStrategy(votedMap, "Maps")

                -- Step 6: Fallback to mode strategy
                if not loaded and GitHubConfig.FallbackToMode then
                    local StateFolder = ReplicatedStorage:FindFirstChild("State")
                    local CurrentMode = StateFolder and StateFolder.Difficulty and StateFolder.Difficulty.Value
                    if CurrentMode and CurrentMode ~= "" then
                        Logger:Log("[GitHub] Falling back to mode strategy: " .. CurrentMode)
                        TDS:LoadGitHubStrategy(CurrentMode, "Modes")
                    end
                end
            end)
        end

        GitHubDetectorRunning = false
    end)
end

-- // Manual: Refresh strategy index
function TDS:RefreshStrategies()
    StrategyCache = {} -- Clear cache
    return FetchStrategyIndex()
end

-- // Manual: List available strategies
function TDS:ListStrategies()
    Logger:Log("=== Available Strategies ===")
    Logger:Log("Maps:")
    for _, name in ipairs(AvailableStrats.Maps or {}) do
        Logger:Log("  - " .. name)
    end
    Logger:Log("Modes:")
    for _, name in ipairs(AvailableStrats.Modes or {}) do
        Logger:Log("  - " .. name)
    end
    return AvailableStrats
end

-- // Send detected maps to webhook
function TDS:SendMapDetectionWebhook(webhookUrl)
    if not webhookUrl or webhookUrl == "" then return end
    local maps = ScanAvailableMaps()
    if #maps == 0 then return end

    local mapList = ""
    for i, m in ipairs(maps) do
        local hasStrat = StrategyExists(m.Name, "Maps") and " ✅" or " ❌"
        mapList = mapList .. i .. ". " .. m.Name .. hasStrat .. "\n"
    end

    local stratCount = 0
    for _ in pairs(AvailableStrats.Maps or {}) do stratCount += 1 end

    local data = {
        username = "TDS Map Detector",
        embeds = {{
            title = "🗺️ Available Maps Detected",
            color = 0x3498db,
            description = "**Detected " .. #maps .. " maps:**\n" .. mapList,
            fields = {
                {
                    name = "📚 GitHub Strategies",
                    value = stratCount .. " map strategies available",
                    inline = true
                },
                {
                    name = "🎮 Server",
                    value = "```" .. game.JobId .. "```",
                    inline = true
                }
            },
            footer = { text = "TDS GitHub Auto-Detector" },
            timestamp = DateTime.now():ToIsoDate()
        }}
    }

    pcall(function()
        SendRequest({
            Url = webhookUrl,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode(data)
        })
    end)
end

-- // Default settings merge
local DefaultGitHubSettings = {
    GitHubBaseURL = "",
    GitHubIndexPath = "index.json",
    GitHubMapsFolder = "Maps",
    GitHubModesFolder = "Modes",
    GitHubAutoFetch = true,
    GitHubFallbackToMode = true,
    GitHubCacheStrategies = true,
    GitHubDebug = false,
    -- Legacy compat
    MultiMapEnabled = false,
    PreferredMaps = {},
    AutoLoadStrat = false,
    SendMapWebhook = false,
    MapWebhookURL = ""
}

for k, v in pairs(DefaultGitHubSettings) do
    if Globals[k] == nil then Globals[k] = v end
end

-- Update config from globals
GitHubConfig.BaseURL = Globals.GitHubBaseURL
GitHubConfig.IndexPath = Globals.GitHubIndexPath
GitHubConfig.MapsFolder = Globals.GitHubMapsFolder
GitHubConfig.ModesFolder = Globals.GitHubModesFolder
GitHubConfig.AutoFetch = Globals.GitHubAutoFetch
GitHubConfig.FallbackToMode = Globals.GitHubFallbackToMode
GitHubConfig.CacheStrategies = Globals.GitHubCacheStrategies
GitHubConfig.Debug = Globals.GitHubDebug

-- // TDS Public API
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
