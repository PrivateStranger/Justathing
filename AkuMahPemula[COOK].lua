local script_state = "CONFIGURING"
local stop_requested = false
local cycle_count = 0
local WEBHOOK_CYCLE_INTERVAL = 10
local WEBHOOK_URL = "WEBHOOK LINKS"
local COLLECT_DELAY = 75
ChangeValue("[C] Modfly", true)
local CONFIG = {
    RECIPE = "ARROZ",
    COOKING_POS_ID = 1308,
    EGGS_CONFIG = {
        HEAT_MODE = "LOW",
        GRID_SIZE = { width = 11, height = 11 },
        DELAY_BETWEEN_OVENS_MS = 500,
        RESTOCK_FAIL_WAIT_S = 30,
        RESTOCK_COLLECT_DELAY_MS = 500,
        TARGET_COOKED_ITEM = GetItemInfo("Eggs Benedict").id,
        VEND_THRESHOLD = 250
    },
    ARROZ_CONFIG = {
        HEAT_MODE = "HIGH",
        GRID_SIZE = { width = 7, height = 7 },
        DELAY_BETWEEN_OVENS_MS = 200,
        RESTOCK_FAIL_WAIT_S = 30,
        RESTOCK_COLLECT_DELAY_MS = 500,
        TARGET_COOKED_ITEM = GetItemInfo("Arroz Con Pollo").id,
        VEND_THRESHOLD = 250
    }
}

local TIMELINES = {
    EGGS = {
        LOW    = { DOUGH = 0, EGG = 100, BACON = 10000, MILK = 26000, SALT = 30000, COLLECT = 60000 },
        MEDIUM = { DOUGH = 0, EGG = 100, BACON = 5000, MILK = 13000, SALT = 15000, COLLECT = 30000 },
        HIGH   = { DOUGH = 0, EGG = 100, BACON = 3330, MILK = 8660, SALT = 10000, COLLECT = 20000 }
    },
    ARROZ = {
        LOW    = { RICE = 0, PEPPER1 = 100, CHICKEN = 33700, ONION = 33800, TOMATO = 70000, SALT = 70100, PEPPER2 = 99900, COLLECT = 100000 },
        MEDIUM = { RICE = 0, PEPPER1 = 100, CHICKEN = 16850, ONION = 16950, TOMATO = 35000, SALT = 35100, PEPPER2 = 49900, COLLECT = 50000 },
        HIGH   = { RICE = 0, PEPPER1 = 100, CHICKEN = 11230, ONION = 11430, TOMATO = 23330, SALT = 23730, PEPPER2 = 33030, COLLECT = 33330 }
    }
}

function table.copy(t)
    local t2 = {}
    for k, v in pairs(t) do
        if type(v) == "table" then
            t2[k] = table.copy(v)
        else
            t2[k] = v
        end
    end
    return t2
end

local ui_config = {
    cooking_pos_id = CONFIG.COOKING_POS_ID,
    recipe = "ARROZ",
    config_mode = "DEFAULT",
    heat_mode = "HIGH",
    use_webhook = false,
    webhook_url = WEBHOOK_URL,
    webhook_interval = WEBHOOK_CYCLE_INTERVAL,
    arroz_grid_w = CONFIG.ARROZ_CONFIG.GRID_SIZE.width,
    arroz_grid_h = CONFIG.ARROZ_CONFIG.GRID_SIZE.height,
    arroz_delay = CONFIG.ARROZ_CONFIG.DELAY_BETWEEN_OVENS_MS,
    arroz_manual_timelines = table.copy(TIMELINES.ARROZ),
    eggs_grid_w = CONFIG.EGGS_CONFIG.GRID_SIZE.width,
    eggs_grid_h = CONFIG.EGGS_CONFIG.GRID_SIZE.height,
    eggs_delay = CONFIG.EGGS_CONFIG.DELAY_BETWEEN_OVENS_MS,
    eggs_manual_timelines = table.copy(TIMELINES.EGGS)
}


local Success_cook, Failed_cook = 0, 0
local cooking_active = false
local current_phase = "IDLE"
local script_start_time = 0

local oven_coords, oven_status, oven_count = {}, {}, 0
local vendCount, vendList, vendfull = 0, {}, false

local Trash_id = GetItemInfo("Disgusting Mess").id
local Trash_id2 = GetItemInfo("Bland Mush").id

local script_boot_time = os.time()
local ITEM_IDS = {}
local cooking_pos = {}

local function getCurrentConfig()
    if CONFIG.RECIPE == "ARROZ" then
        return CONFIG.ARROZ_CONFIG
    else
        return CONFIG.EGGS_CONFIG
    end
end

function GetWorldObjects(itemId)
    local total = 0
    local objectList = GetObjectList()
    if objectList then
        for _, obj in pairs(objectList) do
            if obj.id == itemId then
                total = total + obj.amount
            end
        end
    end
    return total
end

function FormatNumber(num)
    if not num then return "0" end
    num = math.floor(num + 0.5)
    local formatted = tostring(num)
    local k = 3
    while k < #formatted do
        formatted = formatted:sub(1, #formatted - k) .. "," .. formatted:sub(#formatted - k + 1)
        k = k + 4
    end
    return formatted
end

function SendWebhook()
    if not ui_config.use_webhook then return end

    local currentConfig = getCurrentConfig()
    local ingredient_lines = {}

    for name, id in pairs(ITEM_IDS) do
        local total = GetWorldObjects(id)
        table.insert(ingredient_lines, name:upper() .. " : " .. FormatNumber(total))
    end

    local ingredient_text = table.concat(ingredient_lines, "\\n")

    local runtime_sec = os.time() - script_boot_time
    local hours = math.floor(runtime_sec / 3600)
    local minutes = math.floor((runtime_sec % 3600) / 60)
    local seconds = runtime_sec % 60
    local runtime_str = hours .. " Hours " .. minutes .. " Minutes " .. seconds .. " Seconds "

    local runtime_h = runtime_sec / 3600
    local cycles_per_hour = runtime_h > 0 and (cycle_count / runtime_h) or 0

    local total_attempt = Success_cook + Failed_cook
    local success_rate = total_attempt > 0 and (Success_cook / total_attempt * 100) or 0

    local payload = [[{
        "username": "COOKING CHEF - 1K4N COMMUNITY",
        "avatar_url": "https://media.discordapp.net/attachments/1397494990480871464/1397600589474693313/image.png",
        "content": null,
        "embeds": [{
            "title": "COOK MODE ]] .. CONFIG.RECIPE .. [[",
            "color": 3447003,
            "fields": [
                {
                    "name": "────────────────────\n**CYCLE COMPLETED : ]] .. cycle_count .. [[**",
                    "value": "SUCCESS : ]] ..
        Success_cook .. [[ <:arroz:1341902107506376825>\nFAILED : ]] .. Failed_cook .. [[ <:trash:1406984715533291530>",
                    "inline": false
                },
                {
                    "name": "────────────────────\n**COOKING STATUS**",
                    "value": "]] ..
        CONFIG.RECIPE ..
        [[ In Inventory : ]] .. GetItemCount(currentConfig.TARGET_COOKED_ITEM) .. [[\nVENDING : ]] .. vendCount .. [[",
                    "inline": false
                },
                {
                    "name": "────────────────────\n**INGREDIENT STOCK**",
                    "value": "]] .. ingredient_text .. [[",
                    "inline": false
                },
                {
                    "name": "────────────────────\n**PERFORMANCE STATS**",
                    "value": "Runtime : ]] ..
        runtime_str ..
        [[\nCycles/h : ]] ..
        string.format("%.2f", cycles_per_hour) .. [[\nSuccess Rate : ]] .. string.format("%.1f", success_rate) .. [[%",
                    "inline": false
                }
            ],
            "thumbnail": {
                "url": "https://media.discordapp.net/attachments/1397494990480871464/1398596566415314984/ble.gif"
            },
            "image": {
                "url": "https://media.discordapp.net/attachments/1397494990480871464/1398595921125834815/1K4NBANNER.png"
            },
            "footer": {
                "text": "🚀 1K4N COMMUNITY COOKING CHEF • ]] .. os.date("%Y-%m-%d %H:%M:%S") .. [[",
                "icon_url": "https://media.discordapp.net/attachments/1339707323035160638/1339955286739390495/a.jpg"
            }
        }]
    }]]

    MakeRequest(WEBHOOK_URL, "POST", { ["Content-Type"] = "application/json" }, payload)
end

local function start_oven_low(x, y, id)
    SendPacket(2, "action|dialog_return\ndialog_name|homeoven_edit\nx|" .. x ..
        "|\ny|" .. y .. "|\ncookthis|" .. id .. "|\nbuttonClicked|low")
end

local function start_oven_med(x, y, id)
    SendPacket(2, "action|dialog_return\ndialog_name|homeoven_edit\nx|" .. x ..
        "|\ny|" .. y .. "|\ncookthis|" .. id .. "|\nbuttonClicked|med")
end

local function start_oven_high(x, y, id)
    SendPacket(2, "action|dialog_return\ndialog_name|homeoven_edit\nx|" .. x ..
        "|\ny|" .. y .. "|\ncookthis|" .. id .. "|\nbuttonClicked|high")
end

local function interact_oven(x, y, id)
    SendPacketRaw(false, { type = 3, value = id, px = x, py = y, x = x * 32, y = y * 32 })
end

local function collect_item(obj)
    SendPacketRaw(false, { type = 11, value = obj.oid, x = obj.pos.x, y = obj.pos.y })
end

local function GenerateOvenGrid(center_pos, grid_width, grid_height)
    local ovens, id = {}, 1
    local half_w, half_h = math.floor(grid_width / 2), math.floor(grid_height / 2)

    for y = half_h, -half_h, -1 do
        for x = -half_w, half_w do
            if not (x == 0 and y == 0) then
                table.insert(ovens, { id = id, x = center_pos.x + x, y = center_pos.y + y })
                id = id + 1
            end
        end
    end
    return ovens
end

local oven_ids = { 4620, 6412, 4618 }

local function isOven(fg)
    for _, id in ipairs(oven_ids) do
        if fg == id then return true end
    end
    return false
end

local function isOvenCooking(tile)
    if not tile.extra then return false end
    if tile.extra.volume and tile.extra.volume > 0 then return true end
    if tile.extra.admin and #tile.extra.admin > 0 then return true end
    return false
end

local function checkAndPunchOvens()
    local world = GetTiles()
    if not world then return end

    local cleaned = false
    while not cleaned do
        cleaned = true
        for _, tile in pairs(world) do
            if isOven(tile.fg) and isOvenCooking(tile) then
                interact_oven(tile.x, tile.y, 18)
                Sleep(200)
                cleaned = false
            end
        end
        Sleep(300)
        world = GetTiles()
    end
end

local DIGIVEND_ID = 9268

local function scanVend()
    vendCount, vendList = 0, {}
    local currentConfig = getCurrentConfig()
    local world = GetTiles()
    if not world then return end

    for _, tile in pairs(world) do
        if tile.fg == DIGIVEND_ID and tile.extra and tile.extra.lastupdate == currentConfig.TARGET_COOKED_ITEM then
            vendCount = vendCount + 1
            table.insert(vendList, { x = tile.x, y = tile.y })
        end
    end
end

function TeleportTo(x, y)
    local localPlayer = GetLocal()
    if not localPlayer then
        return
    end
    local px = math.floor(localPlayer.pos.x / 32)
    local py = math.floor(localPlayer.pos.y / 32)
    local dx = math.abs(x - px)
    local dy = math.abs(y - py)
    local distance = math.max(dx, dy)
    local delay = 250
    if distance > 10 then
        delay = 1000
    end
    FindPath(x, y, delay)
end

local function TeleportToVend(index)
    if index > 0 and index <= vendCount and vendList[index] then
        local vend = vendList[index]
        TeleportTo(vend.x, vend.y)
        return true
    end
    return false
end

function EnsureCookingPosition()
    if not cooking_pos or not cooking_pos.x then return end -- Jangan lakukan apa-apa jika posisi belum diset

    local localPlayer = GetLocal()
    if not localPlayer then return end

    local px = math.floor(localPlayer.pos.x / 32)
    local py = math.floor(localPlayer.pos.y / 32)

    if px ~= cooking_pos.x or py ~= cooking_pos.y then
        LogToConsole("`e[System]`0 Player is not at the cooking position. Teleporting back...")
        TeleportTo(cooking_pos.x, cooking_pos.y)
        Sleep(1500) -- Beri waktu untuk pathfinding
    end
end

-- GANTI FUNGSI LAMA DENGAN VERSI SPESIFIK INI
function FindCookingPosition()
    if ui_config.cooking_pos_id == 0 then
        LogToConsole("`e[System]`0 Cooking Position ID is 0. Using player's starting position.")
        cooking_pos = {
            x = GetLocal().pos.x // 32,
            y = GetLocal().pos.y // 32
        }
        return true
    end

    LogToConsole("`e[System]`0 Scanning for cooking position with ID: " ..
        ui_config.cooking_pos_id .. " (must be below an oven).")
    local world = GetTiles()
    if not world then
        LogToConsole("`4[Error]`0 Failed to get world tiles.")
        return false
    end

    for key, tile in pairs(world) do
        -- 1. Kelompokkan kondisi ID dengan tanda kurung
        if (tile.fg == ui_config.cooking_pos_id or tile.bg == ui_config.cooking_pos_id) then
            -- 2. Ambil tile di atasnya dan simpan di variabel
            local tile_above = GetTile(tile.x, tile.y + 1)

            -- 3. Cek apakah tile di atas ada DAN apakah itu oven
            if tile_above and isOven(tile_above.fg) then
                LogToConsole("`2[Cooking Pos]`0 Found at " ..
                    tile.x .. ", " .. tile.y .. ", located directly below an oven.")
                cooking_pos = { x = tile.x, y = tile.y }
                return true -- Posisi valid ditemukan, hentikan pencarian
            end
        end
    end

    LogToConsole("`4[Error]`0 Cooking Position with ID " ..
        ui_config.cooking_pos_id .. " was not found directly below an oven.")
    return false
end

function addToVend()
    if vendCount <= 0 then return false end

    for i = vendCount, 1, -1 do
        if vendList[i] then
            if TeleportToVend(i) then
                Sleep(1000)
                interact_oven(vendList[i].x, vendList[i].y, 32)
                Sleep(100)

                SendPacket(2, "action|dialog_return\ndialog_name|vend_edit\nx|" ..
                    vendList[i].x .. "|\ny|" .. vendList[i].y ..
                    "|\nbuttonClicked|addstock")

                Sleep(800)

                if vendfull then
                    vendfull = false
                    table.remove(vendList, i)
                    vendCount = vendCount - 1
                    LogToConsole("Vend " .. i .. " is full, trying next vend")
                else
                    return true
                end
            else
                LogToConsole("Failed to teleport to vend " .. i .. ", trying next")
            end
        end
    end

    LogToConsole("All vends are full or unavailable")
    return false
end

AddHook("onvariant", "Cook_Combined", function(var)
    if var[0] == "OnTalkBubble" then
        if var[2]:find("too full") then
            vendfull = true
            return true
        end
        if var[2]:find("Disgusting Mess") or var[2]:find("Bland Mush") then
            Failed_cook = Failed_cook + 1
            return true
        end
    end

    if var[0] == "OnDialogRequest" then
        if var[1]:find("DigiVend Machine") or var[1]:find("Oven") or var[1]:find("Replicator") then
            return true
        end
    end

    if var[0] == "OnConsoleMessage" then
        if var[1]:find("You toss a") then
            return true
        end
        if var[1]:find("You cooked up") then
            if (CONFIG.RECIPE == "ARROZ" and var[1]:find("Arroz")) or (CONFIG.RECIPE == "EGGS") then
                Success_cook = Success_cook + 1
            end
            return true
        end
    end

    return false
end)

local gui_settings = {
    show_window          = true,
    window_alpha         = 0.85,
    lock_window_position = true,
}
local green        = ImVec4(0.3, 1, 0.3, 1)
local red          = ImVec4(1, 0.3, 0.3, 1)
local cyan         = ImVec4(0.2, 0.8, 1, 1)
local yellow       = ImVec4(1, 1, 0.2, 1)
local pink         = ImVec4(1, 0.6, 0.6, 1)
local white        = ImVec4(1, 1, 1, 1)

function render_cooking_info()
    local currentConfig = getCurrentConfig()
    ImGui.Begin("COOKING PREMIUM V1.2 - 1K4N COMMUNITY")
    ImGui.BeginGroup()
    local changed_lock, new_lock = ImGui.Checkbox("LOCK", gui_settings.lock_window_position)
    if changed_lock then gui_settings.lock_window_position = new_lock end
    ImGui.EndGroup()

    ImGui.Separator()
    if ImGui.Button("STOP", ImVec2(ImGui.GetWindowWidth(), 30)) then
        stop_requested = true
        script_state = "CONFIGURING"
        LogToConsole("`e[System]`0 Stop requested by user. Finishing current cycle...")
    end
    ImGui.Text("Configuration:")
    ImGui.BulletText("Recipe: " .. CONFIG.RECIPE)
    ImGui.BulletText("Heat Mode: " .. currentConfig.HEAT_MODE .. " | Ovens: " .. oven_count)

    ImGui.TextColored(green, "Cooking Results")
    ImGui.TextColored(green, "Success: " .. Success_cook)
    ImGui.SameLine()
    ImGui.TextColored(red, "Failed: " .. Failed_cook)

    ImGui.Separator()
    ImGui.Text("Vending Status:")
    ImGui.BulletText("Available Vends: " .. vendCount)
    ImGui.BulletText("Cooked Items In Inv: " .. GetItemCount(currentConfig.TARGET_COOKED_ITEM))

    ImGui.Separator()
    ImGui.Text("Script Status: ")
    ImGui.SameLine()

    local status_text, status_color = "IDLE", red
    if cooking_active then
        status_text, status_color = "COOKING (" .. current_phase .. ")", green
    elseif current_phase == "RESTOCKING" then
        status_text, status_color = "RESTOCKING", yellow
    elseif current_phase == "VENDING" then
        status_text, status_color = "VENDING", cyan
    end

    ImGui.TextColored(status_color, status_text)

    if cooking_active then
        local timeline_key = CONFIG.RECIPE == "ARROZ" and "ARROZ" or "EGGS"
        local timeline = TIMELINES[timeline_key][currentConfig.HEAT_MODE:upper()] or TIMELINES[timeline_key].LOW

        local total_duration_ms = timeline.COLLECT + (oven_count - 1) * currentConfig.DELAY_BETWEEN_OVENS_MS
        local elapsed_ms = os.clock() * 1000 - script_start_time
        local progress = math.min(1.0, elapsed_ms / total_duration_ms)
        local progress_text = string.format("Cycle Time: %.1fs / %.1fs", elapsed_ms / 1000, total_duration_ms / 1000)

        ImGui.ProgressBar(progress, nil, progress_text)
    end

    ImGui.Separator()

    if ImGui.BeginTable("OvenStatus", 4) then
        ImGui.TableSetupColumn("Oven #", 0, 0.15)
        ImGui.TableSetupColumn("Phase", 0, 0.35)
        ImGui.TableSetupColumn("Status (Start Time)", 0, 0.25)
        ImGui.TableSetupColumn("ETA", 0, 0.25)
        ImGui.TableHeadersRow()

        local timeline_key = CONFIG.RECIPE == "ARROZ" and "ARROZ" or "EGGS"
        local timeline = TIMELINES[timeline_key][currentConfig.HEAT_MODE:upper()] or TIMELINES[timeline_key].LOW

        for oven_id = 1, oven_count do
            ImGui.TableNextRow()
            local status = oven_status[oven_id]

            ImGui.TableSetColumnIndex(0)
            ImGui.Text(tostring(oven_id))

            if status and status.start_time then
                local elapsed_since_start = (os.clock() * 1000) - status.start_time
                local display_phase, phase_color = "", yellow

                if CONFIG.RECIPE == "EGGS" then
                    if elapsed_since_start >= timeline.COLLECT then
                        display_phase, phase_color = "COOKED", green
                    elseif elapsed_since_start >= timeline.MILK then
                        display_phase, phase_color = "MILK+SALT", pink
                    elseif elapsed_since_start >= timeline.BACON then
                        display_phase, phase_color = "BACON", cyan
                    else
                        display_phase, phase_color = "DOUGH+EGG", yellow
                    end
                else
                    if elapsed_since_start >= timeline.COLLECT then
                        display_phase, phase_color = "COOKED", green
                    elseif elapsed_since_start >= timeline.TOMATO then
                        display_phase, phase_color = "TOMATO+SPICES", pink
                    elseif elapsed_since_start >= timeline.CHICKEN then
                        display_phase, phase_color = "CHICKEN+ONION", cyan
                    else
                        display_phase, phase_color = "RICE", yellow
                    end
                end

                ImGui.TableSetColumnIndex(1)
                ImGui.TextColored(phase_color, display_phase)

                ImGui.TableSetColumnIndex(2)
                ImGui.Text(string.format("%.2fs", (status.start_time - script_start_time) / 1000))

                local eta_remaining_s = (status.final_eta - os.clock() * 1000) / 1000
                ImGui.TableSetColumnIndex(3)
                ImGui.TextColored(
                    eta_remaining_s > 0.1 and white or green,
                    eta_remaining_s > 0.1 and string.format("%.1fs", eta_remaining_s) or "READY"
                )
            else
                ImGui.TableSetColumnIndex(1)
                ImGui.Text("-")
                ImGui.TableSetColumnIndex(2)
                ImGui.Text("-")
                ImGui.TableSetColumnIndex(3)
                ImGui.Text("-")
            end
        end

        ImGui.EndTable()
    end

    ImGui.End()
end

-- Tentukan path otomatis (Android / PC)
local function getConfigPath(filename)
    local base_path = ""
    if package.config:sub(1, 1) == "\\" then
        -- Windows / PC
        base_path = "./"
    else
        -- Android (GT App path)
        base_path = "/storage/emulated/0/Android/media/com.rtsoft.growtopia/IKAN/"
    end
    return base_path .. filename
end

-- Serialize table (sudah ada, biarin)
local function serialize_table(tbl, indent)
    indent = indent or ""
    local str = "{\n"
    for k, v in pairs(tbl) do
        local key_str = type(k) == "string" and '["' .. k .. '"]' or '[' .. k .. ']'
        str = str .. indent .. "  " .. key_str .. " = "
        if type(v) == "string" then
            str = str .. string.format("%q", v)
        elseif type(v) == "table" then
            str = str .. serialize_table(v, indent .. "  ")
        else
            str = str .. tostring(v)
        end
        str = str .. ",\n"
    end
    return str .. indent .. "}"
end

-- SAVE CONFIG
function SaveConfig()
    local file_path = getConfigPath("cook_config.lua")
    local file, err = io.open(file_path, "w")
    if not file then
        LogToConsole("`4[Error]`0 Cannot save config: " .. (err or "Unknown error"))
        return
    end

    local serialized_data = serialize_table(ui_config)
    file:write("return " .. serialized_data)
    file:close()
    LogToConsole("`2[Config]`0 Saved to " .. file_path)
end

-- LOAD CONFIG
function LoadConfig()
    local file_path = getConfigPath("cook_config.lua")
    local f = io.open(file_path, "r")
    if not f then
        LogToConsole("`4[Error]`0 Config file not found at " .. file_path)
        return
    end
    f:close()

    local success, loaded_data = pcall(dofile, file_path)
    if not success or type(loaded_data) ~= "table" then
        LogToConsole("`4[Error]`0 Config may be corrupted. " .. (loaded_data or "Unknown error"))
        return
    end

    for key, value in pairs(loaded_data) do
        if ui_config[key] ~= nil then
            ui_config[key] = value
        end
    end

    -- Sinkronisasi variabel global (kalau ada)
    WEBHOOK_URL = ui_config.webhook_url
    WEBHOOK_CYCLE_INTERVAL = ui_config.webhook_interval

    LogToConsole("`2[Config]`0 Loaded successfully from " .. file_path)
end

function RenderConfigUI()
    local changed, new_val
    ImGui.Begin("COOKING PREMIUM V1.2 - 1K4N COMMUNITY")
    ImGui.BeginGroup()
    local changed_lock, new_lock = ImGui.Checkbox("LOCK", gui_settings.lock_window_position)
    if changed_lock then gui_settings.lock_window_position = new_lock end
    ImGui.SameLine()
    ImGui.Text("- | -")
    ImGui.SameLine()
    ImGui.Text("HIDE / SHOW MENU [ F5 ]")
    ImGui.Separator()
    ImGui.Dummy(ImVec2(0, 10))
    ImGui.EndGroup()
    ImGui.TextColored(green, "COOKING MODE")
    ImGui.PushItemWidth(ImGui.GetWindowWidth() * 0.45)

    if ImGui.Checkbox("COOK ARROZ CON POLLO", ui_config.recipe == "ARROZ") then
        ui_config.recipe = "ARROZ"
        ui_config.heat_mode = "LOW"
    end

    ImGui.SameLine()

    if ImGui.Checkbox("COOK EGGS BENEDICT", ui_config.recipe == "EGGS") then
        ui_config.recipe = "EGGS"
        ui_config.heat_mode = "LOW"
    end

    ImGui.PopItemWidth()

    ImGui.Dummy(ImVec2(0, 10))
    ImGui.TextColored(green, "CONFIGURING")

    if ImGui.Checkbox("SET DEFAULT", ui_config.config_mode == "DEFAULT") then
        ui_config.config_mode = "DEFAULT"
    end

    ImGui.SameLine()

    if ImGui.Checkbox("SET MANUAL", ui_config.config_mode == "MANUAL") then
        ui_config.config_mode = "MANUAL"
    end

    ImGui.Dummy(ImVec2(0, 10))
    ImGui.TextColored(green, "COOKING LEVEL")

    if ImGui.Checkbox("LOW MODE", ui_config.heat_mode == "LOW") then
        ui_config.heat_mode = "LOW"
    end

    if ImGui.Checkbox("MEDIUM MODE", ui_config.heat_mode == "MEDIUM") then
        ui_config.heat_mode = "MEDIUM"
    end

    if ImGui.Checkbox("HIGH MODE", ui_config.heat_mode == "HIGH") then
        ui_config.heat_mode = "HIGH"
    end

    if ui_config.config_mode == "MANUAL" then
        ImGui.TextColored(green, "SETTINGS: " .. ui_config.recipe)

        if ui_config.recipe == "ARROZ" then
            local default_conf = CONFIG.ARROZ_CONFIG
            local default_timeline = TIMELINES.ARROZ[ui_config.heat_mode]
            local manual_timeline = ui_config.arroz_manual_timelines[ui_config.heat_mode]

            ImGui.PushItemWidth(120)
            changed, new_val = ImGui.InputInt("GRID X",
                ui_config.config_mode == "MANUAL" and ui_config.arroz_grid_w or default_conf.GRID_SIZE.width)
            if changed then ui_config.arroz_grid_w = new_val end

            ImGui.SameLine()
            changed, new_val = ImGui.InputInt("GRID Y",
                ui_config.config_mode == "MANUAL" and ui_config.arroz_grid_h or default_conf.GRID_SIZE.height)
            if changed then ui_config.arroz_grid_h = new_val end

            changed, new_val = ImGui.InputInt("DELAY PER OVEN",
                ui_config.config_mode == "MANUAL" and ui_config.arroz_delay or default_conf.DELAY_BETWEEN_OVENS_MS)
            if changed then ui_config.arroz_delay = new_val end

            ImGui.Dummy(ImVec2(0, 10))
            changed, new_val = ImGui.InputInt("PEPPER 1",
                ui_config.config_mode == "MANUAL" and manual_timeline.PEPPER1 or default_timeline.PEPPER1)
            if changed then manual_timeline.PEPPER1 = new_val end

            changed, new_val = ImGui.InputInt("CHICKEN",
                ui_config.config_mode == "MANUAL" and manual_timeline.CHICKEN or default_timeline.CHICKEN)
            if changed then manual_timeline.CHICKEN = new_val end

            changed, new_val = ImGui.InputInt("ONION",
                ui_config.config_mode == "MANUAL" and manual_timeline.ONION or default_timeline.ONION)
            if changed then manual_timeline.ONION = new_val end

            changed, new_val = ImGui.InputInt("TOMATO",
                ui_config.config_mode == "MANUAL" and manual_timeline.TOMATO or default_timeline.TOMATO)
            if changed then manual_timeline.TOMATO = new_val end

            changed, new_val = ImGui.InputInt("SALT",
                ui_config.config_mode == "MANUAL" and manual_timeline.SALT or default_timeline.SALT)
            if changed then manual_timeline.SALT = new_val end

            changed, new_val = ImGui.InputInt("PEPPER 2",
                ui_config.config_mode == "MANUAL" and manual_timeline.PEPPER2 or default_timeline.PEPPER2)
            if changed then manual_timeline.PEPPER2 = new_val end

            changed, new_val = ImGui.InputInt("COLLECT",
                ui_config.config_mode == "MANUAL" and manual_timeline.COLLECT or default_timeline.COLLECT)
            if changed then manual_timeline.COLLECT = new_val end

            changed, new_val = ImGui.InputInt("COLLECT DELAY", COLLECT_DELAY)
            if changed then COLLECT_DELAY = new_val end

            ImGui.PopItemWidth()
        else
            local default_conf = CONFIG.EGGS_CONFIG
            local default_timeline = TIMELINES.EGGS[ui_config.heat_mode]
            local manual_timeline = ui_config.eggs_manual_timelines[ui_config.heat_mode]

            ImGui.PushItemWidth(100)
            changed, new_val = ImGui.InputInt("GRID X",
                ui_config.config_mode == "MANUAL" and ui_config.eggs_grid_w or default_conf.GRID_SIZE.width)
            if changed then ui_config.eggs_grid_w = new_val end

            ImGui.SameLine()
            changed, new_val = ImGui.InputInt("GRID Y",
                ui_config.config_mode == "MANUAL" and ui_config.eggs_grid_h or default_conf.GRID_SIZE.height)
            if changed then ui_config.eggs_grid_h = new_val end

            changed, new_val = ImGui.InputInt("DELAY PER OVEN",
                ui_config.config_mode == "MANUAL" and ui_config.eggs_delay or default_conf.DELAY_BETWEEN_OVENS_MS)
            if changed then ui_config.eggs_delay = new_val end

            ImGui.Dummy(ImVec2(0, 10))
            changed, new_val = ImGui.InputInt("EGG",
                ui_config.config_mode == "MANUAL" and manual_timeline.EGG or default_timeline.EGG)
            if changed then manual_timeline.EGG = new_val end

            changed, new_val = ImGui.InputInt("BACON",
                ui_config.config_mode == "MANUAL" and manual_timeline.BACON or default_timeline.BACON)
            if changed then manual_timeline.BACON = new_val end

            changed, new_val = ImGui.InputInt("MILK",
                ui_config.config_mode == "MANUAL" and manual_timeline.MILK or default_timeline.MILK)
            if changed then manual_timeline.MILK = new_val end

            changed, new_val = ImGui.InputInt("SALT",
                ui_config.config_mode == "MANUAL" and manual_timeline.SALT or default_timeline.SALT)
            if changed then manual_timeline.SALT = new_val end

            changed, new_val = ImGui.InputInt("COLLECT",
                ui_config.config_mode == "MANUAL" and manual_timeline.COLLECT or default_timeline.COLLECT)
            if changed then manual_timeline.COLLECT = new_val end

            changed, new_val = ImGui.InputInt("COLLECT DELAY", COLLECT_DELAY)
            if changed then COLLECT_DELAY = new_val end

            ImGui.PopItemWidth()
        end
    end

    ImGui.TextColored(green, "WEBHOOK LINK")

    changed, new_val = ImGui.Checkbox("USE WEBHOOK", ui_config.use_webhook)
    if changed then ui_config.use_webhook = new_val end

    if not ui_config.use_webhook then
        ImGui.BeginDisabled()
    end

    ImGui.PushItemWidth(-1)
    changed, new_val = ImGui.InputText("##webhookurl", ui_config.webhook_url, 512)
    if changed then ui_config.webhook_url = new_val end
    ImGui.PopItemWidth()

    ImGui.PushItemWidth(100)
    changed, new_val = ImGui.InputInt("WEBHOOK INTERVAL", ui_config.webhook_interval)
    if changed then ui_config.webhook_interval = new_val end
    ImGui.PopItemWidth()

    if not ui_config.use_webhook then
        ImGui.EndDisabled()
    end

    ImGui.Separator() -- Tambahan pemisah
    ImGui.TextColored(green, "POSITIONING")
    ImGui.PushItemWidth(200)
    changed, new_val = ImGui.InputInt("Cooking Position ID", ui_config.cooking_pos_id)
    if changed then ui_config.cooking_pos_id = new_val end
    ImGui.PopItemWidth()
    ImGui.Text("Set ID block untuk berdiri. 0 = Posisi awal player.")


    ImGui.Separator()
    ImGui.Dummy(ImVec2(0, 10))
    if ImGui.Button("Save Config", ImVec2(ImGui.GetWindowWidth() * 0.49, 25)) then
        SaveConfig()
    end
    ImGui.SameLine()
    if ImGui.Button("Load Config", ImVec2(ImGui.GetWindowWidth() * 0.49, 25)) then
        LoadConfig()
    end
    ImGui.Dummy(ImVec2(0, 5))
    if script_state == "RUNNING" then
        ImGui.BeginDisabled()
    end

    if ImGui.Button("START", ImVec2(ImGui.GetWindowWidth(), 30)) then
        stop_requested = false
        RunThread(Main)
    end

    if script_state == "RUNNING" then
        ImGui.EndDisabled()
    end

    ImGui.End()
end

-- GANTI SELURUH FUNGSI ApplyConfigAndStart DENGAN YANG INI
function ApplyConfigAndStart()
    -- --- BAGIAN RESET DATA DIMULAI DI SINI ---
    Success_cook, Failed_cook = 0, 0
    cycle_count = 0
    cooking_active = false
    current_phase = "IDLE"
    oven_status = {}
    script_boot_time = os.time()
    -- -----------------------------------------

    CONFIG.RECIPE = ui_config.recipe
    WEBHOOK_URL = ui_config.webhook_url
    WEBHOOK_CYCLE_INTERVAL = ui_config.webhook_interval
    CONFIG.COOKING_POS_ID = ui_config.cooking_pos_id

    if ui_config.recipe == "ARROZ" then
        CONFIG.ARROZ_CONFIG.HEAT_MODE = ui_config.heat_mode
        if ui_config.config_mode == "MANUAL" then
            CONFIG.ARROZ_CONFIG.GRID_SIZE.width        = ui_config.arroz_grid_w
            CONFIG.ARROZ_CONFIG.GRID_SIZE.height       = ui_config.arroz_grid_h
            CONFIG.ARROZ_CONFIG.DELAY_BETWEEN_OVENS_MS = ui_config.arroz_delay
            TIMELINES.ARROZ                            = table.copy(ui_config.arroz_manual_timelines)
        end
    else
        CONFIG.EGGS_CONFIG.HEAT_MODE = ui_config.heat_mode
        if ui_config.config_mode == "MANUAL" then
            CONFIG.EGGS_CONFIG.GRID_SIZE.width        = ui_config.eggs_grid_w
            CONFIG.EGGS_CONFIG.GRID_SIZE.height       = ui_config.eggs_grid_h
            CONFIG.EGGS_CONFIG.DELAY_BETWEEN_OVENS_MS = ui_config.eggs_delay
            TIMELINES.EGGS                            = table.copy(ui_config.manual_timelines) -- Anda mungkin salah ketik di sini, saya perbaiki menjadi 'eggs_manual_timelines'
        end
    end

    if CONFIG.RECIPE == "ARROZ" then
        -- KEMBALIKAN KE STRUKTUR INI
        ITEM_IDS = {
            rice    = GetItemInfo("Rice").id,
            chicken = GetItemInfo("Chicken Meat").id,
            onion   = GetItemInfo("Onion").id,
            tomato  = GetItemInfo("Tomato").id,
            salt    = GetItemInfo("Salt").id,
            pepper  = GetItemInfo("Pepper").id
        }
    else
        -- KEMBALIKAN KE STRUKTUR INI
        ITEM_IDS = {
            dough = GetItemInfo("Dough").id,
            egg   = GetItemInfo("Egg").id,
            bacon = GetItemInfo("Bacon").id,
            milk  = GetItemInfo("Milk").id,
            salt  = GetItemInfo("Salt").id
        }
    end

    if not FindCookingPosition() then
        LogToConsole("`4[FATAL]`0 Could not start. Cooking position is not valid.")
        script_state = "CONFIGURING"
        return
    end

    TeleportTo(cooking_pos.x, cooking_pos.y)
    Sleep(1500)
    scanVend()

    local currentConfig = getCurrentConfig()
    oven_coords = GenerateOvenGrid(cooking_pos, currentConfig.GRID_SIZE.width, currentConfig.GRID_SIZE.height)
    oven_count = #oven_coords

    script_state = "RUNNING"
end

AddHook("OnInput", "PTHook_ToggleUI", function(key)
    if key == 116 then
        gui_settings.show_window = not gui_settings.show_window
        return true
    end
    return false
end)

AddHook("OnDraw", "main_ui_router", function()
    if not gui_settings.show_window then return end
    if gui_settings.lock_window_position then
        ImGui.SetNextWindowPos(ImVec2(0, 0), ImGui.Cond.Always)
    end
    ImGui.SetNextWindowBgAlpha(1.00)
    if script_state == "CONFIGURING" then
        RenderConfigUI()
    elseif script_state == "RUNNING" then
        render_cooking_info()
    end
end)

function Main()
    ApplyConfigAndStart()
    if script_state ~= "RUNNING" then return end -- Hentikan jika ApplyConfigAndStart gagal

    while not stop_requested do
        -- Selalu pastikan posisi benar di awal setiap loop
        EnsureCookingPosition()
        if stop_requested then break end
        -- Step 1: Punch ovens
        checkAndPunchOvens()
        Sleep(100)

        local currentConfig = getCurrentConfig()

        -- Step 2: Vending check
        if GetItemCount(currentConfig.TARGET_COOKED_ITEM) >= currentConfig.VEND_THRESHOLD and vendCount > 0 then
            current_phase = "VENDING"

            local vend_success = addToVend()
            if not vend_success then
                LogToConsole("No available vends, continuing with cooking")
            end

            -- Pastikan kembali ke posisi memasak setelah vending
            EnsureCookingPosition()
            current_phase = "IDLE"
        end

        -- Step 3: Check required items
        local required = {}
        if CONFIG.RECIPE == "ARROZ" then
            required = {
                [ITEM_IDS.rice]    = oven_count,
                [ITEM_IDS.chicken] = oven_count,
                [ITEM_IDS.onion]   = oven_count,
                [ITEM_IDS.tomato]  = oven_count,
                [ITEM_IDS.salt]    = oven_count,
                [ITEM_IDS.pepper]  = oven_count * 2
            }
        else
            required = {
                [ITEM_IDS.dough] = oven_count,
                [ITEM_IDS.egg]   = oven_count,
                [ITEM_IDS.bacon] = oven_count,
                [ITEM_IDS.milk]  = oven_count,
                [ITEM_IDS.salt]  = oven_count
            }
        end

        local needs_restock, needed_items = false, {}
        for id, needed in pairs(required) do
            if needed > 0 and GetItemCount(id) < needed then
                needs_restock = true
                needed_items[id] = needed - GetItemCount(id)
            end
        end

        -- Step 4: Cooking cycle
        if not needs_restock then
            -- Pastikan posisi sebelum memulai siklus memasak
            EnsureCookingPosition()

            current_phase      = "STARTING CYCLE"
            cooking_active     = true
            oven_status        = {}

            local timeline_key = CONFIG.RECIPE == "ARROZ" and "ARROZ" or "EGGS"
            local timeline     = TIMELINES[timeline_key][currentConfig.HEAT_MODE:upper()] or TIMELINES[timeline_key].LOW
            local heat_mode    = currentConfig.HEAT_MODE:lower()

            local PHASES       = {}
            if CONFIG.RECIPE == "ARROZ" then
                PHASES = {
                    { name = "RICE",    timeline = timeline.RICE,    item = ITEM_IDS.rice },
                    { name = "CHICKEN", timeline = timeline.CHICKEN, item = ITEM_IDS.chicken },
                    { name = "ONION",   timeline = timeline.ONION,   item = ITEM_IDS.onion },
                    { name = "TOMATO",  timeline = timeline.TOMATO,  item = ITEM_IDS.tomato },
                    { name = "SALT",    timeline = timeline.SALT,    item = ITEM_IDS.salt },
                    { name = "PEPPER1", timeline = timeline.PEPPER1, item = ITEM_IDS.pepper },
                    { name = "PEPPER2", timeline = timeline.PEPPER2, item = ITEM_IDS.pepper },
                }
            else
                PHASES = {
                    { name = "DOUGH", timeline = timeline.DOUGH, item = ITEM_IDS.dough },
                    { name = "EGG",   timeline = timeline.EGG,   item = ITEM_IDS.egg },
                    { name = "BACON", timeline = timeline.BACON, item = ITEM_IDS.bacon },
                    { name = "MILK",  timeline = timeline.MILK,  item = ITEM_IDS.milk },
                    { name = "SALT",  timeline = timeline.SALT,  item = ITEM_IDS.salt },
                }
            end

            -- Collect phase at the end
            table.insert(PHASES, { name = "COLLECT", timeline = timeline.COLLECT, item = 18 })

            -- Schedule actions for ovens
            local schedule = {}
            for i, oven in ipairs(oven_coords) do
                local start_offset = (i - 1) * currentConfig.DELAY_BETWEEN_OVENS_MS
                for _, phase in ipairs(PHASES) do
                    local first_ingredient = CONFIG.RECIPE == "ARROZ" and "RICE" or "DOUGH"
                    table.insert(schedule, {
                        time    = start_offset + phase.timeline,
                        action  = (phase.name == first_ingredient) and "start" or "interact",
                        x       = oven.x,
                        y       = oven.y,
                        item    = phase.item,
                        phase   = phase.name,
                        oven_id = i
                    })
                end
            end
            table.sort(schedule, function(a, b) return a.time < b.time end)

            script_start_time         = os.clock() * 1000
            local current_event_index = 1

            while current_event_index <= #schedule do
                local event        = schedule[current_event_index]
                local target_time  = script_start_time + event.time
                local current_time = os.clock() * 1000
                current_phase      = event.phase

                if current_time >= target_time then
                    if event.action == "start" then
                        if heat_mode == "low" then
                            start_oven_low(event.x, event.y, event.item)
                        elseif heat_mode == "medium" then
                            start_oven_med(event.x, event.y, event.item)
                        else
                            start_oven_high(event.x, event.y, event.item)
                        end
                    else
                        interact_oven(event.x, event.y, event.item)
                        if event.phase == "COLLECT" then
                            Sleep(COLLECT_DELAY)
                        else
                            Sleep(50)
                        end
                    end

                    local first_ingredient = CONFIG.RECIPE == "ARROZ" and "RICE" or "DOUGH"
                    if event.phase == first_ingredient then
                        oven_status[event.oven_id] = {
                            start_time = current_time,
                            final_eta  = current_time + timeline.COLLECT
                        }
                    end

                    current_event_index = current_event_index + 1
                end
                Sleep(10)
            end

            current_phase = "COMPLETED"
            Sleep(100)
            cooking_active = false
            current_phase  = "IDLE"

            -- Trash handling
            if GetItemCount(Trash_id) >= 250 then
                SendPacket(2, "action|dialog_return\ndialog_name|trash\nitem_trash|" .. Trash_id .. "|\nitem_count|250")
                Sleep(100)
            elseif GetItemCount(Trash_id2) >= 250 then
                SendPacket(2, "action|dialog_return\ndialog_name|trash\nitem_trash|" .. Trash_id2 .. "|\nitem_count|250")
                Sleep(100)
            end

            cycle_count = cycle_count + 1
            if cycle_count % WEBHOOK_CYCLE_INTERVAL == 0 then
                SendWebhook()
            end

            -- Step 5: Restocking
        else
            -- --- BAGIAN RESTOCKING YANG DIPERBARUI (VERSI LEBIH BAIK) ---
            local item_names_needed = {}
            for id, count in pairs(needed_items) do
                local item_name = GetItemInfo(id).name
                table.insert(item_names_needed, item_name .. " (x" .. count .. ")")
            end

            local needed_text = table.concat(item_names_needed, ", ")
            current_phase = "RESTOCKING (" .. needed_text .. ")" -- Update status untuk GUI
            LogToConsole("`e[Restock]`0 Missing items: " .. needed_text)

            cooking_active = false
            local items_found_this_loop = false

            for _, obj in pairs(GetObjectList()) do
                if needed_items[obj.id] and needed_items[obj.id] > 0 then
                    items_found_this_loop = true
                    local item_name = GetItemInfo(obj.id).name
                    LogToConsole("`e[Restock]`0 Found " .. item_name .. ". Moving to collect...")

                    local x, y = math.floor(obj.pos.x / 32), math.floor(obj.pos.y / 32)
                    TeleportTo(x, y)
                    Sleep(currentConfig.RESTOCK_COLLECT_DELAY_MS)
                    collect_item(obj)
                    needed_items[obj.id] = needed_items[obj.id] - obj.amount
                    Sleep(250)
                end
            end

            if not items_found_this_loop then
                LogToConsole("`4[Restock]`0 No required items found on the ground. Waiting for " ..
                currentConfig.RESTOCK_FAIL_WAIT_S .. " seconds...")
                Sleep(currentConfig.RESTOCK_FAIL_WAIT_S * 1000)
                SendWebhook()
            else
                LogToConsole("`2[Restock]`0 Finished collecting for now. Returning to cooking position.")
                EnsureCookingPosition()
            end
            -- --- AKHIR BAGIAN YANG DIPERBARUI ---
        end

        if stop_requested then break end
        Sleep(100)
    end
    LogToConsole("`2[System]`0 Cooking script has been stopped.")
    cooking_active = false -- Reset status visual
    current_phase = "IDLE" -- Reset status visual
end
