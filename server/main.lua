-- Server side of the Vehicle Hacker. This is the authority: it decides who may use the app, which
-- vehicles a player may target, how often, what it costs and what happens to the vehicle. The app and
-- the client only ever send an intent ("run this action on that vehicle"); no price, no result and no
-- player id comes from them, and the effect is pushed to whoever owns the vehicle, not run by the
-- player who asked for it.

---@type string This resource, for the sd-phone unlock ledger lookups and the log prefix.
local RESOURCE <const> = GetCurrentResourceName()

---@param message string
---@param ... any
local function debugLog(message, ...)
    if Config.Debug then print(('^3[%s]^0 %s'):format(RESOURCE, message:format(...))) end
end

---@class VehicleHackFail
---@field success false
---@field message string
---@field code string

---A refusal. `code` is a key under `errors` in the locale file; the message is that text in the
---server's language.
---@param code string
---@return VehicleHackFail
local function fail(code)
    debugLog('refused: %s', code)
    return { success = false, code = code, message = locale('errors.' .. code) }
end

-- ---------------------------------------------------------------------------------------------
-- Who may use the app
-- ---------------------------------------------------------------------------------------------

---Whether the player holds at least one of an item, through whichever inventory bridge/inventory.lua found.
---@param src integer
---@param item string
---@return boolean
local function hasItem(src, item)
    return Bridge.Inventory.Has(src, item, 1)
end

---Whether the player has the app: in sd-phone, that character has installed it (or it ships on every
---phone); standalone, they are carrying the device.
---@param src integer
---@return boolean
local function allowed(src)
    if Config.UseSdPhone then
        if Config.DefaultApp then return GetResourceState('sd-phone') == 'started' end
        local ok, unlocked = pcall(function() return exports['sd-phone']:hasAppUnlock(src, Config.Identifier) end)
        return ok and unlocked == true
    end
    return hasItem(src, Config.StandaloneItem)
end

-- ---------------------------------------------------------------------------------------------
-- The action catalogue, built once from the config
-- ---------------------------------------------------------------------------------------------

---@type { type: string, label: string, symbol: string, symbolFirst: boolean, decimals: integer } How the currency is shown.
local CURRENCY <const> = Bridge.CurrencyInfo()

---@param value number
---@return number
local function roundToPlaces(value)
    local scale <const> = 10 ^ CURRENCY.decimals
    return math.floor(value * scale + 0.5) / scale
end

---@type table<string, table> Action id -> its config row, with the category folded in.
local ACTIONS = {}
---@type table[] The categories as the app lists them, each holding its actions in order.
local CATEGORIES = {}

for _, category in ipairs(Config.Categories or {}) do
    local listed = { id = category.id, label = category.label, description = category.description, actions = {} }
    for _, id in ipairs(category.actions or {}) do
        local row = Config.Actions[id]
        if row and row.enabled ~= false then
            local action = {
                id          = id,
                category    = category.id,
                label       = row.label,
                description = row.description,
                duration    = tonumber(row.duration) or 0,
                risk        = row.risk == 'low' and 'low' or (row.risk == 'medium' and 'medium' or 'high'),
                cost        = roundToPlaces(math.max(0, tonumber(row.cost) or 0)),
            }
            ACTIONS[id] = action
            listed.actions[#listed.actions + 1] = action
        end
    end
    if #listed.actions > 0 then CATEGORIES[#CATEGORIES + 1] = listed end
end

---@type table<integer, true> Model hashes nobody can hack.
local PROTECTED = {}
for _, name in ipairs(Config.ProtectedModels or {}) do
    if type(name) == 'string' then PROTECTED[joaat(name)] = true end
end

-- ---------------------------------------------------------------------------------------------
-- State
-- ---------------------------------------------------------------------------------------------

---@class VehicleHackTarget
---@field via 'tag'|'aim'
---@field at integer GetGameTimer() when it was added
---@field cid string the character it belongs to

---@type table<integer, table<integer, VehicleHackTarget>> source -> netId -> target
local targets = {}
---@type table<integer, integer> source -> GetGameTimer() of the last action that got past the checks
local lastRun = {}
---@type table<integer, { at: integer }> source -> a tag in progress, started by tagBegin
local pendingTag = {}

---@class VehicleHackBomb
---@field owner integer source that armed it
---@field armedAt integer
---@field untilAt integer

---@type table<integer, VehicleHackBomb> netId -> armed speed bomb
local bombs = {}
---@type boolean True while the bomb watcher thread is alive.
local watching = false

---@param netId any
---@return boolean
local function validNetId(netId)
    return type(netId) == 'number' and netId > 0 and netId == math.floor(netId)
end

---Turns a client-claimed network id into a live vehicle entity, or nil.
---@param netId integer
---@return integer|nil
local function resolveVehicle(netId)
    if not NetworkDoesEntityExistWithNetworkId(netId) then return nil end
    local veh <const> = NetworkGetEntityFromNetworkId(netId)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return nil end
    if GetEntityType(veh) ~= 2 then return nil end
    return veh
end

---@param src integer
---@param entity integer
---@return number|nil metres from the player's ped to the entity
local function distanceTo(src, entity)
    local ped <const> = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return #(GetEntityCoords(ped) - GetEntityCoords(entity))
end

---The player's targets with the stale ones dropped: another character, an expired aim, or a vehicle
---that is gone.
---@param src integer
---@return table<integer, VehicleHackTarget>
local function liveTargets(src)
    local set <const> = targets[src]
    if not set then return {} end

    local cid <const> = Bridge.GetIdentifier(src)
    local now <const> = GetGameTimer()
    for netId, entry in pairs(set) do
        local stale = entry.cid ~= cid
            or (entry.via == 'aim' and now - entry.at > Config.Aim.Window)
            or not resolveVehicle(netId)
        if stale then set[netId] = nil end
    end
    return set
end

---@param src integer
---@return integer[] tagged vehicles' network ids
local function taggedIds(src)
    local out = {}
    for netId, entry in pairs(liveTargets(src)) do
        if entry.via == 'tag' then out[#out + 1] = netId end
    end
    table.sort(out)
    return out
end

---Tells the player's client which vehicles are tagged, so its scan list needs no server round trip.
---@param src integer
local function pushTags(src)
    TriggerClientEvent('ghm-vehiclehack:client:tags', src, taggedIds(src))
end

---Records a target for a player.
---@param src integer
---@param netId integer
---@param via 'tag'|'aim'
local function addTarget(src, netId, via)
    local cid <const> = Bridge.GetIdentifier(src)
    if not cid then return end

    targets[src] = targets[src] or {}
    -- A tag is kept over an aim of the same vehicle; the reverse would let a click downgrade it.
    local existing <const> = targets[src][netId]
    if existing and existing.via == 'tag' and via == 'aim' then return end
    targets[src][netId] = { via = via, at = GetGameTimer(), cid = cid }
end

---The vehicle a player may hack right now: it is one of theirs, still there, not protected, in reach
---and not the one they are sitting in.
---@param src integer
---@param netId any
---@return integer|nil veh
---@return string|nil code
local function checkTarget(src, netId)
    if not validNetId(netId) then return nil, 'no_vehicle' end

    local entry <const> = liveTargets(src)[netId]
    if not entry then return nil, 'not_linked' end

    local veh <const> = resolveVehicle(netId)
    if not veh then return nil, 'gone' end
    if PROTECTED[GetEntityModel(veh)] then return nil, 'protected' end

    local dist <const> = distanceTo(src, veh)
    if not dist or dist > Config.ScanRadius + 5.0 then return nil, 'out_of_range' end

    if GetVehiclePedIsIn(GetPlayerPed(src), false) == veh then return nil, 'own_vehicle' end

    return veh
end

---The player's balance of the currency, read whether or not free mode is on.
---@param src integer
---@return number|false balance false when the framework does not track the currency for this player
local function balanceOf(src)
    local tracked <const>, has <const> = pcall(Bridge.HasMoneyType, src, CURRENCY.type)
    if not tracked or not has then return false end
    local ok <const>, balance <const> = pcall(Bridge.GetMoney, src, CURRENCY.type)
    if not ok or type(balance) ~= 'number' then return false end
    return balance
end

-- ---------------------------------------------------------------------------------------------
-- Effects. The owner of the vehicle runs the natives (only the owner's client can change it);
-- the people sitting in it get their input taken away on their own clients.
-- ---------------------------------------------------------------------------------------------

---@class VehicleHackOccupantEffect
---@field driverOnly boolean
---@field controls? integer[] control ids to disable on the occupant's own client
---@field steer? number 1 left, -1 right (SetVehicleSteerBias): forces the wheel on the driver's client
---@field eject? boolean throws the occupant out of the seat

---@type table<string, VehicleHackOccupantEffect> Actions that also reach the people inside. A
---player's input and seat can only be changed on that player's own client, so these go to them.
local OCCUPANT_EFFECTS <const> = {
    disable_brakes  = { driverOnly = true,  controls = { 72, 76 } },         -- INPUT_VEH_BRAKE, INPUT_VEH_HANDBRAKE
    lock_steering   = { driverOnly = true,  controls = { 59, 60, 63, 64 } }, -- INPUT_VEH_MOVE_LR / LEFT_ONLY / RIGHT_ONLY
    lock_doors      = { driverOnly = false, controls = { 75 } },             -- INPUT_VEH_EXIT
    steer_left      = { driverOnly = true,  steer = 1.0 },
    steer_right     = { driverOnly = true,  steer = -1.0 },
    eject_occupants = { driverOnly = false, eject = true },
}

---Everyone who is a player and sits in the vehicle (or just the driver).
---@param veh integer
---@param driverOnly boolean
---@return integer[] sources
local function occupantPlayers(veh, driverOnly)
    local out, seen = {}, {}
    -- No server native counts the seats; the biggest vehicle has fewer than sixteen, and an empty or
    -- missing seat answers 0.
    for seat = -1, (driverOnly and -1 or 15) do
        local ped <const> = GetPedInVehicleSeat(veh, seat)
        if ped ~= 0 and DoesEntityExist(ped) and IsPedAPlayer(ped) then
            local owner <const> = NetworkGetEntityOwner(ped)
            if owner and owner > 0 and not seen[owner] then
                seen[owner] = true
                out[#out + 1] = owner
            end
        end
    end
    return out
end

---Speed in the configured unit.
---@param veh integer
---@return number
local function speedOf(veh)
    local ms <const> = #GetEntityVelocity(veh)
    return Config.SpeedUnit == 'kmh' and ms * 3.6 or ms * 2.236936
end

---Watches the armed bombs until none are left. One thread for all of them, polling the vehicle's
---velocity on the server so a change of owner never loses a bomb.
local function startWatcher()
    if watching then return end
    watching = true

    CreateThread(function()
        while next(bombs) do
            local now <const> = GetGameTimer()
            for netId, bomb in pairs(bombs) do
                local veh <const> = resolveVehicle(netId)
                if not veh or now >= bomb.untilAt then
                    bombs[netId] = nil
                elseif now - bomb.armedAt >= Config.SpeedBomb.ArmDelay and speedOf(veh) < Config.SpeedBomb.Threshold then
                    bombs[netId] = nil
                    local owner <const> = NetworkGetEntityOwner(veh)
                    if owner and owner > 0 then
                        TriggerClientEvent('ghm-vehiclehack:client:explode', owner, netId)
                    end
                end
            end
            Wait(250)
        end
        watching = false
    end)
end

---Arms a speed bomb on a vehicle. A second arm on the same vehicle just keeps the first.
---@param src integer
---@param netId integer
local function armBomb(src, netId)
    if bombs[netId] then return end
    local now <const> = GetGameTimer()
    bombs[netId] = { owner = src, armedAt = now, untilAt = now + Config.SpeedBomb.ArmDelay + Config.SpeedBomb.MaxArmedDuration }
    startWatcher()
end

---Sends an action to the vehicle's owner and to the people inside it.
---@param src integer who ran it
---@param veh integer
---@param netId integer
---@param action table
---@return boolean ok false when nobody can apply it
local function dispatch(src, veh, netId, action)
    if action.id == 'speed_bomb' then
        armBomb(src, netId)
        return true
    end

    local owner <const> = NetworkGetEntityOwner(veh)
    if not owner or owner <= 0 then return false end

    TriggerClientEvent('ghm-vehiclehack:client:apply', owner, netId, action.id, action.duration)

    local occupant <const> = OCCUPANT_EFFECTS[action.id]
    if occupant then
        local ms <const> = math.floor(action.duration * 1000)
        for _, target in ipairs(occupantPlayers(veh, occupant.driverOnly)) do
            TriggerClientEvent('ghm-vehiclehack:client:occupant', target, netId,
                { controls = occupant.controls, steer = occupant.steer, eject = occupant.eject }, ms)
        end
    end
    return true
end

-- ---------------------------------------------------------------------------------------------
-- Callbacks
-- ---------------------------------------------------------------------------------------------

---Everything the app draws: which targeting modes exist, the action catalogue, the player's links
---and what the actions cost. Built here so the app never carries its own copy of the config.
lib.callback.register('ghm-vehiclehack:server:overview', function(src)
    if not allowed(src) then return fail('denied') end

    local balance <const> = balanceOf(src)
    return {
        success = true,
        data = {
            targeting  = { tagged = Config.Targeting.Tagged == true, aim = Config.Targeting.Aim == true },
            tag        = { item = Config.TagItem, range = Config.Tag.Range },
            scanRadius = Config.ScanRadius,
            aimRange   = Config.Aim.MaxDistance,
            cooldownMs = Config.Cooldown,
            freeMode   = Config.FreeMode == true,
            currency   = { id = CURRENCY.type, label = CURRENCY.label, symbol = CURRENCY.symbol, symbolFirst = CURRENCY.symbolFirst, decimals = CURRENCY.decimals },
            balance    = balance or 0,
            walletOk   = balance ~= false,
            speedUnit  = Config.SpeedUnit == 'kmh' and 'kmh' or 'mph',
            speedBomb  = { threshold = Config.SpeedBomb.Threshold, armDelayMs = Config.SpeedBomb.ArmDelay, maxArmedMs = Config.SpeedBomb.MaxArmedDuration },
            categories = CATEGORIES,
            tags       = taggedIds(src),
        },
    }
end)

---Locks in a vehicle the player aimed at.
lib.callback.register('ghm-vehiclehack:server:aim', function(src, payload)
    if not allowed(src) then return fail('denied') end
    if not Config.Targeting.Aim then return fail('aim_off') end
    if type(payload) ~= 'table' or not validNetId(payload.netId) then return fail('invalid') end

    local veh <const> = resolveVehicle(payload.netId)
    if not veh then return fail('gone') end
    if PROTECTED[GetEntityModel(veh)] then return fail('protected') end

    local dist <const> = distanceTo(src, veh)
    -- A little over the crosshair's reach: the vehicle keeps rolling between the click and this check.
    if not dist or dist > Config.Aim.MaxDistance + 15.0 then return fail('out_of_range') end

    addTarget(src, payload.netId, 'aim')
    return { success = true }
end)

---Drops one tag, or all of them.
lib.callback.register('ghm-vehiclehack:server:untag', function(src, payload)
    if not allowed(src) then return fail('denied') end
    if type(payload) ~= 'table' then return fail('invalid') end

    local set <const> = targets[src]
    if payload.all == true then
        targets[src] = nil
    elseif validNetId(payload.netId) and set then
        set[payload.netId] = nil
    else
        return fail('invalid')
    end

    pushTags(src)
    return { success = true }
end)

---Runs an action on a linked vehicle.
lib.callback.register('ghm-vehiclehack:server:execute', function(src, payload)
    if not allowed(src) then return fail('denied') end
    if type(payload) ~= 'table' or type(payload.action) ~= 'string' then return fail('invalid') end

    local action <const> = ACTIONS[payload.action]
    if not action then return fail('unknown_action') end

    local now <const> = GetGameTimer()
    local last <const> = lastRun[src]
    if last and now - last < Config.Cooldown then return fail('cooldown') end

    local veh <const>, code <const> = checkTarget(src, payload.netId)
    if not veh then return fail(code or 'no_vehicle') end

    -- Stamped before anything that can yield, so two calls in the same frame cannot both pass.
    lastRun[src] = now

    local cost = 0
    if not Config.FreeMode and action.cost > 0 then
        local balance <const> = balanceOf(src)
        if balance == false then
            lastRun[src] = nil
            return fail('money_unavailable')
        end
        if balance < action.cost then
            lastRun[src] = nil
            return fail('insufficient_funds')
        end
        if not Bridge.RemoveMoney(src, CURRENCY.type, action.cost, ('Vehicle Hacker: %s'):format(action.label)) then
            lastRun[src] = nil
            return fail('money_unavailable')
        end
        cost = action.cost
    end

    if not dispatch(src, veh, payload.netId, action) then
        -- Nothing could carry it out, so nothing is kept.
        if cost > 0 then Bridge.AddMoney(src, CURRENCY.type, cost, 'Vehicle Hacker: refund') end
        lastRun[src] = nil
        return fail('no_response')
    end

    local duration = action.duration
    if action.id == 'speed_bomb' then duration = (Config.SpeedBomb.ArmDelay + Config.SpeedBomb.MaxArmedDuration) / 1000 end

    return {
        success = true,
        data = { id = action.id, label = action.label, duration = duration, cost = cost, balance = balanceOf(src) or 0 },
    }
end)

---Starts a tag. The server keeps the clock: a tag only lands if the animation had time to finish.
lib.callback.register('ghm-vehiclehack:server:tagBegin', function(src)
    if not allowed(src) then return fail('denied') end
    if not Config.Targeting.Tagged then return fail('tag_off') end
    if not hasItem(src, Config.TagItem) then return fail('no_tag_item') end

    if #taggedIds(src) >= Config.Tag.Max then return fail('tag_limit') end

    pendingTag[src] = { at = GetGameTimer() }
    return { success = true }
end)

---Finishes a tag: the time has passed, the player is next to the vehicle and still has the item.
lib.callback.register('ghm-vehiclehack:server:tagCommit', function(src, payload)
    local pending <const> = pendingTag[src]
    pendingTag[src] = nil

    if not allowed(src) then return fail('denied') end
    if not pending or type(payload) ~= 'table' or not validNetId(payload.netId) then return fail('invalid') end

    local elapsed <const> = GetGameTimer() - pending.at
    if elapsed < Config.Tag.Duration - 400 then return fail('tag_failed') end
    if elapsed > Config.Tag.Duration + 30000 then return fail('tag_timeout') end

    local veh <const> = resolveVehicle(payload.netId)
    if not veh then return fail('gone') end
    if PROTECTED[GetEntityModel(veh)] then return fail('protected') end

    local dist <const> = distanceTo(src, veh)
    if not dist or dist > Config.Tag.Range + 2.0 then return fail('too_far') end

    if Config.Tag.Consume then
        if not Bridge.Inventory.Remove(src, Config.TagItem, 1) then return fail('no_tag_item') end
    end

    addTarget(src, payload.netId, 'tag')
    pushTags(src)
    return { success = true }
end)

-- ---------------------------------------------------------------------------------------------
-- Items. Each is a usable item whose handler is a local function below. ox_inventory calls them
-- through the server exports at the end of this block (named in the item's definition, see the README);
-- every other inventory calls them through the usable-item registration. Either way the inventory must
-- not consume the item itself: this resource spends it, once, only when the thing the item is for has
-- actually happened.
-- ---------------------------------------------------------------------------------------------

---Unlock item (sd-phone mode): installs the app for this character, then spends the item.
---@param src integer
local function useUnlock(src)
    if not Config.UseSdPhone then return end

    local ok <const>, already <const> = pcall(function() return exports['sd-phone']:hasAppUnlock(src, Config.Identifier) end)
    if not ok then
        TriggerClientEvent('ox_lib:notify', src, { title = Config.Name, description = locale('notify.phone_missing'), type = 'error', icon = 'fa-solid fa-mobile-screen' })
        return
    end
    if already then
        TriggerClientEvent('ox_lib:notify', src, { title = Config.Name, description = locale('notify.already_installed'), type = 'inform', icon = 'fa-solid fa-mobile-screen' })
        return
    end

    local pok <const>, granted <const> = pcall(function() return exports['sd-phone']:unlockApp(src, Config.Identifier) end)
    if not pok or not granted then
        print(('^1[%s]^0 sd-phone:unlockApp failed; is sd-phone started?'):format(RESOURCE))
        return
    end

    Bridge.Inventory.Remove(src, Config.UnlockItem, 1)
    TriggerClientEvent('ox_lib:notify', src, { title = Config.Name, description = locale('notify.installed'), type = 'success', icon = 'fa-solid fa-mobile-screen' })
end

---Vehicle tag item: the player must have the app, then their client plays the animation.
---@param src integer
local function useTag(src)
    if not Config.Targeting.Tagged or not allowed(src) then return end
    TriggerClientEvent('ghm-vehiclehack:client:useTag', src)
end

---Standalone device (Config.UseSdPhone = false): opens the screen on the player's client.
---@param src integer
local function useStandalone(src)
    if Config.UseSdPhone then return end
    TriggerClientEvent('ghm-vehiclehack:client:openStandalone', src)
end

---The player an ox_inventory item event is for, from the inventory the event carries.
---@param inv any
---@return integer|nil
local function sourceOf(inv)
    return type(inv) == 'table' and type(inv.id) == 'number' and inv.id or nil
end

---Wraps a handler as the export ox_inventory expects: (event, item, inventory).
---@param handler fun(src: integer)
local function oxExport(handler)
    return function(event, _item, inv)
        if event ~= 'usingItem' then return end
        local src <const> = sourceOf(inv)
        if src then handler(src) end
    end
end

exports('useUnlockItem', oxExport(useUnlock))
exports('useTagItem', oxExport(useTag))
exports('useStandaloneItem', oxExport(useStandalone))

-- Every other inventory (and the framework's own) is told about the items here instead.
if not Bridge.Inventory.usesExports then
    local function guarded(handler)
        return function(src)
            if type(src) == 'number' then handler(src) end
        end
    end
    Bridge.Inventory.RegisterUsable(Config.UnlockItem, guarded(useUnlock))
    Bridge.Inventory.RegisterUsable(Config.TagItem, guarded(useTag))
    Bridge.Inventory.RegisterUsable(Config.StandaloneItem, guarded(useStandalone))
end

-- ---------------------------------------------------------------------------------------------
-- Public API and cleanup
-- ---------------------------------------------------------------------------------------------

---Whether a player has linked to a vehicle: exports['ghm-vehiclehack']:isTagged(source, netId)
exports('isTagged', function(source, netId)
    if not validNetId(netId) then return false end
    local entry <const> = liveTargets(source)[netId]
    return entry ~= nil and entry.via == 'tag'
end)

---Drops every link a player has: exports['ghm-vehiclehack']:clearTargets(source)
exports('clearTargets', function(source)
    targets[source] = nil
    pushTags(source)
end)

AddEventHandler('playerDropped', function()
    local src <const> = source
    -- A bomb is on the vehicle, not the player: it stays armed and runs out on its own.
    targets[src], lastRun[src], pendingTag[src] = nil, nil, nil
end)
