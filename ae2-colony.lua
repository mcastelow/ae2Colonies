-- ATM10 MineColonies to AE2 Bridge Dashboard (Neon Tech Variant)
-- Optimized for 5x3 Monitor with a Futuristic Dark Base Aesthetic
-- FUZZY MATRIX DISCOVERY CORE: Zero-failure string mapping and flat routing parameters

-- ====== CONFIGURATION ======
local MONITOR_SIDE = "top"         
local EXPORT_DIRECTION = "down"   -- Targets the Netherite Barrel beneath the ME Bridge
local REFRESH_RATE = 5             
-- ===========================

-- Shared thread communication states
local hasActiveErrors = false
local isPolling = false
local colonyConnected = false
local ae2Connected = false
local currentRequests = {}

-- Dynamic Progress Telemetry State
local currentTickProgress = 0

-- Diagnostics log array
local debugLogs = {}
local function addLog(msg)
    table.insert(debugLogs, 1, ":: [" .. os.date("%H:%M:%S") .. "] " .. msg)
    if #debugLogs > 4 then table.remove(debugLogs) end
end

-- Delivery history tracker
local deliveryHistory = {}
local function addDelivery(name, qty)
    local timestamp = os.date("%H:%M")
    table.insert(deliveryHistory, 1, string.format("[%s] -> %dx %s", timestamp, qty, name))
    if #deliveryHistory > 5 then table.remove(deliveryHistory) end
end

-- Safely wrap monitor
local monitor = peripheral.wrap(MONITOR_SIDE)
if not monitor then error("[FATAL] Monitor not found on side: " .. MONITOR_SIDE) end

monitor.setTextScale(1)
local w, h = monitor.getSize()

if w < 40 or h < 14 then
    error(string.format("[FATAL] Monitor too small. Got %dx%d, need at least 40x14.", w, h))
end

-- ====== FUTURISTIC CYBERPUNK PALETTE ======
local C_BG      = colors.black       -- Void Space
local C_PANEL   = colors.gray        -- Structural Frame
local C_TEXT    = colors.lightGray   -- Terminal Output Text
local C_HEADER  = colors.cyan        -- Matrix Cyan
local C_SUB     = colors.purple      -- AE2 Singularity Purple
local C_SUCCESS = colors.lime        -- Plasma Green (Active/Fulfilling)
local C_WARN    = colors.orange      -- Quantum Amber (Partial/Pending)
local C_FAIL    = colors.red         -- Critical Red (Missing/Offline)
-- ==========================================
local function drawHeader()
    monitor.setBackgroundColor(C_BG)
    monitor.clear()
    
    monitor.setBackgroundColor(C_PANEL)
    monitor.setTextColor(C_HEADER)
    monitor.setCursorPos(1, 1)
    monitor.clearLine()
    
    local title = "// AE2 LOGISTICS KERNEL v10.0 //"
    local padding = math.max(0, math.floor((w - #title) / 2))
    monitor.setCursorPos(padding + 1, 1)
    monitor.write(title)
    
    -- PROGRESS TELEMETRY MATRIX BAR [====    ]
    local barWidth = 8
    local progressChars = math.floor((currentTickProgress / 100) * barWidth)
    if progressChars > barWidth then progressChars = barWidth end
    
    local barText = "[" .. string.rep("=", progressChars) .. string.rep(" ", barWidth - progressChars) .. "]"
    monitor.setCursorPos(w - (barWidth + 2), 1)
    
    if isPolling then
        monitor.setTextColor(C_SUB)
    else
        monitor.setTextColor(C_SUCCESS)
    end
    monitor.write(barText)
    
    monitor.setBackgroundColor(C_BG)
    monitor.setCursorPos(2, 3)
    monitor.setTextColor(C_TEXT)
    monitor.write("» COLONY INTEGRATOR (LEFT): ")
    if colonyConnected then
        monitor.setTextColor(C_SUCCESS)
        monitor.write("[SECURE]")
    else
        monitor.setTextColor(C_FAIL)
        monitor.write("[DISCONNECTED]")
    end
    
    monitor.setCursorPos(2, 4)
    monitor.setTextColor(C_TEXT)
    monitor.write("» ME NETWORK BRIDGE (RIGHT): ")
    if ae2Connected then
        monitor.setTextColor(C_SUCCESS)
        monitor.write("[ONLINE]")
    else
        monitor.setTextColor(C_FAIL)
        monitor.write("[LINK DOWN]")
    end
    
    monitor.setCursorPos(1, 6)
    monitor.setTextColor(C_SUB)
    monitor.write(string.rep("=", w))
    
    monitor.setCursorPos(2, 7)
    monitor.setTextColor(C_HEADER)
    monitor.write(string.format("%-22s | %-5s | %s", "LOGISTICS REGISTRY", "QTY", "MATRIX STATE"))
    
    monitor.setCursorPos(1, 8)
    monitor.setTextColor(C_SUB)
    monitor.write(string.rep("=", w))
end

local function drawDebugPanel()
    -- EXPLICIT COMPLIANCE: Error panel completely hides if hasActiveErrors resolves to false
    if hasActiveErrors then
        local startY = h - 4
        monitor.setCursorPos(1, startY)
        monitor.setBackgroundColor(C_PANEL)
        monitor.setTextColor(C_SUB)
        monitor.clearLine()
        monitor.write(" // CORE DIAGNOSTICS & SYSTEM EVENT FEED //")
        monitor.setBackgroundColor(C_BG)
        
        for i, log in ipairs(debugLogs) do
            if startY + i <= h then
                monitor.setCursorPos(2, startY + i)
                monitor.setTextColor(C_TEXT)
                monitor.clearLine()
                monitor.write(log)
            end
        end
    elseif #deliveryHistory > 0 then
        local startY = h - 5
        monitor.setCursorPos(1, startY)
        monitor.setBackgroundColor(C_PANEL)
        monitor.setTextColor(C_SUCCESS)
        monitor.clearLine()
        monitor.write(" // RECENT LOGISTICS ROUTING DELIVERIES //")
        monitor.setBackgroundColor(C_BG)
        
        for i, delivery in ipairs(deliveryHistory) do
            if startY + i <= h then
                monitor.setCursorPos(2, startY + i)
                monitor.setTextColor(colors.lightGray)
                monitor.clearLine()
                monitor.write(delivery)
            end
        end
    end
end

local function renderLoop()
    while true do
        drawHeader()
        local y = 9
        local hasPanel = hasActiveErrors or (#deliveryHistory > 0)
        local maxDisplayY = hasPanel and (h - 7) or (h - 1)
        
        if #currentRequests == 0 and not hasActiveErrors then
            monitor.setCursorPos(2, y)
            monitor.setTextColor(C_SUCCESS)
            monitor.write("✔ Network Idle: All sector demands met.")
        else
            for _, displayLine in ipairs(currentRequests) do
                if y > maxDisplayY then
                    monitor.setCursorPos(2, y)
                    monitor.setTextColor(C_WARN)
                    monitor.write("... Buffer Overflow: Output Truncated ...")
                    break
                end
                monitor.setCursorPos(2, y)
                monitor.setTextColor(displayLine.color or C_TEXT)
                monitor.write(displayLine.text)
                y = y + 1
            end
        end
        drawDebugPanel()
        sleep(0.2)
    end
end
local function networkWorker()
    term.clear()
    while true do
        term.setCursorPos(1,1)
        print("=== LOGISTICS KERNEL ASYNC SYSTEM RUNNING ===")
        local colony = peripheral.find("colony_integrator")
        local ae2 = peripheral.find("me_bridge")
        colonyConnected = (colony ~= nil)
        ae2Connected = (ae2 ~= nil)
        
        if not colony or not ae2 then
            hasActiveErrors = true
            currentRequests = {}
            currentTickProgress = 0
            sleep(REFRESH_RATE)
        else
            isPolling = true
            currentTickProgress = 100
            local success, requests = pcall(colony.getRequests)
            isPolling = false
            
            if not success or not requests then
                hasActiveErrors = true
                currentRequests = {}
                sleep(REFRESH_RATE)
            else
                hasActiveErrors = false
                local tempRequests = {}
                print(":: Polled Network: " .. #requests .. " groups at " .. os.date("%H:%M:%S"))
                
                -- FUZZY DISCOVERY SCAN: Cache everything in storage via string indexing to bypass key bugs
                local aeInventory = {}
                local listSuccess, listData = pcall(function() return ae2.listItems() or ae2.getItems() end)
                if listSuccess and listData then
                    for _, item in ipairs(listData) do
                        local nameKey = item.name or item.id
                        if nameKey then
                            aeInventory[nameKey] = {
                                amount = tonumber(item.amount) or tonumber(item.count) or 0,
                                craftable = item.isCraftable or item.craftable or false
                            }
                        end
                    end
                end
                
                for _, req in ipairs(requests) do
                    sleep(0.01)
                    
                    local extractedItems = {}
                    if req.items and type(req.items) == "table" then
                        for _, subItem in pairs(req.items) do
                            if type(subItem) == "table" then table.insert(extractedItems, subItem) end
                        end
                        if #extractedItems == 0 then table.insert(extractedItems, req.items) end
                    elseif type(req.item) == "table" then
                        for _, subItem in pairs(req.item) do
                            if type(subItem) == "table" then table.insert(extractedItems, subItem) end
                        end
                        if #extractedItems == 0 then table.insert(extractedItems, req.item) end
                    else
                        table.insert(extractedItems, req)
                    end
                    
                    for _, activeItem in ipairs(extractedItems) do
                        local itemID = "void:null"
                        local displayName = "Unknown Block"
                        local needed = 0
                        
                        if type(activeItem) == "table" then
                            itemID = activeItem.name or activeItem.id or (activeItem.item and activeItem.item.name) or "void:null"
                            displayName = activeItem.displayName or activeItem.name or itemID
                            needed = tonumber(activeItem.count) or tonumber(activeItem.needed) or tonumber(activeItem.amount) or 0
                            if (needed == 0 or needed == 1) and activeItem.item and type(activeItem.item) == "table" then
                                needed = tonumber(activeItem.item.count) or tonumber(activeItem.item.needed) or tonumber(activeItem.item.amount) or needed
                            end
                        elseif type(activeItem) == "string" then
                            itemID = activeItem
                            displayName = itemID
                        end
                        
                        -- Enforce top-level requirement extraction values to maintain correct totals
                        if needed == 0 or needed == 1 then
                            needed = tonumber(req.count) or tonumber(req.needed) or tonumber(req.amount) or needed
                        end
                        
                        if itemID ~= "void:null" and needed > 0 then
                            if not string.find(itemID, ":") then itemID = "minecraft:" .. itemID end
                            
                            displayName = displayName:gsub("minecraft:", ""):gsub("domum_ornamentum:", "")
                            displayName = displayName:gsub("^%l", string.upper):gsub("_", " ")
                            if #displayName > 22 then displayName = displayName:sub(1, 19) .. "..." end
                            
                            local linePrefix = string.format("%-22s | %-5d | ", displayName, needed)
                            
                            -- Extract data from our clean fuzzy cache string map
                            local matchData = aeInventory[itemID]
                            local available = matchData and matchData.amount or 0
                            local craftable = matchData and matchData.craftable or false
                            
                            -- Fallback: If cache lookup came back empty, run single item query checks
                            if available == 0 and not craftable then
                                local singleSuccess, singleItem = pcall(function() return ae2.getItem({name = itemID}) or ae2.getItem({item = itemID}) end)
                                if singleSuccess and singleItem then
                                    available = tonumber(singleItem.amount) or tonumber(singleItem.count) or 0
                                    craftable = singleItem.isCraftable or singleItem.craftable or false
                                end
                            end
                            
                            if available >= needed then
                                table.insert(tempRequests, {text = linePrefix .. "▶ ROUTING", color = C_SUCCESS})
                                
                                -- 1.21 HYPER-STABLE EXTRACTION DISPATCH ENGINE
                                local ok = pcall(function() return ae2.exportItem({name = itemID, count = needed}, EXPORT_DIRECTION) end)
                                if not ok then
                                    ok = pcall(function() return ae2.exportItemToPeripheral({id = itemID, count = needed}, EXPORT_DIRECTION) end)
                                end
                                if ok then addDelivery(displayName, needed) end
                                
                            elseif available > 0 and available < needed then
                                table.insert(tempRequests, {text = linePrefix .. "⚠ DEPLETED (" .. available .. ")", color = C_WARN})
                                
                                local ok = pcall(function() return ae2.exportItem({name = itemID, count = available}, EXPORT_DIRECTION) end)
                                if not ok then
                                    ok = pcall(function() return ae2.exportItemToPeripheral({id = itemID, count = available}, EXPORT_DIRECTION) end)
                                end
                                if ok then 
                                    addDelivery(displayName, available)
                                    if craftable then 
                                        local craftShortage = needed - available
                                        pcall(function() return ae2.requestCrafting({id = itemID, count = craftShortage}) or ae2.craftItem({name = itemID, count = craftShortage}) end) 
                                    end
                                end
                            else
                                if craftable then
                                    table.insert(tempRequests, {text = linePrefix .. "⚒ QUEUED", color = C_SUB})
                                    pcall(function() return ae2.requestCrafting({id = itemID, count = needed}) or ae2.craftItem({name = itemID, count = needed}) end)
                                else
                                    table.insert(tempRequests, {text = linePrefix .. "✖ VOID", color = C_FAIL})
                                end
                            end
                        end
                    end
                end
                
                currentRequests = tempRequests
                
                -- Animate loading ticks smoothly
                local totalSleep = REFRESH_RATE
                local increments = 25
                local stepTime = totalSleep / increments
                for i = increments, 0, -1 do
                    currentTickProgress = math.floor((i / increments) * 100)
                    sleep(stepTime)
                end
            end
        end
    end
end

parallel.waitForAny(renderLoop, networkWorker)
