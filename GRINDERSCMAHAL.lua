
--[[ Grind System - Created by Yumiko ]]--

local Settings = {
    per = {},
    delay = 150,
    drop = {84, 22},
    max = 125
}

local gui = {
    running = false,
    status = "Idle",
    total_dropped = 0,
    session_start = 0,
    delay_text = "150",
    drop_x_text = "84",
    drop_y_text = "22",
    use_pepper = true,
    use_salt = false
}

function inv(id)
    local c = 0
    for _, i in pairs(GetInventory()) do
        if i.id == id then
            c = c + i.amount
        end
    end
    return c
end

local can_drop = true

AddHook("onvariant", "hook", function(var)
    if var[0] == "OnDialogRequest" and var[1]:find("Item Finder") then
        return true
    end
    if var[0] == "OnTextOverlay" and var[1]:find("You can't drop") then
        can_drop = false
        local player = GetLocal()
        if player.isleft then
            Settings.drop[1] = Settings.drop[1] + 1
        else
            Settings.drop[1] = Settings.drop[1] - 1
        end
        FindPath(Settings.drop[1] - 1, Settings.drop[2] - 1)
        Sleep(1000)
        can_drop = true
    end
end)

function FP(x, y)
    if not gui.running then return false end
    FindPath(x - 1, y - 1)
    Sleep(500)
    return true
end

function drops()
    if not gui.running then return false end
    
    if inv(4568) < 250 and inv(4570) < 250 then
        return true
    end
    
    if not can_drop then
        Sleep(1000)
        return true
    end
    
    gui.status = "Dropping items..."
    SendPacket(2, "action|input\n|text|/ghost")
    Sleep(1500)
    
    if not FP(Settings.drop[1], Settings.drop[2]) then return false end
    Sleep(500)
    
    local drop_amount = 0
    
    if inv(4568) > 0 then
        drop_amount = drop_amount + inv(4568)
        SendPacket(2, "action|dialog_return\ndialog_name|drop\nitem_drop|4568|\nitem_count|" .. inv(4568))
        Sleep(500)
    end
    
    if inv(4570) > 0 then
        drop_amount = drop_amount + inv(4570)
        SendPacket(2, "action|dialog_return\ndialog_name|drop\nitem_drop|4570|\nitem_count|" .. inv(4570))
        Sleep(500)
    end
    
    gui.total_dropped = gui.total_dropped + drop_amount
    
    SendPacket(2, "action|input\n|text|/ghost")
    Sleep(1500)
    
    p = p or math.floor(GetLocal().pos.x / 32)
    h = h or math.floor(GetLocal().pos.y / 32)
    if not FP(p + 1, h + 1) then return false end
    Sleep(500)
    
    gui.status = "Searching & Grinding..."
    
    return true
end

function updateSettings()
    Settings.delay = tonumber(gui.delay_text) or 150
    Settings.drop[1] = tonumber(gui.drop_x_text) or 84
    Settings.drop[2] = tonumber(gui.drop_y_text) or 22
    
    Settings.per = {}
    if gui.use_pepper then
        table.insert(Settings.per, 4584)
    end
    if gui.use_salt then
        table.insert(Settings.per, 4566)
    end
end

function formatTime(seconds)
    local hours = math.floor(seconds / 3600)
    local mins = math.floor((seconds % 3600) / 60)
    local secs = math.floor(seconds % 60)
    return string.format("%02dh %02dm %02ds", hours, mins, secs)
end

function startGrinding()
    updateSettings()
    
    if #Settings.per == 0 then
        LogToConsole("`4[YUMIKO] `wPlease select at least one mode!")
        return
    end
    
    gui.running = true
    gui.status = "Searching & Grinding..."
    gui.total_dropped = 0
    gui.session_start = os.time()
    
    LogToConsole("`2[YUMIKO] `wSession started!")
    
    RunThread(function()
        p = math.floor(GetLocal().pos.x/32)
        h = math.floor(GetLocal().pos.y/32)
        
        local item_index = 1
        
        while gui.running do
            if inv(4568) >= 250 or inv(4570) >= 250 then
                if not drops() then break end
                Sleep(600)
            end
            
            local currentItem = Settings.per[item_index]
            
            if not gui.running then break end
            SendPacket(2, "action|dialog_return\ndialog_name|item_search\n"..currentItem.."|1\n")
            Sleep(Settings.delay)
            SendPacket(2, "action|dialog_return\ndialog_name|grinder\nx|"..p.."|\ny|"..h.."|\nitemID|"..currentItem.."|\namount|2")
            Sleep(100)
            
            if #Settings.per > 1 then
                item_index = item_index + 1
                if item_index > #Settings.per then
                    item_index = 1
                end
            end
            
            Sleep(100)
        end
        
        gui.running = false
        gui.status = "Stopped"
        LogToConsole("`2[YUMIKO] `wSession ended. Total dropped: `4" .. gui.total_dropped)
    end)
end

function stopGrinding()
    gui.running = false
    gui.status = "Stopping..."
end

local ICON_CHART_LINE = "\xef\x88\x81"
local ICON_PLAY = "\xef\x81\x8b"
local ICON_STOP = "\xef\x81\x8d"
local ICON_GEAR = "\xef\x80\x93"
local ICON_CLOCK = "\xef\x80\x97"
local ICON_LOCATION_DOT = "\xef\x8f\x85"
local ICON_CUBES = "\xef\x86\xb3"
local ICON_FIRE = "\xef\x81\xad"
local ICON_BOX = "\xef\x91\xa6"
local ICON_INFO = "\xef\x81\x9a"
local ICON_SLIDERS = "\xef\x87\xa6"

function GrindGUIOnDraw()
    ImGui.SetNextWindowSize(ImVec2(420, 480), ImGui.Cond.FirstUseEver)
    local flags = ImGui.WindowFlags.NoCollapse
    ImGui.Begin(ICON_FIRE .. " Grind Advance", flags)
    
    ImGui.Text("GRIND ADVANCE")
    ImGui.Separator()
    
    if ImGui.BeginTabBar("MainTabs") then
        
        if ImGui.BeginTabItem(ICON_INFO .. " Info") then
            
            ImGui.Text(ICON_CHART_LINE .. " STATUS")
            ImGui.Separator()
            
            if gui.running then
                ImGui.Text("Status: ACTIVE")
            else
                ImGui.Text("Status: IDLE")
            end
            
            ImGui.Text("Action: " .. gui.status)
            
            local session_time = gui.running and (os.time() - gui.session_start) or 0
            ImGui.Text(ICON_CLOCK .. " Time: " .. formatTime(session_time))
            
            ImGui.Separator()
            
            ImGui.Text(ICON_CUBES .. " MODE")
            ImGui.Separator()
            
            local modes = {}
            if gui.use_pepper then table.insert(modes, "Pepper (4584)") end
            if gui.use_salt then table.insert(modes, "Salt (4566)") end
            local mode_text = #modes > 0 and table.concat(modes, " + ") or "None"
            
            ImGui.TextWrapped("Active: " .. mode_text)
            ImGui.Text("Delay: " .. Settings.delay .. "ms")
            ImGui.Text("Drop: X=" .. Settings.drop[1] .. " Y=" .. Settings.drop[2])
            
            ImGui.Separator()
            
            ImGui.Text(ICON_BOX .. " INVENTORY")
            ImGui.Separator()
            
            local salt_inv = inv(4568)
            local salt_progress = salt_inv / 250
            ImGui.Text("Salt (4568): " .. salt_inv .. " / 250")
            ImGui.ProgressBar(salt_progress, ImVec2(-1, 0), string.format("%.1f%%", salt_progress * 100))
            
            local pepper_inv = inv(4570)
            local pepper_progress = pepper_inv / 250
            ImGui.Text("Pepper (4570): " .. pepper_inv .. " / 250")
            ImGui.ProgressBar(pepper_progress, ImVec2(-1, 0), string.format("%.1f%%", pepper_progress * 100))
            
            ImGui.Separator()
            
            ImGui.Text(ICON_BOX .. " PRODUCTION")
            ImGui.Separator()
            ImGui.Text("Dropped: " .. gui.total_dropped .. " items")
            
            ImGui.EndTabItem()
        end
        
        if ImGui.BeginTabItem(ICON_CUBES .. " Mode") then
            
            ImGui.Text(ICON_CUBES .. " SELECT MODE")
            ImGui.Separator()
            
            ImGui.TextWrapped("Choose grinding mode (can select both):")
            ImGui.Spacing()
            
            if ImGui.Checkbox("Pepper Tree (4584)", gui.use_pepper) then
                gui.use_pepper = not gui.use_pepper
            end
            
            ImGui.Spacing()
            
            if ImGui.Checkbox("Salt Block (4566)", gui.use_salt) then
                gui.use_salt = not gui.use_salt
            end
            
            ImGui.Spacing()
            ImGui.Separator()
            ImGui.Spacing()
            
            ImGui.TextWrapped("Select one or both modes. Will grind both items alternately if both selected.")
            
            ImGui.EndTabItem()
        end
        
        if ImGui.BeginTabItem(ICON_GEAR .. " Settings") then
            
            ImGui.Text(ICON_SLIDERS .. " CONFIGURATION")
            ImGui.Separator()
            
            ImGui.Text(ICON_CLOCK .. " Search Delay (ms)")
            ImGui.PushItemWidth(-1)
            local changed, new_val = ImGui.InputText("##delay", gui.delay_text, 256)
            if changed then gui.delay_text = new_val end
            ImGui.PopItemWidth()
            
            ImGui.Spacing()
            ImGui.Separator()
            
            ImGui.Text(ICON_LOCATION_DOT .. " Drop Position")
            ImGui.Spacing()
            
            ImGui.Text("X:")
            ImGui.PushItemWidth(-1)
            local changed, new_val = ImGui.InputText("##dropx", gui.drop_x_text, 256)
            if changed then gui.drop_x_text = new_val end
            ImGui.PopItemWidth()
            
            ImGui.Spacing()
            
            ImGui.Text("Y:")
            ImGui.PushItemWidth(-1)
            local changed, new_val = ImGui.InputText("##dropy", gui.drop_y_text, 256)
            if changed then gui.drop_y_text = new_val end
            ImGui.PopItemWidth()
            
            ImGui.Spacing()
            ImGui.TextWrapped("Drop coordinates when inventory full")
            
            ImGui.EndTabItem()
        end
        
        ImGui.EndTabBar()
    end
    
    ImGui.Separator()
    
    if not gui.running then
        if ImGui.Button(ICON_PLAY .. " START GRINDING", ImVec2(-1, 0)) then
            startGrinding()
        end
    else
        if ImGui.Button(ICON_STOP .. " STOP GRINDING", ImVec2(-1, 0)) then
            stopGrinding()
        end
    end
    
    ImGui.Separator()
    ImGui.Text("Created by Yumiko")
    
    ImGui.End()
end

AddHook("OnDraw", "GRIND_GUI", GrindGUIOnDraw)

LogToConsole("`2[YUMIKO] `wGrind System loaded!")
