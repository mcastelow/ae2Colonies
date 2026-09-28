-- ATM10 MineColonies to AE2 Bridge Supply Engine
-- Production Core (ATM10 v8.1 / MC 1.21.1 / Infrastructure Grid & Table Edition)

-- ====== CONFIGURATION ======
local EXPORT_CONTAINER = "sophisticatedstorage:barrel_0"   
local REFRESH_RATE = 5
-- ===========================

-- Global heartbeat tick tracker
local tickState = true

local function extractItemString(itemObj)
    if not itemObj then return nil end
    if type(itemObj) == "string" then return itemObj end
    if type(itemObj) == "table" then
        local raw = itemObj.id or itemObj.name or itemObj.display_name
        if type(raw) == "table" then return raw.id or raw.name end
        return raw
    end
    return nil
end

-- Helper function to perfectly pad text columns
local function padRight(text, length)
    text = tostring(text)
    if #text >= length then
        return text:sub(1, length - 2) .. ".."
    end
    return text .. string.rep(" ", length - #text)
end

local function renderDashboard(statusLines)
    -- Interrogate peripheral presence on the wire live per-tick
    local colony = peripheral.find("colony_integrator")
    local ae2 = peripheral.find("me_bridge")
    local barrel = peripheral.wrap(EXPORT_CONTAINER)
    local mon = peripheral.find("monitor")

    -- 1. Console Printing Fallback
    term.clear()
    term.setCursorPos(1,1)
    print("=== LOGISTICS MATRIX: " .. os.date("%H:%M:%S") .. " ===")
    print(string.format("NET: AP[%s] ME[%s] OUT[%s]", colony and "ON" or "OFF", ae2 and "ON" or "OFF", barrel and "ON" or "OFF"))
    print("| ITEM            | QTY | STATUS   |")
    for _, line in ipairs(statusLines) do
        print(line.text)
    end

    -- 2. Advanced Monitor Rendering Layout
    if mon then
        mon.setTextScale(0.5)
        mon.clear()
        local w, h = mon.getSize()
        
        -- Row 1: Header Ticker Ribbon
        mon.setBackgroundColor(colors.gray)
        mon.setTextColor(colors.white)
        mon.setCursorPos(1, 1)
        mon.clearLine()
        local pulse = tickState and "*" or " "
        tickState = not tickState
        mon.write(" LOGISTICS SYSTEM HUB [" .. pulse .. "] " .. os.date("%H:%M:%S"))
        
        -- Row 2: Live Connection Infrastructure Grid
        mon.setBackgroundColor(colors.black)
        mon.setCursorPos(1, 2)
        mon.setTextColor(colors.lightGray)
        mon.write("NET STATUS: ")
        
        -- Colony Integrator Node
        mon.setTextColor(colony and colors.lime or colors.red)
        mon.write("AP[" .. (colony and "ON" or "OFF") .. "] ")
        -- ME Bridge Node
        mon.setTextColor(ae2 and colors.lime or colors.red)
        mon.write("ME[" .. (ae2 and "ON" or "OFF") .. "] ")
        -- Target Distribution Barrel Node
        mon.setTextColor(barrel and colors.lime or colors.red)
        mon.write("OUT[" .. (barrel and "ON" or "OFF") .. "]")

        -- Row 4: Static Table Column Dividers
        mon.setCursorPos(1, 4)
        mon.setTextColor(colors.yellow)
        -- Sized cleanly for typical 5x3 Advanced Monitor aspect layouts
        mon.write("| ITEM            | QTY | STATUS   |")
        
        -- Rows 5+: Tabular Stream Population
        local currentLine = 5
        if #statusLines == 0 then
            mon.setCursorPos(1, currentLine)
            mon.setTextColor(colors.lightBlue)
            mon.write("| [Matrix Idle]   | --  | COMPLETE |")
        else
            for _, line in ipairs(statusLines) do
                if currentLine > h then break end
                mon.setCursorPos(1, currentLine)
                mon.setTextColor(line.color or colors.white)
                mon.write(line.text)
                currentLine = currentLine + 1
            end
        end
    end
end

local function processDemands()
    local statusLines = {}
    
    local colony = peripheral.find("colony_integrator")
    local ae2 = peripheral.find("me_bridge")
    
    -- Graceful error suppression so missing wires don't completely crash the runtime loop
    if not colony or not ae2 then
        renderDashboard(statusLines)
        return
    end

    local requests = colony.getRequests()
    if not requests or #requests == 0 then
        renderDashboard(statusLines)
        return
    end

    for _, req in ipairs(requests) do
        local needed = req.count or req.needed or 1
        if req.items then
            for _, item in ipairs(req.items) do
                local itemID = extractItemString(item)
                if itemID and type(itemID) == "string" then
                    itemID = itemID:match("^[^#]+") or itemID
                    
                    -- Strip namespace and format string safely
                    local cleanName = itemID:gsub("^[^:]+:", "")
                    
                    local detail = ae2.getItem({id = itemID})
                    if not detail then detail = ae2.getItem({name = itemID}) end
                    
                    local available = detail and (detail.count or detail.amount) or 0
                    local isCraftable = detail and detail.isCraftable or false

                    if available >= needed then
                        -- ROUTING STATE (Plasma Green)
                        local itemTable = { name = itemID, count = needed }
                        local callSuccess, res = pcall(ae2.exportItem, itemTable, EXPORT_CONTAINER)
                        if not callSuccess or not res or res == 0 then
                            pcall(ae2.exportItem, EXPORT_CONTAINER, itemTable)
                        end
                        
                        local colItem   = padRight(cleanName, 15)
                        local colQty    = padRight(needed, 3)
                        local tableRow  = string.format("| %s | %s | ROUTING  |", colItem, colQty)
                        
                        table.insert(statusLines, { text = tableRow, color = colors.lime })
                    else
                        local craftQty = needed - available
                        local colItem  = padRight(cleanName, 15)
                        local colQty   = padRight(craftQty, 3)
                        
                        if isCraftable then
                            -- DEPLETED STATE (Quantum Amber)
                            pcall(ae2.craftItem, {name = itemID, count = craftQty})
                            
                            local tableRow = string.format("| %s | %s | CRAFTING |", colItem, colQty)
                            table.insert(statusLines, { text = tableRow, color = colors.orange })
                        else
                            -- VOID STATE (Critical Red)
                            local tableRow = string.format("| %s | %s | MISSING  |", colItem, colQty)
                            table.insert(statusLines, { text = tableRow, color = colors.red })
                        end
                    end
                end
            end
        end
    end
    
    renderDashboard(statusLines)
end

while true do
    local globalSuccess, globalErr = pcall(processDemands)
    if not globalSuccess then
        local errText = "[ERR]: " .. tostring(globalErr):sub(1, 25)
        local mon = peripheral.find("monitor")
        if mon then
            mon.setBackgroundColor(colors.red)
            mon.setTextColor(colors.white)
            mon.clear()
            mon.setCursorPos(1, 2)
            mon.write("!! KERNEL PANIC !!")
            mon.setCursorPos(1, 3)
            mon.write(errText)
        end
        print("\n[CRITICAL NETWORK EXCEPTION]: " .. tostring(globalErr))
    end
    sleep(REFRESH_RATE)
end
