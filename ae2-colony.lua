-- ATM10 MineColonies to AE2 Bridge Dashboard (Neon Tech Variant)
-- Optimized for 5x3 Monitor with a Futuristic Dark Base Aesthetic
-- FUZZY MATRIX DISCOVERY CORE: Fixes unpacking truncation & updates AE2 Bridge API

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
-- Safely wrap monitor
local monitor = peripheral.wrap(MONITOR_SIDE)
if not monitor then error("[FATAL] Monitor not found on side: " .. MONITOR_SIDE) end

monitor.setTextScale(1)
local w, h = monitor.getSize()

-- Dynamic peripheral resolution core
local colony = peripheral.find("colony")
local meBridge = peripheral.find("meBridge")

-- Deep-inspect item names for fuzzy matrix matching
local function matchSystemItem(colonyItemName)
    if not meBridge then return nil end
    local aeItems = meBridge.listItems()
    local cleanName = colonyItemName:gsub(" ", ""):lower()
    
    for _, item in ipairs(aeItems) do
        local techName = item.name:match(":([^:]+)$") or ""
        if techName:gsub("_", ""):lower() == cleanName then
            return item
        end
    end
    return nil
end

-- Process active MineColonies requests safely handling item structures
local function processColonyRequests()
    colonyConnected = (colony ~= nil)
    ae2Connected = (meBridge ~= nil)
    
    if not colonyConnected or not ae2Connected then 
        hasActiveErrors = true
        return 
    end
    
    hasActiveErrors = false
    local requests = colony.getRequests()
    currentRequests = {}
    
    for _, req in ipairs(requests) do
        for _, item in ipairs(req.items) do
            -- FIXED: Avoid array unpack truncation by indexing values directly
            local itemName = item.name or "Unknown Item"
            local needed = item.count or item.needed or 1 
            
            local systemItem = matchSystemItem(itemName)
            local status = "Missing"
            local available = 0
            
            if systemItem then
                local detail = meBridge.getItem({name = systemItem.name})
                available = detail and detail.amount or 0
                
                if available >= needed then
                    status = "Exporting"
                    -- MODERN SIGNATURE: exportItem({name="mod:id", count=X}, direction)
                    local success = meBridge.exportItem({name = systemItem.name, count = needed}, EXPORT_DIRECTION)
                    if success then
                        addDelivery(itemName, needed)
                        addLog("Exported " .. needed .. "x " .. itemName)
                    end
                else
                    status = "Crafting"
                    -- MODERN SIGNATURE: requestCrafting({name="mod:id"}, count)
                    local craftQty = needed - available
                    local success, err = meBridge.requestCrafting({name = systemItem.name}, craftQty)
                    if not success then
                        status = "Craft Fail"
                        addLog("Craft Fail: " .. (err or "No CPU"))
                    end
                end
            else
                addLog("No AE2 item map for: " .. itemName)
            end
            
            table.insert(currentRequests, {
                name = itemName,
                needed = needed,
                available = available,
                status = status
            })
        end
    end
end
-- Helper function for clean background fills on text boundaries
local function drawRowBackground(y, color)
    monitor.setBackgroundColor(color)
    monitor.setCursorPos(1, y)
    monitor.write(string.rep(" ", w))
end

-- Re-engineered 5x3 Structural Screen Mapping Grid
local function drawDashboard()
    monitor.setBackgroundColor(colors.black)
    monitor.clear()
    
    -- Neon Header Bar Construction
    monitor.setBackgroundColor(colors.gray)
    monitor.setCursorPos(1, 1)
    monitor.write(string.rep(" ", w))
    monitor.setCursorPos(2, 1)
    monitor.setTextColor(colors.cyan)
    monitor.write("NEON TECH // ATM10 COLONY BRIDGE")
    
    -- Status Grid Placement Matrix (Prevents overlap on 5x3)
    monitor.setBackgroundColor(colors.black)
    
    monitor.setCursorPos(2, 3)
    monitor.setTextColor(colors.white)
    monitor.write("Colony Integration: ")
    monitor.setTextColor(colonyConnected and colors.green or colors.red)
    monitor.write(colonyConnected and "[ONLINE]" or "[OFFLINE]")
    
    monitor.setCursorPos(2, 4)
    monitor.setTextColor(colors.white)
    monitor.write("AE2 Quantum Bridge: ")
    monitor.setTextColor(ae2Connected and colors.green or colors.red)
    monitor.write(ae2Connected and "[STABLE]" or "[DISCONNECTED]")
    
    -- Section Dividers
    monitor.setCursorPos(2, 6)
    monitor.setTextColor(colors.cyan)
    monitor.write("--- CURRENT COLONY SUPPLY LOOPS ---")
    
    local row = 8
    if #currentRequests == 0 then
        monitor.setCursorPos(4, row)
        monitor.setTextColor(colors.lightGray)
        monitor.write(">> No pending structural matrix items requested.")
    else
        for i, req in ipairs(currentRequests) do
            if row > h - 6 then break end
            
            -- Print quantity and truncated item name
            monitor.setCursorPos(2, row)
            monitor.setTextColor(colors.white)
            local cleanLabel = string.format("%dx %s", req.needed, req.name)
            monitor.write(cleanLabel:sub(1, w - 16))
            
            -- Rigorous right-align status matrix column tracking
            monitor.setCursorPos(w - 12, row)
            if req.status == "Exporting" then monitor.setTextColor(colors.green)
            elseif req.status == "Crafting" then monitor.setTextColor(colors.yellow)
            else monitor.setTextColor(colors.red) end
            monitor.write(string.format("[%s]", req.status))
            
            row = row + 1
        end
    end
    
    -- Fixed-position dynamic diagnostics telemetry block at footer
    local logY = h - 3
    monitor.setCursorPos(2, logY)
    monitor.setTextColor(colors.cyan)
    monitor.write("SYSTEM ROUTING LOGS:")
    
    monitor.setCursorPos(2, logY + 1)
    monitor.setTextColor(colors.lightGray)
    if debugLogs[1] then
        monitor.write(debugLogs[1]:sub(1, w - 2))
    else
        monitor.write("Awaiting bridge matrix polling pulse...")
    end
end

-- Executive Automation Loop
local function main()
    while true do
        colony = peripheral.find("colony")
        meBridge = peripheral.find("meBridge")
        
        isPolling = true
        processColonyRequests()
        drawDashboard()
        isPolling = false
        sleep(REFRESH_RATE)
    end
end

-- Run System Application Core
local status, err = pcall(main)
if not status then
    monitor.setBackgroundColor(colors.black)
    monitor.setTextColor(colors.red)
    monitor.clear()
    monitor.setCursorPos(1,1)
    print("[CRITICAL PANIC]: " .. tostring(err))
end
