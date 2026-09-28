-- ATM10 MineColonies to AE2 Bridge Dashboard (Neon Tech Variant)
-- Optimized for 5x3 Monitor with a Futuristic Dark Base Aesthetic
-- ADVANCED BUILD: File-Logged Isolated Registry Diagnostic Build

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
-- Triple-pass lookup targeting every possible variable property in ATM10 Advanced Peripherals
local function matchSystemItem(colonyItemName, aeInventory)
    if not aeInventory or not colonyItemName then return nil end
    
    local target = colonyItemName:lower():gsub(" ", "")
    local targetTag = target:match(":([^:]+)$") or target
    
    for _, item in ipairs(aeInventory) do
        -- Extract any string identifier from item tables (name, id, fingerprint, display_name, item object)
        local aeRaw = item.name or item.id or item.fingerprint or (type(item.item) == "table" and item.item.id) or ""
        if type(aeRaw) == "string" and aeRaw ~= "" then
            local aeClean = aeRaw:lower():gsub(" ", "")
            
            -- PASS 1: Strict Raw Equivalent Match
            if aeClean == target then
                return item
            end
            
            -- PASS 2: Stripped Mod Namespace Tag Match
            local aeTag = aeClean:match(":([^:]+)$") or aeClean
            if aeTag == targetTag then
                return item
            end
        end
    end
    return nil
end

local function networkWorker()
    term.clear()
    term.setCursorPos(1,1)
    print("=== LOGISTICS KERNEL TERMINAL LOGGER ACTIVE ===")
    print("Diagnostic logs will be saved to: ae2_dump.txt")
    print("Open it using 'edit ae2_dump.txt' to view it without scrolling!")
    
    local initialDumpWritten = false
    
    while true do
        local colony = peripheral.find("colony_integrator")
        local ae2 = peripheral.find("me_bridge")
        colonyConnected = (colony ~= nil)
        ae2Connected = (me_bridge ~= nil) or (ae2 ~= nil)
        
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
                
                local aeInventory = {}
                local listSuccess, listData = pcall(function() return ae2.listItems() or ae2.getItems() or {} end)
                if listSuccess and listData then
                    aeInventory = listData
                    
                    -- HIGH-UTILITY DIAGNOSTIC FILE GENERATION: Dump structure data safely without terminal spam
                    if not initialDumpWritten then
                        local logFile = fs.open("ae2_dump.txt", "w")
                        if logFile then
                            logFile.writeLine("=== AE2 INVENTORY FIELD DUMP MATCHING LOG ===")
                            logFile.writeLine("Generated at: " .. os.date("%H:%M:%S"))
                            logFile.writeLine(string.format("Total Stored Registry Types Found: %d\n", #aeInventory))
                            
                            local dumpLimit = 0
                            for k, v in pairs(aeInventory) do
                                if dumpLimit < 15 then
                                    logFile.writeLine(string.format("[%d] Type: %s", dumpLimit + 1, type(v)))
                                    if type(v) == "table" then
                                        logFile.writeLine(string.format("    -> .name   = %s", tostring(v.name)))
                                        logFile.writeLine(string.format("    -> .id     = %s", tostring(v.id)))
                                        logFile.writeLine(string.format("    -> .count  = %s", tostring(v.count)))
                                        logFile.writeLine(string.format("    -> .amount = %s", tostring(v.amount)))
                                        if v.item and type(v.item) == "table" then
                                            logFile.writeLine(string.format("    -> .item.id= %s", tostring(v.item.id)))
                                        end
                                    else
                                        logFile.writeLine(string.format("    -> Raw Value = %s", tostring(v)))
                                    end
                                    dumpLimit = dumpLimit + 1
                                end
                            end
                            logFile.close()
                            initialDumpWritten = true
                            print("[DIAGNOSTICS] Done! Written 15 registry structure variants to 'ae2_dump.txt'")
                        end
                    end
                end
                
                for _, req in ipairs(requests) do
                    local needed = req.count or req.needed or 1
                    
                    for _, item in ipairs(req.items) do
                        local rawRegistryName = item.id or item.name or item.display_name or "Unknown"
                        
                        if type(rawRegistryName) == "string" then
                            rawRegistryName = rawRegistryName:match("^[^#]+") or rawRegistryName
                        end
                        
                        local displayItemName = rawRegistryName:gsub("^.*:", ""):gsub("_", " ")
                        displayItemName = displayItemName:sub(1,1):upper() .. displayItemName:sub(2)
                        
                        local systemItem = matchSystemItem(rawRegistryName, aeInventory)
                        local status = "Missing"
                        local available = 0
                        
                        if systemItem then
                            available = systemItem.amount or systemItem.count or 0
                            
                            if available >= needed then
                                status = "Exporting"
                                local expSuccess = ae2.exportItem({name = rawRegistryName, count = needed}, EXPORT_DIRECTION)
                                if expSuccess then
                                    addDelivery(displayItemName, needed)
                                    addLog("Exported " .. needed .. "x " .. displayItemName)
                                end
                            else
                                status = "Crafting"
                                local craftQty = needed - available
                                local craftSuccess, err = ae2.requestCrafting({name = rawRegistryName}, craftQty)
                                if not craftSuccess then
                                    status = "Craft Fail"
                                    addLog("Craft Fail: " .. (err or "No CPU"))
                                end
                            end
                        else
                            addLog("No AE2 item map for: " .. displayItemName)
                        end
                        
                        local displayStatus = string.format("[%s]", status)
                        table.insert(tempRequests, {
                            text = string.format("%-22s | %-5d | %s", displayItemName:sub(1, 22), needed, displayStatus),
                            color = (status == "Exporting") and C_SUCCESS or ((status == "Crafting") and C_WARN or C_FAIL)
                        })
                    end
                end
                currentRequests = tempRequests
                sleep(REFRESH_RATE)
            end
        end
    end
end
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
    
    local barWidth = 8
    local progressChars = math.floor((currentTickProgress / 100) * barWidth)
    if progressChars > barWidth then progressChars = barWidth end
    
    local barText = "[" .. string.rep("=", progressChars) .. string.rep(" ", barWidth - progressChars) .. "]"
    monitor.setCursorPos(w - (barWidth + 2), 1)
    
    if isPolling then monitor.setTextColor(C_SUB) else monitor.setTextColor(C_SUCCESS) end
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

-- Concurrent Thread Executor Orchestration
parallel.waitForAll(renderLoop, networkWorker)
