-- ATM10 MineColonies to AE2 Bridge Kernel
-- Minimalist 1.21.1 Execution Core

-- ====== CONFIGURATION ======
local EXPORT_DIRECTION = "down"   -- Target direction of the chest/barrel below the ME Bridge
local REFRESH_RATE = 5             -- Polling loop tick rate in seconds
-- ===========================

-- Locate core peripherals strictly matching modern names
local colony = peripheral.find("colony_integrator")
local ae2 = peripheral.find("me_bridge")

if not colony then error("[FATAL] colony_integrator block not found on local network!") end
if not ae2 then error("[FATAL] me_bridge block not found on local network!") end

print("=============================================")
print("  ATM10 SUPPLY CHAIN SYSTEMS ONLINE          ")
print("=============================================")
local function processDemands()
    term.clear()
    term.setCursorPos(1,1)
    print("=== LOGISTICS EVENT TIMELINE: " .. os.date("%H:%M:%S") .. " ===")
    
    local requests = colony.getRequests()
    if not requests or #requests == 0 then
        print(">> Status: System Idle. All colony demands met.")
        return
    end

    print(string.format("Processing %d active colony request lines...", #requests))

    for _, req in ipairs(requests) do
        if req.items then
            for _, item in ipairs(req.items) do
                -- Target namespaced registry string accurately
                local itemID = item.id or item.name
                local needed = item.count or item.needed or 1

                if itemID then
                    print(string.format("\n[TARGET] Item: %s | Demand Qty: %d", itemID, needed))
                    
                    -- BYPASS GETITEMS BUG: Read storage metadata via discrete item calls directly
                    local detail = ae2.getItem({name = itemID})
                    local available = detail and (detail.amount or detail.count) or 0
                    print(string.format("  -> Storage Check: Stored Balance = %d", available))

                    if available >= needed then
                        print("  -> Status: In Stock. Dispatching item payload...")
                        -- MODERN SIGNATURE: exportItem({name, count}, direction)
                        local success = ae2.exportItem({name = itemID, count = needed}, EXPORT_DIRECTION)
                        if success then
                            print("  ✔ SUCCESS: Pulled to chest!")
                        else
                            print("  ❌ EXPORT ERROR: Extraction block obstructed.")
                        end
                    else
                        -- Calculate exact remainder needed
                        local craftQty = needed - available
                        print(string.format("  -> Status: Shortage. Triggering autocraft for %d units...", craftQty))
                        
                        -- MODERN SIGNATURE: requestCrafting({name}, count)
                        local success, err = ae2.requestCrafting({name = itemID}, craftQty)
                        if success then
                            print("  ✔ SUCCESS: Craft order locked into AE2 system.")
                        else
                            print("  ❌ CRAFT ERROR: " .. tostring(err or "Missing Pattern/CPU"))
                        end
                    end
                end
            end
        end
    end
end
-- Simple single-threaded linear execution automation loop
while true do
    local status, err = pcall(processDemands)
    if not status then
        print("\n[CRITICAL ERROR EXCEPTION]: " .. tostring(err))
    end
    sleep(REFRESH_RATE)
end
