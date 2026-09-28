-- ATM10 MineColonies to AE2 Bridge Supply Engine
-- Minimalist 1.21.1 Execution Core

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
                    itemID = itemID:match("^[^#]+") or itemID
                    local detail = ae2.getItem({name = itemID})
                    local available = detail and (detail.count or detail.amount) or 0

                    if available >= needed then
                        ae2.exportItem({name = itemID, count = needed}, EXPORT_DIRECTION)
                    else
                        ae2.requestCrafting({name = itemID}, needed - available)
                    end
                end
            end
        end
    end
end

while true do
    pcall(processDemands)
    sleep(REFRESH_RATE)
end
