-- ATM10 MineColonies to AE2 Bridge Supply Engine
-- Production Core (ATM10 v8.1 / MC 1.21.1 / AP v0.7.x)

-- ====== CONFIGURATION ======
-- NOTE: If "down" keeps throwing INVENTORY_NOT_FOUND, wrap the barrel with a wired 
-- modem and paste its exact peripheral name here (e.g. "metalbarrels:netherite_barrel_0")
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
                    
                    -- Native query using verified modern v0.7.x payload constraints
                    local detail = ae2.getItem({id = itemID})
                    if not detail then detail = ae2.getItem({name = itemID}) end
                    
                    local available = detail and (detail.count or detail.amount) or 0
                    local isCraftable = detail and detail.isCraftable or false
                    
                    print("  -> Storage Check: Stored Balance = " .. available)

                    if available >= needed then
                        print("  -> Status: In Stock. Executing audited export...")
                        
                        -- Pass 1: Try lowercase config direction/name
                        local callSuccess, itemsMoved = pcall(ae2.exportItem, ae2, {id = itemID, count = needed}, EXPORT_TARGET:lower())
                        if not callSuccess or not itemsMoved or itemsMoved == 0 then
                            -- Pass 2: Fallback to variant payload identifier
                            callSuccess, itemsMoved = pcall(ae2.exportItem, ae2, {name = itemID, count = needed}, EXPORT_TARGET:lower())
                        end
                        if not callSuccess or not itemsMoved or itemsMoved == 0 then
                            -- Pass 3: Fallback to uppercase cardinal string matching
                            callSuccess, itemsMoved = pcall(ae2.exportItem, ae2, {id = itemID, count = needed}, EXPORT_TARGET:upper())
                        end
                        
                        -- Verify items moved matching current structural number returns
                        if callSuccess and type(itemsMoved) == "number" and itemsMoved > 0 then
                            print("  ✔ SUCCESS: Pulled " .. itemsMoved .. " units to target container!")
                        else
                            print("  ❌ EXPORT ERROR: " .. tostring(itemsMoved or "INVENTORY_NOT_FOUND (Check Barrel placement below ME Bridge block)"))
                        end
                    else
                        local craftQty = needed - available
                        print("  -> Status: Shortage. Evaluating craft capability...")
                        
                        if isCraftable then
                            print("  -> Triggering autocraft for " .. craftQty .. " units...")
                            local callSuccess, craftErr = pcall(ae2.craftItem, ae2, {id = itemID, count = craftQty})
                            if not callSuccess then
                                callSuccess, craftErr = pcall(ae2.craftItem, ae2, {name = itemID, count = craftQty})
                            end
                            
                            if callSuccess then
                                print("  ✔ SUCCESS: Craft order locked into AE2 system.")
                            else
                                print("  ❌ CRAFT ERROR: " .. tostring(craftErr or "Stalled"))
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
