loadstring(game:HttpGet("https://raw.githubusercontent.com/Dewzhud/CLOWNTDS/refs/heads/main/asf"))()

local Rayfield = loadstring(game:HttpGet("https://sirius.menu/gen2"))()

local window = Rayfield:CreateWindow({
    name     = "WANDA",
    subtitle = "DQR",
    configuration = {
        autoSave     = true,
        autoLoad     = true,
        fileName     = "WD_DQR",
        customFolder = "WD",
    },
})

local tab  = window:CreateTab({ name = "Room",    icon = 93364949241311 })
local tab2 = window:CreateTab({ name = "Dungeon", icon = 93364949241311 })
local tab3 = window:CreateTab({ name = "Enemies", icon = 93364949241311 })

-- ─────────────────────────────────────────────────────────────────────────────
--   SHARED STATE
-- ─────────────────────────────────────────────────────────────────────────────

local StageName     = "Desert Temple"
local Difficult     = "Easy"
local SkillCooldown = 4

_G.IsHc        = false
_G.AutoRoom    = false
_G.AutoRejoin  = false
_G.Farm        = false
_G.FarmEnemies = false
_G.AutoSkill   = false

-- ─────────────────────────────────────────────────────────────────────────────
--   ANTI SELF-FLING
--   Clamps angular & linear velocity every Heartbeat so rapid CFrame
--   teleports (looking down at a mob) never build up enough spin to fling.
-- ─────────────────────────────────────────────────────────────────────────────

local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")

-- ─────────────────────────────────────────────────────────────────────────────
--   KEY PRESS HELPER
--   Simulates a real keydown + keyup so the game's InputBegan fires normally.
--   Works the same way a player pressing the key would.
-- ─────────────────────────────────────────────────────────────────────────────

local function PressKey(keyCode, holdTime)
    holdTime = holdTime or 0.08
    VirtualInputManager:SendKeyEvent(true,  keyCode, false, game)
    task.wait(holdTime)
    VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
end

local AntiFling = {
    MaxAngularVelocity       = 2.5,   -- rad/s max spin
    MaxLinearVelocity        = 80,    -- studs/s max horizontal speed
    AirborneVelocityThreshold = 60,   -- studs/s airborne hard-reset threshold
    CheckInterval            = 0.05,  -- seconds between checks
}

local _afLastCheck  = 0
local _afResetting  = false
local _afChar       = nil  -- updated on each spawn (see CharacterAdded below)

local function _afClampVec(v, maxMag)
    return v.Magnitude > maxMag and v.Unit * maxMag or v
end

local function _afTick(dt)
    _afLastCheck += dt
    if _afLastCheck < AntiFling.CheckInterval then return end
    _afLastCheck = 0

    local char = _afChar
    if not char or not char.Parent then return end

    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum or hum.Health <= 0 then return end

    -- 1) Clamp angular velocity (the rotation-fling culprit)
    local av = hrp.AssemblyAngularVelocity
    if av.Magnitude > AntiFling.MaxAngularVelocity then
        hrp.AssemblyAngularVelocity = _afClampVec(av, AntiFling.MaxAngularVelocity)
    end

    -- 2) Clamp horizontal linear velocity (preserve Y so jumping still works)
    local lv   = hrp.AssemblyLinearVelocity
    local flat = Vector3.new(lv.X, 0, lv.Z)
    if flat.Magnitude > AntiFling.MaxLinearVelocity then
        local cf = _afClampVec(flat, AntiFling.MaxLinearVelocity)
        hrp.AssemblyLinearVelocity = Vector3.new(cf.X, lv.Y, cf.Z)
    end

    -- 3) Airborne hard-reset for extreme mid-air velocity
    local grounded = hum.FloorMaterial ~= Enum.Material.Air
    if not grounded and lv.Magnitude > AntiFling.AirborneVelocityThreshold and not _afResetting then
        _afResetting = true
        hrp.AssemblyLinearVelocity  = Vector3.new(0, math.min(lv.Y, 20), 0)
        hrp.AssemblyAngularVelocity = Vector3.zero
        task.delay(0.2, function() _afResetting = false end)
    end
end

RunService.Heartbeat:Connect(function(dt)
    pcall(_afTick, dt)
end)

-- Keep _afChar in sync with respawns
game.Players.LocalPlayer.CharacterAdded:Connect(function(c)
    _afChar = c
    _afResetting = false
end)
_afChar = game.Players.LocalPlayer.Character  -- grab current character right now

-- ─────────────────────────────────────────────────────────────────────────────
--   SHARED HELPERS
-- ─────────────────────────────────────────────────────────────────────────────

local function GetSwingEvent()
    local char = game.Players.LocalPlayer.Character
    if not char then return nil end
    for _, v in pairs(char:GetDescendants()) do
        if v:IsA("RemoteEvent") and v.Name == "swing" then return v end
    end
    return nil
end

local function GetSkillEvents()
    local plr    = game.Players.LocalPlayer
    local events = {}
    for _, tool in pairs(plr.Backpack:GetChildren()) do
        if tool:IsA("Tool") then
            local spell = tool:FindFirstChild("spellEvent")
            if spell and spell:IsA("RemoteEvent") then
                table.insert(events, spell)
                if #events == 2 then break end
            end
        end
    end
    return events[1], events[2]
end

-- ─────────────────────────────────────────────────────────────────────────────
--   SAFE TELEPORT HELPER
--   • Teleports above the mob and faces straight DOWN (no sideways tilt)
--   • Anchors the HRP for exactly one frame so physics can't build up
--     velocity during the CFrame write, then immediately un-anchors.
--   • Returns false and does nothing if the mob/hrp is gone.
-- ─────────────────────────────────────────────────────────────────────────────

local function SafeTeleportToMob(mob, heightOffset)
    local success, result = pcall(function()
        local char = game.Players.LocalPlayer.Character
        if not char then return false end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return false end

        local mobHead = mob and mob:FindFirstChild("Humanoid")
        if not mobHead or not mobHead.Parent then return false end
        if mobHead.Health <= 1 then return false end

        local targetCFrame = mobHead.CFrame * CFrame.new(0, heightOffset or 1, 0)

        hrp.Anchored = true
        hrp.CFrame = CFrame.new(targetCFrame.Position, mobHead.Position)
        hrp.AssemblyLinearVelocity  = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        hrp.Anchored = false
        return true
    end)

    return success and result == true
end
-- ─────────────────────────────────────────────────────────────────────────────
--   TAB 1 – ROOM
-- ─────────────────────────────────────────────────────────────────────────────

tab:CreateDropdown({
    name        = "Stage",
    multiSelect = false,
    value       = { "Desert Temple" },
    options     = {
        "Desert Temple", "Winter Outpost", "Pirate Island",
        "King's Castle", "The Underworld", "Samurai Palace",
        "The Canals", "Ghastly Harbor", "Steampunk Sewers", "Orbital Outpost"
    },
    callback = function(value) StageName = value end,
})

tab:CreateDropdown({
    name        = "Difficult",
    multiSelect = false,
    value       = { "Easy" },
    options     = { "Easy", "Medium", "Hard", "Insane", "Nightmare" },
    callback = function(value) Difficult = value end,
})

tab:CreateToggle({
    name     = "Hardcore",
    value    = false,
    callback = function(value) _G.IsHc = value end,
})

tab:CreateToggle({
    name     = "Auto Create Room",
    value    = false,
    callback = function(value)
        _G.AutoRoom = value
        while _G.AutoRoom do
            task.wait()
            local playerGui = game:GetService("Players").LocalPlayer.PlayerGui
            local GUi = playerGui:FindFirstChild("queueGui")
            if not GUi then continue end
if not workspace.Map:FindFirstChild("Interactables"):WaitForChild("tutorialTravelTouchPart") then continue end
            local remotes = game:GetService("ReplicatedStorage").remotes
            remotes.createLobby:InvokeServer(StageName, Difficult, 0, _G.IsHc, false, false)
            remotes.startDungeon:FireServer()
            break
        end
    end,
})

local rejoinConnection = nil
tab:CreateToggle({
    name     = "Auto Rejoin",
    value    = false,
    callback = function(value)
        _G.AutoRejoin = value

        if rejoinConnection then
            rejoinConnection:Disconnect()
            rejoinConnection = nil
        end

        if not _G.AutoRejoin then return end

        local dungeonProgress = workspace:WaitForChild("dungeonProgress")
        rejoinConnection = dungeonProgress.Changed:Connect(function(newValue)
            if newValue ~= "bossKilled" then return end
            if not _G.AutoRejoin then return end

            task.wait(3)
            local remotes = game:GetService("ReplicatedStorage").remotes
            remotes.createLobby:InvokeServer(StageName, Difficult, 0, _G.IsHc, false, false)
            remotes.startDungeon:FireServer()
        end)
    end,
})

-- ─────────────────────────────────────────────────────────────────────────────
--   TAB 2 – DUNGEON
-- ─────────────────────────────────────────────────────────────────────────────

tab2:CreateSlider({
    name     = "Skill Cooldown (seconds)",
    min      = 1,
    max      = 15,
    value    = 4,
    callback = function(value) SkillCooldown = value end,
})

tab2:CreateToggle({
    name     = "Auto Skill",
    value    = false,
    callback = function(value)
        _G.AutoSkill = value
        if not value then return end

        task.spawn(function()
            while _G.AutoSkill do
                -- Press E (skill 1)
                PressKey(Enum.KeyCode.E)
                task.wait(0.1)
                -- Press Q (skill 2)
                PressKey(Enum.KeyCode.Q)
                task.wait(SkillCooldown)
            end
        end)
    end,
})
local high = 7
tab2:CreateSlider({
    name     = "Height (seconds)",
    min      = 7,
    max      = 15,
    value    = 7,
    callback = function(value) high = value end,
})
tab2:CreateToggle({
    name     = "Auto Dungeon",
    value    = false,
    callback = function(value)
        _G.Farm = value
        if not value then return end

        local plr  = game.Players.LocalPlayer
        local char = plr.Character
        if not char then return end

        char.HumanoidRootPart.Anchored = false

        local startButton = plr.PlayerGui:WaitForChild("startButton", 3)
        if startButton then
            game:GetService("ReplicatedStorage").remotes.changeStartValue:FireServer()
        end

        local Dun = workspace:WaitForChild("dungeon", 30)
        if not Dun then warn("Dungeon folder never appeared!") return end

        local function GetMon()
            for _, room in pairs(Dun:GetChildren()) do
                if (room:IsA("Model") or room:IsA("Folder"))
                    and string.match(room.Name:lower(), "room")
                then
                    local EF = room:FindFirstChild("enemyFolder")
                    if not EF then continue end
                    for _, mob in pairs(EF:GetChildren()) do
                        if mob:IsA("Model") then
                            local head = mob:FindFirstChild("Head")
                            if head and head.Transparency ~= 1 then
                                return mob, mob:FindFirstChild("HumanoidRootPart")
                            end
                        end
                    end
                end
            end
            return nil, nil
        end

        local swingEvent = GetSwingEvent()
        if not swingEvent then warn("No swing RemoteEvent found!") return end

        -- Skill loop (parallel) — presses E then Q like a real player
        task.spawn(function()
            while _G.Farm do
                PressKey(Enum.KeyCode.E)
                task.wait(0.1)
                PressKey(Enum.KeyCode.Q)
                task.wait(SkillCooldown)
            end
        end)

        -- Main attack loop
        repeat
            task.wait()

            local mob, _ = GetMon()
            -- ── FIX: no mob found → idle safely, don't touch CFrame ──
            if not mob then continue end

            while _G.Farm do
                -- Check mob is still alive before doing anything
                local head = mob:FindFirstChild("Humanoid")
                if not head or head.Health == <1 then break end

                local mobHRP = mob:FindFirstChild("HumanoidRootPart")
                if not mobHRP then break end

                local currentChar = plr.Character
                if not currentChar then break end

                -- Safe teleport: anchors for 1 frame, zeroes velocity, un-anchors
                -- HEIGHT OFFSET 7 = above mob, facing straight down
                local ok = SafeTeleportToMob(mob,high)
                if not ok then break end  -- mob died mid-frame, stop attacking it

                swingEvent:FireServer()
                task.wait()
            end
        until not _G.Farm
    end,
})

-- ─────────────────────────────────────────────────────────────────────────────
--   TAB 3 – ENEMIES
-- ─────────────────────────────────────────────────────────────────────────────

tab3:CreateToggle({
    name     = "Auto Enemies",
    value    = false,
    callback = function(value)
        _G.FarmEnemies = value
        if not value then return end

        local plr  = game.Players.LocalPlayer
        local char = plr.Character
        if not char then return end

        char.HumanoidRootPart.Anchored = false

        local swingEvent = GetSwingEvent()
        if not swingEvent then warn("No swing RemoteEvent found!") return end

        local enemiesFolder = workspace:WaitForChild("enemies", 30)
        if not enemiesFolder then warn("workspace.enemies never appeared!") return end

        local function GetMon()
            for _, mob in pairs(enemiesFolder:GetChildren()) do
                if mob:IsA("Model") then
                    local head = mob:FindFirstChild("Head")
                    if head and head.Transparency ~= 1 then
                        return mob, mob:FindFirstChild("HumanoidRootPart")
                    end
                end
            end
            return nil, nil
        end

        -- Skill loop (parallel) — presses E then Q like a real player
        task.spawn(function()
            while _G.FarmEnemies do
                PressKey(Enum.KeyCode.E)
                task.wait(0.1)
                PressKey(Enum.KeyCode.Q)
                task.wait(SkillCooldown)
            end
        end)

        -- Main attack loop
        repeat
            task.wait()

            local mob, _ = GetMon()
            -- ── FIX: no mob found → idle safely, don't touch CFrame ──
            if not mob then continue end

            while _G.FarmEnemies do
                local head = mob:FindFirstChild("Head")
                if not head or head.Transparency == 1 then break end

                local mobHRP = mob:FindFirstChild("HumanoidRootPart")
                if not mobHRP then break end

                local currentChar = plr.Character
                if not currentChar then break end

                -- Safe teleport: anchors for 1 frame, zeroes velocity, un-anchors
                -- HEIGHT OFFSET 7.9 = above mob, facing straight down
                local ok = SafeTeleportToMob(mob, 7.9)
                if not ok then break end  -- mob died mid-frame

                swingEvent:FireServer()
                task.wait()
            end
        until not _G.FarmEnemies
    end,
})
