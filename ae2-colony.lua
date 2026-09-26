-- ATM10 MineColonies to AE2 Bridge Dashboard (Neon Tech Variant)
-- Optimized for 5x3 Monitor with a Futuristic Dark Base Aesthetic

-- ====== CONFIGURATION ======
local MONITOR_SIDE = "top"         
local EXPORT_DIRECTION = "front"   
local REFRESH_RATE = 5             
-- ===========================

-- Diagnostics log array
local debugLogs = {}
local function addLog(msg)
    table.insert(debugLogs, 1, "⚡ [" .. os.date("%H:%M:%S") .. "] " .. msg)
    if #debugLogs > 4 then table.remove(debugLogs) end
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

local function drawHeader(colony, ae2, isPolling)
    monitor.setBackgroundColor(C_BG)
    monitor.clear()
    
    -- Main Cyber Title Bar
    monitor.setBackgroundColor(C_PANEL)
    monitor.setTextColor(C_HEADER)
    monitor.setCursorPos(1, 1)
    monitor.clearLine()
    
    local title = "// AE2 LOGISTICS KERNEL v10.0 //"
    local padding = math.max(0, math.floor((w - #title) / 2))
    monitor.setCursorPos(padding + 1, 1)
    monitor.write(title)
    
    -- Glowing network query indicator
    if isPolling then
        monitor.setTextColor(colors.magenta)
        monitor.setCursorPos(w - 3, 1)
        monitor.write("[⚡]")
    end
    
    -- Connection Matrices
    monitor.setBackgroundColor(C_BG)
    monitor.setCursorPos(2, 3)
    monitor.setTextColor(C_TEXT)
    monitor.write("» COLONY INTEGRATOR (LEFT): ")
    if colony then
        monitor.setTextColor(C_SUCCESS)
        monitor.write("[SECURE]")
    else
        monitor.setTextColor(C_FAIL)
        monitor.write("[DISCONNECTED]")
    end
    
    monitor.setCursorPos(2, 4)
    monitor.setTextColor(C_TEXT)
    monitor.write("» ME NETWORK BRIDGE (RIGHT): ")
    if ae2 then
        monitor.setTextColor(C_SUCCESS)
        monitor.write("[ONLINE]")
    else
        monitor.setTextColor(C_FAIL)
        monitor.write("[LINK DOWN]")
    end
    
    -- Tech Grid Dividers (Swapped to safe ASCII equivalents)
    monitor.setCursorPos(1, 6)
    monitor.setTextColor(C_SUB)
    monitor.write(string.rep("=", w))
    
    monitor.setCursorPos(2, 7)
    monitor.setTextColor(C_HEADER)
    monitor.write(string.format("%-22s | %-5s | %s", "LOGISTICS REGISTRY", "QTY", "MATRIX STATE"))
    
    monitor.setCursorPos(1, 8)
    monitor.setTextColor(C_SUB)
    monitor.write(string.rep("-", w))
end

local function drawDebugPanel()
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
end

local function processRequests(colony, ae2)
    if not colony or not ae2 then return end
    
    local success, requests = pcall(colony.getRequests)
    if not success or not requests then 
        error("Matrix pipeline failure querying Colony Integrator.") 
    end
    
    local y = 9
    local maxDisplayY = h - 6
    
    if #requests == 0 then
        monitor.setCursorPos(2, y)
        monitor.setTextColor(C_SUCCESS)
        monitor.write("✔ Network Idle: All sector demands met.")
        return
    end
    
    for _, req in ipairs(requests) do
        if y > maxDisplayY then 
            monitor.setCursorPos(2, y)
            monitor.setTextColor(C_WARN)
            monitor.write("... Buffer Overflow: Output Truncated ...")
            break 
        end
        
        local itemID = req.item or "void:null"
        local needed = tonumber(req.needed) or 0
        local displayName = req.name or itemID
        
        -- Tech layout formatting for names
        displayName = displayName:gsub("minecraft:", ""):gsub("domum_ornamentum:", "")
        displayName = displayName:gsub("^%l", string.upper):gsub("_", " ")
        if #displayName > 22 then displayName = displayName:sub(1, 19) .. "..." end
        
        monitor.setCursorPos(2, y)
        monitor.setTextColor(C_TEXT)
        monitor.write(string.format("%-22s | %-5d | ", displayName, needed))
        
        local aeSuccess, aeItem = pcall(ae2.getItem, {name = itemID})
        local available = 0
        if aeSuccess and aeItem then
            available = tonumber(aeItem.amount) or tonumber(aeItem.count) or 0
        end
        
        if available >= needed then
            monitor.setTextColor(C_SUCCESS)
            monitor.write("▶ ROUTING")
            
            pcall(function()
                ae2.exportItem({name = itemID, count = needed}, EXPORT_DIRECTION)
            end)
        elseif available > 0 and available < needed then
            monitor.setTextColor(C_WARN)
            monitor.write("⚠ DEPLETED (" .. available .. ")")
            
            pcall(function()
                ae2.exportItem({name = itemID, count = available}, EXPORT_DIRECTION)
            end)
        else
            monitor.setTextColor(C_FAIL)
            monitor.write("✖ VOID")
        end
        
        y = y + 1
    end
end

-- ====== MAIN LOOP ======
addLog("Logistics kernel initialized.")
while true do
    -- HOTFIXED FOR 1.21.1: Swapped registry target identifiers to pure snake_case
    local colony = peripheral.find("colony_integrator")
    local ae2 = peripheral.find("me_bridge")
    
    drawHeader(colony, ae2, true)
    
    if not colony or not ae2 then
        if not colony then addLog("Hardware Fault: Colony node handshake failed.") end
        if not ae2 then addLog("Hardware Fault: ME system grid parity lost.") end
    else
        local coreSuccess, coreError = pcall(processRequests, colony, ae2)
        if not coreSuccess then
            addLog("Core Error: " .. tostring(coreError):sub(1, 25))
        end
    end
    
    drawDebugPanel()
    sleep(0.5)
    
    drawHeader(colony, ae2, false)
    drawDebugPanel()
    
    sleep(REFRESH_RATE - 0.5)
end
