local Globals = getgenv()

return function(ctx)
    if not ctx or not ctx.Window then
        warn("[Recorder] ctx.Window missing, UI not created")
        return
    end

    local Window = ctx.Window
    local replicated_storage = ctx.ReplicatedStorage or game:GetService("ReplicatedStorage")
    local http_service = ctx.HttpService or game:GetService("HttpService")
    local game_state = ctx.GameState or "UNKNOWN"
    local workspace_ref = ctx.workspace or workspace

    local players_service = game:GetService("Players")
    local local_player = ctx.LocalPlayer or players_service.LocalPlayer or players_service.PlayerAdded:Wait()

    Globals.record_strat = Globals.record_strat or false

    local spawned_towers = {}
    local tower_count = 0
    local last_wave = 0
    local Recorder
    local has_hook = type(hookmetamethod) == "function"
    local map_listener_connected = false

    local current_map = "Unknown"
    local map_actions = {}
    local current_map_started = false
    local current_towers = {"None", "None", "None", "None", "None"}
    local current_modifiers = ""
    local current_mode = "Unknown"
    local skip_game_info = false

    -- ============================================
    -- HELPERS
    -- ============================================
    local function keys(t)
        local r = {}
        for k in pairs(t) do table.insert(r, tostring(k)) end
        table.sort(r)
        return r
    end

    local function count(t)
        local n = 0
        for _ in pairs(t) do n += 1 end
        return n
    end

    local function notify(title, desc, kind)
        pcall(function()
            Window:Notify({Title = title, Desc = desc, Time = 3, Type = kind or "normal"})
        end)
    end

    local function log_line(message)
        if Recorder and Recorder.Log then
            pcall(function() Recorder:Log(message) end)
        else
            print("[Recorder] " .. tostring(message))
        end
    end

    local function get_wave()
        local ok, w = pcall(function()
            return replicated_storage.StateReplicators.GameStateReplicator:GetAttribute("Wave")
        end)
        if ok and type(w) == "number" then return w end
        return 0
    end

    -- ============================================
    -- STATE GETTERS
    -- ============================================
    local function GetCurrentMapName()
        local state_folder = replicated_storage:FindFirstChild("State")
        if state_folder then
            local map = state_folder:GetAttribute("Map")
            if map and map ~= "" and map ~= "Unknown" then
                return map
            end
        end

        local state_replicators = replicated_storage:FindFirstChild("StateReplicators")
        if state_replicators then
            local gs = state_replicators:FindFirstChild("GameStateReplicator")
            if gs then
                local map = gs:GetAttribute("Map")
                if map and map ~= "" then
                    return map
                end
            end
        end
        return "Unknown"
    end

    local function GetCurrentMode()
        local state_folder = replicated_storage:FindFirstChild("State")
        if not state_folder then
            return "Unknown"
        end

        local diff_obj = state_folder:FindFirstChild("Difficulty")
        local mode = diff_obj and diff_obj.Value or "Unknown"
        local mode_obj = state_folder:FindFirstChild("Mode")

        if mode_obj then
            if mode_obj.Value == "Hardcore" then
                return (mode == "Hard") and "Voidcore" or "Hardcore"
            elseif mode_obj.Value == "DuckEvent" then
                if mode == "Easy" then
                    return "DuckyEasy"
                elseif mode == "Hard" then
                    return "DuckyHard"
                end
                skip_game_info = true
            elseif mode_obj.Value == "Special" then
                skip_game_info = true
            end
        end

        if mode == "Trial" then
            skip_game_info = true
        end

        return mode
    end

    local function GetEquippedTowers()
        local towers = {"None", "None", "None", "None", "None"}
        local state_replicators = replicated_storage:FindFirstChild("StateReplicators")

        if state_replicators then
            for _, folder in ipairs(state_replicators:GetChildren()) do
                if folder.Name == "PlayerReplicator" and folder:GetAttribute("UserId") == local_player.UserId then
                    local equipped = folder:GetAttribute("EquippedTowers")
                    if type(equipped) == "string" then
                        local cleaned_json = equipped:match("%[.*%]")
                        if cleaned_json then
                            local success, tower_table = pcall(function()
                                return http_service:JSONDecode(cleaned_json)
                            end)
                            if success and type(tower_table) == "table" then
                                for i = 1, 5 do
                                    towers[i] = tower_table[i] or "None"
                                end
                            end
                        end
                    end
                end
            end
        end
        return towers
    end

    local function GetModifiers()
        local mods = {}
        local state_replicators = replicated_storage:FindFirstChild("StateReplicators")

        if state_replicators then
            for _, folder in ipairs(state_replicators:GetChildren()) do
                if folder.Name == "ModifierReplicator" then
                    local raw_votes = folder:GetAttribute("Votes")
                    if type(raw_votes) == "string" then
                        local cleaned_json = raw_votes:match("{.*}")
                        if cleaned_json then
                            local success, mod_table = pcall(function()
                                return http_service:JSONDecode(cleaned_json)
                            end)
                            if success and type(mod_table) == "table" then
                                for mod_name in pairs(mod_table) do
                                    table.insert(mods, mod_name .. " = true")
                                end
                            end
                        end
                    end
                end
            end
        end
        return table.concat(mods, ", ")
    end

    local function get_wave_prefix()
        local current_wave = get_wave()
        if current_wave > last_wave then
            last_wave = current_wave
            return "\n-- [ Wave " .. current_wave .. " ] --\n"
        end
        return ""
    end

    -- ============================================
    -- RECORD ACTION
    -- ============================================
    local function record_action(command_str)
        if not Globals.record_strat then return end

        local line = get_wave_prefix() .. command_str

        if current_map ~= "Unknown" then
            map_actions[current_map] = map_actions[current_map] or {}
            table.insert(map_actions[current_map], line)
        end

        if appendfile then
            pcall(appendfile, "Strat.txt", line .. "\n")
        end
    end

    -- ============================================
    -- MAP HEADER
    -- ============================================
    local function GetMapHeader()
        local towers = GetEquippedTowers()
        local mode = GetCurrentMode()
        local modifiers = GetModifiers()

        return string.format([[
-- ============================================
-- MAP: %s
-- Mode: %s
-- Towers: %s, %s, %s, %s, %s
-- Modifiers: %s
-- ============================================
]], current_map, mode, towers[1], towers[2], towers[3], towers[4], towers[5], modifiers)
    end

    local LIB_LINE = "local TDS = loadstring(game:HttpGet(\"https://raw.githubusercontent.com/DuxiiT/auto-strat/refs/heads/main/Library.lua\"))()\n\n"

    -- ============================================
    -- SAVE MULTI-MAP
    -- ============================================
    local function SaveMultiMapStrategy()
        if not writefile then
            log_line("⚠️ writefile not available, cannot save")
            return false
        end

        local content = LIB_LINE
        content = content .. "-- MULTI-MAP STRATEGY FILE\n"
        content = content .. "-- Generated at: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n"
        content = content .. "-- Maps recorded: " .. table.concat(keys(map_actions), ", ") .. "\n\n"
        content = content .. "local MapActions = {}\n\n"

        local has_actions = false
        for map_name, actions in pairs(map_actions) do
            if #actions > 0 then
                has_actions = true
                content = content .. string.format("MapActions[%q] = function()\n", map_name)
                for _, action in ipairs(actions) do
                    content = content .. action .. "\n"
                end
                content = content .. "end\n\n"
            end
        end

        if not has_actions then
            log_line("⚠️ No actions recorded yet!")
            return false
        end

        content = content .. [=[
local ran = {}

local function RunMap(map)
    if not map or map == "" or ran[map] then return end
    local fn = MapActions[map]
    if fn then
        ran[map] = true
        print("Running strategy for map: " .. map)
        local ok, err = pcall(fn)
        if not ok then warn("Strategy error: " .. tostring(err)) end
    else
        print("No strategy for map: " .. tostring(map))
    end
end

task.spawn(function()
    local rs = game:GetService("ReplicatedStorage")
    local sr = rs:WaitForChild("StateReplicators", 30)
    local gs = sr and sr:WaitForChild("GameStateReplicator", 30)
    if not gs then
        warn("GameStateReplicator not found")
        return
    end
    gs:GetAttributeChangedSignal("Map"):Connect(function()
        RunMap(gs:GetAttribute("Map"))
    end)
    RunMap(gs:GetAttribute("Map"))
end)
]=]

        local ok, err = pcall(writefile, "Strat_MultiMap.lua", content)
        if not ok then
            log_line("⚠️ writefile failed: " .. tostring(err))
            return false
        end

        log_line("✅ Saved Strat_MultiMap.lua")
        log_line("📊 Maps: " .. table.concat(keys(map_actions), ", "))
        notify("✅ Multi-Map Strategy Saved", "Saved " .. count(map_actions) .. " map(s) to Strat_MultiMap.lua")
        return true
    end

    -- ============================================
    -- START NEW MAP
    -- ============================================
    local function StartNewMapRecording()
        local new_map = GetCurrentMapName()
        if new_map == "Unknown" then
            return
        end

        if new_map ~= current_map then
            current_map = new_map
            current_map_started = false
            current_towers = GetEquippedTowers()
            current_mode = GetCurrentMode()
            current_modifiers = GetModifiers()
            last_wave = 0

            log_line("📝 New map detected: " .. current_map)
            log_line("  Mode: " .. current_mode)
            log_line("  Towers: " .. table.concat(current_towers, ", "))
        end

        if not current_map_started then
            current_map_started = true
            map_actions[current_map] = map_actions[current_map] or {}

            local header = GetMapHeader()
            table.insert(map_actions[current_map], header)

            if appendfile then
                pcall(appendfile, "Strat.txt", header .. "\n")
            end

            log_line("✅ Recording started for map: " .. current_map)
            notify("🎯 Map Detected", "Recording for: " .. current_map)
        end
    end

    -- ============================================
    -- TOWER INDEX
    -- ============================================
    local function resolve_tower_index(tower)
        if typeof(tower) ~= "Instance" then
            return nil
        end
        if spawned_towers[tower] then
            return spawned_towers[tower]
        end
        local current = tower.Parent
        while current do
            if spawned_towers[current] then
                return spawned_towers[current]
            end
            current = current.Parent
        end
        return nil
    end

    local function sync_existing_towers()
        if game_state ~= "GAME" then return end
        local towers_folder = workspace_ref:FindFirstChild("Towers")
        if not towers_folder then return end

        table.clear(spawned_towers)
        tower_count = 0

        for _, tower in ipairs(towers_folder:GetChildren()) do
            local replicator = tower:FindFirstChild("TowerReplicator")
            if replicator and replicator:GetAttribute("OwnerId") == local_player.UserId then
                tower_count += 1
                spawned_towers[tower] = tower_count
            end
        end
    end

    -- ============================================
    -- SERIALIZE
    -- ============================================
    local function num_to_str(n)
        if type(n) ~= "number" then return tostring(n) end
        if n == math.huge then return "math.huge" end
        if n == -math.huge then return "-math.huge" end
        if n ~= n then return "0/0" end
        return tostring(n)
    end

    local function instance_expr(inst)
        local ok, full = pcall(function() return inst:GetFullName() end)
        if not ok or type(full) ~= "string" or full == "" then
            return nil
        end
        local parts = string.split(full, ".")
        local expr = 'game:GetService("' .. parts[1] .. '")'
        for i = 2, #parts do
            local part = parts[i]
            if part:match("^[_%a][_%w]*$") then
                expr = expr .. "." .. part
            else
                expr = expr .. "[" .. string.format("%q", part) .. "]"
            end
        end
        return expr
    end

    local function is_array(tbl)
        local max_idx = 0
        for k in pairs(tbl) do
            if type(k) ~= "number" or k < 1 or k % 1 ~= 0 then
                return false, 0
            end
            if k > max_idx then max_idx = k end
        end
        return true, max_idx
    end

    -- mode "tower": Instance -> tower index. mode "raw": Instance -> path expr
    local function serialize(v, raw, depth)
        depth = depth or 0
        if depth > 4 then return "nil" end

        local t = typeof(v)
        if t == "string" then
            return string.format("%q", v)
        elseif t == "number" then
            return num_to_str(v)
        elseif t == "boolean" then
            return tostring(v)
        elseif t == "Vector3" then
            return string.format("Vector3.new(%s, %s, %s)", num_to_str(v.X), num_to_str(v.Y), num_to_str(v.Z))
        elseif t == "CFrame" then
            local comps = {v:GetComponents()}
            local parts = {}
            for i = 1, #comps do parts[i] = num_to_str(comps[i]) end
            return "CFrame.new(" .. table.concat(parts, ", ") .. ")"
        elseif t == "Instance" then
            if raw then
                return instance_expr(v) or "nil"
            end
            local idx = resolve_tower_index(v)
            return idx and tostring(idx) or "nil"
        elseif t == "table" then
            local is_arr, max_idx = is_array(v)
            local parts = {}
            if is_arr then
                for i = 1, max_idx do
                    parts[i] = serialize(v[i], raw, depth + 1)
                end
            else
                local ks = {}
                for k in pairs(v) do table.insert(ks, k) end
                table.sort(ks, function(a, b) return tostring(a) < tostring(b) end)
                for _, k in ipairs(ks) do
                    local key_str
                    if type(k) == "string" and k:match("^[_%a][_%w]*$") then
                        key_str = k
                    elseif type(k) == "number" then
                        key_str = "[" .. num_to_str(k) .. "]"
                    else
                        key_str = "[" .. serialize(k, raw, depth + 1) .. "]"
                    end
                    table.insert(parts, key_str .. " = " .. serialize(v[k], raw, depth + 1))
                end
            end
            return "{" .. table.concat(parts, ", ") .. "}"
        end
        return "nil"
    end

    local function serialize_value(v) return serialize(v, false, 0) end
    local function serialize_value_raw(v) return serialize(v, true, 0) end

    local function build_remote_call(remote, method, args)
        if typeof(remote) ~= "Instance" then return nil end
        local expr = instance_expr(remote)
        if not expr then return nil end

        local arg_parts = {}
        for i = 1, #args do
            arg_parts[i] = serialize_value_raw(args[i])
        end
        return expr .. ":" .. method .. "(" .. table.concat(arg_parts, ", ") .. ")"
    end

    local function is_consumable_call(remote, args)
        local first = args[1]
        if type(first) == "string" then
            local lower = first:lower()
            if lower:find("consum") then return true end
            if lower:find("item") and type(args[2]) == "string" and args[2]:lower():find("use") then
                return true
            end
        end

        if typeof(remote) == "Instance" then
            local ok, full = pcall(function() return remote:GetFullName() end)
            if ok and type(full) == "string" then
                local lower = full:lower()
                if lower:find("consum") then return true end
                if lower:find("item") and lower:find("use") then return true end
            end
        end
        return false
    end

    local function any_string_contains(args, token)
        for i = 1, #args do
            local v = args[i]
            if type(v) == "string" and v:lower():find(token, 1, true) then
                return true
            end
        end
        return false
    end

    local keyword_set = {
        troops = true, troop = true, option = true, options = true, target = true,
        ability = true, abilities = true, activate = true, set = true, voting = true,
        skip = true, inventory = true, equip = true, unequip = true, tower = true
    }

    local function collect_non_keyword_strings(args)
        local list = {}
        for i = 1, #args do
            local v = args[i]
            if type(v) == "string" and not keyword_set[v:lower()] then
                table.insert(list, v)
            end
        end
        return list
    end

    local function find_payload(args)
        for i = 1, #args do
            local v = args[i]
            if type(v) == "table" and (v.Troop or v.troop or v.Tower or v.tower) then
                return v
            end
        end
        return nil
    end

    local function find_tower_arg(args)
        for i = 1, #args do
            local v = args[i]
            if typeof(v) == "Instance" and resolve_tower_index(v) then
                return v
            end
        end
        return nil
    end

    local function record_line(line, message)
        record_action(line)
        if message then log_line(message) end
    end

    local function ability_cmd(idx, name, data)
        if data == nil or (type(data) == "table" and next(data) == nil) then
            return string.format("TDS:Ability(%d, %q)", idx, name)
        end
        return string.format("TDS:Ability(%d, %q, %s)", idx, name, serialize_value(data))
    end

    Globals.__tds_record_equip = function(tower_name)
        if type(tower_name) ~= "string" then return end
        record_line(string.format("TDS:Equip(%q)", tower_name), "Equipped: " .. tower_name)
    end

    Globals.__tds_record_unequip = function(tower_name)
        if type(tower_name) ~= "string" then return end
        record_line(string.format("TDS:Unequip(%q)", tower_name), "Unequipped: " .. tower_name)
    end

    -- ============================================
    -- NAMECALL HANDLER
    -- ============================================
    local function handle_namecall(remote, method, args, results)
        if not Globals.record_strat then return end
        if method ~= "InvokeServer" and method ~= "FireServer" then return end

        local a1, a2, a3, a4, a5 = args[1], args[2], args[3], args[4], args[5]

        if a1 == "Troops" and a2 == "Abilities" and a3 == "Activate" then
            if type(a4) == "table" and type(a4.Name) == "string" then
                local n = a4.Name
                if n == "Call Of Arms" or n == "Support Caravan" or n == "Drop The Beat" or n == "Raise The Dead" then
                    return
                end
            end
            if not results or results[1] ~= true then return end

            if type(a4) == "table" then
                local idx = resolve_tower_index(a4.Troop)
                local name = a4.Name
                if idx and type(name) == "string" then
                    record_line(ability_cmd(idx, name, a4.Data), "Ability: " .. name .. " (Index: " .. idx .. ")")
                    return
                end
            end
        end

        if a1 == "Troops" and a2 == "Target" and a3 == "Set" then
            if type(a4) == "table" then
                local idx = resolve_tower_index(a4.Troop)
                local target_type = a4.Target
                if idx and type(target_type) == "string" then
                    record_line(string.format("TDS:SetTarget(%d, %q)", idx, target_type),
                        "Target: " .. idx .. " -> " .. target_type)
                    return
                end
            end
        end

        if a1 == "Troops" and a2 == "Upgrade" and a3 == "Set" then
            if type(a4) == "table" then
                local tower = a4.Troop
                local my_index = resolve_tower_index(tower)
                local path = a4.Path or 1

                if my_index and tower and results and results[1] == true then
                    local replicator = tower:FindFirstChild("TowerReplicator")
                    local tower_name = replicator and replicator:GetAttribute("Name") or tower.Name
                    local cmd = (path > 1) and string.format("TDS:Upgrade(%d, %d)", my_index, path)
                        or string.format("TDS:Upgrade(%d)", my_index)
                    record_line(cmd, "Upgraded " .. tostring(tower_name) .. " (Index: " .. my_index .. ")")
                    return
                end
            end
        end

        if a1 == "Troops" and a2 == "Option" and a3 == "Set" then
            if type(a4) == "table" then
                local idx = resolve_tower_index(a4.Troop)
                local opt_name = a4.Name or a4.Option or a4.Key or a4.Track
                local opt_val = a4.Value or a4.Val
                if idx and type(opt_name) == "string" then
                    record_line(string.format("TDS:SetOption(%d, %q, %s)", idx, opt_name, serialize_value(opt_val)),
                        "Option: " .. idx .. " " .. opt_name .. " = " .. tostring(opt_val))
                    return
                end
            end
        end

        if a1 == "Troops" and a2 == "TowerServerEvent" and a3 == "ToggleSelectedTower" then
            local idx = resolve_tower_index(a4)
            local target_idx = resolve_tower_index(a5)
            if idx and target_idx then
                record_line(string.format("TDS:MedicSelect(%d, %d)", idx, target_idx),
                    "Medic: " .. idx .. " -> " .. target_idx)
                return
            end
        end

        if a1 == "Voting" and a2 == "Skip" then
            local current_wave = get_wave()
            if current_wave == 0 then
                record_line("TDS:Ready()", "Readied up for the match")
            else
                record_line("TDS:VoteSkip(" .. current_wave .. ")", "Voted to skip wave " .. current_wave)
            end
            return
        end

        if a1 == "Inventory" and a2 == "Equip" and a3 == "tower" then
            if type(a4) == "string" then
                record_line(string.format("TDS:Equip(%q)", a4), "Equipped: " .. a4)
            end
            return
        end

        if a1 == "Inventory" and a2 == "Unequip" and a3 == "tower" then
            if type(a4) == "string" then
                record_line(string.format("TDS:Unequip(%q)", a4), "Unequipped: " .. a4)
            end
            return
        end

        if is_consumable_call(remote, args) then
            local raw_call = build_remote_call(remote, method, args)
            if raw_call then
                record_line(raw_call, "Consumable used")
            end
            return
        end

        if a1 ~= "Troops" then return end

        local payload = find_payload(args)
        local tower_obj = payload and (payload.Troop or payload.troop or payload.Tower or payload.tower) or find_tower_arg(args)
        local idx = resolve_tower_index(tower_obj)
        if not idx then return end

        local strings = collect_non_keyword_strings(args)
        local has_option = any_string_contains(args, "option") or any_string_contains(args, "track")
        local has_ability = any_string_contains(args, "abil")
        local has_target = any_string_contains(args, "target")

        if has_option then
            local opt_name = payload and (payload.Name or payload.Option or payload.Key or payload.Track)
            local opt_val = payload and (payload.Value or payload.Val)

            if not opt_name and #strings >= 1 then opt_name = strings[1] end
            if opt_val == nil and #strings >= 2 then opt_val = strings[2] end
            if not opt_name and any_string_contains(args, "track") then opt_name = "Track" end

            if opt_name then
                record_line(string.format("TDS:SetOption(%d, %q, %s)", idx, tostring(opt_name), serialize_value(opt_val)),
                    "Option: " .. idx .. " " .. tostring(opt_name) .. " = " .. tostring(opt_val))
            end
            return
        end

        if has_target then
            local target_type = payload and payload.Target or (#strings >= 1 and strings[1] or nil)
            if target_type then
                record_line(string.format("TDS:SetTarget(%d, %q)", idx, tostring(target_type)),
                    "Target: " .. idx .. " -> " .. tostring(target_type))
            end
            return
        end

        if has_ability then
            local name = payload and payload.Name or (#strings >= 1 and strings[1] or nil)
            if name then
                record_line(ability_cmd(idx, name, payload and payload.Data or nil),
                    "Ability: " .. name .. " (Index: " .. idx .. ")")
            end
            return
        end
    end

    -- ============================================
    -- HOOK (install once)
    -- ============================================
    local function install_hook()
        Globals.__tds_recorder_handler = function(remote, method, args, results)
            handle_namecall(remote, method, args, results)
        end

        if Globals.__tds_recorder_hooked then return end
        Globals.__tds_recorder_hooked = true

        local original
        original = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod and getnamecallmethod() or nil

            if Globals.record_strat and (method == "InvokeServer" or method == "FireServer") then
                local args = {...}
                local results = table.pack(original(self, ...))
                local handler = Globals.__tds_recorder_handler
                if handler then
                    task.spawn(function()
                        local set_id = setthreadidentity or setidentity or setthreadcontext
                        if set_id then pcall(set_id, 7) end
                        pcall(handler, self, method, args, results)
                    end)
                end
                return table.unpack(results, 1, results.n)
            end

            return original(self, ...)
        end)
    end

    -- ============================================
    -- UI (built first so it always appears)
    -- ============================================
    local RecorderTab = Window:Tab({Title = "Recorder", Icon = "camera"})

    local ok_logger, logger = pcall(function()
        return RecorderTab:CreateLogger({
            Title = "RECORDER:",
            Size = UDim2.new(0, 330, 0, 230)
        })
    end)
    if ok_logger and logger then
        Recorder = logger
    else
        warn("[Recorder] CreateLogger failed, using print fallback: " .. tostring(logger))
        Recorder = {Log = function(_, m) print("[Recorder] " .. tostring(m)) end, Clear = function() end}
    end

    local function clear_log()
        pcall(function() Recorder:Clear() end)
    end

    RecorderTab:Button({
        Title = "START RECORDING",
        Desc = "Start recording for the current map",
        Callback = function()
            clear_log()

            if not has_hook then
                log_line("\nYour executor is not supported for recording and is \nonly meant for replaying strats.")
                return
            end

            local ok, err = pcall(install_hook)
            if not ok then
                log_line("⚠️ Hook failed: " .. tostring(err))
                return
            end

            log_line("✅ Recorder started - Multi-Map Mode")
            log_line("📝 Recording will auto-detect maps")

            current_map = GetCurrentMapName()
            current_mode = GetCurrentMode()
            current_towers = GetEquippedTowers()
            current_modifiers = GetModifiers()
            current_map_started = false
            last_wave = 0

            sync_existing_towers()
            Globals.record_strat = true

            if current_map ~= "Unknown" then
                log_line("🎯 Current map: " .. current_map)
                log_line("  Mode: " .. current_mode)
                log_line("  Towers: " .. table.concat(current_towers, ", "))
                StartNewMapRecording()
            else
                log_line("⏳ Waiting for map detection...")
            end

            if not map_listener_connected then
                local sr = replicated_storage:FindFirstChild("StateReplicators")
                local gsr = sr and sr:FindFirstChild("GameStateReplicator")
                if gsr then
                    map_listener_connected = true
                    gsr:GetAttributeChangedSignal("Map"):Connect(function()
                        if not Globals.record_strat then return end
                        local new_map = gsr:GetAttribute("Map")
                        if new_map and new_map ~= "" and new_map ~= current_map then
                            log_line("🔄 Map changed to: " .. new_map)
                            StartNewMapRecording()
                        end
                    end)
                end
            end

            notify("🎥 Recorder Started", "Recording for map: " .. current_map)
        end
    })

    RecorderTab:Button({
        Title = "STOP & SAVE",
        Desc = "Stop recording and save multi-map strategy",
        Callback = function()
            Globals.record_strat = false

            if count(map_actions) > 0 then
                local saved = SaveMultiMapStrategy()
                if saved then
                    clear_log()
                    log_line("✅ Recording stopped and saved!")
                    log_line("📊 Maps recorded: " .. table.concat(keys(map_actions), ", "))
                    log_line("📁 Saved as: Strat_MultiMap.lua")
                    log_line("📄 Also appended to Strat.txt")
                end
            else
                log_line("⚠️ No actions recorded!")
                notify("⚠️ No Actions", "No actions recorded. Play a match first!", "error")
            end
        end
    })

    RecorderTab:Button({
        Title = "SAVE CURRENT MAP ONLY",
        Desc = "Save only the current map's strategy",
        Callback = function()
            if not current_map or current_map == "Unknown" then
                log_line("⚠️ No map detected!")
                notify("⚠️ No Map", "Join a match first!", "error")
                return
            end

            local actions = map_actions[current_map]
            if not actions or #actions == 0 then
                log_line("⚠️ No actions for map: " .. current_map)
                notify("⚠️ No Actions", "No actions recorded for " .. current_map, "error")
                return
            end

            if not writefile then
                log_line("⚠️ writefile not available")
                return
            end

            local content = LIB_LINE .. GetMapHeader() .. "\n-- Actions\n"
            for _, action in ipairs(actions) do
                if not action:match("^%-%- =") then
                    content = content .. action .. "\n"
                end
            end

            local ok, err = pcall(writefile, "Strat_" .. current_map .. ".lua", content)
            if ok then
                log_line("✅ Saved strategy for: " .. current_map)
                notify("✅ Saved", "Saved strategy for: " .. current_map)
            else
                log_line("⚠️ Save failed: " .. tostring(err))
            end
        end
    })

    RecorderTab:Button({
        Title = "CLEAR ALL RECORDINGS",
        Desc = "Clear all recorded map actions",
        Callback = function()
            table.clear(map_actions)
            table.clear(spawned_towers)
            tower_count = 0
            current_map_started = false
            last_wave = 0
            clear_log()
            log_line("🗑️ All recordings cleared!")
            notify("🗑️ Cleared", "All recorded actions cleared")
        end
    })

    -- ============================================
    -- STATUS (optional, never breaks UI)
    -- ============================================
    pcall(function() RecorderTab:Section({Title = "Status"}) end)

    local function safe_label(text)
        local ok, lbl = pcall(function()
            return RecorderTab:Label({Title = text, Desc = ""})
        end)
        return ok and lbl or nil
    end

    local MapLabel = safe_label("Current Map: " .. current_map)
    local MapCountLabel = safe_label("Maps Recorded: 0")
    local ActionsLabel = safe_label("Total Actions: 0")

    local function set_label(lbl, text)
        if lbl and lbl.SetTitle then
            pcall(function() lbl:SetTitle(text) end)
        end
    end

    task.spawn(function()
        while true do
            task.wait(2)
            set_label(MapLabel, "Current Map: " .. current_map)
            set_label(MapCountLabel, "Maps Recorded: " .. count(map_actions))
            local total = 0
            for _, actions in pairs(map_actions) do total += #actions end
            set_label(ActionsLabel, "Total Actions: " .. total)
        end
    end)

    -- ============================================
    -- TOWER TRACKING (guarded)
    -- ============================================
    if game_state == "GAME" then
        task.spawn(function()
            local towers_folder = workspace_ref:WaitForChild("Towers", 15)
            if not towers_folder then
                log_line("⚠️ Towers folder not found, placement tracking off")
                return
            end

            towers_folder.ChildAdded:Connect(function(tower)
                if not Globals.record_strat then return end

                local replicator = tower:WaitForChild("TowerReplicator", 5)
                if not replicator then return end

                local owner_id = replicator:GetAttribute("OwnerId")
                if owner_id and owner_id ~= local_player.UserId then return end
                if replicator:GetAttribute("Hologram") == true then return end

                tower_count += 1
                local my_index = tower_count
                spawned_towers[tower] = my_index

                local tower_name = replicator:GetAttribute("Name") or tower.Name
                local raw_pos = replicator:GetAttribute("Position")

                local pos_x, pos_y, pos_z
                if typeof(raw_pos) == "Vector3" then
                    pos_x, pos_y, pos_z = raw_pos.X, raw_pos.Y, raw_pos.Z
                else
                    local p = tower:GetPivot().Position
                    pos_x, pos_y, pos_z = p.X, p.Y, p.Z
                end

                local command = string.format("TDS:Place(%q, %s, %s, %s%s)",
                    tower_name, tostring(pos_x), tostring(pos_y), tostring(pos_z),
                    Globals.StackEnabled and ", true" or "")

                record_action(command)
                log_line("📌 Placed " .. tower_name .. " (Index: " .. my_index .. ") on " .. current_map)
            end)

            towers_folder.ChildRemoved:Connect(function(tower)
                if not Globals.record_strat then return end

                local my_index = spawned_towers[tower]
                if my_index then
                    record_action(string.format("TDS:Sell(%d)", my_index))
                    log_line("💀 Sold Tower " .. my_index)
                    spawned_towers[tower] = nil
                end
            end)
        end)
    end
end
