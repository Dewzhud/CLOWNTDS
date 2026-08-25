--========================================================--
-- WANDA DQR
-- Fixed nil / dropdown / character / folder handling
-- + Workspace danger model check & dodge
--========================================================--

-- Load required scripts
pcall(function()
    loadstring(game:HttpGet(
        "https://raw.githubusercontent.com/Dewzhud/CLOWNTDS/refs/heads/main/asf"
    ))()
end)

local Rayfield = loadstring(game:HttpGet(
    "https://sirius.menu/gen2"
))()

--========================================================--
-- WINDOW
--========================================================--

local window = Rayfield:CreateWindow({
    name = "WANDA",
    subtitle = "DQR",

    configuration = {
        autoSave = true,
        autoLoad = true,
        fileName = "WD_DQR",
        customFolder = "WD",
    },
})

local tab = window:CreateTab({
    name = "Room",
    icon = 93364949241311
})

local tab2 = window:CreateTab({
    name = "Dungeon",
    icon = 93364949241311
})

local tab3 = window:CreateTab({
    name = "Enemies",
    icon = 93364949241311
})

--========================================================--
-- SERVICES
--========================================================--

local Players             = game:GetService("Players")
local RunService          = game:GetService("RunService")
local UserInputService    = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer

--========================================================--
-- SHARED STATE
--========================================================--

local StageName    = "Desert Temple"
local Difficult    = "Easy"
local SkillCooldown = 4
local high         = 7

_G.IsHc         = false
_G.AutoRoom     = false
_G.AutoRejoin   = false
_G.Farm         = false
_G.FarmEnemies  = false
_G.AutoSkill    = false

--========================================================--
-- SAFE CHARACTER
--========================================================--

local _afChar      = LocalPlayer.Character
local _afResetting = false
local _afLastCheck = 0

LocalPlayer.CharacterAdded:Connect(function(character)
    _afChar      = character
    _afResetting = false
end)

--========================================================--
-- ANTI FLING
--========================================================--

local AntiFling = {
    MaxAngularVelocity       = 2.5,
    MaxLinearVelocity        = 80,
    AirborneVelocityThreshold = 60,
    CheckInterval            = 0.05,
}

local function _afClampVec(v, maxMag)
    if not v then return Vector3.zero end
    if v.Magnitude > maxMag then return v.Unit * maxMag end
    return v
end

local function _afTick(dt)
    _afLastCheck += dt
    if _afLastCheck < AntiFling.CheckInterval then return end
    _afLastCheck = 0

    local char = _afChar
    if not char or not char.Parent then return end

    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end
    if hum.Health <= 0 then return end

    local av = hrp.AssemblyAngularVelocity
    if av and av.Magnitude > AntiFling.MaxAngularVelocity then
        hrp.AssemblyAngularVelocity = _afClampVec(av, AntiFling.MaxAngularVelocity)
    end

    local lv = hrp.AssemblyLinearVelocity
    if lv then
        local flat = Vector3.new(lv.X, 0, lv.Z)
        if flat.Magnitude > AntiFling.MaxLinearVelocity then
            local cf = _afClampVec(flat, AntiFling.MaxLinearVelocity)
            hrp.AssemblyLinearVelocity = Vector3.new(cf.X, lv.Y, cf.Z)
        end

        local grounded = hum.FloorMaterial ~= Enum.Material.Air
        if not grounded
            and lv.Magnitude > AntiFling.AirborneVelocityThreshold
            and not _afResetting
        then
            _afResetting = true
            hrp.AssemblyLinearVelocity   = Vector3.new(0, math.min(lv.Y, 20), 0)
            hrp.AssemblyAngularVelocity  = Vector3.zero
            task.delay(0.2, function() _afResetting = false end)
        end
    end
end

RunService.Heartbeat:Connect(function(dt)
    pcall(function() _afTick(dt) end)
end)

--========================================================--
-- KEY PRESS
--========================================================--

local function PressKey(keyCode, holdTime)
    holdTime = holdTime or 0.08
    pcall(function()
        VirtualInputManager:SendKeyEvent(true,  keyCode, false, game)
        task.wait(holdTime)
        VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
    end)
end

--========================================================--
-- REMOTE HELPERS
--========================================================--

local function GetRemotes()
    local remotes = ReplicatedStorage:FindFirstChild("remotes")
    if not remotes then return nil end
    return remotes
end

local function GetSwingEvent()
    local char = LocalPlayer.Character
    if not char then return nil end
    for _, v in ipairs(char:GetDescendants()) do
        if v:IsA("RemoteEvent") and v.Name == "swing" then
            return v
        end
    end
    return nil
end

local function GetSkillEvents()
    local events  = {}
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if not backpack then return nil, nil end
    for _, tool in ipairs(backpack:GetChildren()) do
        if tool:IsA("Tool") then
            local spell = tool:FindFirstChild("spellEvent")
            if spell and spell:IsA("RemoteEvent") then
                table.insert(events, spell)
                if #events >= 2 then break end
            end
        end
    end
    return events[1], events[2]
end

--========================================================--
-- DANGER MODEL CHECK
--  The game clones attack models directly into workspace
--  with names like "spirtStrike" / "aoeSwipe".
--  We scan ALL of workspace descendants every TP.
--========================================================--

local DANGER_NAMES  = {
    spiritstrike = true,
    aoeswipe     = true,
    -- add more here in lowercase if needed
}
local DANGER_RADIUS = 14   -- studs from the mob we consider "dangerous"
local DODGE_DIST    = 10   -- studs we slide sideways to dodge

--[[
    Returns the closest danger model position near `targetPos`,
    or nil if none found within DANGER_RADIUS.
]]
local function FindNearestDanger(targetPos)
    local closest     = nil
    local closestDist = math.huge

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and DANGER_NAMES[obj.Name:lower()] then

            -- Try PrimaryPart, then first BasePart
            local part = obj.PrimaryPart
            if not part then
                for _, p in ipairs(obj:GetDescendants()) do
                    if p:IsA("BasePart") then
                        part = p
                        break
                    end
                end
            end

            if part then
                local dist = (part.Position - targetPos).Magnitude
                if dist < DANGER_RADIUS and dist < closestDist then
                    closestDist = dist
                    closest     = part
                end
            end
        end
    end

    return closest  -- BasePart or nil
end

--[[
    Compute a dodge position:
    - Take the right-vector of the look-at toward the danger model
    - Slide DODGE_DIST studs to the right (or left if blocked)
    Returns a CFrame for HRP.
]]
local function ComputeDodgeCFrame(myPos, dangerPos, mobPos)
    -- Face toward the mob
    local lookDir = (mobPos - myPos)
    if lookDir.Magnitude < 0.1 then
        lookDir = Vector3.new(1, 0, 0)
    end
    lookDir = lookDir.Unit

    -- Right-perpendicular (flat)
    local right = Vector3.new(-lookDir.Z, 0, lookDir.X).Unit

    -- Direction away from danger
    local toDanger = (dangerPos - myPos)
    local dot      = right:Dot(toDanger)

    -- Slide away from danger side
    local slideDir = (dot >= 0) and -right or right

    local dodgePos = myPos + slideDir * DODGE_DIST
    return CFrame.new(dodgePos, Vector3.new(mobPos.X, dodgePos.Y, mobPos.Z))
end

--========================================================--
-- SAFE TELEPORT  (with danger dodge)
--========================================================--

local function SafeTeleportToMob(mob, heightOffset)

    local success, result = pcall(function()

        if not mob or not mob.Parent then return false end

        local char = LocalPlayer.Character
        if not char or not char.Parent then return false end

        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return false end

        -- Resolve mob head / HRP
        local mobHead = mob:FindFirstChild("Head", true)
        if not mobHead then
            mobHead = mob:FindFirstChild("HumanoidRootPart", true)
        end
        if not mobHead or not mobHead.Parent then return false end

        local hum = mob:FindFirstChildOfClass("Humanoid")
            or mob:FindFirstChild("Humanoid", true)
        if not hum or hum.Health <= 0 then return false end

        local offset         = tonumber(heightOffset) or 8
        local mobPos         = mobHead.Position
        local targetPosition = mobPos + Vector3.new(0, offset, 0)

        --================================================--
        -- CHECK WORKSPACE FOR DANGER MODELS
        --================================================--

        local dangerPart = FindNearestDanger(mobPos)

        local finalCF

        if dangerPart then
            -- Danger found: compute a dodge position instead
            finalCF = ComputeDodgeCFrame(
                targetPosition,  -- where we would have stood
                dangerPart.Position,
                mobPos
            )
            -- keep the height offset
            finalCF = CFrame.new(
                Vector3.new(finalCF.X, mobPos.Y + offset, finalCF.Z),
                Vector3.new(mobPos.X,  mobPos.Y,          mobPos.Z)
            )
        else
            -- No danger: normal teleport
            finalCF = CFrame.lookAt(targetPosition, mobPos)
        end

        hrp.Anchored = true
        hrp.CFrame   = finalCF
        hrp.AssemblyLinearVelocity  = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        hrp.Anchored = false

        return true
    end)

    return success and result == true
end

--========================================================--
-- DROPDOWN VALUE HELPER
--========================================================--

local function GetDropdownValue(value, fallback)
    if typeof(value) == "table" then
        local first = value[1]
        if first ~= nil then return first end
    elseif value ~= nil then
        return value
    end
    return fallback
end

--========================================================--
-- ROOM TAB
--========================================================--

tab:CreateDropdown({
    name        = "Stage",
    multiSelect = false,
    value       = { "Desert Temple" },
    options     = {
        "Desert Temple", "Winter Outpost", "Pirate Island",
        "King's Castle",  "The Underworld", "Samurai Palace",
        "The Canals",     "Ghastly Harbor", "Steampunk Sewers",
        "Orbital Outpost"
    },
    callback = function(value)
        StageName = GetDropdownValue(value, "Desert Temple")
    end,
})

tab:CreateDropdown({
    name        = "Difficult",
    multiSelect = false,
    value       = { "Easy" },
    options     = { "Easy", "Medium", "Hard", "Insane", "Nightmare" },
    callback = function(value)
        Difficult = GetDropdownValue(value, "Easy")
    end,
})

--========================================================--
-- HARDCORE
--========================================================--

tab:CreateToggle({
    name     = "Hardcore",
    value    = false,
    callback = function(value) _G.IsHc = value == true end,
})

--========================================================--
-- CREATE ROOM
--========================================================--

tab:CreateToggle({
    name  = "Auto Create Room",
    value = false,
    callback = function(value)

        _G.AutoRoom = value
        if not value then return end

        task.spawn(function()
            while _G.AutoRoom do
                task.wait(0.5)

                local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
                if not playerGui then continue end

                local queueGui = playerGui:FindFirstChild("queueGui")
                if not queueGui then continue end

                local map          = workspace:FindFirstChild("Map")
                if not map then continue end

                local interactables = map:FindFirstChild("Interactables")
                if not interactables then continue end

                local travelPart = interactables:FindFirstChild("tutorialTravelTouchPart")
                if not travelPart then continue end

                local remotes = GetRemotes()
                if not remotes then continue end

                local createLobby  = remotes:FindFirstChild("createLobby")
                local startDungeon = remotes:FindFirstChild("startDungeon")

                if not createLobby then
                    warn("createLobby remote not found")
                    continue
                end
                if not startDungeon then
                    warn("startDungeon remote not found")
                    continue
                end

                pcall(function()
                    createLobby:InvokeServer(StageName, Difficult, 0, _G.IsHc, false, false)
                end)

                task.wait(0.5)

                pcall(function() startDungeon:FireServer() end)

                break
            end
        end)
    end,
})

--========================================================--
-- AUTO REJOIN
--========================================================--

local rejoinConnection = nil

tab:CreateToggle({
    name  = "Auto Rejoin",
    value = false,
    callback = function(value)

        _G.AutoRejoin = value

        if rejoinConnection then
            rejoinConnection:Disconnect()
            rejoinConnection = nil
        end

        if not value then return end

        task.spawn(function()
            local dungeonProgress = workspace:WaitForChild("dungeonProgress", 30)
            if not dungeonProgress then
                warn("dungeonProgress not found")
                return
            end

            rejoinConnection = dungeonProgress.Changed:Connect(function(newValue)
                if newValue ~= "bossKilled" then return end
                if not _G.AutoRejoin then return end

                task.wait(3)

                local remotes = GetRemotes()
                if not remotes then return end

                local createLobby  = remotes:FindFirstChild("createLobby")
                local startDungeon = remotes:FindFirstChild("startDungeon")
                if not createLobby or not startDungeon then return end

                pcall(function()
                    createLobby:InvokeServer(StageName, Difficult, 0, _G.IsHc, false, false)
                end)

                task.wait(0.5)

                pcall(function() startDungeon:FireServer() end)
            end)
        end)
    end,
})

--========================================================--
-- DUNGEON TAB
--========================================================--

tab2:CreateSlider({
    name  = "Skill Cooldown (seconds)",
    min   = 1,
    max   = 15,
    value = 4,
    callback = function(value)
        SkillCooldown = tonumber(value) or 4
    end,
})

--========================================================--
-- AUTO SKILL
--========================================================--

tab2:CreateToggle({
    name  = "Auto Skill",
    value = false,
    callback = function(value)

        _G.AutoSkill = value
        if not value then return end

        task.spawn(function()
            while _G.AutoSkill do
                PressKey(Enum.KeyCode.E)
                task.wait(0.1)
                PressKey(Enum.KeyCode.Q)
                task.wait(math.max(tonumber(SkillCooldown) or 4, 0.1))
            end
        end)
    end,
})

--========================================================--
-- HEIGHT
--========================================================--

tab2:CreateSlider({
    name  = "Height",
    min   = 7,
    max   = 15,
    value = 7,
    callback = function(value)
        high = tonumber(value) or 7
    end,
})

--========================================================--
-- AUTO DUNGEON
--========================================================--

tab2:CreateToggle({
    name  = "Auto Dungeon",
    value = false,
    callback = function(value)

        _G.Farm = value
        if not value then return end

        task.spawn(function()
            local plr  = LocalPlayer
            local char = plr.Character or plr.CharacterAdded:Wait()
            local hrp  = char:FindFirstChild("HumanoidRootPart")
            if hrp then hrp.Anchored = false end

            local startButton = plr.PlayerGui:FindFirstChild("startButton")
            if startButton then
                local remotes = GetRemotes()
                if remotes then
                    local changeStartValue = remotes:FindFirstChild("changeStartValue")
                    if changeStartValue then
                        pcall(function() changeStartValue:FireServer() end)
                    end
                end
            end

            local Dun = workspace:WaitForChild("dungeon", 30)
            if not Dun then
                warn("Dungeon folder never appeared!")
                _G.Farm = false
                return
            end

            --========================================--
            -- FIND DUNGEON MOB
            --========================================--

            local function GetMon()
                if not Dun or not Dun.Parent then return nil end

                for _, room in ipairs(Dun:GetChildren()) do
                    if room:IsA("Model") or room:IsA("Folder") then
                        if room.Name:lower():match("room") then

                            local enemyFolder = room:FindFirstChild("enemyFolder")
                            if not enemyFolder then continue end

                            for _, mob in ipairs(enemyFolder:GetChildren()) do
                                if mob:IsA("Model") then
                                    local hum = mob:FindFirstChildOfClass("Humanoid")
                                        or mob:FindFirstChild("Humanoid", true)
                                    local mobHRP = mob:FindFirstChild("HumanoidRootPart")
                                        or mob:FindFirstChild("HumanoidRootPart", true)

                                    if hum and mobHRP and hum.Health > 0 then
                                        return mob
                                    end
                                end
                            end
                        end
                    end
                end

                return nil
            end

            --========================================--
            -- SWING EVENT
            --========================================--

            local swingEvent = GetSwingEvent()
            if not swingEvent then
                warn("No swing RemoteEvent found!")
                _G.Farm = false
                return
            end

            --========================================--
            -- SKILL LOOP
            --========================================--

            task.spawn(function()
                while _G.Farm do
                    PressKey(Enum.KeyCode.E)
                    task.wait(0.1)
                    PressKey(Enum.KeyCode.Q)
                    task.wait(math.max(tonumber(SkillCooldown) or 4, 0.1))
                end
            end)

            --========================================--
            -- ATTACK LOOP
            --========================================--

            while _G.Farm do
                local mob = GetMon()
                if not mob then
                    task.wait(0.2)
                    continue
                end

                while _G.Farm and mob and mob.Parent do
                    local hum = mob:FindFirstChildOfClass("Humanoid")
                        or mob:FindFirstChild("Humanoid", true)
                    if not hum or hum.Health <= 0 then break end

                    local mobHRP = mob:FindFirstChild("HumanoidRootPart")
                        or mob:FindFirstChild("HumanoidRootPart", true)
                    if not mobHRP then break end

                    local currentChar = plr.Character
                    if not currentChar then break end

                    -- SafeTeleportToMob now checks workspace for
                    -- spirtStrike / aoeSwipe and dodges if found
                    local ok = SafeTeleportToMob(mob, high)
                    if not ok then break end

                    pcall(function() swingEvent:FireServer() end)

                    task.wait()
                end
            end
        end)
    end,
})

--========================================================--
-- ENEMIES TAB
--========================================================--

tab3:CreateToggle({
    name  = "Auto Enemies",
    value = false,
    callback = function(value)

        _G.FarmEnemies = value
        if not value then return end

        task.spawn(function()
            local plr  = LocalPlayer
            local char = plr.Character or plr.CharacterAdded:Wait()
            local hrp  = char:FindFirstChild("HumanoidRootPart")
            if hrp then hrp.Anchored = false end

            --========================================--
            -- SWING
            --========================================--

            local swingEvent = GetSwingEvent()
            if not swingEvent then
                warn("No swing RemoteEvent found!")
                _G.FarmEnemies = false
                return
            end

            --========================================--
            -- ENEMY FOLDER
            --========================================--

            local enemiesFolder = workspace:WaitForChild("enemies", 30)
            if not enemiesFolder or not enemiesFolder.Parent then
                warn("workspace.enemies never appeared!")
                _G.FarmEnemies = false
                return
            end

            --========================================--
            -- FIND ENEMY
            --========================================--

            local function GetMon()
                if not enemiesFolder or not enemiesFolder.Parent then return nil end

                for _, mob in ipairs(enemiesFolder:GetChildren()) do
                    if mob:IsA("Model") then
                        local hum = mob:FindFirstChildOfClass("Humanoid")
                            or mob:FindFirstChild("Humanoid", true)
                        local head  = mob:FindFirstChild("Head", true)
                        local mobHRP = mob:FindFirstChild("HumanoidRootPart", true)

                        if hum and hum.Health > 0 and mobHRP then
                            if not head or head.Transparency ~= 1 then
                                return mob
                            end
                        end
                    end
                end

                return nil
            end

            --========================================--
            -- SKILL LOOP
            --========================================--

            task.spawn(function()
                while _G.FarmEnemies do
                    PressKey(Enum.KeyCode.E)
                    task.wait(0.1)
                    PressKey(Enum.KeyCode.Q)
                    task.wait(math.max(tonumber(SkillCooldown) or 4, 0.1))
                end
            end)

            --========================================--
            -- ATTACK LOOP
            --========================================--

            while _G.FarmEnemies do
                local mob = GetMon()
                if not mob then
                    task.wait(0.2)
                    continue
                end

                while _G.FarmEnemies and mob and mob.Parent do
                    local hum = mob:FindFirstChildOfClass("Humanoid")
                        or mob:FindFirstChild("Humanoid", true)
                    if not hum or hum.Health <= 0 then break end

                    local mobHRP = mob:FindFirstChild("HumanoidRootPart", true)
                    if not mobHRP then break end

                    local currentChar = plr.Character
                    if not currentChar then break end

                    local head = mob:FindFirstChild("Head", true)
                    if head and head.Transparency == 1 then break end

                    -- SafeTeleportToMob checks workspace for danger models
                    -- and dodges sideways (DODGE_DIST studs) if one is nearby
                    local ok = SafeTeleportToMob(mob, 7.9)
                    if not ok then break end

                    pcall(function() swingEvent:FireServer() end)

                    task.wait()
                end
            end
        end)
    end,
})

--========================================================--
-- DONE
--========================================================--

print("WANDA DQR loaded successfully.")
end

local function _afTick(dt)

    _afLastCheck += dt

    if _afLastCheck < AntiFling.CheckInterval then
        return
    end

    _afLastCheck = 0

    local char = _afChar

    if not char or not char.Parent then
        return
    end

    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")

    if not hrp or not hum then
        return
    end

    if hum.Health <= 0 then
        return
    end

    -- Angular velocity
    local av = hrp.AssemblyAngularVelocity

    if av and av.Magnitude > AntiFling.MaxAngularVelocity then
        hrp.AssemblyAngularVelocity =
            _afClampVec(av, AntiFling.MaxAngularVelocity)
    end

    -- Linear velocity
    local lv = hrp.AssemblyLinearVelocity

    if lv then

        local flat = Vector3.new(
            lv.X,
            0,
            lv.Z
        )

        if flat.Magnitude > AntiFling.MaxLinearVelocity then

            local cf =
                _afClampVec(
                    flat,
                    AntiFling.MaxLinearVelocity
                )

            hrp.AssemblyLinearVelocity = Vector3.new(
                cf.X,
                lv.Y,
                cf.Z
            )
        end

        -- Extreme airborne velocity
        local grounded =
            hum.FloorMaterial ~= Enum.Material.Air

        if
            not grounded
            and lv.Magnitude > AntiFling.AirborneVelocityThreshold
            and not _afResetting
        then

            _afResetting = true

            hrp.AssemblyLinearVelocity = Vector3.new(
                0,
                math.min(lv.Y, 20),
                0
            )

            hrp.AssemblyAngularVelocity = Vector3.zero

            task.delay(0.2, function()
                _afResetting = false
            end)
        end
    end
end

RunService.Heartbeat:Connect(function(dt)
    pcall(function()
        _afTick(dt)
    end)
end)

--========================================================--
-- KEY PRESS
--========================================================--

local function PressKey(keyCode, holdTime)

    holdTime = holdTime or 0.08

    pcall(function()

        VirtualInputManager:SendKeyEvent(
            true,
            keyCode,
            false,
            game
        )

        task.wait(holdTime)

        VirtualInputManager:SendKeyEvent(
            false,
            keyCode,
            false,
            game
        )

    end)
end

--========================================================--
-- REMOTE HELPERS
--========================================================--

local function GetRemotes()

    local remotes = ReplicatedStorage:FindFirstChild("remotes")

    if not remotes then
        return nil
    end

    return remotes
end

local function GetSwingEvent()

    local char = LocalPlayer.Character

    if not char then
        return nil
    end

    for _, v in ipairs(char:GetDescendants()) do

        if
            v:IsA("RemoteEvent")
            and v.Name == "swing"
        then
            return v
        end

    end

    return nil
end

local function GetSkillEvents()

    local events = {}

    local backpack = LocalPlayer:FindFirstChild("Backpack")

    if not backpack then
        return nil, nil
    end

    for _, tool in ipairs(backpack:GetChildren()) do

        if tool:IsA("Tool") then

            local spell =
                tool:FindFirstChild("spellEvent")

            if
                spell
                and spell:IsA("RemoteEvent")
            then

                table.insert(events, spell)

                if #events >= 2 then
                    break
                end
            end
        end
    end

    return events[1], events[2]
end

--========================================================--
-- SAFE TELEPORT
--========================================================--

local function SafeTeleportToMob(mob, heightOffset)

    local success, result = pcall(function()

        if not mob or not mob.Parent then
            return false
        end

        local char = LocalPlayer.Character

        if not char or not char.Parent then
            return false
        end

        local hrp =
            char:FindFirstChild("HumanoidRootPart")

        if not hrp then
            return false
        end

        local mobHead =
            mob:FindFirstChild("Head", true)

        if not mobHead then
            mobHead =
                mob:FindFirstChild(
                    "HumanoidRootPart",
                    true
                )
        end

        if not mobHead or not mobHead.Parent then
            return false
        end

        local hum =
            mob:FindFirstChildOfClass("Humanoid")
            or mob:FindFirstChild(
                "Humanoid",
                true
            )

        if not hum or hum.Health <= 0 then
            return false
        end

        local offset =
            tonumber(heightOffset) or 8

        local targetPosition =
            mobHead.Position
            + Vector3.new(0, offset, 0)

        hrp.Anchored = true

        hrp.CFrame =
            CFrame.lookAt(
                targetPosition,
                mobHead.Position
            )

        hrp.AssemblyLinearVelocity =
            Vector3.zero

        hrp.AssemblyAngularVelocity =
            Vector3.zero

        hrp.Anchored = false

        return true
    end)

    return success and result == true
end

--========================================================--
-- DROPDOWN VALUE HELPER
--========================================================--

local function GetDropdownValue(value, fallback)

    if typeof(value) == "table" then

        local first = value[1]

        if first ~= nil then
            return first
        end

    elseif value ~= nil then

        return value
    end

    return fallback
end

--========================================================--
-- ROOM TAB
--========================================================--

tab:CreateDropdown({
    name = "Stage",

    multiSelect = false,

    value = {
        "Desert Temple"
    },

    options = {
        "Desert Temple",
        "Winter Outpost",
        "Pirate Island",
        "King's Castle",
        "The Underworld",
        "Samurai Palace",
        "The Canals",
        "Ghastly Harbor",
        "Steampunk Sewers",
        "Orbital Outpost"
    },

    callback = function(value)

        StageName =
            GetDropdownValue(
                value,
                "Desert Temple"
            )
    end,
})

tab:CreateDropdown({
    name = "Difficult",

    multiSelect = false,

    value = {
        "Easy"
    },

    options = {
        "Easy",
        "Medium",
        "Hard",
        "Insane",
        "Nightmare"
    },

    callback = function(value)

        Difficult =
            GetDropdownValue(
                value,
                "Easy"
            )
    end,
})

--========================================================--
-- HARDCORE
--========================================================--

tab:CreateToggle({
    name = "Hardcore",

    value = false,

    callback = function(value)
        _G.IsHc = value == true
    end,
})

--========================================================--
-- CREATE ROOM
--========================================================--

tab:CreateToggle({
    name = "Auto Create Room",

    value = false,

    callback = function(value)

        _G.AutoRoom = value

        if not value then
            return
        end

        task.spawn(function()

            while _G.AutoRoom do

                task.wait(0.5)

                local playerGui =
                    LocalPlayer:FindFirstChild(
                        "PlayerGui"
                    )

                if not playerGui then
                    continue
                end

                local queueGui =
                    playerGui:FindFirstChild(
                        "queueGui"
                    )

                if not queueGui then
                    continue
                end

                local map =
                    workspace:FindFirstChild(
                        "Map"
                    )

                if not map then
                    continue
                end

                local interactables =
                    map:FindFirstChild(
                        "Interactables"
                    )

                if not interactables then
                    continue
                end

                local travelPart =
                    interactables:FindFirstChild(
                        "tutorialTravelTouchPart"
                    )

                if not travelPart then
                    continue
                end

                local remotes =
                    GetRemotes()

                if not remotes then
                    continue
                end

                local createLobby =
                    remotes:FindFirstChild(
                        "createLobby"
                    )

                local startDungeon =
                    remotes:FindFirstChild(
                        "startDungeon"
                    )

                if not createLobby then
                    warn(
                        "createLobby remote not found"
                    )
                    continue
                end

                if not startDungeon then
                    warn(
                        "startDungeon remote not found"
                    )
                    continue
                end

                pcall(function()

                    createLobby:InvokeServer(
                        StageName,
                        Difficult,
                        0,
                        _G.IsHc,
                        false,
                        false
                    )

                end)

                task.wait(0.5)

                pcall(function()
                    startDungeon:FireServer()
                end)

                break
            end
        end)
    end,
})

--========================================================--
-- AUTO REJOIN
--========================================================--

local rejoinConnection = nil

tab:CreateToggle({
    name = "Auto Rejoin",

    value = false,

    callback = function(value)

        _G.AutoRejoin = value

        if rejoinConnection then

            rejoinConnection:Disconnect()

            rejoinConnection = nil
        end

        if not value then
            return
        end

        task.spawn(function()

            local dungeonProgress =
                workspace:WaitForChild(
                    "dungeonProgress",
                    30
                )

            if not dungeonProgress then
                warn(
                    "dungeonProgress not found"
                )
                return
            end

            rejoinConnection =
                dungeonProgress.Changed:Connect(
                    function(newValue)

                        if newValue ~= "bossKilled" then
                            return
                        end

                        if not _G.AutoRejoin then
                            return
                        end

                        task.wait(3)

                        local remotes =
                            GetRemotes()

                        if not remotes then
                            return
                        end

                        local createLobby =
                            remotes:FindFirstChild(
                                "createLobby"
                            )

                        local startDungeon =
                            remotes:FindFirstChild(
                                "startDungeon"
                            )

                        if not createLobby
                            or not startDungeon
                        then
                            return
                        end

                        pcall(function()

                            createLobby:InvokeServer(
                                StageName,
                                Difficult,
                                0,
                                _G.IsHc,
                                false,
                                false
                            )

                        end)

                        task.wait(0.5)

                        pcall(function()
                            startDungeon:FireServer()
                        end)
                    end
                )
        end)
    end,
})

--========================================================--
-- DUNGEON TAB
--========================================================--

tab2:CreateSlider({
    name = "Skill Cooldown (seconds)",

    min = 1,
    max = 15,
    value = 4,

    callback = function(value)

        SkillCooldown =
            tonumber(value) or 4

    end,
})

--========================================================--
-- AUTO SKILL
--========================================================--

tab2:CreateToggle({
    name = "Auto Skill",

    value = false,

    callback = function(value)

        _G.AutoSkill = value

        if not value then
            return
        end

        task.spawn(function()

            while _G.AutoSkill do

                PressKey(Enum.KeyCode.E)

                task.wait(0.1)

                PressKey(Enum.KeyCode.Q)

                task.wait(
                    math.max(
                        tonumber(SkillCooldown) or 4,
                        0.1
                    )
                )
            end
        end)
    end,
})

--========================================================--
-- HEIGHT
--========================================================--

tab2:CreateSlider({
    name = "Height",

    min = 7,
    max = 15,
    value = 7,

    callback = function(value)

        high =
            tonumber(value) or 7

    end,
})

--========================================================--
-- AUTO DUNGEON
--========================================================--

tab2:CreateToggle({
    name = "Auto Dungeon",

    value = false,

    callback = function(value)

        _G.Farm = value

        if not value then
            return
        end

        task.spawn(function()

            local plr = LocalPlayer

            local char =
                plr.Character
                or plr.CharacterAdded:Wait()

            local hrp =
                char:FindFirstChild(
                    "HumanoidRootPart"
                )

            if hrp then
                hrp.Anchored = false
            end

            local startButton =
                plr.PlayerGui:FindFirstChild(
                    "startButton"
                )

            if startButton then

                local remotes =
                    GetRemotes()

                if remotes then

                    local changeStartValue =
                        remotes:FindFirstChild(
                            "changeStartValue"
                        )

                    if changeStartValue then

                        pcall(function()
                            changeStartValue:FireServer()
                        end)
                    end
                end
            end

            local Dun =
                workspace:WaitForChild(
                    "dungeon",
                    30
                )

            if not Dun then

                warn(
                    "Dungeon folder never appeared!"
                )

                _G.Farm = false

                return
            end

            --========================================--
            -- FIND DUNGEON MOB
            --========================================--

            local function GetMon()

                if not Dun or not Dun.Parent then
                    return nil
                end

                for _, room in ipairs(
                    Dun:GetChildren()
                ) do

                    if
                        room:IsA("Model")
                        or room:IsA("Folder")
                    then

                        if room.Name:lower():match(
                            "room"
                        ) then

                            local enemyFolder =
                                room:FindFirstChild(
                                    "enemyFolder"
                                )

                            if not enemyFolder then
                                continue
                            end

                            for _, mob in ipairs(
                                enemyFolder:GetChildren()
                            ) do

                                if mob:IsA("Model") then

                                    local hum =
                                        mob:FindFirstChildOfClass(
                                            "Humanoid"
                                        )
                                        or mob:FindFirstChild(
                                            "Humanoid",
                                            true
                                        )

                                    local mobHRP =
                                        mob:FindFirstChild(
                                            "HumanoidRootPart"
                                        )
                                        or mob:FindFirstChild(
                                            "HumanoidRootPart",
                                            true
                                        )

                                    if
                                        hum
                                        and mobHRP
                                        and hum.Health > 0
                                    then

                                        return mob
                                    end
                                end
                            end
                        end
                    end
                end

                return nil
            end

            --========================================--
            -- SWING EVENT
            --========================================--

            local swingEvent =
                GetSwingEvent()

            if not swingEvent then

                warn(
                    "No swing RemoteEvent found!"
                )

                _G.Farm = false

                return
            end

            --========================================--
            -- SKILL LOOP
            --========================================--

            task.spawn(function()

                while _G.Farm do

                    PressKey(
                        Enum.KeyCode.E
                    )

                    task.wait(0.1)

                    PressKey(
                        Enum.KeyCode.Q
                    )

                    task.wait(
                        math.max(
                            tonumber(SkillCooldown)
                                or 4,
                            0.1
                        )
                    )
                end
            end)

            --========================================--
            -- ATTACK LOOP
            --========================================--

            while _G.Farm do

                local mob = GetMon()

                if not mob then

                    task.wait(0.2)

                    continue
                end

                while
                    _G.Farm
                    and mob
                    and mob.Parent
                do

                    local hum =
                        mob:FindFirstChildOfClass(
                            "Humanoid"
                        )
                        or mob:FindFirstChild(
                            "Humanoid",
                            true
                        )

                    if not hum
                        or hum.Health <= 0
                    then
                        break
                    end

                    local mobHRP =
                        mob:FindFirstChild(
                            "HumanoidRootPart"
                        )
                        or mob:FindFirstChild(
                            "HumanoidRootPart",
                            true
                        )

                    if not mobHRP then
                        break
                    end

                    local currentChar =
                        plr.Character

                    if not currentChar then
                        break
                    end

                    local ok =
                        SafeTeleportToMob(
                            mob,
                            high
                        )

                    if not ok then
                        break
                    end

                    pcall(function()
                        swingEvent:FireServer()
                    end)

                    task.wait()
                end
            end
        end)
    end,
})

--========================================================--
-- ENEMIES TAB
--========================================================--

tab3:CreateToggle({
    name = "Auto Enemies",

    value = false,

    callback = function(value)

        _G.FarmEnemies = value

        if not value then
            return
        end

        task.spawn(function()

            local plr = LocalPlayer

            local char =
                plr.Character
                or plr.CharacterAdded:Wait()

            local hrp =
                char:FindFirstChild(
                    "HumanoidRootPart"
                )

            if hrp then
                hrp.Anchored = false
            end

            --========================================--
            -- SWING
            --========================================--

            local swingEvent =
                GetSwingEvent()

            if not swingEvent then

                warn(
                    "No swing RemoteEvent found!"
                )

                _G.FarmEnemies = false

                return
            end

            --========================================--
            -- ENEMY FOLDER
            --========================================--

            local enemiesFolder =
                workspace:WaitForChild(
                    "enemies",
                    30
                )

            if
                not enemiesFolder
                or not enemiesFolder.Parent
            then

                warn(
                    "workspace.enemies never appeared!"
                )

                _G.FarmEnemies = false

                return
            end

            --========================================--
            -- FIND ENEMY
            --========================================--

            local function GetMon()

                if
                    not enemiesFolder
                    or not enemiesFolder.Parent
                then
                    return nil
                end

                for _, mob in ipairs(
                    enemiesFolder:GetChildren()
                ) do

                    if mob:IsA("Model") then

                        local hum =
                            mob:FindFirstChildOfClass(
                                "Humanoid"
                            )
                            or mob:FindFirstChild(
                                "Humanoid",
                                true
                            )

                        local head =
                            mob:FindFirstChild(
                                "Head",
                                true
                            )

                        local mobHRP =
                            mob:FindFirstChild(
                                "HumanoidRootPart",
                                true
                            )

                        if
                            hum
                            and hum.Health > 0
                            and mobHRP
                        then

                            if
                                not head
                                or head.Transparency ~= 1
                            then
                                return mob
                            end
                        end
                    end
                end

                return nil
            end

            --========================================--
            -- SKILL LOOP
            --========================================--

            task.spawn(function()

                while _G.FarmEnemies do

                    PressKey(
                        Enum.KeyCode.E
                    )

                    task.wait(0.1)

                    PressKey(
                        Enum.KeyCode.Q
                    )

                    task.wait(
                        math.max(
                            tonumber(SkillCooldown)
                                or 4,
                            0.1
                        )
                    )
                end
            end)

            --========================================--
            -- ATTACK LOOP
            --========================================--

            while _G.FarmEnemies do

                local mob = GetMon()

                if not mob then

                    task.wait(0.2)

                    continue
                end

                while
                    _G.FarmEnemies
                    and mob
                    and mob.Parent
                do

                    local hum =
                        mob:FindFirstChildOfClass(
                            "Humanoid"
                        )
                        or mob:FindFirstChild(
                            "Humanoid",
                            true
                        )

                    if
                        not hum
                        or hum.Health <= 0
                    then
                        break
                    end
if mob == "Demonic Pirate Captain " then break end
                    local mobHRP =
                        mob:FindFirstChild(
                            "HumanoidRootPart",
                            true
                        )

                    if not mobHRP then
                        break
                    end

                    local currentChar =
                        plr.Character

                    if not currentChar then
                        break
                    end

                    local head =
                        mob:FindFirstChild(
                            "Head",
                            true
                        )

                    if
                        head
                        and head.Transparency == 1
                    then
                        break
                    end

                    local ok =
                        SafeTeleportToMob(
                            mob,
                            9.7
                        )

                    if not ok then
                        break
                    end

                    pcall(function()
                        swingEvent:FireServer()
                    end)

                    task.wait()
                end
            end
        end)
    end,
})

--========================================================--
-- DONE
--========================================================--

print("WANDA DQR loaded successfully.")
