-- ATM10 MineColonies to AE2 Bridge Supply Engine
-- Minimalist 1.21.1 Linear Verification Core

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
                    -- Strip trailing NBT hash blocks cleanly
                    itemID = itemID:match("^[^#]+") or itemID
                    
                    print("\n[TARGET] Item: " .. itemID .. " | Demand Qty: " .. needed)
                    
                    -- Query item balance cleanly using string matching wrappers
                    local detail = ae2.getItem({name = itemID})
                    local available = detail and (detail.count or detail.amount) or 0
                    print("  -> Storage Check: Stored Balance = " .. available)

                    if available >= needed then
                        print("  -> Status: In Stock. Dispatching flat arguments...")
                        
                        -- CRITICAL PASS FIX: Direct single-string assignment to bypass table parser limitations
                        local success, res = pcall(ae2.exportItem, itemID, needed, EXPORT_DIRECTION)
                        
                        -- Defensive fallback pass in case direction matches a peripheral name string block
                        if not success then
                            success, res = pcall(ae2.exportItem, {name = itemID, count = needed}, EXPORT_DIRECTION)
                        end
                        
                        if success then
                            print("  ✔ SUCCESS: Pulled items into delivery chest!")
                        else
                            print("  ❌ EXPORT ERROR: " .. tostring(res or "No item moved"))
                        end
                    else
                        local craftQty = needed - available
                        print("  -> Status: Shortage. Triggering flat craft query for " .. craftQty .. " units...")
                        
                        -- Execute craft routines directly via strict table descriptors
                        local success, err = pcall(ae2.craftItem, {id = itemID, count = craftQty})
                        
                        if not success then
                            success, err = pcall(ae2.craftItem, {name = itemID, count = craftQty})
                        end
                        
                        if success then
                            print("  ✔ SUCCESS: Craft order locked into AE2 system.")
                        else
                            print("  ❌ CRAFT ERROR: " .. tostring(err or "No Pattern/CPU"))
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
        print("\n[CRITICAL ERROR]: " .. tostring(globalErr))
    end
    sleep(REFRESH_RATE)
end
