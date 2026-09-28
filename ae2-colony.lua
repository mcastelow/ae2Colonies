-- ATM10 MineColonies to AE2 Bridge Supply Engine
-- Fixed for 1.21.1+ ME Bridge Signatures

local EXPORT_DIRECTION = "down"
local REFRESH_RATE = 5

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
                    -- Strip trailing NBT hash identifiers cleanly
                    itemID = itemID:match("^[^#]+") or itemID
                    
                    print("\n[TARGET] Item: " .. itemID .. " | Demand Qty: " .. needed)
                    
                    local detail = ae2.getItem({name = itemID})
                    local available = detail and (detail.count or detail.amount) or 0
                    print("  -> Storage Check: Stored Balance = " .. available)

                    if available >= needed then
                        print("  -> Status: In Stock. Executing export...")
                        
                        -- FIX 1: Try the new 1.21.1+ signature first (Direction, Item Table)
                        local success, res, err = pcall(ae2.exportItem, EXPORT_DIRECTION, {name = itemID, count = needed})
                        
                        -- Fallback to old signature if the first one failed due to argument typing
                        if not success or res == 0 then
                            success, res, err = pcall(ae2.exportItem, {name = itemID, count = needed}, EXPORT_DIRECTION)
                        end
                        
                        -- Double fallback check with alternative ID property
                        if not success or res == 0 then
                            pcall(ae2.exportItem, EXPORT_DIRECTION, {id = itemID, count = needed})
                        end
                        
                        if success and (res and res ~= 0) then
                            print("  ✔ SUCCESS: Pulled items into delivery chest!")
                        else
                            print("  ❌ EXPORT ERROR: " .. tostring(res or err or "No item moved / Obstructed"))
                        end
                    else
                        local craftQty = needed - available
                        print("  -> Status: Shortage. Executing crafting call for " .. craftQty .. " units...")
                        
                        -- FIX 2: Evaluate the true return value of craftItem, not just pcall's status
                        local pcallSuccess, craftSuccess, craftErr = pcall(ae2.craftItem, {name = itemID, count = craftQty})
                        
                        if pcallSuccess and craftSuccess then
                            print("  ✔ SUCCESS: Craft order accepted by AE2 system.")
                        else
                            local actualError = craftErr or craftSuccess or "No Pattern, missing CPU, or no co-processors available"
                            print("  ❌ CRAFT ERROR: " .. tostring(actualError))
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
