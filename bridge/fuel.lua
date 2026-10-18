-- Fuel bridge: reading and writing a vehicle's fuel level through whichever fuel script the server runs.
-- Only the Fuel Leak action needs it. Client side only: the effect runs on the vehicle owner's client.
--
-- Config.Fuel: 'auto', a resource name from the list below, or 'none'. 'auto' uses the first one that is started.
-- With none (or 'none') only the GTA fuel level is changed, which a fuel script will usually overwrite.

---@type { name: string, kind: 'state_bag'|'export' }[] Supported fuel scripts, in detection order.
---'state_bag' scripts keep the level in the vehicle's `fuel` state bag; 'export' scripts have GetFuel / SetFuel exports.
local SUPPORTED <const> = {
    { name = 'ox_fuel',          kind = 'state_bag' },
    { name = 'LegacyFuel',       kind = 'export' },
    { name = 'cdn-fuel',         kind = 'export' },
    { name = 'ps-fuel',          kind = 'export' },
    { name = 'lj-fuel',          kind = 'export' },
    { name = 'okokFuel',         kind = 'export' },
    { name = 'stg-vanaheimfuel', kind = 'export' },
}

---@return { name: string, kind: string }|nil
local function detect()
    local wanted <const> = Config.Fuel
    if wanted == 'none' or wanted == false then return nil end
    for i = 1, #SUPPORTED do
        local row <const> = SUPPORTED[i]
        if (wanted == nil or wanted == 'auto' or wanted == row.name) and GetResourceState(row.name) == 'started' then
            return row
        end
    end
    return nil
end

local active <const> = detect()

---@class VehicleHackFuel
local Fuel = { name = active and active.name or nil }

---The vehicle's fuel level (0-100). Falls back to the GTA level when the script cannot say.
---@param vehicle integer
---@return number
function Fuel.Get(vehicle)
    if active then
        if active.kind == 'state_bag' then
            local level <const> = Entity(vehicle).state.fuel
            if type(level) == 'number' then return level end
        else
            local ok, level = pcall(function() return exports[active.name]:GetFuel(vehicle) end)
            if ok and type(level) == 'number' then return level end
        end
    end
    return GetVehicleFuelLevel(vehicle)
end

---Sets the vehicle's fuel level (0-100) in the GTA gauge and in the fuel script, so the script does not put it back.
---@param vehicle integer
---@param level number
function Fuel.Set(vehicle, level)
    level = math.min(100.0, math.max(0.0, level + 0.0))
    SetVehicleFuelLevel(vehicle, level)
    if not active then return end

    if active.kind == 'state_bag' then
        Entity(vehicle).state:set('fuel', level, true)
        return
    end
    local ok, err = pcall(function() exports[active.name]:SetFuel(vehicle, level) end)
    if not ok and Config.Debug then
        print(('[%s] %s:SetFuel failed: %s'):format(GetCurrentResourceName(), active.name, tostring(err)))
    end
end

Bridge.Fuel = Fuel
