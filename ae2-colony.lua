-- ATM10 MineColonies to AE2 Bridge Supply Engine
-- Production Core (ATM10 v8.1 / MC 1.21.1 / Extended Balanced Monitor Layout)

-- ====== CONFIGURATION ======
local EXPORT_CONTAINER = "sophisticatedstorage:barrel_0"   
local REFRESH_RATE = 4       
local SCROLL_LINES_PER_PAGE = 6 
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

-- Pads or truncates text to an exact length
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

    -- 1. Standard Computer Terminal Fallback Printing
    term.clear()
    term.setCursorPos(1,1)
    print("=== LOGISTICS HUB ===")
    for _, line in ipairs(statusLines) do print(line.text) end

    -- 2. Advanced Multi-Block Monitor Layout
    if mon then
        mon.setTextScale(1.0) 
        mon.clear()
        local w, h = mon.getSize() -- w is exactly 36 on a standard 5x3 at scale 1
        
        -- Row 1: Centered Cyberpunk Header Ribbon
        mon.setBackgroundColor(colors.gray)
        mon.setTextColor(colors.white)
        mon.setCursorPos(1, 1)
        mon.clearLine()
        
        local pulse = tickState and "*" or " "
        tickState = not tickState
        local headerText = "LOGISTICS MATRIX [" .. pulse .. "] " .. os.date("%H:%M:%S")
        local headerPad = math.max(1, math.floor((w - #headerText) / 2))
        mon.setCursorPos(headerPad, 1)
        mon.write(headerText)
        
        -- Reset background for information rows
        mon.setBackgroundColor(colors.black)
        
        -- Row 2: Centered Infrastructure Node Ticker
        local netText = string.format("NET: AP[%s] ME[%s] OUT[%s]", colony and "ON" or "OFF", ae2 and "ON" or "OFF", barrel and "ON" or "OFF")
        local netPad = math.max(1, math.floor((w - #netText) / 2))
        
        mon.setCursorPos(netPad, 2)
        mon.setTextColor(colors.lightGray)
        mon.write("NET: ")
        mon.setTextColor(colony and colors.lime or colors.red)
        mon.write("AP[" .. (colony and "ON" or "OFF") .. "] ")
        mon.setTextColor(ae2 and colors.lime or colors.red)
        mon.write("ME[" .. (ae2 and "ON" or "OFF") .. "] ")
        mon.setTextColor(barrel and colors.lime or colors.red)
        mon.write("OUT[" .. (barrel and "ON" or "OFF") .. "]")

        -- Row 3: Centered Active Computing Load Metrics
        local cpuText = "AE2 COMPUTE: CPU[" .. cpuUsage .. "]"
        local cpuPad = math.max(1, math.floor((w - #cpuText) / 2))
        mon.setCursorPos(cpuPad, 3)
        mon.setTextColor(colors.lightGray)
        mon.write("AE2 COMPUTE: ")
        mon.setTextColor(cpuUsage:sub(1,1) == "0" and colors.cyan or colors.magenta)
        mon.write("CPU[" .. cpuUsage .. "]")

        -- Row 5: Widened Balanced Table Header Strip (Takes exactly 36 characters)
        -- ITEM: 16 chars | QTY: 4 chars | STATUS: 8 chars (+ spacing and boundaries = 36)
        mon.setCursorPos(1, 5)
        mon.setTextColor(colors.yellow)
        mon.write("| ITEM             | QTY  | STATUS   |")
        
        -- Rows 6+: Full-Width Page Scrolling Windows
        local currentLine = 6
        if #statusLines == 0 then
            mon.setCursorPos(1, currentLine)
            mon.setTextColor(colors.lightBlue)
            -- Perfectly aligned blank filler line across the 36 char frame
            mon.write("| [All Demands Cleared]            |")
        else
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

    for itemID, totalNeeded in pairs(mergedDemands) do
        local cleanName = itemID:gsub("^[^:]+:", "")
        
        local detail = ae2.getItem({id = itemID})
        if not detail then detail = ae2.getItem({name = itemID}) end
        
        local available = detail and (detail.count or detail.amount) or 0
        local isCraftable = detail and detail.isCraftable or false

        -- Stretch item description column to 16 characters wide to match the new grid boundaries
        local colItem = padRight(cleanName, 16)

        if available >= totalNeeded then
            -- ROUTING STATE (Plasma Green)
            local itemTable = { name = itemID, count = totalNeeded }
            local callSuccess, res = pcall(ae2.exportItem, itemTable, EXPORT_CONTAINER)
            if not callSuccess or not res or res == 0 then
                pcall(ae2.exportItem, EXPORT_CONTAINER, itemTable)
            end
            
            local colQty   = padRight(totalNeeded, 4)
            local tableRow = string.format("| %s | %s | ROUTING  |", colItem, colQty)
            table.insert(statusLines, { text = tableRow, color = colors.lime })
        else
            local craftQty = totalNeeded - available
            local colQty   = padRight(craftQty, 4)
            
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
