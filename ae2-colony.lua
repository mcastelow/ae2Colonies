-- ATM10 MineColonies to AE2 Bridge Supply Engine
-- Production Core (ATM10 v8.1 / MC 1.21.1 / Edge-to-Edge ASCII Grid Edition)

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

local function padRight(text, length)
    text = tostring(text)
    if #text >= length then
        return text:sub(1, length - 2) .. ".."
    end
    return text .. string.rep(" ", length - #text)
end

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

    -- 1. Console Fallback Print out
    term.clear()
    term.setCursorPos(1,1)
    print("=== LOGISTICS RADAR ACTIVE ===")
    for _, line in ipairs(statusLines) do print(line.text) end

    -- 2. Clean 39-Wide Edge-to-Edge Monitor Layout
    if mon then
        mon.setTextScale(1.0) 
        mon.clear()
        local w, h = mon.getSize() -- Snaps to exactly 39 character width slots
        
        -- Row 1: Structural Upper Title Frame Ribbon
        mon.setBackgroundColor(colors.black)
        mon.setTextColor(colors.gray)
        mon.setCursorPos(1, 1)
        
        local pulse = tickState and "o" or " "
        tickState = not tickState
        local headerText = "--- LOGISTICS MATRIX [" .. pulse .. "] ---"
        local headerPad = math.max(1, math.floor((w - #headerText) / 2))
        mon.write(string.rep("+", headerPad - 1) .. headerText .. string.rep("+", w - (headerPad + #headerText) + 1))
        
        -- Row 2: Live Balanced Component Diagnostics Readout
        mon.setCursorPos(1, 2)
        mon.setTextColor(colors.gray)
        mon.write("| ")
        
        mon.setTextColor(colors.lightGray)
        mon.write("AP")
        mon.setTextColor(colony and colors.lime or colors.red)
        mon.write("[o]  ")
        
        mon.setTextColor(colors.lightGray)
        mon.write("ME")
        mon.setTextColor(ae2 and colors.lime or colors.red)
        mon.write("[o]  ")
        
        mon.setTextColor(colors.lightGray)
        mon.write("OUT")
        mon.setTextColor(barrel and colors.lime or colors.red)
        mon.write("[o]    ")
        
        mon.setTextColor(colors.lightGray)
        mon.write("AE2 CPU LOAD:[")
        mon.setTextColor(cpuUsage:sub(1,1) == "0" and colors.cyan or colors.magenta)
        mon.write(cpuUsage)
        mon.setTextColor(colors.lightGray)
        mon.write("]")
        
        mon.setCursorPos(w, 2)
        mon.setTextColor(colors.gray)
        mon.write("|")

        -- Row 3, 4, 5: Expanded Table Structural Sections (Exactly 39 Chars Wide)
        mon.setCursorPos(1, 3)
        mon.setTextColor(colors.gray)
        mon.write("+====================================+")
        
        mon.setCursorPos(1, 4)
        mon.setTextColor(colors.cyan)
        mon.write("| ITEM                 | QTY  | STATE |")
        
        mon.setCursorPos(1, 5)
        mon.setTextColor(colors.gray)
        mon.write("+------------------------------------+")
        
        -- Rows 6+: Tabular Queue Data Stream
        local currentLine = 6
        if #statusLines == 0 then
            mon.setCursorPos(1, currentLine)
            mon.setTextColor(colors.blue)
            mon.write("| . MATRIX IDLE: STREAM STABLE       |")
            
            for r = currentLine + 1, h - 1 do
                mon.setCursorPos(1, r)
                mon.setTextColor(colors.gray)
                mon.write("|                                    |")
            end
        else
            if scrollIndex > #statusLines then scrollIndex = 1 end
            
            local renderedCount = 0
            for i = scrollIndex, #statusLines do
                if currentLine >= h or renderedCount >= SCROLL_LINES_PER_PAGE then break end
                
                local line = statusLines[i]
                mon.setCursorPos(1, currentLine)
                mon.setTextColor(line.color or colors.white)
                mon.write(line.text)
                
                currentLine = currentLine + 1
                renderedCount = renderedCount + 1
            end
            
            -- Keep frame brackets pristine by printing wall spaces down empty cells
            for r = currentLine, h - 1 do
                mon.setCursorPos(1, r)
                mon.setTextColor(colors.gray)
                mon.write("|                                    |")
            end
            
            if #statusLines > SCROLL_LINES_PER_PAGE then
                scrollIndex = scrollIndex + SCROLL_LINES_PER_PAGE
            else
                scrollIndex = 1
            end
        end
        
        -- Final Row: Baseline Frame Bracket
        mon.setCursorPos(1, h)
        mon.setTextColor(colors.gray)
        mon.write("+" .. string.rep("-", w - 2) .. "+")
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
    if not requests or type(requests) ~= "table" or #requests == 0 then
        renderDashboard(statusLines)
        return
    end

    local mergedDemands = {}
    for _, req in ipairs(requests) do
        local needed = req.count or req.needed or req.amount or 1
        -- Guard against broken work orders missing an item array
        if req.items and type(req.items) == "table" and req.items[1] then
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

        -- Expanded item field padding to 20 columns to line up perfectly across the 39 character width
        local colItem = padRight(cleanName, 20)

        if available >= totalNeeded then
            -- ROUTING STATE (Plasma Green)
            local itemTable = { name = itemID, count = totalNeeded }
            local callSuccess, res = pcall(ae2.exportItem, itemTable, EXPORT_CONTAINER)
            if not callSuccess or not res or res == 0 then
                pcall(ae2.exportItem, EXPORT_CONTAINER, itemTable)
            end
            
            local colQty   = padRight(totalNeeded, 4)
            local tableRow = string.format("| . %s | %s | ROUTE |", colItem, colQty)
            table.insert(statusLines, { text = tableRow, color = colors.lime })
        else
            local craftQty = totalNeeded - available
            local colQty   = padRight(craftQty, 4)
            
            if isCraftable then
                -- CRAFTING STATE (Quantum Amber)
                pcall(ae2.craftItem, {name = itemID, count = craftQty})
                
                local tableRow = string.format("| . %s | %s | CRAFT |", colItem, colQty)
                table.insert(statusLines, { text = tableRow, color = colors.orange })
            else
                -- VOID STATE (Critical Missing Red)
                local tableRow = string.format("| . %s | %s | VOID  |", colItem, colQty)
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
            mon.setBackgroundColor(colors.black)
            mon.setTextColor(colors.red)
            mon.clear()
            mon.setCursorPos(1, 2)
            mon.write("+-------------------------------------+")
            mon.setCursorPos(1, 3)
            mon.write("|        !! CRITICAL ERROR !!         |")
            mon.setCursorPos(1, 4)
            mon.write("| " .. padRight(errText, 35) .. " |")
            mon.setCursorPos(1, 5)
            mon.write("+-------------------------------------+")
        end
        print("\n[CRITICAL NETWORK EXCEPTION]: " .. tostring(globalErr))
    end
    sleep(REFRESH_RATE)
end
