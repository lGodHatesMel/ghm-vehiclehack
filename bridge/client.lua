-- Client-side half of the bridge: subscribes `cb` to whichever framework's player-loaded /
-- player-unload events are actually firing. Used exclusively by client.lua to (re)sync tags
-- on character load and clear local state on unload/logout.

local Framework = Bridge.Framework

---@param cb function
function Bridge.OnPlayerLoaded(cb)
    if Framework == 'qbx' then
        RegisterNetEvent('qbx_core:client:playerLoaded', cb)
    elseif Framework == 'qbcore' then
        RegisterNetEvent('QBCore:Client:OnPlayerLoaded', cb)
    elseif Framework == 'esx' then
        RegisterNetEvent('esx:playerLoaded', cb)
    end
end

---@param cb function
function Bridge.OnPlayerUnload(cb)
    if Framework == 'qbx' then
        RegisterNetEvent('qbx_core:client:onPlayerUnload', cb)
    elseif Framework == 'qbcore' then
        RegisterNetEvent('QBCore:Client:OnPlayerUnload', cb)
    elseif Framework == 'esx' then
        RegisterNetEvent('esx:onPlayerLogout', cb)
    end
end
