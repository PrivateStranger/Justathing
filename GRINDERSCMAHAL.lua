
--[[ Grind Ver 27black or Rp300.0000,00 with ImGui ]]--

-- Settings
local Settings = {
    per = 4584,
    delay = 150,
    drop = {84, 22},
    max = 125
}

-- GUI State
local gui = {
    running = false,
    status = "Idle",
    grind_count = 0,
    total_dropped = 0,
    
    -- Settings as strings
    delay_text = "150",
    drop_x_text = "84",
    drop_y_text = "22",
    max_text = "125",
    
    -- Checkboxes for item selection
    use_pepper = true,  -- 4584
    use_salt = false    -- 4566
}

-- Original Functions
function inv(id)
    local c = 0
    for _, i in pairs(GetInventory()) do
        if i.id == id then
            c = c + i.amount
        end
    end
    return c
end

AddHook("onvariant", "hook", function(var)
    if var[0] == "OnDialogRequest" and var[1]:find("Item Finder") then
        return true
    end
end)

DropY = {}

function FP(x, y)
    local px = math.floor(GetLocal().pos.x / 32)
    local py = math.floor(GetLocal().pos.y / 32)
    
    while math.abs(y - py) > 6 do
        if not gui.running then return false end
        py = py + (y - py > 0 and 6 or -6)
        FindPath(px, py)
        Sleep(200)
    end
    while math.abs(x - px) > 6 do
        if not gui.running then return false end
        px = px + (x - px > 0 and 6 or -6)
        FindPath(px, py)
        Sleep(200)
    end
    Sleep(100)
    FindPath(x, y)
    return true
end

function drops(id, i)
    if not gui.running then return false end
    
    if not DropY[i] then
        DropY[i] = Settings.drop[2]
    end
    local x = Settings.drop[1] + (i - 1)
    local y = DropY[i] or Settings.drop[2]
    
    if not FP(x - 1, y) then return false end
    Sleep(500)
    
    for a = 1, 24 do
        if not gui.running then return false end
        if inv(id) >= 250 then
            SendPacket(2, "action|dialog_return\ndialog_name|drop\nitem_drop|"..id.."|\nitem_count|"..inv(id).."|\n")
            Sleep(400)
            gui.total_dropped = gui.total_dropped + inv(id)
        end
    end
    
    if not FP(p, h) then return false end
    Sleep(500)
    
    if inv(id) >= 250 then
        DropY[i] = DropY[i] - 1
    end
    return true
end

function updateSettings()
    Settings.delay = tonumber(gui.delay_text) or 150
    Settings.drop[1] = tonumber(gui.drop_x_text) or 84
    Settings.drop[2] = tonumber(gui.drop_y_text) or 22
    Settings.max = tonumber(gui.max_text) or 125
    
    -- Set item ID based on checkbox
    if gui.use_pepper then
        Settings.per = 4570
    elseif gui.use_salt then
        Settings.per = 4566
    end
end

function startGrinding()
    gui.running = true
    gui.status = "Starting..."
    gui.grind_count = 0
    gui.total_dropped = 0
    
    updateSettings()
    
    RunThread(function()
        p = math.floor(GetLocal().pos.x/32)
        h = math.floor(GetLocal().pos.y/32)
        
        local c = 0
        local g = false
        
        while gui.running do
            if inv(Settings.per) >= 250 then
                gui.status = "Dropping items..."
                if not drops(Settings.per, 1) then break end
                Sleep(600)
                c = 0
                g = false
            end
            
            if g then
                if not gui.running then break end
                gui.status = "Grinding... (" .. c .. "/" .. Settings.max .. ")"
                SendPacket(2, "action|dialog_return\ndialog_name|grinder\nx|"..p.."|\ny|"..h.."|\nitemID|"..Settings.per.."|\namount|2")
                Sleep(100)
            else
                if c < Settings.max then
                    if not gui.running then break end
                    gui.status = "Searching & Grinding... (" .. c .. "/" .. Settings.max .. ")"
                    SendPacket(2, "action|dialog_return\ndialog_name|item_search\n"..Settings.per.."|1\n")
                    Sleep(Settings.delay)
                    SendPacket(2, "action|dialog_return\ndialog_name|grinder\nx|"..p.."|\ny|"..h.."|\nitemID|"..Settings.per.."|\namount|2")
                    Sleep(100)
                    c = c + 1
                    gui.grind_count = c
                    LogToConsole(string.format("Grinding Attempt: %d/%d", c, Settings.max))
                    if c >= Settings.max then
                        g = true
                    end
                end
            end
            
            if g and c < Settings.max then
                g = false
            end
            
            Sleep(100)
        end
        
        gui.running = false
        gui.status = "Stopped"
        LogToConsole("Grinding stopped!")
    end)
end

function stopGrinding()
    gui.running = false
    gui.status = "Stopping..."
    LogToConsole("Stop button pressed...")
end

-- Font Awesome Icons
local ICON_SEEDLING = "\xef\x93\x98"
local ICON_CHART_LINE = "\xef\x88\x81"
local ICON_PLAY = "\xef\x81\x8b"
local ICON_STOP = "\xef\x81\x8d"
local ICON_GEAR = "\xef\x80\x93"
local ICON_CLOCK = "\xef\x80\x97"
local ICON_LOCATION_DOT = "\xef\x8f\x85"
local ICON_CUBES = "\xef\x86\xb3"

-- GUI Render Function
function GrindGUIOnDraw()
    ImGui.SetNextWindowSize(ImVec2(450, 550), ImGui.Cond.FirstUseEver)
    local flags = ImGui.WindowFlags.NoCollapse
    ImGui.Begin("Grind Script by 27black", flags)
    
    -- Status Section
    ImGui.Separator()
    ImGui.Text(ICON_CHART_LINE .. " Status Information")
    ImGui.Separator()
    
    if gui.running then
        ImGui.TextColored(ImVec4(0.2, 1.0, 0.2, 1.0), "Status: " .. gui.status)
    else
        ImGui.TextColored(ImVec4(1.0, 0.3, 0.3, 1.0), "Status: " .. gui.status)
    end
    
    ImGui.Text("Grind Count: " .. gui.grind_count .. " / " .. Settings.max)
    ImGui.Text("Total Dropped: " .. gui.total_dropped)
    ImGui.Text("Inventory: " .. inv(Settings.per))
    
    local progress = math.min(gui.grind_count / Settings.max, 1.0)
    ImGui.ProgressBar(progress, ImVec2(-1, 0), string.format("%d / %d (%.1f%%)", gui.grind_count, Settings.max, progress * 100))
    
    ImGui.Spacing()
    ImGui.Separator()
    
    -- Control Buttons
    ImGui.Text(ICON_PLAY .. " Controls")
    ImGui.Separator()
    
    if not gui.running then
        if ImGui.Button(ICON_PLAY .. " Start Grinding", ImVec2(-1, 35)) then
            startGrinding()
        end
    else
        if ImGui.Button(ICON_STOP .. " Stop Grinding", ImVec2(-1, 35)) then
            stopGrinding()
        end
    end
    
    ImGui.Spacing()
    ImGui.Separator()
    
    -- Settings Section
    ImGui.Text(ICON_GEAR .. " Settings")
    ImGui.Separator()
    
    -- Item Selection
    ImGui.Text(ICON_CUBES .. " Item Type")
    ImGui.Separator()
    
    if ImGui.Checkbox("Pepper Tree (ID: 4584)", gui.use_pepper) then
        gui.use_pepper = not gui.use_pepper
        if gui.use_pepper then
            gui.use_salt = false
        end
    end
    
    if ImGui.Checkbox("Salt Block (ID: 4566)", gui.use_salt) then
        gui.use_salt = not gui.use_salt
        if gui.use_salt then
            gui.use_pepper = false
        end
    end
    
    ImGui.Spacing()
    ImGui.Text(ICON_CLOCK .. " Timing")
    ImGui.Separator()
    
    ImGui.Text("Delay (ms)")
    ImGui.PushItemWidth(-1)
    local changed, new_val = ImGui.InputText("##delay", gui.delay_text, 256)
    if changed then gui.delay_text = new_val end
    ImGui.PopItemWidth()
    
    ImGui.Spacing()
    ImGui.Text("Max Grind Count")
    ImGui.PushItemWidth(-1)
    local changed, new_val = ImGui.InputText("##max", gui.max_text, 256)
    if changed then gui.max_text = new_val end
    ImGui.PopItemWidth()
    
    ImGui.Spacing()
    ImGui.Text(ICON_LOCATION_DOT .. " Drop Position")
    ImGui.Separator()
    
    ImGui.Text("Drop X")
    ImGui.PushItemWidth(-1)
    local changed, new_val = ImGui.InputText("##dropx", gui.drop_x_text, 256)
    if changed then gui.drop_x_text = new_val end
    ImGui.PopItemWidth()
    
    ImGui.Spacing()
    ImGui.Text("Drop Y")
    ImGui.PushItemWidth(-1)
    local changed, new_val = ImGui.InputText("##dropy", gui.drop_y_text, 256)
    if changed then gui.drop_y_text = new_val end
    ImGui.PopItemWidth()
    
    ImGui.Spacing()
    ImGui.Separator()
    ImGui.TextColored(ImVec4(0.5, 0.5, 0.5, 1.0), "Grind Script v1.0 by 27black")
    
    ImGui.End()
end

-- Register GUI Hook
AddHook("OnDraw", "GRIND_GUI", GrindGUIOnDraw)

LogToConsole("Grind Script with ImGui loaded!")
