-- Helpers shared by the client scripts. Everything lives on one table so the other files do not
-- reach for globals.

VH = {}

---Turns a network id into a live vehicle entity on this client, or nil.
---@param netId any
---@return integer|nil
function VH.vehicleFromNetId(netId)
    if type(netId) ~= 'number' or not NetworkDoesEntityExistWithNetworkId(netId) then return nil end
    local veh <const> = NetworkGetEntityFromNetworkId(netId)
    if not veh or veh == 0 or not DoesEntityExist(veh) or GetEntityType(veh) ~= 2 then return nil end
    return veh
end

---Asks for control of an entity and waits a moment for it.
---@param entity integer
---@return boolean
function VH.takeControl(entity)
    if NetworkHasControlOfEntity(entity) then return true end
    NetworkRequestControlOfEntity(entity)
    local give <const> = GetGameTimer() + 1000
    while not NetworkHasControlOfEntity(entity) and GetGameTimer() < give do Wait(0) end
    return NetworkHasControlOfEntity(entity)
end

---A vehicle's display name: the game's label when it has one, the model name otherwise.
---@param veh integer
---@return string
function VH.displayName(veh)
    local display <const> = GetDisplayNameFromVehicleModel(GetEntityModel(veh))
    local label <const> = GetLabelText(display)
    if label and label ~= 'NULL' and label ~= '' then return label end
    if display and display ~= 'CARNOTFOUND' and display ~= 'NULL' and display ~= '' then return display end
    return locale('notify.unknown_vehicle')
end

---A notification in the Vehicle Hacker's style.
---@param description string
---@param kind 'success'|'error'|'inform'
---@param icon string Font Awesome class string
function VH.notify(description, kind, icon)
    lib.notify({ title = Config.Name, description = description, type = kind, icon = icon })
end
