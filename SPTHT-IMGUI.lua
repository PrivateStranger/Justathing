
-- Original script variables
lineY = 197
amtseed = 18000
FirstSeed = 2019
combined = 53785
delayPlant = 50
delayHarvest = 30
delayGrow = 50
FirstMagplant = {3, 199}
TwoMagplant = {4, 199}
World = "island"
autoUWS = 0
autoAGE = 1

-- GUI State
local gui = {
    running = false,
    status = "Idle",
    seeds_ready = 0,
    cycle_count = 0,
    current_tab = 0,
    
    -- Settings as strings for text input
    lineY_text = "197",
    amtseed_text = "18000",
    FirstSeed_text = "2019",
    combined_text = "53785",
    delayPlant_text = "50",
    delayHarvest_text = "30",
    delayGrow_text = "50",
    FirstMagX_text = "3",
    FirstMagY_text = "199",
    TwoMagX_text = "4",
    TwoMagY_text = "199",
    
    -- Checkboxes
    WorldNormal = false,
    WorldIsland = true,
    autoUWS_check = false,
    autoAGE_check = true
}

y1 = 0
y2 = lineY

-- Helper Functions
function IsReady(tile)
    return tile and tile.extra and tile.extra.progress and tile.extra.progress == 1.0
end

AddHook("onvariant", "dcwatch", function(var)
    if var[0] == "OnSDBroadcast" then
        return true
    end
    if var[0] == "OnDialogRequest" and var[1]:find("MAGPLANT 5000") then
        if var[1]:find("empty!") then end
        return true
    end
end)

local function wrench(x, y)
    SendPacketRaw(false, {
        px = x,
        py = y,
        x = x * 32,
        y = y * 32,
        type = 3,
        value = 32
    })
end

local below = true

function FindPathSmart(targetX, targetY, stepDelay)
    if not gui.running then return false end
    
    local me = GetLocal()
    local currentX = math.floor(me.pos.x / 32)
    local currentY = math.floor(me.pos.y / 32)

    local distanceX = targetX - currentX
    local distanceY = targetY - currentY

    local steps = math.max(math.abs(distanceX), math.abs(distanceY))
    local stepSize = 3

    if steps > stepSize then
        local stepsNeeded = math.ceil(steps / stepSize)
        local stepX = distanceX / stepsNeeded
        local stepY = distanceY / stepsNeeded

        for i = 1, stepsNeeded do
            if not gui.running then return false end
            local nextX = math.floor(currentX + stepX * i)
            local nextY = math.floor(currentY + stepY * i)
            FindPath(nextX, nextY, stepDelay)
            Sleep(150)
        end
    else
        FindPath(targetX, targetY, stepDelay)
    end
    return true
end

local function magplant(x, y, z)
    if not gui.running then return false end
    
    if not FindPathSmart(x, y, 70) then return false end
    Sleep(200)
    
    if not gui.running then return false end
    wrench(x, y + (below and 1 or -1))
    Sleep(200)
    
    if not gui.running then return false end
    SendPacket(2, "action|dialog_return\ndialog_name|magplant_edit\nx|"..x.."|\ny|"..(y + (below and 1 or -1)).."|\nbuttonClicked|"..z)
    Sleep(200)
    return true
end

local function TakeMagplant1()
    if not gui.running then return false end
    
    SendPacket(2, "action|respawn")
    Sleep(3000)
    
    if not gui.running then return false end
    if not FindPathSmart(FirstMagplant[1] - 1, FirstMagplant[2] - 1, 70) then return false end
    Sleep(100)
    
    if not gui.running then return false end
    if not magplant(FirstMagplant[1] - 1, FirstMagplant[2] - 1, "getRemote") then return false end
    Sleep(1000)
    return true
end

local function TakeMagplant2()
    if not gui.running then return false end
    
    SendPacket(2, "action|respawn")
    Sleep(3000)
    
    if not gui.running then return false end
    if not FindPathSmart(TwoMagplant[1] - 1, TwoMagplant[2] - 1, 70) then return false end
    Sleep(100)
    
    if not gui.running then return false end
    if not magplant(TwoMagplant[1] - 1, TwoMagplant[2] - 1, "getRemote") then return false end
    Sleep(1000)
    return true
end

function checkseed()
    local Ready = 0
    for y = y1, y2 do
        for x = 0, 199 do
            if IsReady(GetTile(x, y)) and GetTile(x, y).fg == combined then
                Ready = Ready + 1
            end
        end
    end
    gui.seeds_ready = Ready
    return Ready
end

function punch(x, y)
    local pkt = {
        type = 3,
        value = 18,
        x = GetLocal().pos.x,
        y = GetLocal().pos.y,
        px = math.floor(GetLocal().pos.x / 32 + x),
        py = math.floor(GetLocal().pos.y / 32 + y)
    }
    SendPacketRaw(false, pkt)
end

function place(id, x, y)
    local pkt = {
        type = 3,
        value = id,
        px = math.floor(GetLocal().pos.x / 32 + x),
        py = math.floor(GetLocal().pos.y / 32 + y),
        x = GetLocal().pos.x,
        y = GetLocal().pos.y
    }
    SendPacketRaw(false, pkt)
end

function plant1(startX, endX, stepX, startY, endY, stepY)
    if not gui.running then return false end
    if checkseed() >= amtseed then return true end
    
    for x = startX, endX, stepX do
        if not gui.running then return false end
        for y = startY, endY, stepY do
            if not gui.running then return false end
            if GetTile(x, y).fg == 0 then
                if not FindPathSmart(x, y, 50) then return false end
                Sleep(delayPlant)
                if not gui.running then return false end
                place(5640, 0, 0)
                Sleep(delayPlant)
            end
        end
    end
    return true
end

function plant2(startX, endX, stepX, startY, endY, stepY)
    if not gui.running then return false end
    if checkseed() >= amtseed then return true end
    
    for x = startX, endX, stepX do
        if not gui.running then return false end
        for y = startY, endY, stepY do
            if not gui.running then return false end
            if GetTile(x, y).fg == FirstSeed then
                if not FindPathSmart(x, y, 50) then return false end
                Sleep(delayPlant)
                if not gui.running then return false end
                place(5640, 0, 0)
                Sleep(delayPlant)
            end
        end
    end
    return true
end

function harvest()
    if not gui.running then return false end
    if checkseed() <= amtseed then return true end
    
    gui.status = "Harvesting..."
    for y = y2, y1, -1 do
        if not gui.running then return false end
        for x = 0, 0 do
            if not gui.running then return false end
            if IsReady(GetTile(x, y)) then
                if not FindPathSmart(x, y, 50) then return false end
                Sleep(delayHarvest)
                if not gui.running then return false end
                punch(0, 0)
                Sleep(delayHarvest)
            end
        end
    end
    return true
end

function plantRow(x)
    if not gui.running then return false end
    
    gui.status = "Planting Row " .. x
    if not TakeMagplant1() then return false end
    if not plant1(x, x, 1, y2, y1, -1) then return false end
    if not TakeMagplant2() then return false end
    if not plant2(x, x, 1, y2, y1, -1) then return false end
    return true
end

function startPlanting()
    if not gui.running then return false end
    
    local xSteps = {}

    if World == "normal" then
        xSteps = {0, 10, 20, 30, 40, 50, 60, 70, 80, 90}
    elseif World == "island" then
        xSteps = {0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120, 130, 140, 150, 160, 170, 180, 190}
    else
        LogToConsole("World type not recognized: " .. World)
        return false
    end

    for _, x in ipairs(xSteps) do
        if not gui.running then return false end
        if not plantRow(x) then return false end
    end
    return true
end

function uws()
    if not gui.running then return false end
    
    if autoUWS == 1 then
        gui.status = "Using UWS..."
        SendPacket(2, "action|dialog_return\ndialog_name|ultraworldspray")
        Sleep(4000)
    else
        Sleep(delayGrow)
    end
    return true
end

local message1 = "/age 999999"

function age()
    if not gui.running then return false end
    
    if autoAGE == 1 then
        gui.status = "Using AGE..."
        SendPacket(2, "action|input\n|text|" .. message1)
        Sleep(4000)
    else
        Sleep(delayGrow)
    end
    return true
end

function startFarmingLoop()
    gui.running = true
    gui.status = "Starting..."
    
    RunThread(function()
        while gui.running do
            gui.cycle_count = gui.cycle_count + 1
            
            if World == "normal" then
                if not harvest() then break end
                if not gui.running then break end
                Sleep(200)
                if not harvest() then break end
                if not gui.running then break end
                Sleep(1500)
                if not startPlanting() then break end
                if not gui.running then break end
                Sleep(1000)
                if not age() then break end
                if not gui.running then break end
                if not uws() then break end
            elseif World == "island" then
                if not harvest() then break end
                if not gui.running then break end
                Sleep(200)
                if not harvest() then break end
                if not gui.running then break end
                Sleep(500)
                if not startPlanting() then break end
                if not gui.running then break end
                Sleep(1000)
                if not age() then break end
                if not gui.running then break end
                if not uws() then break end
            end
            
            if not gui.running then break end
        end
        
        gui.running = false
        gui.status = "Stopped"
        LogToConsole("Farming stopped successfully!")
    end)
end

function stopFarmingLoop()
    gui.running = false
    gui.status = "Stopping..."
    LogToConsole("Stop button pressed, waiting for current action to finish...")
end

function updateSettings()
    lineY = tonumber(gui.lineY_text) or 197
    amtseed = tonumber(gui.amtseed_text) or 18000
    FirstSeed = tonumber(gui.FirstSeed_text) or 2019
    combined = tonumber(gui.combined_text) or 53785
    delayPlant = tonumber(gui.delayPlant_text) or 50
    delayHarvest = tonumber(gui.delayHarvest_text) or 30
    delayGrow = tonumber(gui.delayGrow_text) or 50
    FirstMagplant = {tonumber(gui.FirstMagX_text) or 3, tonumber(gui.FirstMagY_text) or 199}
    TwoMagplant = {tonumber(gui.TwoMagX_text) or 4, tonumber(gui.TwoMagY_text) or 199}
    World = gui.WorldIsland and "island" or "normal"
    autoUWS = gui.autoUWS_check and 1 or 0
    autoAGE = gui.autoAGE_check and 1 or 0
    y2 = lineY
end

-- Font Awesome Icons
local ICON_SEEDLING = "\xef\x93\x98"
local ICON_CHART_LINE = "\xef\x88\x81"
local ICON_PLAY = "\xef\x81\x8b"
local ICON_STOP = "\xef\x81\x8d"
local ICON_GEAR = "\xef\x80\x93"
local ICON_SCREWDRIVER_WRENCH = "\xef\x9f\x99"
local ICON_ROBOT = "\xef\x95\x84"
local ICON_INFO = "\xef\x84\xa9"
local ICON_GLOBE = "\xef\x82\xac"
local ICON_CLOCK = "\xef\x80\x97"
local ICON_WATER = "\xef\x9d\xb3"
local ICON_HOURGLASS = "\xef\x89\x94"
local ICON_LOCATION_DOT = "\xef\x8f\x85"
local ICON_LIGHTBULB = "\xef\x83\xab"
local ICON_TRIANGLE_EXCLAMATION = "\xef\x81\xb1"
local ICON_CROSSHAIRS = "\xef\x81\x9b"

-- GUI Render Function
function FarmGUIOnDraw()
    ImGui.SetNextWindowSize(ImVec2(550, 650), ImGui.Cond.FirstUseEver)
    local flags = ImGui.WindowFlags.NoCollapse
    ImGui.Begin(ICON_SEEDLING .. " SPTHT IMGUI", flags)
    
    -- Status Section
    ImGui.Separator()
    ImGui.Text(ICON_CHART_LINE .. " Status Information")
    ImGui.Separator()
    
    if gui.running then
        ImGui.TextColored(ImVec4(0.2, 1.0, 0.2, 1.0), "Status: " .. gui.status)
    else
        ImGui.TextColored(ImVec4(1.0, 0.3, 0.3, 1.0), "Status: " .. gui.status)
    end
    
    ImGui.Text("Seeds Ready: " .. gui.seeds_ready .. " / " .. amtseed)
    ImGui.Text("Cycle Count: " .. gui.cycle_count)
    
    local progress = math.min(gui.seeds_ready / amtseed, 1.0)
    ImGui.ProgressBar(progress, ImVec2(-1, 0), string.format("%d / %d (%.1f%%)", gui.seeds_ready, amtseed, progress * 100))
    
    ImGui.Spacing()
    ImGui.Separator()
    
    -- Control Buttons
    ImGui.Text(ICON_PLAY .. " Controls")
    ImGui.Separator()
    
    if not gui.running then
        if ImGui.Button(ICON_PLAY .. " Start Farm", ImVec2(-1, 35)) then
            updateSettings()
            startFarmingLoop()
        end
    else
        if ImGui.Button(ICON_STOP .. " Stop Farm", ImVec2(-1, 35)) then
            stopFarmingLoop()
        end
    end
    
    ImGui.Spacing()
    ImGui.Separator()
    
    -- Tabs
    if ImGui.BeginTabBar("MainTabs") then
        
        -- Basic Settings Tab
        if ImGui.BeginTabItem(ICON_GEAR .. " Basic Settings") then
            ImGui.Spacing()
            
            ImGui.Text(ICON_GLOBE .. " World Settings")
            ImGui.Separator()
            
            if ImGui.Checkbox("Normal World", gui.WorldNormal) then
                gui.WorldNormal = not gui.WorldNormal
                if gui.WorldNormal then
                    gui.WorldIsland = false
                end
            end
            
            if ImGui.Checkbox("Island World", gui.WorldIsland) then
                gui.WorldIsland = not gui.WorldIsland
                if gui.WorldIsland then
                    gui.WorldNormal = false
                end
            end
            
            ImGui.Spacing()
            ImGui.Text(ICON_SEEDLING .. " Farm Settings")
            ImGui.Separator()
            
            ImGui.Text("Farm Limit Line Y")
            ImGui.PushItemWidth(-1)
            local changed, new_val = ImGui.InputText("##lineY", gui.lineY_text, 256)
            if changed then gui.lineY_text = new_val end
            ImGui.PopItemWidth()
            
            ImGui.Spacing()
            ImGui.Text("Maximum Trees")
            ImGui.PushItemWidth(-1)
            local changed, new_val = ImGui.InputText("##amtseed", gui.amtseed_text, 256)
            if changed then gui.amtseed_text = new_val end
            ImGui.PopItemWidth()
            
            ImGui.Spacing()
            ImGui.Text(ICON_SEEDLING .. " Seed Settings")
            ImGui.Separator()
            
            ImGui.Text("First Seed ID")
            ImGui.PushItemWidth(-1)
            local changed, new_val = ImGui.InputText("##FirstSeed", gui.FirstSeed_text, 256)
            if changed then gui.FirstSeed_text = new_val end
            ImGui.PopItemWidth()
            
            ImGui.Spacing()
            ImGui.Text("Combined Seed ID")
            ImGui.PushItemWidth(-1)
            local changed, new_val = ImGui.InputText("##combined", gui.combined_text, 256)
            if changed then gui.combined_text = new_val end
            ImGui.PopItemWidth()
            
            ImGui.EndTabItem()
        end
        
        -- Advanced Settings Tab
        if ImGui.BeginTabItem(ICON_SCREWDRIVER_WRENCH .. " Advanced") then
            ImGui.Spacing()
            
            ImGui.Text(ICON_CLOCK .. " Delay Settings (ms)")
            ImGui.Separator()
            
            ImGui.Text("Plant Delay")
            ImGui.PushItemWidth(-1)
            local changed, new_val = ImGui.InputText("##delayPlant", gui.delayPlant_text, 256)
            if changed then gui.delayPlant_text = new_val end
            ImGui.PopItemWidth()
            
            ImGui.Spacing()
            ImGui.Text("Harvest Delay")
            ImGui.PushItemWidth(-1)
            local changed, new_val = ImGui.InputText("##delayHarvest", gui.delayHarvest_text, 256)
            if changed then gui.delayHarvest_text = new_val end
            ImGui.PopItemWidth()
            
            ImGui.Spacing()
            ImGui.Text("Grow Delay")
            ImGui.PushItemWidth(-1)
            local changed, new_val = ImGui.InputText("##delayGrow", gui.delayGrow_text, 256)
            if changed then gui.delayGrow_text = new_val end
            ImGui.PopItemWidth()
            
            ImGui.Spacing()
            ImGui.Text(ICON_LOCATION_DOT .. " Magplant Positions")
            ImGui.Separator()
            
            -- First Magplant
            ImGui.Text("First Magplant Position")
            ImGui.TextColored(ImVec4(0.7, 0.7, 0.7, 1.0), "Stand on magplant, then click GET TILE")
            
            if ImGui.Button(ICON_CROSSHAIRS .. " GET TILE (First)", ImVec2(180, 0)) then
                local player = GetLocal()
                if player then
                    local px = math.floor(player.pos.x / 32 + 1)
                    local py = math.floor(player.pos.y / 32 + 1)
                    gui.FirstMagX_text = tostring(px)
                    gui.FirstMagY_text = tostring(py)
                    LogToConsole("First Magplant set to: X=" .. px .. ", Y=" .. py)
                end
            end
            
            ImGui.SameLine()
            ImGui.Text("X:")
            ImGui.SameLine()
            ImGui.PushItemWidth(80)
            local changed, new_val = ImGui.InputText("##FirstMagX", gui.FirstMagX_text, 256)
            if changed then gui.FirstMagX_text = new_val end
            ImGui.PopItemWidth()
            ImGui.SameLine()
            ImGui.Text("Y:")
            ImGui.SameLine()
            ImGui.PushItemWidth(80)
            local changed, new_val = ImGui.InputText("##FirstMagY", gui.FirstMagY_text, 256)
            if changed then gui.FirstMagY_text = new_val end
            ImGui.PopItemWidth()
            
            ImGui.Spacing()
            ImGui.Separator()
            
            -- Second Magplant
            ImGui.Text("Second Magplant Position")
            ImGui.TextColored(ImVec4(0.7, 0.7, 0.7, 1.0), "Stand on magplant, then click GET TILE")
            
            if ImGui.Button(ICON_CROSSHAIRS .. " GET TILE (Second)", ImVec2(180, 0)) then
                local player = GetLocal()
                if player then
                    local px = math.floor(player.pos.x / 32 + 1)
                    local py = math.floor(player.pos.y / 32 + 1)
                    gui.TwoMagX_text = tostring(px)
                    gui.TwoMagY_text = tostring(py)
                    LogToConsole("Second Magplant set to: X=" .. px .. ", Y=" .. py)
                end
            end
            
            ImGui.SameLine()
            ImGui.Text("X:")
            ImGui.SameLine()
            ImGui.PushItemWidth(80)
            local changed, new_val = ImGui.InputText("##TwoMagX", gui.TwoMagX_text, 256)
            if changed then gui.TwoMagX_text = new_val end
            ImGui.PopItemWidth()
            ImGui.SameLine()
            ImGui.Text("Y:")
            ImGui.SameLine()
            ImGui.PushItemWidth(80)
            local changed, new_val = ImGui.InputText("##TwoMagY", gui.TwoMagY_text, 256)
            if changed then gui.TwoMagY_text = new_val end
            ImGui.PopItemWidth()
            
            ImGui.EndTabItem()
        end
        
        -- Auto Features Tab
        if ImGui.BeginTabItem(ICON_ROBOT .. " Auto Features") then
            ImGui.Spacing()
            
            ImGui.Text("Automatic Features")
            ImGui.Separator()
            
            if ImGui.Checkbox(ICON_WATER .. " Auto UWS (Ultra World Spray)", gui.autoUWS_check) then
                gui.autoUWS_check = not gui.autoUWS_check
            end
            ImGui.TextWrapped("Automatically use Ultra World Spray after planting")
            
            ImGui.Spacing()
            ImGui.Spacing()
            
            if ImGui.Checkbox(ICON_HOURGLASS .. " Auto AGE (Age Command)", gui.autoAGE_check) then
                gui.autoAGE_check = not gui.autoAGE_check
            end
            ImGui.TextWrapped("Automatically use /age command after planting")
            
            ImGui.Spacing()
            ImGui.Separator()
            
            ImGui.TextColored(ImVec4(1.0, 0.8, 0.2, 1.0), ICON_TRIANGLE_EXCLAMATION .. " Warning:")
            ImGui.TextWrapped("Make sure you have the necessary permissions and items before enabling auto features.")
            
            ImGui.EndTabItem()
        end
        
        -- Info Tab
        if ImGui.BeginTabItem(ICON_INFO .. " Info") then
            ImGui.Spacing()
            
            ImGui.Text("All Recipe(maybe) soon")
            ImGui.Separator()
            ImGui.TextWrapped("1. Configure your farm settings in the Basic Settings tab")
            ImGui.TextWrapped("2. Set up your Magplant positions in Advanced Settings")
            ImGui.TextWrapped("3. Enable auto features if desired")
            ImGui.TextWrapped("4. Click 'Start Farm' to begin the farming process")
            
            ImGui.Spacing()
            ImGui.Text(ICON_LIGHTBULB .. " Tips")
            ImGui.Separator()
            ImGui.TextWrapped("- Use GET TILE button for easy Magplant position detection")
            ImGui.TextWrapped("- Stand directly on top of the Magplant before clicking GET TILE")
            ImGui.TextWrapped("- Adjust delays based on your connection speed")
            ImGui.TextWrapped("- Monitor the progress bar to track farming efficiency")
            ImGui.TextWrapped("- Use Island World mode for larger farms")
            
            ImGui.Spacing()
            ImGui.Text(ICON_TRIANGLE_EXCLAMATION .. " Important")
            ImGui.Separator()
            ImGui.TextWrapped("Always review settings before starting the farm to avoid errors or unexpected behavior.")
            
            ImGui.EndTabItem()
        end
        
        ImGui.EndTabBar()
    end
    
    ImGui.Separator()
    ImGui.TextColored(ImVec4(0.5, 0.5, 0.5, 1.0), "Auto Farm Script v1.0")
    
    ImGui.End()
end

-- Register GUI Hook
AddHook("OnDraw", "AUTOFARM_GUI", FarmGUIOnDraw)

LogToConsole("Auto Farm Script loaded! GUI is now active.")