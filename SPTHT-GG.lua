lineY = 197 -- Farm limit down
amtseed = 18000 -- Maximum Tree (Usage; UWS)
FirstSeed = 2019 -- Seeds you chose in the first magplant
combined = 53785 -- id seed yang di splice
delayPlant = 50 -- Delay Plant
delayHarvest = 30 -- Delay Harvest
delayGrow = 50 -- Splice item growth time
FirstMagplant = {3, 199} -- Set First Magplant
TwoMagplant = {4, 199} -- Set Two Magplant

--(OPTIONAL SETTINGS)
World = "island" -- Choose use [ "normal" or "island" ]
autoUWS = 0 -- 1 or 0 ( Automatically use UWS )
autoAGE = 1 -- 1 or 0 ( Automatically use AGE )

--(DONT TOUCH DOWN)
y1 = 0
y2 = lineY

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

-- === FindPathSmart Function (Langkah Maks 3 Tile) ===
function FindPathSmart(targetX, targetY, stepDelay)
    local me = GetLocal()
    local currentX = math.floor(me.pos.x / 32)
    local currentY = math.floor(me.pos.y / 32)

    local distanceX = targetX - currentX
    local distanceY = targetY - currentY

    local steps = math.max(math.abs(distanceX), math.abs(distanceY))
    local stepSize = 3 -- Maksimum langkah per gerak

    if steps > stepSize then
        local stepsNeeded = math.ceil(steps / stepSize)
        local stepX = distanceX / stepsNeeded
        local stepY = distanceY / stepsNeeded

        for i = 1, stepsNeeded do
            local nextX = math.floor(currentX + stepX * i)
            local nextY = math.floor(currentY + stepY * i)
            FindPath(nextX, nextY, stepDelay)
            Sleep(150)
        end
    else
        FindPath(targetX, targetY, stepDelay)
    end
end

-- === Magplant Control ===
local function magplant(x, y, z)
    FindPathSmart(x, y, 70)
    Sleep(200)
    wrench(x, y + (below and 1 or -1))
    Sleep(200)
    SendPacket(2, "action|dialog_return\ndialog_name|magplant_edit\nx|"..x.."|\ny|"..(y + (below and 1 or -1)).."|\nbuttonClicked|"..z)
    Sleep(200)
end

local function TakeMagplant1()
    SendPacket(2, "action|respawn")
    Sleep(3000)
    FindPathSmart(FirstMagplant[1] - 1, FirstMagplant[2] - 1, 70)
    Sleep(100)
    magplant(FirstMagplant[1] - 1, FirstMagplant[2] - 1, "getRemote")
    Sleep(1000)
end

local function TakeMagplant2()
    SendPacket(2, "action|respawn")
    Sleep(3000)
    FindPathSmart(TwoMagplant[1] - 1, TwoMagplant[2] - 1, 70)
    Sleep(100)
    magplant(TwoMagplant[1] - 1, TwoMagplant[2] - 1, "getRemote")
    Sleep(1000)
end

-- === Core Functions ===
function checkseed()
    local Ready = 0
    for y = y1, y2 do
        for x = 0, 199 do
            if IsReady(GetTile(x, y)) and GetTile(x, y).fg == combined then
                Ready = Ready + 1
            end
        end
    end
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
    if checkseed() < amtseed then
        for x = startX, endX, stepX do
            for y = startY, endY, stepY do
                if GetTile(x, y).fg == 0 then
                    FindPathSmart(x, y, 50)
                    Sleep(delayPlant)
                    place(5640, 0, 0)
                    Sleep(delayPlant)
                end
            end
        end
    end
end

function plant2(startX, endX, stepX, startY, endY, stepY)
    if checkseed() < amtseed then
        for x = startX, endX, stepX do
            for y = startY, endY, stepY do
                if GetTile(x, y).fg == FirstSeed then
                    FindPathSmart(x, y, 50)
                    Sleep(delayPlant)
                    place(5640, 0, 0)
                    Sleep(delayPlant)
                end
            end
        end
    end
end

function harvest()
    if checkseed() > amtseed then
        for y = y2, y1, -1 do
            for x = 0, 0 do
                if IsReady(GetTile(x, y)) then
                    FindPathSmart(x, y, 50)
                    Sleep(delayHarvest)
                    punch(0, 0)
                    Sleep(delayHarvest)
                end
            end
        end
    end
end

function plantRow(x)
    TakeMagplant1()
    plant1(x, x, 1, y2, y1, -1)
    TakeMagplant2()
    plant2(x, x, 1, y2, y1, -1)
end

function startPlanting()
    local xSteps = {}

    if World == "normal" then
        xSteps = {0, 10, 20, 30, 40, 50, 60, 70, 80, 90}
    elseif World == "island" then
        xSteps = {0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120, 130, 140, 150, 160, 170, 180, 190}
    else
        LogToConsole("World type not recognized: " .. World)
        return
    end

    for _, x in ipairs(xSteps) do
        plantRow(x)
    end
end

function uws()
    if autoUWS == 1 then
        SendPacket(2, "action|dialog_return\ndialog_name|ultraworldspray")
        Sleep(4000)
    else
        Sleep(delayGrow)
    end
end

local message1 = "/age 999999"

function age()
    if autoAGE == 1 then
        SendPacket(2, "action|input\n|text|" .. message1)
        Sleep(4000)
    else
        Sleep(delayGrow)
    end
end

function startFarmingLoop()
    while true do
        if World == "normal" then
            harvest()
            Sleep(200)
            harvest()
            Sleep(1500)
            startPlanting()
            Sleep(1000)
            age()
            uws()
        elseif World == "island" then
            harvest()
            Sleep(200)
            harvest()
            Sleep(500)
            startPlanting()
            Sleep(1000)
            age()
            uws()
        end
    end
end

startFarmingLoop()
