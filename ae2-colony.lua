-- 1
-- ATM10 MineColonies to AE2 Bridge Supply Engine
-- Production Core (ATM10 v8.1 / MC 1.21.1 / AP v0.7.x)

-- ====== CONFIGURATION ======
local EXPORT_TARGET = "down"   
local REFRESH_RATE = 5
-- ===========================

local colony = peripheral.find("colony_integrator")
local ae2 = peripheral.find("me_bridge")

if not colony then error("[FATAL] colony_integrator block not found!") end
if not ae2 then error("[FATAL] me_bridge block not found!") end

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
                    
                    -- Native single-key item tracking check
                    local detail = ae2.getItem({id = itemID})
                    if not detail then detail = ae2.getItem({name = itemID}) end
                    
                    local available = detail and (detail.count or detail.amount) or 0
                    local isCraftable = detail and detail.isCraftable or false
                    
                    print("  -> Storage Check: Stored Balance = " .. available)

                    if available >= needed then
                        print("  -> Status: In Stock. Executing clean export...")
                        
                        -- FIXED: Wrap item criteria into a table (Map) to prevent "map expected, got number"
                        local callSuccess, res, err = pcall(ae2.exportItem, EXPORT_TARGET:lower(), {name = itemID, count = needed})
                        
                        -- Dynamic fallback sequence for old AP versions if direction parameters are flipped
                        if not callSuccess or res == 0 then
                            callSuccess, res, err = pcall(ae2.exportItem, {name = itemID, count = needed}, EXPORT_TARGET:lower())
                        end
                        
                        if callSuccess and (res and res ~= 0) then
                            print("  ✔ SUCCESS: Pulled items to target container!")
                        else
                            print("  ❌ EXPORT ERROR: " .. tostring(res or err or "INVENTORY_NOT_FOUND"))
                        end
                    else
                        local craftQty = needed - available
                        print("  -> Status: Shortage. Evaluating craft capability...")
                        
                        if isCraftable then
                            print("  -> Triggering autocraft for " .. craftQty .. " units...")
                            
                            -- Pass a proper item stack table and catch both pcall and API return states
                            local callSuccess, craftSuccess, craftErr = pcall(ae2.craftItem, {name = itemID, count = craftQty})
                            
                            if callSuccess and craftSuccess then
                                print("  ✔ SUCCESS: Craft order locked into AE2 system.")
                            else
                                local actualErr = craftErr or craftSuccess or "No CPU available or craft rejected"
                                print("  ❌ CRAFT ERROR: " .. tostring(actualErr))
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
