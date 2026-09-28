-- ATM10 MineColonies to AE2 Bridge Supply Engine
-- Production Core (ATM10 v8.1 / MC 1.21.1 / Wired Network + Cyberpunk UI Edition)

-- ====== CONFIGURATION ======
local EXPORT_CONTAINER = "sophisticatedstorage:barrel_0"   
local REFRESH_RATE = 5
-- ===========================

local colony = peripheral.find("colony_integrator")
local ae2 = peripheral.find("me_bridge")
local mon = peripheral.find("monitor")

if not colony then error("[FATAL] colony_integrator not detected on the network!") end
if not ae2 then error("[FATAL] me_bridge not detected on the network!") end

-- Global tick tracker for the visual heartbeat animation
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

local function renderDashboard(statusLines)
    -- Render to standard terminal console
    term.clear()
    term.setCursorPos(1,1)
    print("=== LOGISTICS EVENT TIMELINE: " .. os.date("%H:%M:%S") .. " ===")
    for _, line in ipairs(statusLines) do
        print(line.text)
    end

    -- Render to Advanced Monitor ("monitor_0")
    if mon then
        mon.setTextScale(0.5) -- Small text for high scannability on a 5x3 screen
        mon.clear()
        
        local w, h = mon.getSize()
        
        -- Header Bar Background (Deep Slate Blue)
        mon.setBackgroundColor(colors.gray)
        mon.setTextColor(colors.white)
        mon.setCursorPos(1, 1)
        mon.clearLine()
        
        -- Heartbeat ticker animation alternating between [ * ] and [   ]
        local pulse = tickState and "*" or " "
        tickState = not tickState
        
        local headerText = " LOGISTICS MATRIX [" .. pulse .. "] " .. os.date("%H:%M:%S")
        mon.write(headerText)
        
        -- Reset background for body content
        mon.setBackgroundColor(colors.black)
        
        local currentLine = 3
        for _, line in ipairs(statusLines) do
            if currentLine > h then break end -- Prevent screen overflow
            
            mon.setCursorPos(1, currentLine)
            mon.setTextColor(line.color or colors.white)
            mon.write(line.text)
            currentLine = currentLine + 1
        end
    end
end

local function processDemands()
    local statusLines = {}
    local requests = colony.getRequests()
    
    if not requests or #requests == 0 then
        table.insert(statusLines, {text = ">> MATRIX IDLE: Demands satisfied.", color = colors.lightBlue})
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
                    
                    -- Strip mod prefixes (e.g. 'minecraft:oak_log' -> 'oak_log') and cap length
                    local cleanName = itemID:gsub("^[^:]+:", "")
                    if #cleanName > 15 then
                        cleanName = cleanName:sub(1, 13) .. ".."
                    end
                    
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
                        
                        table.insert(statusLines, {
                            text = string.format("[>] ROUTING: %s (%d)", cleanName, needed),
                            color = colors.lime
                        })
                    else
                        local craftQty = needed - available
                        
                        if isCraftable then
                            -- DEPLETED STATE (Quantum Amber) - Doing a partial dump and auto-crafting remainder
                            pcall(ae2.craftItem, {name = itemID, count = craftQty})
                            
                            table.insert(statusLines, {
                                text = string.format("[!] DEPLETED: %s (+%d C)", cleanName, craftQty),
                                color = colors.orange
                            })
                        else
                            -- VOID STATE (Critical Red) - Uncraftable deficit
                            table.insert(statusLines, {
                                text = string.format("[X] VOID: %s (%d Mis)", cleanName, craftQty),
                                color = colors.red
                            })
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
