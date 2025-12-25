local config = {
    seed_id = 4585,
    plat_id = 3126,
    mag_bg_id_ptht = 8208,
    delay_plant = 70,
    delay_harvest = 150,
    uws_threshold = 99,
    pnb_bfg_facing = 1,
    bfg_id = 2810,
    mag_bg_id_pnb = 284,
    pnb_bot_mode = 0,
    pnb_bgems_drop = 1000,
    pnb_suck_cooldown = 1,
    pnb_consume_id_1 = 4604,
    pnb_consume_id_2 = 1056,
    target_world = GetWorld().name,
    use_webhook = true,
    webhook_url = "WEBHOOK LINK",
    discord_user_id = GetDiscordID() or 0,
    webhook_interval = 5,
    show_window = true,
    lock_window_position = true,
    window_alpha = 0.9,
    active_account = 1,
    pnb_take_gems = 1
}

local state = {
    is_running = false,
    bot_status = "STOPPED",
    current_mode = "PTHT",
    current_action = "IDLE",
    mode_switching = false,
    taking_remote = false,
    magplant_ptht_pos = nil,
    magplant_pnb_pos = nil,
    bfg_pos = nil,
    platform_locations = {},
    telephone_pos = nil,
    ptht_active = false,
    pnb_active = false,
    last_switch_time = 0,
    last_webhook_time = 0,
    is_ghost_active = false,
    is_mray_active = false,
    is_consume_active = false,
    needs_consume = false,
    need_reconnect = false,
    consume_checked_on_switch = false,
    session_start_time = 0,
    world_name = "N/A",
    initial_gems = 0,
    current_gems = 0,
    ptht_session_time = 0,
    ptht_total_session = 0,
    ptht_cycle_count = 0,
    ptht_cycle_times = {},
    ptht_avg_time_per_cycle = 0,
    ptht_last_cycle_start_time = 0,
    platforms = 0,
    seeds = 0,
    ready_trees = 0,
    seeds_total_to_plant = 0,
    seeds_planted_this_cycle = 0,
    initial_uws_stock = 0,
    uws_used = 0,
    pnb_session_time = 0,
    pnb_total_session = 0,
    pnb_last_remote_time = 0,
    pnb_magplant_duration = 0,
    pnb_last_gem_check_time = 0,
    pnb_last_gem_count = 0,
    pnb_gems_per_minute = 0,
    pnb_next_suck_time = 0,
    world_uws_dropped = 0,
    world_pgems_dropped = 0,
    consume1_end_time = 0,
    consume2_end_time = 0,
    pnb_initial_dl = 0,
    pnb_current_dl = 0,
    pnb_initial_bgl = 0,
    pnb_current_bgl = 0,
    pnb_initial_irg = 0,
    pnb_current_irg = 0,
    pnb_initial_bgems_bank = 0,
    pnb_current_bgems_bank = 0,
    pnb_world_bgems_dropped = 0,
    last_time_update = 0,
    ptht_session_start_time = 0,
    pnb_session_start_time = 0,
}

_G.ptht_magplant_is_empty = false
_G.pnb_magplant_is_empty = false
_G.remote_obtained_success = false
_G.uws_tree_ready = false

function Log(text)
    LogToConsole("`b[`6ROTASI`b] `0- " .. text)
end

function RawMove(x, y, z)
    SendPacketRaw(false, { state = z or 0, px = x, py = y, x = x * 32, y = y * 32 })
    Sleep(50)
end

function Place(x, y, id)
    SendPacketRaw(false, { type = 3, value = id, px = x, py = y, x = x * 32, y = y * 32 })
end

function wear(id)
    SendPacketRaw(false, { type = 10, value = id })
end

function cek(id)
    for _, item in pairs(GetInventory()) do
        if item.id == id then return item.amount end
    end
    return 0
end

function GetWorldObjects(itemId)
    local total = 0
    local objectList = GetObjectList() or {}
    for _, obj in pairs(objectList) do
        if obj.id == itemId then
            total = total + obj.amount
        end
    end
    return total
end

function CalculateAverageTime(times_table)
    if not times_table or #times_table == 0 then return 0 end
    local total = 0
    for _, time in ipairs(times_table) do total = total + time end
    return math.floor(total / #times_table)
end

function ResetAndInitializeStats()
    Log("`6Initializing session statistics...")
    state.session_start_time = os.time()
    state.last_webhook_time = 0
    state.world_name = GetWorld() and GetWorld().name or "N/A"
    local player_info = GetPlayerInfo()
    state.initial_gems = player_info and player_info.gems or 0
    state.current_gems = state.initial_gems
    state.last_time_update = os.time()
    state.ptht_session_time = 0
    state.pnb_session_time = 0
    state.ptht_cycle_count = 0
    state.ptht_cycle_times = {}
    state.ptht_avg_time_per_cycle = 0
    state.ptht_last_cycle_start_time = os.time()
    state.initial_uws_stock = cek(GetItemInfo("Ultra World Spray").id)
    state.uws_used = 0
    state.pnb_last_remote_time = 0
    state.pnb_magplant_duration = 0
    state.pnb_last_gem_check_time = 0
    state.pnb_last_gem_count = state.initial_gems
    state.pnb_gems_per_minute = 0
    state.pnb_initial_dl = cek(1796)
    state.pnb_current_dl = state.pnb_initial_dl
    state.pnb_initial_bgl = cek(7188)
    state.pnb_current_bgl = state.pnb_initial_bgl
    state.pnb_initial_irg = cek(11550)
    state.pnb_current_irg = state.pnb_initial_irg
    state.pnb_initial_bgems_bank = 0
    state.pnb_current_bgems_bank = 0
    state.ptht_total_session = 0
    state.pnb_total_session = 0
    Log("`2Statistics initialized. Ready to start.")
end

function FormatTime(seconds)
    seconds = math.floor(seconds or 0)
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = seconds % 60
    if h > 0 then
        return string.format("%dh %dm %ds", h, m, s)
    elseif m > 0 then
        return string.format("%dm %ds", m, s)
    else
        return string.format("%ds", s)
    end
end

function KOMA(num)
    num = math.floor((num or 0) + 0.5)
    local formatted = tostring(num)
    local k = 3
    while k < #formatted do
        formatted = formatted:sub(1, #formatted - k) .. "," .. formatted:sub(#formatted - k + 1)
        k = k + 4
    end
    return formatted
end

function cleanText(str)
    local cleanedStr = string.gsub(str, "`(%S)", '')
    cleanedStr = string.gsub(cleanedStr, "`{2}|(~{2})", '')
    return cleanedStr
end

function SaveConfig()
    local world_name = GetWorld() and GetWorld().name or "default"
    local filename = "rotasi_config_" .. world_name:gsub("[^%w]", "") .. ".lua"
    local content = "return {\n"
    for key, value in pairs(config) do
        local value_type = type(value)
        if value_type == "number" or value_type == "boolean" then
            content = content .. string.format("  %s = %s,\n", key, tostring(value))
        elseif value_type == "string" then
            local escaped_value = value:gsub("\\", "\\\\"):gsub("\"", "\\\"")
            content = content .. string.format("  %s = \"%s\",\n", key, escaped_value)
        end
    end
    content = content .. "}"
    local file, err = io.open(filename, "w")
    if not file then
        Log("`4ERROR: Failed to save config - " .. (err or "unknown error"))
        return
    end
    file:write(content)
    file:close()
    Log("`2Configuration for World '" .. world_name .. "' has been saved successfully.")
end

function LoadConfig()
    local world_name = GetWorld() and GetWorld().name or "default"
    local filename = "rotasi_config_" .. world_name:gsub("[^%w]", "") .. ".lua"
    local loader, err = loadfile(filename)
    if not loader then
        Log("`eConfig file not found for world '" .. world_name .. "'. Using default settings.")
        return
    end
    local success, loaded_config = pcall(loader)
    if not success or type(loaded_config) ~= "table" then
        Log("`4ERROR: Failed to load or parse config file. " .. tostring(loaded_config))
        return
    end
    for key, value in pairs(loaded_config) do
        if config[key] ~= nil then
            config[key] = value
        end
    end
    Log("`2Configuration for world '" .. world_name .. "' loaded successfully.")
end

function ScanWorldObjects()
    state.platform_locations = {}
    state.magplant_ptht_pos, state.magplant_pnb_pos, state.bfg_pos, state.telephone_pos = nil, nil, nil, nil
    local world = GetWorld()
    if not world then return false end
    local telephones = {}
    for x = 0, world.width - 1 do
        for y = 0, world.height - 1 do
            local tile = GetTile(x, y)
            if tile then
                if tile.fg == 5638 and tile.bg == config.mag_bg_id_ptht then state.magplant_ptht_pos = { x = x, y = y } end
                if tile.fg == 5638 and tile.bg == config.mag_bg_id_pnb then state.magplant_pnb_pos = { x = x, y = y } end
                if tile.fg == config.bfg_id then state.bfg_pos = { x = x, y = y } end
                if tile.fg == 3898 then table.insert(telephones, { x = x, y = y }) end
                local above = GetTile(x, y + 1)
                if above and above.fg == config.plat_id then table.insert(state.platform_locations, { x = x, y = y }) end
            end
        end
    end
    state.platforms = #state.platform_locations
    if state.bfg_pos and #telephones > 0 then
        local closest_dist = 9999
        for _, phone_pos in ipairs(telephones) do
            local dist = math.sqrt((phone_pos.x - state.bfg_pos.x) ^ 2 + (phone_pos.y - state.bfg_pos.y) ^ 2)
            if dist < closest_dist then
                closest_dist = dist
                state.telephone_pos = phone_pos
            end
        end
    end
    local required_objects = { "Magplant PTHT", "Magplant PNB", "BFG" }
    local missing_objects = {}
    if not state.magplant_ptht_pos then table.insert(missing_objects, "Magplant PTHT") end
    if not state.magplant_pnb_pos then table.insert(missing_objects, "Magplant PNB") end
    if not state.bfg_pos then table.insert(missing_objects, "BFG") end
    if (config.pnb_bot_mode == 1 or config.pnb_bot_mode == 2) and not state.telephone_pos then
        table.insert(missing_objects, "Telephone")
    end
    if #missing_objects == 0 then
        Log("`2Scan Complete: All required objects found.")
        return true
    else
        Log("`4ERROR: Missing objects: " .. table.concat(missing_objects, ", "))
        return false
    end
end

function TakeRemote(mode)
    local mag_pos = (mode == "PTHT") and state.magplant_ptht_pos or state.magplant_pnb_pos
    if not mag_pos then return false end
    _G.remote_obtained_success = false
    state.taking_remote = true
    Log("Attempting to take remote for `6" .. mode .. "`0 mode...")
    RawMove(mag_pos.x, mag_pos.y)
    Sleep(150)
    Place(mag_pos.x, mag_pos.y, 32)
    Sleep(150)
    SendPacket(2,
        "action|dialog_return\ndialog_name|magplant_edit\nx|" ..
        mag_pos.x .. "|\ny|" .. mag_pos.y .. "|\nbuttonClicked|getRemote\n\n")
    local timeout = os.time() + 5
    while os.time() < timeout and not _G.remote_obtained_success do
        Sleep(100)
    end
    state.taking_remote = false
    if _G.remote_obtained_success then
        Sleep(1000)
        if mode == "PTHT" then
            _G.ptht_magplant_is_empty = false
        else
            _G.pnb_magplant_is_empty = false
        end
        return true
    end
    return false
end

function GetWorldStats()
    local seeds, ready = 0, 0
    local seed_id = config.seed_id
    if not GetWorld() or #state.platform_locations == 0 then return end
    for _, pos in ipairs(state.platform_locations) do
        local tile = GetTile(pos.x, pos.y)
        if tile and tile.fg == seed_id then
            seeds = seeds + 1
            if tile.extra.progress == 1.0 then ready = ready + 1 end
        end
    end
    state.seeds, state.ready_trees = seeds, ready
end

function DetermineAction()
    GetWorldStats()
    if state.ready_trees > 0 then return "HARVEST" end
    if state.platforms > 0 and state.seeds < state.platforms then
        return (state.seeds / state.platforms) * 100 >= config.uws_threshold and "UWS" or "PLANT"
    end
    if state.platforms > 0 and state.seeds == state.platforms and state.ready_trees == 0 then return "UWS" end
    return "WAIT"
end

function SmartPlant()
    local world = GetWorld()
    if not world then return end
    state.seeds_planted_this_cycle = 0
    local move_z, x_start, x_end, x_step, reverse_y
    if config.active_account == 1 then
        move_z = 32
        x_start, x_end, x_step = 0, world.width - 1, 10
        reverse_y = false
    else
        move_z = 48
        x_start, x_end, x_step = world.width - 1, 0, -10
        reverse_y = true
    end
    for x = x_start, x_end, x_step do
        if not state.is_running or not state.ptht_active then return end
        local y_start, y_end, y_step
        if reverse_y then
            y_start, y_end, y_step = world.height - 1, 0, -1
        else
            y_start, y_end, y_step = 0, world.height - 1, 1
        end
        for y = y_start, y_end, y_step do
            if not state.is_running or not state.ptht_active then return end
            local tile = GetTile(x, y)
            local above = GetTile(x, y + 1)
            if tile and above and tile.fg == 0 and above.fg == config.plat_id then
                RawMove(x, y, move_z); Place(x, y, 5640); Sleep(config.delay_plant)
                state.seeds_planted_this_cycle = state.seeds_planted_this_cycle + 10
            end
        end
        reverse_y = not reverse_y
    end
end

function SmartHarvest()
    local world = GetWorld()
    if not world then return end
    local seed_id = config.seed_id
    local y_start, y_end, y_step
    if config.active_account == 1 then
        y_start, y_end, y_step = world.height - 1, 0, -1
    else
        y_start, y_end, y_step = 0, world.height - 1, 1
    end
    for x = 0, world.width - 1 do
        if not state.is_running or not state.ptht_active then return end
        for y = y_start, y_end, y_step do
            if not state.is_running or not state.ptht_active then return end
            local tile = GetTile(x, y)
            if tile and tile.fg == seed_id and tile.extra.progress == 1.0 then
                RawMove(x, y, 32); Place(x, y, 18); Sleep(config.delay_harvest)
            end
        end
    end
    Log("Harvest cycle complete.")
    local cycle_duration = os.time() - state.ptht_last_cycle_start_time
    table.insert(state.ptht_cycle_times, cycle_duration)
    state.ptht_avg_time_per_cycle = CalculateAverageTime(state.ptht_cycle_times)
    state.ptht_cycle_count = state.ptht_cycle_count + 1
    state.ptht_last_cycle_start_time = os.time()
end

function UseUWS()
    _G.uws_tree_ready = false
    if config.active_account == 1 then
        if cek(GetItemInfo("Ultra World Spray").id) < 1 then
            SendAlertWebhook("UWS Depleted", "Ultra World Spray stock in the inv is empty. PTHT mode may stop.")
            stop_bot()
            return false
        end
        Log("`2ACC `01 : Using Ultra World Spray")
        SendPacket(2, "action|dialog_return\ndialog_name|ultraworldspray")
        state.uws_used = state.uws_used + 1
    else
        Log("ACC `02 : Waiting for trees to grow (no UWS used)")
    end
    Log("Waiting for trees to grow...")
    local wait_start_time = os.time()
    while not _G.uws_tree_ready do
        if not state.is_running or not state.ptht_active then return false end
        state.current_action = "Waiting for trees..."
        Sleep(1000)
        GetWorldStats()
        if state.ready_trees > 0 then
            _G.uws_tree_ready = true
            Log("Proactive check found ready trees!")
        end
        if os.time() - wait_start_time > 180 then
            Log("`4Timeout: Trees did not grow."); return false
        end
    end
    Log("Trees are ready!")
    return true
end

function PNB_EnableCheat()
    Log("PNB: Enabling BFG cheat.")
    local gems_value
    if config.pnb_bot_mode == 1 or config.pnb_bot_mode == 2 then
        gems_value = 1
    elseif config.pnb_bot_mode == 3 then
        gems_value = 0
    else
        gems_value = config.pnb_take_gems
    end

    SendPacket(2,
        "action|dialog_return\ndialog_name|cheats\ncheck_autofarm|1\ncheck_bfg|1\ncheck_gems|" ..
        gems_value .. "\ncheck_lonely|1")
end

function PNB_DisableCheat()
    Log("PNB: Disabling BFG cheat.")
    SendPacket(2, "action|dialog_return\ndialog_name|cheats\ncheck_autofarm|0\ncheck_bfg|0\ncheck_gems|1\ncheck_lonely|1")
end

function CheckAndActivateEffects()
    Log("Checking for active effects (Ghost & M-Ray)...")
    SendPacket(2, "action|wrench\n|netid|" .. GetLocal().netid)
    Sleep(1000)
    if not state.is_ghost_active then
        Log("Activating Ghost...")
        SendPacket(2, "action|input\ntext|/ghost")
        Sleep(500)
    end
    if not state.is_mray_active then
        local mray_id = GetItemInfo("Mythical Infinity Rayman's Fist").id
        if cek(mray_id) > 0 then
            Log("Equipping M-Ray...")
            wear(mray_id)
            Sleep(500)
        else
            Log("`4M-Ray not found in inventory.")
        end
    end
end

function CheckConsumeEffects()
    Log("`6Checking consume effects status...")
    SendPacket(2, "action|wrench\n|netid|" .. GetLocal().netid)
    Sleep(1000)
end

function PNB_UpdateBankBgems()
    SendPacket(2, "action|dialog_return\ndialog_name|popup\nbuttonClicked|bgems")
    Sleep(500)
end

function PNB_ConsumeItems()
    Log("`6PNB: Consuming items for effects...")
    local p = GetLocal()
    if not p then return end
    local items = { config.pnb_consume_id_1, config.pnb_consume_id_2 }
    for _, id in ipairs(items) do
        if cek(id) > 0 then
            Place(state.bfg_pos.x, state.bfg_pos.y, id)
            Sleep(1200)
        else
            Log("`4Warning: Out of " .. (GetItemInfo(id).name or "Item " .. id))
            SendAlertWebhook("Consume Lost", "Warning: Out of " .. (GetItemInfo(id).name or "Item " .. id))
        end
    end
    state.needs_consume = false
    state.is_consume_active = true
    Log("`2Consume finished!")
end

function SafeJoinWorld(target_world)
    Log("`6Attempting to rejoin world: " .. target_world)
    SendPacket(3, "action|join_request\nname|" .. target_world .. "\ninvitedWorld|0")
    local start = os.time()
    while true do
        local world = GetWorld()
        if world and world.name and world.name:lower() == target_world:lower() then
            Log("`2Successfully rejoined world: " .. target_world)
            return true
        end
        Sleep(100)
        if os.time() - start > 10 then
            Log("`4Timeout: Failed to join world " .. target_world)
            return false
        end
    end
end

function HandleReconnect()
    if not state.need_reconnect then return false end
    SendAlertWebhook("Connection Lost", "The bot is attempting to reconnect to world " .. config.target_world)
    Log("`4Handling reconnection...")
    state.need_reconnect = false
    state.ptht_active = false
    state.pnb_active = false
    state.mode_switching = false
    state.taking_remote = false
    Sleep(2000)
    if SafeJoinWorld(config.target_world) then
        Log("`2Reconnected successfully. Restarting bot...")
        Sleep(3000)
        if ScanWorldObjects() then
            CheckAndActivateEffects()
            state.current_mode = "PTHT"
            _G.ptht_magplant_is_empty = false
            _G.pnb_magplant_is_empty = false
            if TakeRemote("PTHT") then
                state.ptht_active = true
                Log("`2Bot restarted successfully after reconnection!")
            else
                _G.ptht_magplant_is_empty = true
            end
        else
            Log("`4Failed to restart bot after reconnection - world setup invalid")
            state.is_running = false
        end
        return true
    else
        Log("`4Failed to rejoin world. Stopping bot.")
        state.is_running = false
        return false
    end
end

function MoveTo(x, y)
    local move_state = (config.pnb_bfg_facing == 1) and 32 or 48
    SendPacketRaw(false, { state = move_state, x = x * 32, y = y * 32 })
end

function SwitchToPNB()
    local current_time = os.time()
    if state.mode_switching or (current_time - state.last_switch_time) < 5 then return end
    state.mode_switching = true
    state.last_switch_time = current_time
    if state.ptht_active then
        state.ptht_total_session = state.ptht_total_session + (os.time() - state.ptht_session_start_time)
        state.ptht_active = false
    end
    Log("`6[MODE SWITCH] PTHT magplant empty. Switching to PNB mode.")
    state.current_action = "Switching to PNB..."
    state.current_mode = "PNB"
    state.pnb_session_start_time = os.time()
    Sleep(2000)
    if TakeRemote("PNB") then
        state.pnb_last_remote_time = os.time()
        state.pnb_last_gem_check_time = os.time()
        state.pnb_last_gem_count = GetPlayerInfo().gems
        Log("`2PNB remote obtained. Moving to BFG location...")
        MoveTo(state.bfg_pos.x, state.bfg_pos.y)
        Sleep(2000)
        Log("`6Checking consume effects before enabling BFG cheat...")
        CheckConsumeEffects()
        Sleep(1500)
        if not state.is_consume_active then
            Log("`4No consume effects detected. Consuming items first...")
            PNB_ConsumeItems()
            Sleep(2000)
        else
            Log("`2Consume effects already active!")
        end
        PNB_EnableCheat()
        state.pnb_active = true
        state.consume_checked_on_switch = true
        Log("`2PNB mode activated successfully!")
    else
        Log("`4Failed to get PNB remote.")
        state.pnb_active = false
    end
    state.mode_switching = false
end

function SwitchToPTHT()
    local current_time = os.time()
    if state.mode_switching or (current_time - state.last_switch_time) < 5 then return end
    state.mode_switching = true
    state.last_switch_time = current_time
    if state.pnb_active then
        state.pnb_total_session = state.pnb_total_session + (os.time() - state.pnb_session_start_time)
        state.pnb_active = false
    end
    state.consume_checked_on_switch = false
    PNB_DisableCheat()
    Log("`6[MODE SWITCH] PNB magplant empty. Switching to PTHT mode.")
    state.current_action = "Switching to PTHT..."
    state.current_mode = "PTHT"
    state.ptht_session_start_time = os.time()
    _G.ptht_magplant_is_empty = false
    _G.pnb_magplant_is_empty = false
    if TakeRemote("PTHT") then
        Log("`2PTHT remote obtained. Running PTHT farm...")
        state.ptht_active = true
    else
        Log("`4Failed to get PTHT remote.")
        state.ptht_active = false
    end
    state.mode_switching = false
end

function DoPTHTLogic()
    if not state.ptht_active or _G.ptht_magplant_is_empty then return end
    local action = DetermineAction()
    state.current_action = "PTHT: " .. action
    if action == "HARVEST" then
        SmartHarvest()
    elseif action == "PLANT" then
        SmartPlant()
    elseif action == "UWS" then
        UseUWS()
    else
        Sleep(1000)
    end
end

function PNB_DoBuyLocks()
    local p_info = GetPlayerInfo()
    if not p_info or not state.telephone_pos then return end
    local phone_pos = state.telephone_pos
    local dl_id = 1796
    local bgl_id = 7188
    if cek(bgl_id) >= 100 then
        Log("`2PNB: Detected 100+ BGL. Converting to 'Ireng'...")
        SendPacket(2, "action|dialog_return\ndialog_name|info_box\nbuttonClicked|make_bgl")
        Sleep(2000)
        return
    end
    if cek(dl_id) >= 100 then
        Log("`2PNB: Detected 100+ DL. Converting to BGL...")
        SendPacket(2,
            "action|dialog_return\ndialog_name|telephone\nnum|53785|\nx|" ..
            phone_pos.x .. "|\ny|" .. phone_pos.y .. "|\nbuttonClicked|bglconvert")
        Sleep(2000)
        return
    end
    if config.pnb_bot_mode == 1 and p_info.gems >= 220000 then
        Log("PNB: Buying Diamond Lock...")
        SendPacket(2,
            "action|dialog_return\ndialog_name|telephone\nnum|53785|\nx|" ..
            phone_pos.x .. "|\ny|" .. phone_pos.y .. "|\nbuttonClicked|dlconvert")
        Sleep(1000)
    end
    if config.pnb_bot_mode == 2 and p_info.gems >= 22000000 then
        Log("PNB: Buying Blue Gem Lock...")
        SendPacket(2,
            "action|dialog_return\ndialog_name|telephone\nnum|53785|\nx|" ..
            phone_pos.x .. "|\ny|" .. phone_pos.y .. "|\nbuttonClicked|bglconvert2")
        Sleep(1000)
    end
end

function PNB_DoSuck()
    local now = os.time()
    if now < state.pnb_next_suck_time then return end
    local bgem_id = GetItemInfo("Black Gems").id
    local bgem_count = GetWorldObjects(bgem_id)
    if bgem_count >= config.pnb_bgems_drop then
        Log("PNB: Sucking `2" .. bgem_count .. " `bBlack Gems...")
        SendPacket(2, "action|dialog_return\ndialog_name|popup\nbuttonClicked|bgem_suckall\n\n")
        Sleep(1000)
        SendPacket(2, "action|dialog_return\ndialog_name|popup\nbuttonClicked|bgem_suckall\n\n")
        Sleep(1000)
        SendPacket(2, "action|dialog_return\ndialog_name|popup\nbuttonClicked|bgem_suckall\n\n")
        Sleep(1000)
        state.pnb_world_bgems_dropped = state.pnb_world_bgems_dropped + bgem_count
    end
    state.pnb_next_suck_time = now + (config.pnb_suck_cooldown * 60)
end

function DoPNBLogic()
    if not state.pnb_active or _G.pnb_magplant_is_empty then return end
    if state.needs_consume then
        Log("`4Effects worn off during PNB mode. Re-consuming...")
        PNB_DisableCheat()
        Sleep(500)
        PNB_ConsumeItems()
        Sleep(2000)
        PNB_EnableCheat()
        Log("`2BFG cheat re-enabled after consume!")
        return
    end
    if config.pnb_bot_mode == 3 then
        PNB_UpdateBankBgems()
    end
    state.current_action = "PNB MODE"

    local now = os.time()
    local player_gems = GetPlayerInfo().gems
    if now - state.pnb_last_gem_check_time >= 10 then
        if state.pnb_last_gem_count > 0 then
            local elapsed_time = now - state.pnb_last_gem_check_time
            if elapsed_time > 0 then
                local gained_gems = player_gems - state.pnb_last_gem_count
                state.pnb_gems_per_minute = math.floor((gained_gems / elapsed_time) * 60)
            end
        end
        state.pnb_last_gem_count = player_gems
        state.pnb_last_gem_check_time = now
    end

    state.pnb_magplant_duration = os.time() - state.pnb_last_remote_time

    if config.pnb_bot_mode == 1 or config.pnb_bot_mode == 2 then
        PNB_DoBuyLocks()
    elseif config.pnb_bot_mode == 3 then
        PNB_DoSuck()
    end
    Sleep(2000)
end

function RotationLoop()
    if not ScanWorldObjects() then
        Log("`4Aborting bot. Please set up your world correctly.")
        return
    end
    state.is_running = true
    state.current_mode = "PTHT"
    state.ptht_active = false
    state.pnb_active = false
    _G.ptht_magplant_is_empty = false
    _G.pnb_magplant_is_empty = false
    Log("Starting Rotation Bot. Initial mode: PTHT")
    CheckAndActivateEffects()
    if TakeRemote("PTHT") then
        state.ptht_active = true
        state.ptht_session_start_time = os.time()
        Log("`2Initial PTHT remote obtained successfully!")
    else
        Log("`4Initial PTHT magplant is empty. Starting with PNB.")
        _G.ptht_magplant_is_empty = true
    end
    state.bot_status = "RUNNING"
    while state.is_running do
        local current_time = os.time()
        state.current_gems = GetPlayerInfo().gems

        if config.use_webhook and (current_time - state.last_webhook_time >= config.webhook_interval * 60) then
            SendStatusWebhook()
            state.last_webhook_time = current_time
        end
        if state.need_reconnect then
            if not HandleReconnect() then
                break
            end
        end
        if _G.ptht_magplant_is_empty and state.current_mode == "PTHT" and not state.mode_switching then
            SwitchToPNB()
        elseif _G.pnb_magplant_is_empty and state.current_mode == "PNB" and not state.mode_switching then
            SwitchToPTHT()
        end
        if state.is_running and not state.mode_switching and not state.need_reconnect then
            if state.current_mode == "PTHT" and state.ptht_active then
                DoPTHTLogic()
            elseif state.current_mode == "PNB" and state.pnb_active then
                DoPNBLogic()
            end
        end
        Sleep(500)
    end
    PNB_DisableCheat()
    Log("`4Rotation has been stopped.")
    state.current_action = "IDLE"
    state.ptht_active = false
    state.pnb_active = false
end

local uws_seed_id = config.seed_id
local uws_detected_13_local, uws_detected_6_local = false, false
AddHook("onprocesstankupdatepacket", "simple_uws_hook", function(packet)
    if not state.is_running or state.current_mode ~= "PTHT" then return end
    if packet.type == 13 and packet.value == uws_seed_id then uws_detected_13_local = true end
    if packet.type == 6 then uws_detected_6_local = true end
    if uws_detected_13_local and uws_detected_6_local then
        _G.uws_tree_ready = true
        uws_detected_13_local, uws_detected_6_local = false, false
    end
end)

function RenderConfigTab()
    local changed, new_val
    local red = ImVec4(1, 0.3, 0.3, 1)
    local green = ImVec4(0.3, 1, 0.3, 1)

    ImGui.SeparatorText("GENERAL SETTINGS")

    ImGui.Text("Active Account:")
    if ImGui.RadioButton("ACC 1", config.active_account == 1) then config.active_account = 1 end; ImGui.SameLine()
    if ImGui.RadioButton("ACC 2", config.active_account == 2) then config.active_account = 2 end
    ImGui.Dummy(ImVec2(0, 5))

    if config.pnb_bot_mode ~= 0 then
        ImGui.BeginDisabled()
    end

    ImGui.Text("TAKE GEMS SETTINGS:");
    if ImGui.RadioButton("TAKE GEMS##takegems", config.pnb_take_gems == 1) then config.pnb_take_gems = 1 end; ImGui
        .SameLine()
    if ImGui.RadioButton("DON'T TAKE GEMS##takegems", config.pnb_take_gems == 0) then config.pnb_take_gems = 0 end

    if config.pnb_bot_mode ~= 0 then
        ImGui.EndDisabled()
    end
    ImGui.Dummy(ImVec2(0, 10))
    ImGui.Text("PNB Mode:")

    changed, new_val = ImGui.Checkbox("Auto Buy DL", config.pnb_bot_mode == 1)
    if changed then config.pnb_bot_mode = new_val and 1 or 0 end
    changed, new_val = ImGui.Checkbox("Auto Buy BGL", config.pnb_bot_mode == 2)
    if changed then config.pnb_bot_mode = new_val and 2 or 0 end
    changed, new_val = ImGui.Checkbox("Auto Suck BGems", config.pnb_bot_mode == 3)
    if changed then config.pnb_bot_mode = new_val and 3 or 0 end
    ImGui.Dummy(ImVec2(0, 10))

    ImGui.SeparatorText("PTHT SETTINGS")
    if ImGui.BeginTable("PthtConfig", 3, ImGuiTableFlags_PadInnerX) then
        ImGui.TableSetupColumn("Input", 0, 0.3)
        ImGui.TableSetupColumn("Label", 0, 0.3)
        ImGui.TableSetupColumn("Item Name", 0, 0.4)

        ImGui.TableNextRow(); ImGui.TableNextColumn(); ImGui.PushItemWidth(-1)
        changed, new_val = ImGui.InputInt("##seedid", config.seed_id); if changed then config.seed_id = new_val end
        ImGui.PopItemWidth()
        ImGui.TableNextColumn(); ImGui.Text("SEED ID")
        ImGui.TableNextColumn()
        local item_name = GetItemInfo(config.seed_id).name or "N/A"
        ImGui.TextColored(item_name == "N/A" and red or green, item_name)

        ImGui.TableNextRow(); ImGui.TableNextColumn(); ImGui.PushItemWidth(-1)
        changed, new_val = ImGui.InputInt("##platid", config.plat_id); if changed then config.plat_id = new_val end
        ImGui.PopItemWidth()
        ImGui.TableNextColumn(); ImGui.Text("PLATFORM ID")
        ImGui.TableNextColumn()
        local item_name = GetItemInfo(config.plat_id).name or "N/A"
        ImGui.TextColored(item_name == "N/A" and red or green, item_name)

        ImGui.TableNextRow(); ImGui.TableNextColumn(); ImGui.PushItemWidth(-1)
        changed, new_val = ImGui.InputInt("##magbgptht", config.mag_bg_id_ptht); if changed then
            config.mag_bg_id_ptht = new_val
        end
        ImGui.PopItemWidth()
        ImGui.TableNextColumn(); ImGui.Text("MAGPLANT BG ID")
        ImGui.TableNextColumn()
        item_name = GetItemInfo(config.mag_bg_id_ptht).name or "N/A"
        ImGui.TextColored(item_name == "N/A" and red or green, item_name)

        ImGui.TableNextRow(); ImGui.TableNextColumn(); ImGui.PushItemWidth(-1)
        changed, new_val = ImGui.InputInt("##delayplant", config.delay_plant); if changed then
            config.delay_plant = new_val
        end
        ImGui.PopItemWidth()
        ImGui.TableNextColumn(); ImGui.Text("DELAY PLANT")

        ImGui.TableNextRow(); ImGui.TableNextColumn(); ImGui.PushItemWidth(-1)
        changed, new_val = ImGui.InputInt("##delayharvest", config.delay_harvest); if changed then
            config.delay_harvest = new_val
        end
        ImGui.PopItemWidth()
        ImGui.TableNextColumn(); ImGui.Text("DELAY HARVEST")

        ImGui.TableNextRow(); ImGui.TableNextColumn(); ImGui.PushItemWidth(-1)
        changed, new_val = ImGui.InputInt("##uwsthreshold", config.uws_threshold, 1, 100, "%d%%"); if changed then
            config.uws_threshold = new_val
        end
        ImGui.PopItemWidth()
        ImGui.TableNextColumn(); ImGui.Text("UWS THRESHOLD")

        ImGui.EndTable()
    end

    ImGui.Dummy(ImVec2(0, 10))
    ImGui.SeparatorText("PNB SETTINGS")

    ImGui.Text("BFG Facing Direction:"); ImGui.SameLine()
    if ImGui.RadioButton("Right", config.pnb_bfg_facing == 1) then config.pnb_bfg_facing = 1 end; ImGui.SameLine()
    if ImGui.RadioButton("Left", config.pnb_bfg_facing == 2) then config.pnb_bfg_facing = 2 end

    if ImGui.BeginTable("PnbConfig", 3, ImGuiTableFlags_PadInnerX) then
        ImGui.TableSetupColumn("Input", 0, 0.3)
        ImGui.TableSetupColumn("Label", 0, 0.3)
        ImGui.TableSetupColumn("Item Name", 0, 0.4)

        ImGui.TableNextRow(); ImGui.TableNextColumn(); ImGui.PushItemWidth(-1)
        changed, new_val = ImGui.InputInt("##bfgid", config.bfg_id); if changed then config.bfg_id = new_val end
        ImGui.PopItemWidth()
        ImGui.TableNextColumn(); ImGui.Text("BFG ID")
        ImGui.TableNextColumn()
        local item_name = GetItemInfo(config.bfg_id).name or "N/A"
        ImGui.TextColored(item_name == "N/A" and red or green, item_name)

        ImGui.TableNextRow(); ImGui.TableNextColumn(); ImGui.PushItemWidth(-1)
        changed, new_val = ImGui.InputInt("##magbgpnb", config.mag_bg_id_pnb); if changed then
            config.mag_bg_id_pnb = new_val
        end
        ImGui.PopItemWidth()
        ImGui.TableNextColumn(); ImGui.Text("MAGPLANT BG ID")
        ImGui.TableNextColumn()
        item_name = GetItemInfo(config.mag_bg_id_pnb).name or "N/A"
        ImGui.TextColored(item_name == "N/A" and red or green, item_name)

        ImGui.TableNextRow(); ImGui.TableNextColumn(); ImGui.PushItemWidth(-1)
        changed, new_val = ImGui.InputInt("##consume1", config.pnb_consume_id_1); if changed then
            config.pnb_consume_id_1 = new_val
        end
        ImGui.PopItemWidth()
        ImGui.TableNextColumn(); ImGui.Text("CONSUME ID 1")
        ImGui.TableNextColumn()
        item_name = GetItemInfo(config.pnb_consume_id_1).name or "N/A"
        ImGui.TextColored(item_name == "N/A" and red or green, item_name)

        ImGui.TableNextRow(); ImGui.TableNextColumn(); ImGui.PushItemWidth(-1)
        changed, new_val = ImGui.InputInt("##consume2", config.pnb_consume_id_2); if changed then
            config.pnb_consume_id_2 = new_val
        end
        ImGui.PopItemWidth()
        ImGui.TableNextColumn(); ImGui.Text("CONSUME ID 2")
        ImGui.TableNextColumn()
        item_name = GetItemInfo(config.pnb_consume_id_2).name or "N/A"
        ImGui.TextColored(item_name == "N/A" and red or green, item_name)

        ImGui.TableNextRow(); ImGui.TableNextColumn(); ImGui.PushItemWidth(-1)
        changed, new_val = ImGui.InputInt("##bgemsdrop", config.pnb_bgems_drop); if changed then
            config.pnb_bgems_drop = new_val
        end
        ImGui.PopItemWidth()
        ImGui.TableNextColumn(); ImGui.Text("Min Black Gems to Suck")

        ImGui.TableNextRow(); ImGui.TableNextColumn(); ImGui.PushItemWidth(-1)
        changed, new_val = ImGui.InputInt("##suckcooldown", config.pnb_suck_cooldown); if changed then
            config.pnb_suck_cooldown = new_val
        end
        ImGui.PopItemWidth()
        ImGui.TableNextColumn(); ImGui.Text("Suck Cooldown (min)")

        ImGui.EndTable()
    end

    ImGui.Dummy(ImVec2(0, 10))
    ImGui.SeparatorText("WEBHOOK SETTINGS")

    changed, new_val = ImGui.Checkbox("Enable Webhook", config.use_webhook); if changed then config.use_webhook = new_val end

    if not config.use_webhook then ImGui.BeginDisabled() end

    ImGui.Text("Webhook URL")
    ImGui.PushItemWidth(-1)
    changed, new_val = ImGui.InputText("##webhookurl", config.webhook_url, 512); if changed then
        config.webhook_url = new_val
    end
    ImGui.PopItemWidth()

    ImGui.Text("Discord User ID")
    ImGui.PushItemWidth(-1)
    changed, new_val = ImGui.InputText("##discordid", config.discord_user_id, 256); if changed then
        config.discord_user_id = new_val
    end
    ImGui.PopItemWidth()

    ImGui.Text("Webhook Interval (minutes)")
    ImGui.PushItemWidth(-1)
    changed, new_val = ImGui.InputInt("##webhookinterval", config.webhook_interval); if changed then
        config.webhook_interval = new_val
    end
    ImGui.PopItemWidth()

    if not config.use_webhook then ImGui.EndDisabled() end

    ImGui.Dummy(ImVec2(0, 10))
    ImGui.Separator()
    ImGui.Dummy(ImVec2(0, 5))

    if ImGui.Button("Save Config", ImVec2(120, 30)) then
        SaveConfig()
    end
    ImGui.SameLine()
    if ImGui.Button("Load Config", ImVec2(120, 30)) then
        LoadConfig()
    end
end

function RenderStatusTab()
    local green = ImVec4(0.3, 1, 0.3, 1)
    local red = ImVec4(1, 0.3, 0.3, 1)
    local cyan = ImVec4(0.2, 0.8, 1, 1)
    local yellow = ImVec4(1, 1, 0.2, 1)
    local gray = ImVec4(0.7, 0.7, 0.7, 1)

    ImGui.TextColored(cyan, "GENERAL STATUS")
    ImGui.Separator()

    local running_time = state.is_running and (os.time() - state.session_start_time) or 0
    local current_gems = GetPlayerInfo().gems
    local gem_profit = current_gems - state.initial_gems
    local profit_color = gem_profit >= 0 and green or red
    local rotate_item = GetItemInfo(config.seed_id).name

    if ImGui.BeginTable("GeneralStatus", 2, ImGuiTableFlags_PadInnerX) then
        ImGui.TableNextRow(); ImGui.TableNextColumn(); ImGui.Text("Rotating item:"); ImGui.TableNextColumn()
        ImGui.TextColored(gray, rotate_item)

        ImGui.TableNextRow(); ImGui.TableNextColumn(); ImGui.Text("Running Time"); ImGui.TableNextColumn()
        ImGui.TextColored(yellow, FormatTime(running_time))

        ImGui.TableNextRow(); ImGui.TableNextColumn(); ImGui.Text("Gem Profit"); ImGui.TableNextColumn()
        ImGui.TextColored(profit_color, (gem_profit >= 0 and "+" or "") .. KOMA(gem_profit))

        ImGui.TableNextRow(); ImGui.TableNextColumn(); ImGui.Text("Current Gems"); ImGui.TableNextColumn()
        ImGui.TextColored(yellow, KOMA(current_gems))
        ImGui.EndTable()
    end

    ImGui.Dummy(ImVec2(0, 10))

    if state.current_mode == "PTHT" then
        ImGui.SeparatorText("MODE STATUS: PTHT")
        if ImGui.BeginTable("PthtStatus", 2, ImGuiTableFlags_PadInnerX) then
            local ptht_current_session_duration = 0
            if state.ptht_active then
                ptht_current_session_duration = os.time() - state.ptht_session_start_time
            end
            ImGui.TableNextRow(); ImGui.TableNextColumn(); ImGui.Text("PTHT Session Time"); ImGui.TableNextColumn()
            ImGui.TextColored(yellow, FormatTime(ptht_current_session_duration))

            ImGui.TableNextRow(); ImGui.TableNextColumn(); ImGui.Text("Total Cycles"); ImGui.TableNextColumn()
            ImGui.TextColored(cyan, tostring(state.ptht_cycle_count))

            ImGui.TableNextRow(); ImGui.TableNextColumn(); ImGui.Text("Avg Time/Cycle"); ImGui.TableNextColumn()
            ImGui.TextColored(yellow, FormatTime(state.ptht_avg_time_per_cycle))

            ImGui.TableNextRow(); ImGui.TableNextColumn(); ImGui.Text("UWS Used"); ImGui.TableNextColumn()
            ImGui.Text(string.format("%d (Remaining: %d)", state.uws_used, cek(GetItemInfo("Ultra World Spray").id)))

            ImGui.TableNextRow(); ImGui.TableNextColumn(); ImGui.Text("Current Action"); ImGui.TableNextColumn()
            ImGui.TextColored(cyan, state.current_action)
            ImGui.EndTable()
        end

        ImGui.Dummy(ImVec2(0, 5))

        local total_platforms = state.platforms > 0 and state.platforms or 1
        local plant_progress = (state.seeds + state.seeds_planted_this_cycle) / total_platforms
        local display_seeds = state.seeds + state.seeds_planted_this_cycle
        local percentage_text = string.format("%.0f%%", plant_progress * 100)

        ImGui.ProgressBar(plant_progress, ImVec2(-1, 0),
            string.format("%d / %d (%s)", display_seeds, state.platforms, percentage_text))
    elseif state.current_mode == "PNB" then
        ImGui.SeparatorText("MODE STATUS: PNB")
        if ImGui.BeginTable("PnbStatus", 2, ImGuiTableFlags_PadInnerX) then
            local pnb_current_session_duration = 0
            if state.pnb_active then
                pnb_current_session_duration = os.time() - state.pnb_session_start_time
            end
            ImGui.TableNextRow(); ImGui.TableNextColumn(); ImGui.Text("PNB Session Time"); ImGui.TableNextColumn()
            ImGui.TextColored(yellow, FormatTime(pnb_current_session_duration))

            ImGui.TableNextRow(); ImGui.TableNextColumn(); ImGui.Text("Remote Duration"); ImGui.TableNextColumn()
            ImGui.TextColored(yellow, FormatTime(state.pnb_magplant_duration))

            ImGui.TableNextRow(); ImGui.TableNextColumn(); ImGui.Text("Gems Per Minute"); ImGui.TableNextColumn()
            ImGui.TextColored(green, KOMA(state.pnb_gems_per_minute))

            ImGui.TableNextRow(); ImGui.TableNextColumn(); ImGui.Text("Current Action"); ImGui.TableNextColumn()
            ImGui.TextColored(cyan, state.current_action)

            local time_left1 = math.max(0, state.consume1_end_time - os.time())
            local time_left2 = math.max(0, state.consume2_end_time - os.time())

            ImGui.TableNextRow(); ImGui.TableNextColumn(); ImGui.Text("Buff Consume 1"); ImGui.TableNextColumn()
            ImGui.TextColored(yellow, FormatTime(time_left1))

            ImGui.TableNextRow(); ImGui.TableNextColumn(); ImGui.Text("Buff Consume 2"); ImGui.TableNextColumn()
            ImGui.TextColored(yellow, FormatTime(time_left2))

            ImGui.EndTable()
        end

        ImGui.Dummy(ImVec2(0, 5))

        if config.pnb_bot_mode == 1 or config.pnb_bot_mode == 2 then
            ImGui.SeparatorText("PROFIT LOCKS")

            local dl_profit = state.pnb_current_dl - state.pnb_initial_dl
            local bgl_profit = state.pnb_current_bgl - state.pnb_initial_bgl
            local irg_profit = state.pnb_current_irg - state.pnb_initial_irg

            local profit_text = ""
            if irg_profit > 0 then profit_text = profit_text .. "Ireng: +" .. irg_profit .. " | " end
            if bgl_profit > 0 then profit_text = profit_text .. "BGL: +" .. bgl_profit .. " | " end
            if dl_profit > 0 then profit_text = profit_text .. "DL: +" .. dl_profit .. " | " end

            if profit_text:sub(-3) == " | " then
                profit_text = profit_text:sub(1, -4)
            end

            if profit_text == "" then
                profit_text = "No lock profit yet."
            end

            ImGui.Text(profit_text)
        elseif config.pnb_bot_mode == 3 then
            local bgem_profit = state.pnb_current_bgems_bank - state.pnb_initial_bgems_bank
            if ImGui.BeginTable("BGemStatus", 2, ImGuiTableFlags_PadInnerX) then
                ImGui.TableNextRow(); ImGui.TableNextColumn(); ImGui.Text("BGems in Bank"); ImGui.TableNextColumn()
                ImGui.TextColored(yellow, KOMA(state.pnb_current_bgems_bank))

                ImGui.TableNextRow(); ImGui.TableNextColumn(); ImGui.Text("BGems Profit"); ImGui.TableNextColumn()
                ImGui.TextColored(green, "+" .. KOMA(bgem_profit))

                ImGui.TableNextRow(); ImGui.TableNextColumn(); ImGui.Text("BGems in World"); ImGui.TableNextColumn()
                ImGui.TextColored(cyan, KOMA(state.pnb_world_bgems_dropped))
                ImGui.EndTable()
            end
        end
    end
end



function RenderUI()
    if not config.show_window then return end
    if config.lock_window_position then
        ImGui.SetNextWindowPos(ImVec2(0, 0), ImGui.Cond.Always)
    end
    ImGui.SetNextWindowBgAlpha(config.window_alpha)
    local is_begin_success, new_show_window_val = ImGui.Begin("ROTASI PREMIUM - 1K4N Community", config.show_window)
    config.show_window = new_show_window_val
    if not is_begin_success then
        ImGui.End()
        return
    end
    ImGui.BeginGroup()
    local changed_lock, new_lock = ImGui.Checkbox("LOCK", config.lock_window_position)
    if changed_lock then config.lock_window_position = new_lock end
    ImGui.EndGroup()
    ImGui.SameLine(0, 20)
    ImGui.BeginGroup()
    ImGui.PushItemWidth(200)
    local changed_alpha, new_alpha = ImGui.SliderFloat("Transparansi", config.window_alpha, 0.2, 1.0)
    if changed_alpha then config.window_alpha = new_alpha end
    ImGui.PopItemWidth()
    ImGui.EndGroup()
    ImGui.Separator()
    ImGui.BeginGroup()
    if not state.is_running then
        if ImGui.Button("START", ImVec2(120, 30)) then
            start_bot()
        end
    else
        if ImGui.Button("STOP", ImVec2(120, 30)) then
            stop_bot()
        end
    end
    ImGui.EndGroup()
    ImGui.SameLine(0, ImGui.GetWindowWidth() * 0.10)
    ImGui.BeginGroup()
    local status_color = ImVec4(1, 0, 0, 1)
    if state.bot_status == "RUNNING" then
        status_color = ImVec4(0, 1, 0, 1)
    elseif state.bot_status == "STARTING" or state.bot_status == "SWITCHING" then
        status_color = ImVec4(1, 1, 0, 1)
    end
    ImGui.Text("STATUS:"); ImGui.SameLine(); ImGui.TextColored(status_color, state.bot_status)
    ImGui.Text("MODE:"); ImGui.SameLine(); ImGui.TextColored(ImVec4(0.2, 0.8, 1, 1), state.current_mode)
    ImGui.EndGroup()
    ImGui.Separator()
    if ImGui.BeginTabBar("MainTabBar") then
        if not state.is_running then
            if ImGui.BeginTabItem("Configuration") then
                RenderConfigTab()
                ImGui.EndTabItem()
            end
        else
            if ImGui.BeginTabItem("Status") then
                RenderStatusTab()
                ImGui.EndTabItem()
            end
        end
        ImGui.EndTabBar()
    end
    ImGui.End()
end

AddHook("OnDraw", "Rotasi_UI_Hook", RenderUI)
AddHook("OnInput", "Rotasi_Toggle_Hook", function(key)
    if key == 116 then
        config.show_window = not config.show_window
        return true
    end
    return false
end)

function EscapeJsonString(str)
    if not str then return "" end
    str = tostring(str)
    str = str:gsub('\\', '\\\\')
    str = str:gsub('"', '\\"')
    str = str:gsub('\n', '\\n')
    str = str:gsub('\r', '\\r')
    str = str:gsub('\t', '\\t')
    return str
end

function SendStatusWebhook()
    if not config.use_webhook or config.webhook_url:find("MASUKKAN") or config.webhook_url == "" then
        return
    end
    local fields = {}

    local running_time = os.time() - state.session_start_time
    local gem_profit = state.current_gems - state.initial_gems
    local player_name = EscapeJsonString(GetLocal() and GetLocal().name or "Unknown")
    local embed_color = 3447003
    local embed_title = "BOT ROTATION STATUS REPORT"
    local rotate_item = GetItemInfo(config.seed_id).name

    table.insert(fields, {
        name = "────────────────────\\n⌞<:world:1398273141150847046>⌝ **BOT INFO**",
        value = "**Account:** " .. cleanText(player_name) ..
            "\\n**World:** " .. state.world_name ..
            "\\n**Rotating item:** " .. rotate_item ..
            "\\n**Running Time:** " .. FormatTime(running_time),
        inline = false
    })

    table.insert(fields, {
        name = "⌞<:gems:1398274904666669129>⌝ **GEMS INFO**",
        value = "**Session Profit:** " .. (gem_profit >= 0 and "+" or "") .. KOMA(gem_profit) ..
            "\\n**Total Gems:** " .. KOMA(state.current_gems),
        inline = false
    })

    if state.current_mode == "PTHT" then
        embed_color = 3447003
        embed_title = "PTHT MODE REPORT"

        local ptht_current_session_duration = 0
        if state.ptht_active then
            ptht_current_session_duration = os.time() - state.ptht_session_start_time
        end

        table.insert(fields, {
            name = "────────────────────\\n⌞<:PTHT:1342116678045139045>⌝ **PTHT STATUS**",
            value = "**Action:** " .. EscapeJsonString(state.current_action) ..
                "\\n**Total Cycles:** " .. state.ptht_cycle_count ..
                "\\n**PTHT Session Time:** " .. FormatTime(ptht_current_session_duration) ..
                "\\n**Average Time per Cycle:** " .. FormatTime(state.ptht_avg_time_per_cycle),
            inline = false
        })

        table.insert(fields, {
            name = "⌞<:UWS:1262820548225007616>⌝ **UWS STATUS**",
            value = "**Used:** " .. state.uws_used ..
                "\\n**Remaining in Bag:** " .. cek(GetItemInfo("Ultra World Spray").id),
            inline = false
        })
    elseif state.current_mode == "PNB" then
        embed_color = 15158332
        embed_title = "PNB MODE REPORT"

        local pnb_current_session_duration = 0
        if state.pnb_active then
            pnb_current_session_duration = os.time() - state.pnb_session_start_time
        end

        table.insert(fields, {
            name = "────────────────────\\n⌞<:bothaxpc:1249259697492459652>⌝ **PNB STATUS**",
            value = "**Action:** " .. EscapeJsonString(state.current_action) ..
                "\\n**PNB Session Time:** " .. FormatTime(pnb_current_session_duration) ..
                "\\n**Current Remote Duration:** " .. FormatTime(state.pnb_magplant_duration) ..
                "\\n**Gems per Minute:** " .. KOMA(state.pnb_gems_per_minute),
            inline = false
        })

        local time_left1 = math.max(0, state.consume1_end_time - os.time())
        local time_left2 = math.max(0, state.consume2_end_time - os.time())

        table.insert(fields, {
            name = "⌞<a:Alert:1224962255909683240>⌝ **CONSUMABLE STATUS**",
            value = "**Buff 1 Expires In:** " .. FormatTime(time_left1) ..
                "\\n**Buff 2 Expires In:** " .. FormatTime(time_left2),
            inline = false
        })

        if config.pnb_bot_mode == 1 or config.pnb_bot_mode == 2 then
            local dl_profit = state.pnb_current_dl - state.pnb_initial_dl
            local bgl_profit = state.pnb_current_bgl - state.pnb_initial_bgl
            local irg_profit = state.pnb_current_irg - state.pnb_initial_irg

            local profit_text = ""
            if irg_profit > 0 then profit_text = profit_text .. "Ireng: +" .. irg_profit .. " | " end
            if bgl_profit > 0 then profit_text = profit_text .. "BGL: +" .. bgl_profit .. " | " end
            if dl_profit > 0 then profit_text = profit_text .. "DL: +" .. dl_profit .. " | " end

            if profit_text:sub(-3) == " | " then
                profit_text = profit_text:sub(1, -4)
            end

            if profit_text == "" then
                profit_text = "No lock profit yet."
            end

            table.insert(fields, {
                name = "⌞<a:BLUEPIN:1274650242683502685>⌝ **PROFIT LOCKS**",
                value = profit_text,
                inline = false
            })
        elseif config.pnb_bot_mode == 3 then
            local bgem_profit = state.pnb_current_bgems_bank - state.pnb_initial_bgems_bank

            table.insert(fields, {
                name = "⌞<:bgems:1341902572356763669>⌝ **BGEMS PROFIT**",
                value = "**Session Profit:** +" .. KOMA(bgem_profit) ..
                    "\\n**BGems in Bank:** " .. KOMA(state.pnb_current_bgems_bank) ..
                    "\\n**BGems in World:** " .. KOMA(state.pnb_world_bgems_dropped),
                inline = false
            })
        end
    end

    local fields_json = ""
    for i, field in ipairs(fields) do
        fields_json = fields_json ..
            string.format('{"name":"%s","value":"%s","inline":%s}', field.name, field.value, tostring(field.inline))
        if i < #fields then fields_json = fields_json .. "," end
    end

    local footer_text = string.format("🚀 1K4N COMMUNITY • ROTATION • %s", os.date("%Y-%m-%d %H:%M:%S"))

    local payload = string.format([[
    {
        "username": "ROTASI - 1K4N COMMUNITY",
        "avatar_url": "https://media.discordapp.net/attachments/1397494990480871464/1397600589474693313/image.png",
        "embeds": [{
            "title": "⌞<:binternal:1396960071291900024>⌝ | %s",
            "description": "Current Mode: **%s**",
            "color": %d,
            "fields": [%s],
            "thumbnail": { "url": "https://media.discordapp.net/attachments/1397494990480871464/1398596566415314984/ble.gif" },
            "image": { "url": "https://media.discordapp.net/attachments/1397494990480871464/1398595921125834815/1K4NBANNER.png" },
            "footer": { "text": "%s", "icon_url": "https://media.discordapp.net/attachments/1339707323035160638/1339955286739390495/a.jpg" }
        }]
    }
    ]], embed_title, state.current_mode, embed_color, fields_json, EscapeJsonString(footer_text))

    MakeRequest(config.webhook_url, "POST", { ["Content-Type"] = "application/json" }, payload)
end

function SendAlertWebhook(alert_title, alert_message)
    if not config.use_webhook or config.webhook_url:find("MASUKKAN") or config.webhook_url == "" then
        return
    end
    local discord_ping = ""
    if config.discord_user_id and config.discord_user_id ~= "" and not config.discord_user_id:find("MASUKKAN") then
        discord_ping = "<@" .. config.discord_user_id .. ">"
    end

    local fields = {}
    table.insert(fields, { name = "Alert Message", value = alert_message, inline = false })
    table.insert(fields, { name = "Current Mode", value = state.current_mode, inline = true })
    table.insert(fields, { name = "Last Action", value = state.current_action, inline = true })

    local fields_json = ""
    for i, field in ipairs(fields) do
        fields_json = fields_json ..
            string.format('{"name":"%s","value":"%s","inline":%s}', EscapeJsonString(field.name),
                EscapeJsonString(field.value), tostring(field.inline))
        if i < #fields then fields_json = fields_json .. "," end
    end

    local footer_text = string.format("🚀 1K4N COMMUNITY • ALERT • %s", os.date("%Y-%m-%d %H:%M:%S"))

    local payload = string.format([[
    {
        "username": "ROTASI - 1K4N COMMUNITY",
        "avatar_url": "https://media.discordapp.net/attachments/1397494990480871464/1397600589474693313/image.png",
        "content": "%s",
        "embeds": [{
            "title": "⌞<a:Alert:1224962255909683240>⌝ BOT ALERT: %s",
            "description": "The bot requires your attention!",
            "color": 16711680,
            "fields": [%s],
            "footer": {"text": "%s"}
        }]
    }
    ]], discord_ping, EscapeJsonString(alert_title), fields_json, EscapeJsonString(footer_text))

    MakeRequest(config.webhook_url, "POST", { ["Content-Type"] = "application/json" }, payload)
end

AddHook("onvariant", "simple_main_hook", function(var)
    if not state.is_running and var[0] ~= "OnDialogRequest" then return false end

    local event_type = var[0]

    if event_type == "OnTalkBubble" then
        local message = var[2] or ""

        if message:find("You received a MAGPLANT 5000 Remote.") then
            Log("`2Remote obtained successfully!")
            _G.remote_obtained_success = true
            return true
        end

        if not state.taking_remote and not state.mode_switching and message:find("The MAGPLANT 5000 is empty.") then
            if state.current_mode == "PTHT" and state.ptht_active and not _G.ptht_magplant_is_empty then
                Log("`6PTHT Magplant empty detected.")
                _G.ptht_magplant_is_empty = true
                state.ptht_active = false
            elseif state.current_mode == "PNB" and state.pnb_active and not _G.pnb_magplant_is_empty then
                Log("`6PNB Magplant empty detected.")
                _G.pnb_magplant_is_empty = true
                state.pnb_active = false
            end
            return true
        end
    elseif event_type == "OnDialogRequest" then
        local dialog = var[1] or ""

        if dialog:find("MAGPLANT 5000") then
            return true
        end

        if dialog:find("Telephone") and (config.pnb_bot_mode == 1 or config.pnb_bot_mode == 2) then
            return true
        end

        if dialog:find("Wow, that's fast delivery") and (dialog:find("Excellent!")) then
            return true
        end

        if dialog:find("add_player_info") then
            state.is_ghost_active = (dialog:find("Ghost in the shell") ~= nil)
            state.is_mray_active = (dialog:find("Mythical Powers") ~= nil)
            state.is_consume_active = (dialog:find("Lucky!") ~= nil or dialog:find("Food: Breaking Gems") ~= nil)

            local food_mins, food_secs = dialog:match("Food: Breaking Gems.-%(%s*(%d+)%s*mins?,%s*(%d+)%s*secs?%s*left%)")
            local luck_mins, luck_secs = dialog:match("Lucky!.-%(%s*(%d+)%s*mins?,%s*(%d+)%s*secs?%s*left%)")
            if food_mins then state.consume1_end_time = os.time() + (tonumber(food_mins) * 60 + tonumber(food_secs or 0)) else state.consume1_end_time = 0 end
            if luck_mins then state.consume2_end_time = os.time() + (tonumber(luck_mins) * 60 + tonumber(luck_secs or 0)) else state.consume2_end_time = 0 end
            return true
        end

        if not state.taking_remote and not state.mode_switching and dialog:find("`6The machine is currently empty!``") then
            if state.current_mode == "PTHT" and state.ptht_active and not _G.ptht_magplant_is_empty then
                Log("`6PTHT Magplant empty detected.")
                _G.ptht_magplant_is_empty = true
                state.ptht_active = false
            elseif state.current_mode == "PNB" and state.pnb_active and not _G.pnb_magplant_is_empty then
                Log("`6PNB Magplant empty detected.")
                _G.pnb_magplant_is_empty = true
                state.pnb_active = false
            end
            return true
        end

        if dialog:find("`bThe Black Backpack````") or dialog:find("bgem_suckall") then
            local gems_text = dialog:match("You have `%$([%d,]+)`` Black Gems") or
                dialog:match("You have `$(%d+)`` Black Gems")
            if gems_text then
                local gems_value = tonumber((gems_text:gsub(",", "")))
                if gems_value then
                    if state.pnb_initial_bgems_bank == 0 then
                        state.pnb_initial_bgems_bank = gems_value
                        Log("Initial BGems in bank set to: " .. KOMA(gems_value))
                    end
                    state.pnb_current_bgems_bank = gems_value
                end
            end
            return true
        end
    elseif event_type == "OnConsoleMessage" then
        if not state.is_running then return false end
        local message = var[1]
        if not message then return false end

        if (message:find("`oYour luck has worn off.") or message:find("`oYour stomach's rumbling.")) and state.current_mode == "PNB" and state.pnb_active then
            Log("`4Effects worn off during PNB mode - Auto re-consume!")
            state.needs_consume = true
            state.is_consume_active = false
            return true
        end

        if message:find("Disconnected") or message:find("Where would you like to go?") then
            Log("`4Connection issue detected. Auto reconnect.")
            state.need_reconnect = true
            return true
        end
    end

    return false
end)

function start_bot()
    if state.is_running then
        Log("`6Bot is already running."); return
    end

    PNB_DisableCheat()
    ResetAndInitializeStats()
    state.bot_status = "STARTING"
    RunThread(RotationLoop)
end

function stop_bot()
    if not state.is_running then
        Log("`6Bot is not running."); return
    end
    state.is_running = false
    if state.ptht_active then
        state.ptht_total_session = state.ptht_total_session + (os.time() - state.ptht_session_start_time)
    elseif state.pnb_active then
        state.pnb_total_session = state.pnb_total_session + (os.time() - state.pnb_session_start_time)
    end
    state.ptht_active = false
    state.pnb_active = false
    PNB_DisableCheat()
    state.bot_status = "STOPPED"
    state.current_action = "IDLE"
end