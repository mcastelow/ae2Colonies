-- ATM10 MineColonies to AE2 Bridge Dashboard (Neon Tech Variant)
-- Optimized for 5x3 Monitor with a Futuristic Dark Base Aesthetic
-- FUZZY CORE: Hardened atomic memory pipelines to prevent background crashes

-- ====== CONFIGURATION ======
local MONITOR_SIDE = "top"         
local EXPORT_DIRECTION = "down"   -- Redirects item routing to hidden base cavity
local REFRESH_RATE = 5             
-- ===========================

-- Shared thread communication states
local hasActiveErrors = false
local isPolling = false
local currentRequests = {}

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

local function drawHeader(colonyPresent, ae2Present)
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
    
    -- FIXED RENDERING ELEMENT: Swapped un-renderable Unicode emoji to secure safe ASCII text blocks
    if isPolling then
        monitor.setTextColor(colors.magenta)
        monitor.setCursorPos(w - 5, 1)
        monitor.write("[::]")
    end
    
    monitor.setBackgroundColor(C_BG)
    monitor.setCursorPos(2, 3)
    monitor.setTextColor(C_TEXT)
    monitor.write("» COLONY INTEGRATOR (LEFT): ")
    if colonyPresent then
        monitor.setTextColor(C_SUCCESS)
        monitor.write("[SECURE]")
    else
        monitor.setTextColor(C_FAIL)
        monitor.write("[DISCONNECTED]")
    end
    
    monitor.setCursorPos(2, 4)
    monitor.setTextColor(C_TEXT)
    monitor.write("» ME NETWORK BRIDGE (RIGHT): ")
    if ae2Present then
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
    -- ARCHITECTURAL PREREQUISITE POLICY: Error panel collapses entirely when hasActiveErrors flags false
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
-- ==========================================
-- THREAD 1: THE RENDERING ENGINE
-- ==========================================
local function renderLoop()
    while true do
        local colonyPresent = peripheral.find("colony_integrator") ~= nil
        local ae2Present = peripheral.find("me_bridge") ~= nil
        
        drawHeader(colonyPresent, ae2Present)
        
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
        sleep(0.5)
    end
end

-- ==========================================
-- THREAD 2: PERIPHERAL INTEGRATOR (DEEP SCHEMAS UNPACKED)
-- ==========================================
local function networkWorker()
    term.clear()
    term.setCursorPos(1,1)
    print("=== LOGISTICS KERNEL ASYNC SYSTEM RUNNING ===")
    
    while true do
        local colony = peripheral.find("colony_integrator")
        local ae2 = peripheral.find("me_bridge")
        
        if not colony or not ae2 then
            hasActiveErrors = true
            currentRequests = {}
            sleep(REFRESH_RATE)
        else
            isPolling = true
            local success, requests = pcall(colony.getRequests)
            isPolling = false
            
            if not success or not requests then
                hasActiveErrors = true
                currentRequests = {}
                sleep(REFRESH_RATE)
            else
                hasActiveErrors = false
                local tempRequests = {}
                
                print(":: Polled Network: " .. #requests .. " item frames at " .. os.date("%H:%M:%S"))
                
                for _, req in ipairs(requests) do
                    sleep(0.02)
                    
                    -- CRITICAL STABLE UPGRADE: Iterate across lists packed inside the items index layer
                    local extractedItems = {}
                    if req.items and type(req.items) == "table" then
                        -- Check if req.items contains sequential index values
                        if req.items[1] then
                            for _, subItem in ipairs(req.items) do
                                table.insert(extractedItems, subItem)
                            end
                        else
                            table.insert(extractedItems, req.items)
                        end
                    elseif type(req.item) == "table" then
                        if req.item[1] then
                            for _, subItem in ipairs(req.item) do
                                table.insert(extractedItems, subItem)
                            end
                        else
                            table.insert(extractedItems, req.item)
                        end
                    else
                        table.insert(extractedItems, req)
                    end
                    
                    -- Process every single item un-nested out of the array collections
                    for _, activeItem in ipairs(extractedItems) do
                        local itemID = "void:null"
                        local displayName = "Unknown Block"
                        local needed = 0
                        
                        if type(activeItem) == "table" then
                            -- Extract identities out of nested fields recursively
                            local subNode = activeItem.item or activeItem
                            if type(subNode) == "table" then
                                itemID = subNode.name or subNode.id or "void:null"
                                displayName = subNode.displayName or subNode.name or displayName
                            elseif type(subNode) == "string" then
                                itemID = subNode
                                displayName = activeItem.name or itemID
                            end
                            
                            needed = tonumber(activeItem.count) or tonumber(activeItem.needed) or tonumber(activeItem.amount) or 0
                        elseif type(activeItem) == "string" then
                            itemID = activeItem
                            displayName = itemID
                        end
                        
                        -- Top-level count key backups block lookup parameters
                        if needed == 0 then
                            needed = tonumber(req.count) or tonumber(req.needed) or tonumber(req.amount) or 0
                        end
                        
                        if itemID ~= "void:null" and needed > 0 then
                            if not string.find(itemID, ":") then
                                itemID = "minecraft:" .. itemID
                            end
                            
                            displayName = displayName:gsub("minecraft:", ""):gsub("domum_ornamentum:", "")
                            displayName = displayName:gsub("^%l", string.upper):gsub("_", " ")
                            if #displayName > 22 then displayName = displayName:sub(1, 19) .. "..." end
                            
                            local linePrefix = string.format("%-22s | %-5d | ", displayName, needed)
                            local available = 0
                            local craftable = false
                            
                            local checkSuccess, checkItem = pcall(function() 
                                return ae2.getItem({item = itemID}) or ae2.getItem({name = itemID}) 
                            end)
                            
                            if checkSuccess and checkItem then
                                available = tonumber(checkItem.amount) or tonumber(checkItem.count) or 0
                                craftable = checkItem.isCraftable or false
                            end
                            
                            if available >= needed then
                                table.insert(tempRequests, {text = linePrefix .. "▶ ROUTING", color = C_SUCCESS})
                                pcall(function() 
                                    return ae2.exportItem({item = itemID, count = needed}, EXPORT_DIRECTION)
                                        or ae2.exportItem({name = itemID, count = needed}, EXPORT_DIRECTION)
                                end)
                                if available > 0 then addDelivery(displayName, needed) end
                            elseif available > 0 and available < needed then
                                table.insert(tempRequests, {text = linePrefix .. "⚠ DEPLETED", color = C_WARN})
                                pcall(function() 
                                    return ae2.exportItem({item = itemID, count = available}, EXPORT_DIRECTION)
                                        or ae2.exportItem({name = itemID, count = available}, EXPORT_DIRECTION)
                                end)
                                addDelivery(displayName, available)
                                if craftable then 
                                    local craftShortage = needed - available
                                    pcall(function() 
                                        local done = ae2.craftItem({item = itemID, count = craftShortage})
                                        if not done then ae2.craftItem({name = itemID, count = craftShortage}) end
                                    end) 
                                end
                            else
                                if craftable then
                                    table.insert(tempRequests, {text = linePrefix .. "⚒ QUEUED", color = C_SUB})
                                    pcall(function() 
                                        local done = ae2.craftItem({item = itemID, count = needed})
                                        if not done then ae2.craftItem({name = itemID, count = needed}) end
                                    end)
                                else
                                    table.insert(tempRequests, {text = linePrefix .. "✖ VOID", color = C_FAIL})
                                end
                            end
                        end
                    end
                end
                
                -- ATOMIC ARRAY INTERCHANGE UPDATE
                currentRequests = tempRequests
                sleep(REFRESH_RATE)
            end
        end
    end
end

-- ====== CONCURRENCY EXECUTIVE KERNEL ======
parallel.waitForAny(renderLoop, networkWorker)
