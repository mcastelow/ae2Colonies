-- ATM10 MineColonies to AE2 Bridge Supply Engine
-- Production Core (ATM10 v8.1 / MC 1.21.1 / Wired Network Mode)

-- ====== CONFIGURATION ======
-- Pointed directly to your connected Netherite Barrel network address
local EXPORT_CONTAINER = "sophisticatedstorage:barrel_0"   
local REFRESH_RATE = 5
-- ===========================

-- Dynamically find the peripherals over the network cable
local colony = peripheral.find("colony_integrator")
local ae2 = peripheral.find("me_bridge")

if not colony then error("[FATAL] colony_integrator not detected on the modem network! (Did you right-click its modem?)") end
if not ae2 then error("[FATAL] me_bridge not detected on the modem network! (Did you right-click its modem?)") end

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

local function processDemands()
    term.clear()
    term.setCursorPos(1,1)
    print("=== LOGISTICS EVENT TIMELINE: " .. os.date("%H:%M:%S") .. " ===")
    
    local requests = colony.getRequests()
    if not requests or #requests == 0 then
        print(">> Status: System Idle. All colony demands met.")
        return
    end

    for _, req in ipairs(requests) do
        local needed = req.count or req.needed or 1
        if req.items then
            for _, item in ipairs(req.items) do
                local itemID = extractItemString(item)
                if itemID and type(itemID) == "string" then
                    itemID = itemID:match("^[^#]+") or itemID
                    
                    print("\n[TARGET] Item: " .. itemID .. " | Demand Qty: " .. needed)
                    
                    local detail = ae2.getItem({id = itemID})
                    if not detail then detail = ae2.getItem({name = itemID}) end
                    
                    local available = detail and (detail.count or detail.amount) or 0
                    local isCraftable = detail and detail.isCraftable or false
                    
                    print("  -> Storage Check: Stored Balance = " .. available)

                    if available >= needed then
                        print("  -> Status: In Stock. Transporting over cable network...")
                        
                        local itemTable = { name = itemID, count = needed }
                        local callSuccess, res, err
                        
                        -- Modern 1.21.1 Advanced Peripherals uses the peripheral ID string as the destination argument
                        callSuccess, res, err = pcall(ae2.exportItem, itemTable, EXPORT_CONTAINER)
                        
                        -- Fallback variant parameter order if your exact AP sub-version requires it
                        if not callSuccess or not res or res == 0 then
                            callSuccess, res, err = pcall(ae2.exportItem, EXPORT_CONTAINER, itemTable)
                        end

                        if callSuccess and (res and res ~= 0) then
                            print("  ✔ SUCCESS: Items pushed directly into target barrel!")
                        else
                            local finalErr = err or res or "BARREL_REJECTED_TRANSFER"
                            print("  ❌ EXPORT ERROR: " .. tostring(finalErr))
                        end
                    else
                        local craftQty = needed - available
                        print("  -> Status: Shortage. Evaluating craft capability...")
                        
                        if isCraftable then
                            print("  -> Triggering autocraft for " .. craftQty .. " units...")
                            
                            local pSuccess, cSuccess, cErr = pcall(ae2.craftItem, {name = itemID, count = craftQty})
                            if pSuccess and cSuccess then
                                print("  ✔ SUCCESS: Craft order locked into AE2 system.")
                            else
                                print("  ❌ CRAFT ERROR: " .. tostring(cErr or cSuccess or "Rejected by AE2"))
                            end
                        else
                            print("  ❌ CRAFT ABORTED: NOT_CRAFTABLE (No encoded AE2 Pattern found)")
                        end
                    end
                end
            end
        end
    end
end

while true do
    local globalSuccess, globalErr = pcall(processDemands)
    if not globalSuccess then
        print("\n[CRITICAL NETWORK EXCEPTION]: " .. tostring(globalErr))
    end
    sleep(REFRESH_RATE)
end
