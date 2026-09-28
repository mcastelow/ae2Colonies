-- ATM10 MineColonies to AE2 Bridge Supply Engine
-- Production Core (ATM10 v8.1 / MC 1.21.1 / Dynamic Scroll & CPU Matrix Edition)

-- ====== CONFIGURATION ======
local EXPORT_CONTAINER = "sophisticatedstorage:barrel_0"   
local REFRESH_RATE = 4       -- Slightly faster loop cycle for smoother screen ticking
local SCROLL_LINES_PER_PAGE = 6 -- Maximum data items to render on a 5x3 monitor at TextScale 1
-- ===========================

local tickState = true
local scrollIndex = 1

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

local function padRight(text, length)
    text = tostring(text)
    if #text >= length then
        return text:sub(1, length - 2) .. ".."
    end
    return text .. string.rep(" ", length - #text)
end

-- Safely calculates active vs total crafting CPUs from AE2
local function getCpuMetrics(ae2)
    if not ae2 or not ae2.getCraftingCPUs then return "0/0" end
    local success, cpus = pcall(ae2.getCraftingCPUs)
    if not success or type(cpus) ~= "table" then return "0/0" end
    
    local total = #cpus
    local active = 0
    for _, cpu in ipairs(cpus) do
        -- Checks if the CPU cluster is actively processing a scheduled task
        if cpu.isBusy or cpu.active or (cpu.storage and cpu.storage > 0 and cpu.craftingJob) then
            active = active + 1
        end
    end
    return string.format("%d/%d", active, total)
end

local function renderDashboard(statusLines)
    local colony = peripheral.find("colony_integrator")
    local ae2 = peripheral.find("me_bridge")
    local barrel = peripheral.wrap(EXPORT_CONTAINER)
    local mon = peripheral.find("monitor")

    local cpuUsage = getCpuMetrics(ae2)

    -- 1. Standard Computer Terminal Printing Fallback
    term.clear()
    term.setCursorPos(1,1)
    print("=== LOGISTICS HUB: " .. os.date("%H:%M:%S") .. " ===")
    print(string.format("NET: AP[%s] ME[%s] OUT[%s] | CPU[%s]", colony and "ON" or "OFF", ae2 and "ON" or "OFF", barrel and "ON" or "OFF", cpuUsage))
    print("| ITEM         | QTY | STATUS    |")
    for _, line in ipairs(statusLines) do print(line.text) end

    -- 2. Advanced Multi-Block Monitor Printing Layout
    if mon then
        mon.setTextScale(1.0) -- Increased to 1.0 for high visibility walking past
        mon.clear()
        local w, h = mon.getSize()
        
        -- Row 1: Cyberpunk Header Bar
        mon.setBackgroundColor(colors.gray)
        mon.setTextColor(colors.white)
        mon.setCursorPos(1, 1)
        mon.clearLine()
        local pulse = tickState and "*" or " "
        tickState = not tickState
        mon.write(" MATRIX CONTROL [" .. pulse .. "] " .. os.date("%H:%M:%S"))
        
        -- Row 2: Live Network Infrastructure Grid
        mon.setBackgroundColor(colors.black)
        mon.setCursorPos(1, 2)
        mon.setTextColor(colors.lightGray)
        mon.write("NET: ")
        
        mon.setTextColor(colony and colors.lime or colors.red)
        mon.write("AP[" .. (colony and "ON" or "OFF") .. "] ")
        mon.setTextColor(ae2 and colors.lime or colors.red)
        mon.write("ME[" .. (ae2 and "ON" or "OFF") .. "] ")
        mon.setTextColor(barrel and colors.lime or colors.red)
        mon.write("OUT[" .. (barrel and "ON" or "OFF") .. "]")

        -- Row 3: Active Crafting Load Readout
        mon.setCursorPos(1, 3)
        mon.setTextColor(colors.lightGray)
        mon.write("AE2 COMPUTING LOAD: ")
        mon.setTextColor(cpuUsage:sub(1,1) == "0" and colors.cyan or colors.magenta)
        mon.write("CPU[" .. cpuUsage .. "]")

        -- Row 5: Table Header Strip
        mon.setCursorPos(1, 5)
        mon.setTextColor(colors.yellow)
        mon.write("| ITEM         | QTY | STATUS    |")
        
        -- Rows 6+: Scrolled Matrix Window
        local currentLine = 6
        if #statusLines == 0 then
            mon.setCursorPos(1, currentLine)
            mon.setTextColor(colors.lightBlue)
            mon.write("| [All Demands Cleared]          |")
        else
            -- Advance window view index if the listing exceeds layout window size
            if scrollIndex > #statusLines then scrollIndex = 1 end
            
            local renderedCount = 0
            for i = scrollIndex, #statusLines do
                if currentLine > h or renderedCount >= SCROLL_LINES_PER_PAGE then break end
                
                local line = statusLines[i]
                mon.setCursorPos(1, currentLine)
                mon.setTextColor(line.color or colors.white)
                mon.write(line.text)
                
                currentLine = currentLine + 1
                renderedCount = renderedCount + 1
            end
            
            -- Increment page indices smoothly across refreshing clock frames
            if #statusLines > SCROLL_LINES_PER_PAGE then
                scrollIndex = scrollIndex + SCROLL_LINES_PER_PAGE
            else
                scrollIndex = 1
            end
        end
    end
end

local function processDemands()
    local statusLines = {}
    local colony = peripheral.find("colony_integrator")
    local ae2 = peripheral.find("me_bridge")
    
    if not colony or not ae2 then
        renderDashboard(statusLines)
        return
    end

    local requests = colony.getRequests()
    if not requests or #requests == 0 then
        renderDashboard(statusLines)
        return
    end

    -- Consolidated mapping cache to combine identical demands together
    local mergedDemands = {}

    for _, req in ipairs(requests) do
        local needed = req.count or req.needed or 1
        if req.items then
            for _, item in ipairs(req.items) do
                local itemID = extractItemString(item)
                if itemID and type(itemID) == "string" then
                    itemID = itemID:match("^[^#]+") or itemID
                    mergedDemands[itemID] = (mergedDemands[itemID] or 0) + needed
                end
            end
        end
    end

    -- Process our neatly compressed table list
    for itemID, totalNeeded in pairs(mergedDemands) do
        local cleanName = itemID:gsub("^[^:]+:", "")
        
        local detail = ae2.getItem({id = itemID})
        if not detail then detail = ae2.getItem({name = itemID}) end
        
        local available = detail and (detail.count or detail.amount) or 0
        local isCraftable = detail and detail.isCraftable or false

        local colItem = padRight(cleanName, 12)

        if available >= totalNeeded then
            -- ROUTING STATE (Plasma Green)
            local itemTable = { name = itemID, count = totalNeeded }
            local callSuccess, res = pcall(ae2.exportItem, itemTable, EXPORT_CONTAINER)
            if not callSuccess or not res or res == 0 then
                pcall(ae2.exportItem, EXPORT_CONTAINER, itemTable)
            end
            
            local colQty   = padRight(totalNeeded, 3)
            local tableRow = string.format("| %s | %s | ROUTING  |", colItem, colQty)
            table.insert(statusLines, { text = tableRow, color = colors.lime })
        else
            local craftQty = totalNeeded - available
            local colQty   = padRight(craftQty, 3)
            
            if isCraftable then
                -- DEPLETED STATE (Quantum Amber Autocrafting)
                pcall(ae2.craftItem, {name = itemID, count = craftQty})
                
                local tableRow = string.format("| %s | %s | CRAFTING |", colItem, colQty)
                table.insert(statusLines, { text = tableRow, color = colors.orange })
            else
                -- VOID STATE (Critical Missing Red)
                local tableRow = string.format("| %s | %s | MISSING  |", colItem, colQty)
                table.insert(statusLines, { text = tableRow, color = colors.red })
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
