local config = {
    world_take = "AEBFG",
    world_drop = "ARROZNYA",
    delay_join_world = 3000,
    item_id = 4602,
    item_name = "",
    mode_take = "DROP",
    mode_drop = "VEND",
    mag_bg_take = 558,
    mag_bg_drop = 200,
    vend_marker_take = 1884,
    vend_marker_drop = 1684,
    vend_price = 1,
    vend_price_mode = "per_item"
}

local state = {
    isRunning = false,
    statusMessage = "Ready. Configure and press START.",
    shouldChangeVend = false,
    shouldSetMag = false,
    shouldSetVend = false,
    noObjectCounter = 0,
    shouldChangeMag = false,
    vendIndex = 1,
    magIndex = 1,
    RECON = false,
    takeVendIndex = 1,
    shouldSkipEmptyMag = false,
    magDropIndex = 1,
    take_magplants = {},
    take_vends = {},
    drop_magplants = {},
    drop_vends = {}
}

function TeleportToss(targetX, targetY, delay)
    local px = math.floor(GetLocal().pos.x / 32)
    local py = math.floor(GetLocal().pos.y / 32)
    delay = delay or 100

    if targetX ~= px then
        local stepX = (targetX > px) and 1 or -1
        for x = px + stepX, targetX, stepX do
            FindPath(x, py, 0)
            Sleep(delay)
        end
    end

    if targetY ~= py then
        local stepY = (targetY > py) and 1 or -1
        for y = py + stepY, targetY, stepY do
            FindPath(targetX, y, 0)
            Sleep(delay)
        end
    end
end

function TeleportTo(targetX, targetY, delay)
    local function distance(x1, y1, x2, y2)
        local dx, dy = x1 - x2, y1 - y2
        return math.sqrt(dx * dx + dy * dy)
    end

    delay = delay or 100

    while true do
        local px = math.floor(GetLocal().pos.x / 32)
        local py = math.floor(GetLocal().pos.y / 32)

        -- kalau udah dalam jarak 3 blok, stop
        if distance(px, py, targetX, targetY) <= 3 then
            break
        end

        -- tentuin arah langkah
        local stepX = (targetX > px) and 1 or (targetX < px and -1 or 0)
        local stepY = (targetY > py) and 1 or (targetY < py and -1 or 0)

        -- gerak satu langkah di arah yang perlu
        local nextX = px + stepX
        local nextY = py + stepY

        FindPath(nextX, nextY, 0)
        Sleep(delay)
    end
end



function IKANS(msg) LogToConsole("`3[SC] " .. msg) end

function wrench(x, y) SendPacketRaw(false, { type = 3, value = 32, px = x, py = y, x = x * 32, y = y * 32 }) end

function scanMagplants(bg)
    local m = {}
    for _, t in pairs(GetTiles()) do if t.fg == 5638 and t.bg == bg then table.insert(m, t) end end
    return m
end

function scanVends(marker_fg)
    local v = {}
    for _, t in pairs(GetTiles()) do
        if t.fg == 9268 and GetTile(t.x, t.y - 1) and GetTile(t.x, t.y - 1).fg == marker_fg then
            table.insert(v, t)
        end
    end
    return v
end

function findNearestObject(item_id)
    local n, d = nil, math.huge; local px, py = GetLocal().pos.x, GetLocal().pos.y
    for _, o in pairs(GetObjectList()) do
        if o.id == item_id then
            local dx, dy = o.pos.x - px, o.pos.y - py
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist < d then
                d = dist; n = o
            end
        end
    end
    return n
end

function takeDropMode()
    local o = findNearestObject(config.item_id)
    if o then
        local tx, ty = math.floor(o.pos.x / 32), math.floor(o.pos.y / 32)
        TeleportToss(tx, ty)
        Sleep(50)
        SendPacketRaw(false, { type = 11, value = o.oid, x = o.pos.x, y = o.pos.y })
        IKANS("`2Picked up object")
    else
        IKANS("`4No object found.")
    end
end

function TextSeparator(text)
    ImGui.Separator()
    ImGui.TextColored(ImVec4(1, 1, 0, 1), text)
    ImGui.Separator()
end

AddHook("OnDraw", "Transporter_GUI", function()
    ImGui.SetNextWindowSize(ImVec2(450, 600), ImGui.Cond.FirstUseEver)
    ImGui.Begin("WORLD TO WORLD V1 - 1K4N Community")

    TextSeparator("STATUS")
    ImGui.Text("Current Status: "); ImGui.SameLine(); ImGui.TextColored(ImVec4(1, 1, 0, 1), state.statusMessage)
    ImGui.Dummy(ImVec2(0, 5))
    ImGui.BeginDisabled(state.isRunning)

    TextSeparator("GLOBAL SETTINGS")
ImGui.Text("Item ID to Move:")
ImGui.PushItemWidth(200)

local item_id = config.item_id or 0
local changed, new_value = ImGui.InputInt("##itemid", item_id)
if changed then
    config.item_id = new_value
    local info = GetItemInfo(new_value)
    config.item_name = (info and info.name) or "Invalid ID"
end

ImGui.PopItemWidth()
ImGui.SameLine()
ImGui.TextColored(ImVec4(0.5, 1, 0.5, 1), config.item_name)

ImGui.Text("Join World Delay (ms):")
ImGui.PushItemWidth(200)

local delay = config.delay_join_world or 0
local c2, v2 = ImGui.InputInt("##delayjoin", delay)
if c2 then config.delay_join_world = v2 end

ImGui.PopItemWidth()
ImGui.Dummy(ImVec2(0, 5))


    if ImGui.BeginTable("ConfigTable", 2) then
        ImGui.TableSetupColumn("TakeColumn", 0, 0.5)
        ImGui.TableSetupColumn("DropColumn", 0, 0.5)
        ImGui.TableNextRow()

        ImGui.TableSetColumnIndex(0)
        TextSeparator("TAKE FROM")

        ImGui.Text("WORLD:DOOR ID - (optional)")
        ImGui.TextDisabled("example : AEBFG:IKAN ")
        ImGui.PushItemWidth(250)

        -- Inisialisasi dengan string kosong jika belum ada
        config.world_take = config.world_take or ""

        local c3, v3 = ImGui.InputText("##worldtake", config.world_take, 256) -- Tambah buffer size
        ImGui.PopItemWidth()
        if c3 then
            config.world_take = v3
        end

        if ImGui.RadioButton("Vending##take", config.mode_take == "VEND") then config.mode_take = "VEND" end
        if ImGui.RadioButton("Magplant##take", config.mode_take == "MAG") then config.mode_take = "MAG" end
        if ImGui.RadioButton("Dropped Item##take", config.mode_take == "DROP") then config.mode_take = "DROP" end

        if config.mode_take == "VEND" then
            ImGui.Text("VEND MARKER ID : "); ImGui.PushItemWidth(150)
            local c4, v4 = ImGui.InputInt("##vendmarkertake", config.vend_marker_take)
            if c4 then config.vend_marker_take = v4 end
            ImGui.PopItemWidth(); ImGui.SameLine(); ImGui.TextColored(ImVec4(0.5, 1, 0.5, 1),
                GetItemInfo(config.vend_marker_take).name)
        end

        if config.mode_take == "MAG" then
            ImGui.Text("MAG BG ID :"); ImGui.PushItemWidth(150)
            local c5, v5 = ImGui.InputInt("##magbgtake", config.mag_bg_take)
            if c5 then config.mag_bg_take = v5 end
            ImGui.PopItemWidth(); ImGui.SameLine(); ImGui.TextColored(ImVec4(0.5, 1, 0.5, 1),
                GetItemInfo(config.mag_bg_take).name)
        end

        ImGui.TableSetColumnIndex(1)
        TextSeparator("SAVE TO")

        ImGui.Text("WORLD:DOOR ID - (optional)")
        ImGui.TextDisabled("example : AEBFG:IKAN ")
        ImGui.PushItemWidth(250)

        -- Inisialisasi dengan string kosong jika belum ada
        config.world_drop = config.world_drop or ""

        local c6, v6 = ImGui.InputText("##worlddrop", config.world_drop, 256) -- Tambah buffer size
        ImGui.PopItemWidth()
        if c6 then
            config.world_drop = v6
        end

        if ImGui.RadioButton("Vending##drop", config.mode_drop == "VEND") then config.mode_drop = "VEND" end
        if ImGui.RadioButton("Magplant##drop", config.mode_drop == "MAG") then config.mode_drop = "MAG" end

        if config.mode_drop == "VEND" then
            ImGui.Text("VEND MARKER ID : "); ImGui.PushItemWidth(150)
            local c7, v7 = ImGui.InputInt("##vendmarkerdrop", config.vend_marker_drop)
            if c7 then config.vend_marker_drop = v7 end
            ImGui.PopItemWidth()
            ImGui.SameLine()
            ImGui.TextColored(ImVec4(0.5, 1, 0.5, 1), GetItemInfo(config.vend_marker_drop).name or "Invalid ID")

            ImGui.Text("Price Value:"); ImGui.PushItemWidth(150)
            local c8, v8 = ImGui.InputInt("##vendprice", config.vend_price)
            if c8 then config.vend_price = v8 end
            ImGui.PopItemWidth()
            if config.vend_price_mode == "per_wl" then
                ImGui.TextDisabled("EXAMPLE : Selling " .. config.vend_price .. " Black Gems for 1 World Lock")
            else
                ImGui.TextDisabled("EXAMPLE : Selling 1 Black Gem for " .. config.vend_price .. " World Locks")
            end
            ImGui.Separator()
            if ImGui.RadioButton("WLs per Item##price", config.vend_price_mode == "per_item") then
                config.vend_price_mode = "per_item"
            end
            ImGui.SameLine()
            if ImGui.RadioButton("Items per WL##price", config.vend_price_mode == "per_wl") then
                config.vend_price_mode = "per_wl"
            end
        end

        if config.mode_drop == "MAG" then
            ImGui.Text("Magplant BG ID:"); ImGui.PushItemWidth(150)
            local c9, v9 = ImGui.InputInt("##magbgdrop", config.mag_bg_drop)
            if c9 then config.mag_bg_drop = v9 end
            ImGui.PopItemWidth(); ImGui.SameLine(); ImGui.TextColored(ImVec4(0.5, 1, 0.5, 1),
                GetItemInfo(config.mag_bg_drop).name)
        end

        ImGui.EndTable()
    end

    ImGui.EndDisabled()
    TextSeparator("CONTROL")
    if not state.isRunning then
        if ImGui.Button("START", ImVec2(ImGui.GetContentRegionAvail().x, 30)) then
            state.isRunning = true
            state.shouldChangeVend = false
            state.shouldSetMag = false
            state.shouldSetVend = false
            state.noObjectCounter = 0
            state.shouldChangeMag = false
            state.RECON = false
            state.shouldSkipEmptyMag = false
            state.vendIndex = 1
            state.magIndex = 1
            state.takeVendIndex = 1
            state.magDropIndex = 1
            RunThread(MainBotLoop)
        end
    else
        if ImGui.Button("STOP", ImVec2(ImGui.GetContentRegionAvail().x, 30)) then
            state.isRunning = false
            state.statusMessage = "Stopping by user..."
        end
    end

    ImGui.End()
end)

AddHook("onvariant", "SC_ALL_HOOK", function(v)
    if not state.isRunning then return false end
    if v[0] == "OnConsoleMessage" and v[1]:find("Where would you like to go?") then
        SendPacket(3, "action|join_request\nname|" .. config.world_take .. "\ninvitedWorld|0")
        state.RECON = true
        return true
    end
    if config.mode_drop == "VEND" and v[0] == "OnTalkBubble" and v[2]:find("too full") then
        state.shouldChangeVend = true
        IKANS("`4FULL DigiVend!")
        return true
    end
    if config.mode_drop == "MAG" and v[0] == "OnTalkBubble" and v[2]:find("doesn't fit") then
        state.shouldChangeMag = true
        IKANS("`4FULL MAGPLANT!")
        return true
    end
    if v[0] == "OnDialogRequest" then
        local d = v[1]
        if d:find("MAGPLANT") then
            if d:find("disabled") or d:find("Choose Item") then
                state.shouldSetMag = true
                IKANS("`4MAG not set!")
            elseif d:find("EMPTY") or d:find("currently empty") then
                state.shouldSkipEmptyMag = true
                IKANS("`4MAG empty!")
            else
                state.shouldSkipEmptyMag = false
                state.shouldSetMag = false
                IKANS("`2MAG ready.")
            end
            return true
        end
        if d:find("DigiVend") then
            if d:find("is empty") then
                state.shouldSetVend = true
                IKANS("`4Empty DigiVend!")
                return true
            end
            return true
        end
    end
    return false
end)

function JoinWorld(targetWorld)
    local currentWorld = GetWorld().name:lower()
    targetWorld = targetWorld:lower()
    if currentWorld ~= targetWorld then
        SendPacket(2, "action|input\ntext|/warp " .. targetWorld)
        Sleep(1000)
        if GetWorld().name:lower() == targetWorld then
            IKANS("`2Already in world: " .. targetWorld)
        else
            Sleep(config.delay_join_world)
        end
    end
end

function MainBotLoop()
    state.statusMessage = "Scanning locations..."
    IKANS("`2Starting scan...")

    -- === SCAN TAKE ===
    if config.mode_take == "MAG" or config.mode_take == "VEND" then
        if GetWorld().name:upper() ~= config.world_take:upper() then
            JoinWorld(config.world_take)
        end
    end

    if config.mode_take == "MAG" then
        state.take_magplants = scanMagplants(config.mag_bg_take)
        IKANS("`2Scanned TAKE MAG: " .. #state.take_magplants)
    end

    if config.mode_take == "VEND" then
        state.take_vends = scanVends(config.vend_marker_take)
        IKANS("`2Scanned TAKE VEND: " .. #state.take_vends)
    end

    -- === SCAN DROP ===
    if config.mode_drop == "MAG" or config.mode_drop == "VEND" then
        if GetWorld().name:upper() ~= config.world_drop:upper() then
            JoinWorld(config.world_drop)
        end
    end

    if config.mode_drop == "MAG" then
        state.drop_magplants = scanMagplants(config.mag_bg_drop)
        IKANS("`2Scanned DROP MAG: " .. #state.drop_magplants)
    end

    if config.mode_drop == "VEND" then
        state.drop_vends = scanVends(config.vend_marker_drop)
        IKANS("`2Scanned DROP VEND: " .. #state.drop_vends)
    end
    -- === MAIN LOOP ===
    while state.isRunning do
        local count = GetItemCount(config.item_id)

        if count >= 250 then
            -- Inventory full, go drop
            state.statusMessage = "[DROP] Inventory full. Warping to drop world..."
            if GetWorld().name:upper() ~= config.world_drop:upper() then
                IKANS("`2[DROP] Warping...")
                JoinWorld(config.world_drop)
            else
                IKANS("`2[DROP] World OK")
            end

            if not state.isRunning then break end

            if config.mode_drop == "MAG" then
                while state.magDropIndex <= #state.drop_magplants and GetItemCount(config.item_id) >= 250 do
                    if not state.isRunning then break end

                    state.statusMessage = "[DROP] To MAG #" .. state.magDropIndex
                    local t = state.drop_magplants[state.magDropIndex]
                    Sleep(200)
                    TeleportTo(t.x, t.y - 1)
                    Sleep(200)
                    wrench(t.x, t.y)
                    Sleep(500)

                    if state.shouldSetMag then
                        SendPacket(2,
                            "action|dialog_return\ndialog_name|magplant_edit\nx|" ..
                            t.x .. "|\ny|" .. t.y .. "|\nitemToSelect|" .. config.item_id .. "\n")
                        IKANS("`2Setting MAG")
                        Sleep(300)
                        state.shouldSetMag = false
                    elseif state.shouldChangeMag then
                        state.shouldChangeMag = false
                        state.magDropIndex = state.magDropIndex + 1
                        IKANS("`4MAG full!")
                        if state.magDropIndex > #state.drop_magplants then
                            IKANS("`4All MAG full.")
                            state.isRunning = false
                            break
                        end
                    else
                        SendPacket(2,
                            "action|dialog_return\ndialog_name|magplant_edit\nx|" ..
                            t.x .. "|\ny|" .. t.y .. "|\nbuttonClicked|additems\n")
                        IKANS("`2Added to MAG")
                        Sleep(500)
                        break
                    end
                end
            elseif config.mode_drop == "VEND" then
                local chk_peritem = (config.vend_price_mode == "per_item") and 1 or 0
                local chk_perlock = (config.vend_price_mode == "per_wl") and 1 or 0

                while state.vendIndex <= #state.drop_vends and GetItemCount(config.item_id) >= 250 do
                    if not state.isRunning then break end

                    state.statusMessage = "[DROP] To VEND #" .. state.vendIndex
                    local v = state.drop_vends[state.vendIndex]
                    Sleep(200)
                    TeleportTo(v.x, v.y)
                    Sleep(200)
                    wrench(v.x, v.y)
                    Sleep(500)

                    if state.shouldSetVend then
                        IKANS("`2Setting VEND")
                        SendPacket(2,
                            "action|dialog_return\ndialog_name|vend_edit\nx|" ..
                            v.x .. "|\ny|" .. v.y .. "|\nstockitem|" .. config.item_id)
                        Sleep(300)
                        SendPacket(2,
                            "action|dialog_return\ndialog_name|vend_edit\nx|" ..
                            v.x .. "|\ny|" .. v.y .. "|\nsetprice|" .. config.vend_price ..
                            "\nchk_peritem|" .. chk_peritem .. "\nchk_perlock|" .. chk_perlock)
                        Sleep(300)
                        state.shouldSetVend = false
                    elseif state.shouldChangeVend then
                        state.shouldChangeVend = false
                        state.vendIndex = state.vendIndex + 1
                        IKANS("`4VEND full!")
                        if state.vendIndex > #state.drop_vends then
                            IKANS("`4All VEND full.")
                            state.isRunning = false
                            break
                        end
                    else
                        SendPacket(2,
                            "action|dialog_return\ndialog_name|vend_edit\nx|" ..
                            v.x .. "|\ny|" .. v.y .. "|\nbuttonClicked|addstock\n")
                        IKANS("`2Stock added")
                        Sleep(500)
                        break
                    end
                end
            end
        else
            -- Inventory has space, go take
            state.statusMessage = "[TAKE] Inventory has space. Warping to take world..."
            if GetWorld().name:upper() ~= config.world_take:upper() then
                IKANS("`2[TAKE] Warping...")
                JoinWorld(config.world_take)
            else
                IKANS("`2[TAKE] World OK")
            end

            if not state.isRunning then break end

            if config.mode_take == "MAG" then
                while state.magIndex <= #state.take_magplants and GetItemCount(config.item_id) < 250 do
                    if not state.isRunning then break end

                    state.statusMessage = "[TAKE] From MAG #" .. state.magIndex
                    local t = state.take_magplants[state.magIndex]
                    TeleportTo(t.x, t.y - 1)
                    Sleep(200)
                    wrench(t.x, t.y)
                    Sleep(500)

                    if state.shouldSkipEmptyMag then
                        state.shouldSkipEmptyMag = false
                        state.magIndex = state.magIndex + 1
                        IKANS("`4MAG empty!")
                        if state.magIndex > #state.take_magplants then
                            IKANS("`4All MAG empty.")
                            state.isRunning = false
                            break
                        end
                    else
                        SendPacket(2,
                            "action|dialog_return\ndialog_name|magplant_edit\nx|" ..
                            t.x .. "|\ny|" .. t.y .. "|\nbuttonClicked|withdraw\n")
                        IKANS("`2Withdraw from MAG")
                        Sleep(500)
                        if GetItemCount(config.item_id) >= 250 then
                            IKANS("`2Inventory full.")
                            break
                        end
                    end
                end
            elseif config.mode_take == "VEND" then
                while state.takeVendIndex <= #state.take_vends and GetItemCount(config.item_id) < 250 do
                    if not state.isRunning then break end

                    state.statusMessage = "[TAKE] From VEND #" .. state.takeVendIndex
                    local v = state.take_vends[state.takeVendIndex]
                    TeleportTo(v.x, v.y)
                    Sleep(200)
                    wrench(v.x, v.y)
                    Sleep(500)

                    if state.shouldSetVend then
                        state.shouldSetVend = false
                        state.takeVendIndex = state.takeVendIndex + 1
                        IKANS("`4TAKE VEND empty!")
                        if state.takeVendIndex > #state.take_vends then
                            IKANS("`4All TAKE VEND empty.")
                            state.isRunning = false
                            break
                        end
                    else
                        SendPacket(2,
                            "action|dialog_return\ndialog_name|vend_edit\nx|" ..
                            v.x .. "|\ny|" .. v.y .. "|\nbuttonClicked|pullstock\n")
                        IKANS("`2Pullstock from VEND")
                        Sleep(500)
                        if GetItemCount(config.item_id) >= 250 then
                            IKANS("`2Inventory full.")
                            break
                        end
                    end
                end
            elseif config.mode_take == "DROP" then
                state.statusMessage = "[TAKE] Searching for dropped items..."
                local obj = findNearestObject(config.item_id)
                if obj then
                    state.noObjectCounter = 0
                    takeDropMode()
                else
                    state.noObjectCounter = state.noObjectCounter + 1
                    IKANS("`4No object. Count: " .. state.noObjectCounter)
                    if state.noObjectCounter >= 5 then
                        IKANS("`4No object found 5 times.")
                        state.isRunning = false
                        break
                    end
                end
            end
        end

        if state.RECON then
            IKANS("`4Reconnecting...")
            state.RECON = false
        end

        Sleep(200)
    end

    -- Final status
    if not state.isRunning then
        state.statusMessage = "Task stopped."
    else
        state.statusMessage = "Task finished."
    end
end

config.item_name = GetItemInfo(config.item_id).name or "Invalid ID"