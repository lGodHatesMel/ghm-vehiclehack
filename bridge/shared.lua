-- Minimal framework bridge: just what this resource actually touches (money, the character
-- identifier, player-loaded/unload events). Deliberately narrow rather than a general player-object
-- abstraction - see bridge/server.lua and bridge/client.lua for what it normalizes.

Bridge = {}

---Detects which supported core is actually running, by checking whichever's resource state.
---Order matters: qbx_core and qb-core can both be present during a migration, so qbx_core wins.
---@return string|nil
local function detectFramework()
    if GetResourceState('qbx_core') == 'started' then return 'qbx' end
    if GetResourceState('qb-core') == 'started' then return 'qbcore' end
    if GetResourceState('es_extended') == 'started' then return 'esx' end
    return nil
end

---Config.Framework: 'auto' | 'qbx' | 'qbcore' | 'esx'. Resolved once, shared by client and
---server so both agree without a round trip.
Bridge.Framework = (Config.Framework ~= 'auto' and Config.Framework) or detectFramework()

if not Bridge.Framework then
    print('^1[ghm-vehiclehack] Could not detect a supported framework (qbx_core / qb-core / es_extended running). Money charges will fail closed and targets will not follow a character - set Config.Framework explicitly if detection is wrong.^0')
end
