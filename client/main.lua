-- Client side of the Vehicle Hacker: registers the app with sd-phone (or opens the standalone screen),
-- answers the app's NUI callbacks, picks targets and plays the tag animation. What actually happens to
-- a vehicle is decided on the server and carried out by client/effects.lua.

---@type string
local RESOURCE <const> = GetCurrentResourceName()

---@type table<integer, true> Network ids of the vehicles this player has tagged, pushed by the server.
local tagged = {}
---@type integer|nil Network id of the vehicle last aimed at.
local aimedNetId = nil
---@type table|nil Result of the last aim, held until the app takes it.
local pendingPick = nil
---@type boolean True while a crosshair or the phone camera is picking a vehicle.
local aiming = false
---@type boolean True while the standalone screen is up.
local standaloneOpen = false

-- ---------------------------------------------------------------------------------------------
-- sd-phone registration
-- ---------------------------------------------------------------------------------------------

---Where sd-phone loads the app's page from.
---@return string|nil
local function resolveUi()
    local page <const> = GetResourceMetadata(RESOURCE, 'ui_page', 0)
    if not page or page == '' then return nil end
    if page:find('^https?://') then return page end
    return RESOURCE .. '/' .. page
end

---Registers the app with sd-phone. sd-phone keeps its app list in its own client memory, so this
---runs on our start and again every time sd-phone (re)starts.
local function registerCustomApp()
    if not Config.UseSdPhone or GetResourceState('sd-phone') ~= 'started' then return end

    local called <const>, ok <const>, err <const> = pcall(function()
        return exports['sd-phone']:addCustomApp({
            identifier  = Config.Identifier,
            name        = Config.Name,
            description = Config.Description,
            developer   = Config.Developer,
            icon        = ('https://cfx-nui-%s/ui/dist/icon.webp'):format(RESOURCE),
            ui          = resolveUi(),
            defaultApp  = Config.DefaultApp,
            -- An icon that only appears once the character has used the unlock item. The server checks
            -- the same unlock before every request, so this only decides whether the icon is drawn.
            requires    = (not Config.DefaultApp) and { item = Config.UnlockItem, consume = true } or nil,
        })
    end)

    if not called then
        print(('^1[%s]^0 could not register with sd-phone (is it up to date?): %s'):format(RESOURCE, tostring(ok)))
    elseif not ok then
        print(('^1[%s]^0 sd-phone refused the app: %s'):format(RESOURCE, tostring(err)))
    end
end

CreateThread(registerCustomApp)

AddEventHandler('onClientResourceStart', function(resource)
    if resource == 'sd-phone' then registerCustomApp() end
end)

-- ---------------------------------------------------------------------------------------------
-- The standalone screen
-- ---------------------------------------------------------------------------------------------

local function openStandalone()
    if Config.UseSdPhone or standaloneOpen then return end
    standaloneOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'standaloneOpen' })
end

local function closeStandalone()
    if not standaloneOpen then return end
    standaloneOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'standaloneClose' })
end

RegisterNetEvent('ghm-vehiclehack:client:openStandalone', openStandalone)

RegisterNUICallback('closeUI', function(_, cb)
    closeStandalone()
    cb({ closed = true })
end)

-- ---------------------------------------------------------------------------------------------
-- NUI: configuration and the calls that go straight to the server
-- ---------------------------------------------------------------------------------------------

---The strings the app shows, from the locale file (everything under `ui`).
---@return table<string, string>
local function uiStrings()
    local out = {}
    for key, value in pairs(lib.getLocales()) do
        if key:find('^ui%.') then out[key:sub(4)] = value end
    end
    return out
end

RegisterNUICallback('getConfig', function(_, cb)
    cb({ success = true, data = { standalone = not Config.UseSdPhone, strings = uiStrings() } })
end)

---@param name string NUI callback name
---@param serverEvent string server callback it forwards to
---@param after? fun(res: table) runs on the answer before the app sees it
local function relay(name, serverEvent, after)
    RegisterNUICallback(name, function(payload, cb)
        local res <const> = lib.callback.await(serverEvent, false, payload)
        if type(res) ~= 'table' then
            cb({ success = false, code = 'no_response', message = locale('errors.no_response') })
            return
        end
        if after and res.success then after(res) end
        cb(res)
    end)
end

---@param list any
local function setTags(list)
    tagged = {}
    if type(list) ~= 'table' then return end
    for _, netId in ipairs(list) do
        if type(netId) == 'number' then tagged[netId] = true end
    end
end

-- The server pushes the list whenever a tag lands or is removed.
RegisterNetEvent('ghm-vehiclehack:client:tags', setTags)

-- The overview doubles as the sync: whatever the server says is tagged is what the scan lists.
relay('overview', 'ghm-vehiclehack:server:overview', function(res)
    if type(res.data) == 'table' then setTags(res.data.tags) end
end)
relay('execute', 'ghm-vehiclehack:server:execute')
relay('untag', 'ghm-vehiclehack:server:untag')

---What the app shows for one vehicle.
---@param netId integer
---@param via 'tag'|'aim'
---@return table|nil
local function describe(netId, via)
    local veh <const> = VH.vehicleFromNetId(netId)
    if not veh then return nil end

    local distance <const> = #(GetEntityCoords(cache.ped) - GetEntityCoords(veh))
    local occupants = 0
    for seat = -1, GetVehicleModelNumberOfSeats(GetEntityModel(veh)) - 2 do
        if GetPedInVehicleSeat(veh, seat) ~= 0 then occupants += 1 end
    end

    return {
        netId     = netId,
        via       = via,
        model     = VH.displayName(veh),
        plate     = (GetVehicleNumberPlateText(veh) or ''):gsub('^%s+', ''):gsub('%s+$', ''),
        distance  = distance,
        inRange   = distance <= Config.ScanRadius,
        occupants = occupants,
        driver    = GetPedInVehicleSeat(veh, -1) ~= 0,
        locked    = GetVehicleDoorLockStatus(veh) >= 2,
    }
end

---The vehicles within reach: every tagged one that exists on this client, plus the aimed one.
RegisterNUICallback('scan', function(_, cb)
    local vehicles = {}
    for netId in pairs(tagged) do
        local row <const> = describe(netId, 'tag')
        if row then vehicles[#vehicles + 1] = row end
    end
    table.sort(vehicles, function(a, b) return a.distance < b.distance end)

    cb({ success = true, data = { vehicles = vehicles, aimed = aimedNetId and describe(aimedNetId, 'aim') or nil } })
end)

---Hands over the result of the last aim, once. The app asks for it whenever it comes to the front.
RegisterNUICallback('takePick', function(_, cb)
    local pick <const> = pendingPick
    pendingPick = nil
    cb({ success = true, data = pick })
end)

-- ---------------------------------------------------------------------------------------------
-- Aiming
-- ---------------------------------------------------------------------------------------------

---@param rotation vector3 camera rotation in degrees
---@return vector3 unit direction
local function rotationToDirection(rotation)
    local rad <const> = vector3(rotation.x, rotation.y, rotation.z) * (math.pi / 180.0)
    return vector3(
        -math.sin(rad.z) * math.abs(math.cos(rad.x)),
        math.cos(rad.z) * math.abs(math.cos(rad.x)),
        math.sin(rad.x)
    )
end

---The vehicle under the middle of the screen (the rendered camera, so the phone's lens counts), if any.
---@return integer|nil
local function vehicleUnderCrosshair()
    local from <const> = GetFinalRenderedCamCoord()
    local to <const> = from + rotationToDirection(GetFinalRenderedCamRot(2)) * Config.Aim.MaxDistance
    -- Flag 2 is vehicles only, so a pedestrian in front of the vehicle does not block the pick.
    local handle <const> = StartExpensiveSynchronousShapeTestLosProbe(from.x, from.y, from.z, to.x, to.y, to.z, 2, cache.ped, 0)
    local _, hit, _, _, entity = GetShapeTestResult(handle)
    if (hit == true or hit == 1) and entity ~= 0 and GetEntityType(entity) == 2 then return entity end
    return nil
end

---@param entity integer|nil
local function setOutline(entity, on)
    if not entity or not DoesEntityExist(entity) then return end
    if on then
        local c <const> = Config.Aim.Outline
        SetEntityDrawOutlineColor(c.r, c.g, c.b, c.a)
    end
    SetEntityDrawOutline(entity, on)
end

---Tells the server which vehicle was aimed at.
---@param veh integer
---@return table result { ok, netId? , message? }
local function lockOn(veh)
    if not NetworkGetEntityIsNetworked(veh) then return { ok = false, message = locale('errors.not_networked') } end

    local netId <const> = NetworkGetNetworkIdFromEntity(veh)
    local res <const> = lib.callback.await('ghm-vehiclehack:server:aim', false, { netId = netId })
    if res and res.success then
        aimedNetId = netId
        return { ok = true, netId = netId }
    end
    return { ok = false, message = res and res.message or locale('errors.no_response') }
end

---Hands a pick to the app: pushed straight into it when it is on screen, and kept for it to collect
---when it was not (the screen was put away while aiming).
---@param pick table
local function deliverPick(pick)
    pendingPick = pick
    if not Config.UseSdPhone then return end
    pcall(function()
        exports['sd-phone']:sendCustomAppMessage(Config.Identifier, { action = 'picked', data = pick })
    end)
end

---Aim through the phone's own camera: the phone stays open and unlocked, the viewfinder is the
---crosshair and the shutter picks the vehicle in the middle of it. Needs an sd-phone that has
---useCamera; returns false when it does not (or the camera is busy) so the caller can fall back.
---@return boolean started
local function aimWithPhoneCamera()
    local live = false
    local hint = locale('ui.camera_hint')
    if #hint > 24 then hint = nil end

    local called <const>, ok <const> = pcall(function()
        return exports['sd-phone']:useCamera(Config.Identifier, {
            hint = hint,
            overlay = ('%s/ui/dist/overlay.html'):format(RESOURCE),
            onOpen = function()
                live = true
                CreateThread(function()
                    local lit
                    while live do
                        local veh <const> = vehicleUnderCrosshair()
                        if veh ~= lit then
                            setOutline(lit, false)
                            lit = veh
                            setOutline(lit, true)
                            pcall(function()
                                exports['sd-phone']:sendCameraMessage({ locked = lit ~= nil, label = lit and VH.displayName(lit) or nil })
                            end)
                        end
                        Wait(0)
                    end
                    setOutline(lit, false)
                end)
            end,
            onShutter = function()
                local veh <const> = vehicleUnderCrosshair()
                if not veh then
                    pcall(function() exports['sd-phone']:sendCameraMessage({ miss = true }) end)
                    return
                end
                local pick <const> = lockOn(veh)
                live = false
                pcall(function() exports['sd-phone']:closeCamera() end)
                deliverPick(pick)
            end,
            onClose = function()
                live = false
                aiming = false
            end,
        })
    end)

    return called and ok == true
end

---Aim with a crosshair: the screen is put away, the player clicks a vehicle and the screen comes back.
---In sd-phone this means the phone re-locks when it returns, which is why the phone camera is the
---default there.
local function aimWithCrosshair()
    if Config.UseSdPhone then
        pcall(function() exports['sd-phone']:close() end)
    else
        closeStandalone()
    end
    Wait(200)

    local deadline <const> = GetGameTimer() + Config.Aim.Timeout
    local lit, picked = nil, nil

    while GetGameTimer() < deadline do
        local veh <const> = vehicleUnderCrosshair()
        if veh ~= lit then
            setOutline(lit, false)
            lit = veh
            setOutline(lit, true)
        end

        BeginTextCommandDisplayText('STRING')
        AddTextComponentSubstringPlayerName(lit and locale('ui.crosshair_locked') or locale('ui.crosshair_looking'))
        SetTextFont(4)
        SetTextScale(0.34, 0.34)
        SetTextColour(255, 255, 255, 230)
        SetTextRightJustify(true)
        SetTextWrap(0.4, 0.97)
        EndTextCommandDisplayText(0.97, 0.05)
        DrawRect(0.5, 0.5, 0.006, 0.006 * (16 / 9), 255, 255, 255, lit and 255 or 160)

        DisableControlAction(0, 24, true)  -- INPUT_ATTACK
        DisableControlAction(0, 25, true)  -- INPUT_AIM
        DisableControlAction(0, 140, true) -- melee, which also sits on the mouse buttons
        DisableControlAction(0, 141, true)
        DisableControlAction(0, 142, true)
        DisableControlAction(0, 200, true) -- keep the pause menu shut
        DisableControlAction(0, 177, true) -- INPUT_FRONTEND_CANCEL

        if IsDisabledControlJustPressed(0, 24) then
            picked = lit
            break
        end
        if IsDisabledControlJustPressed(0, 177) or IsDisabledControlJustPressed(0, 200) then break end

        Wait(0)
    end

    setOutline(lit, false)

    local pick = { ok = false }
    if picked then pick = lockOn(picked) end
    pendingPick = pick

    if Config.UseSdPhone then
        pcall(function() exports['sd-phone']:openApp(Config.Identifier) end)
    else
        openStandalone()
    end
end

local function aim()
    aiming = true
    if Config.UseSdPhone and aimWithPhoneCamera() then return end
    aimWithCrosshair()
    aiming = false
end

RegisterNUICallback('aim', function(_, cb)
    if aiming then
        cb({ success = false, code = 'busy', message = locale('errors.busy') })
        return
    end
    if not Config.Targeting.Aim then
        cb({ success = false, code = 'aim_off', message = locale('errors.aim_off') })
        return
    end
    cb({ success = true })
    CreateThread(aim)
end)

-- ---------------------------------------------------------------------------------------------
-- Tagging
-- ---------------------------------------------------------------------------------------------

---The closest networked vehicle within the tag range.
---@return integer|nil
local function closestTaggable()
    local coords <const> = GetEntityCoords(cache.ped)
    local best, bestDistance = nil, Config.Tag.Range
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        local distance <const> = #(coords - GetEntityCoords(veh))
        if distance < bestDistance and NetworkGetEntityIsNetworked(veh) then
            best, bestDistance = veh, distance
        end
    end
    return best
end

---Server push: the player used the tag item.
RegisterNetEvent('ghm-vehiclehack:client:useTag', function()
    local veh = closestTaggable()
    if not veh then
        VH.notify(locale('notify.no_vehicle_near', Config.Tag.Range), 'error', 'fa-solid fa-car-side')
        return
    end

    local began <const> = lib.callback.await('ghm-vehiclehack:server:tagBegin', false)
    if not began or not began.success then
        VH.notify(began and began.message or locale('errors.no_response'), 'error', 'fa-solid fa-triangle-exclamation')
        return
    end

    TaskTurnPedToFaceEntity(cache.ped, veh, 1000)
    Wait(400)

    local finished <const> = lib.progressBar({
        duration = Config.Tag.Duration,
        label = locale('notify.tagging'),
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', clip = 'machinic_loop_mechandplayer', flag = 49 },
        prop = { model = `prop_cs_swipe_card`, bone = 57005, pos = vec3(0.12, 0.028, -0.01), rot = vec3(-45.0, 0.0, 0.0) },
    })
    if not finished then return end

    -- The player may have walked, or the vehicle driven off, while the bar ran.
    veh = closestTaggable()
    if not veh then
        VH.notify(locale('notify.no_vehicle_near', Config.Tag.Range), 'error', 'fa-solid fa-car-side')
        return
    end

    local res <const> = lib.callback.await('ghm-vehiclehack:server:tagCommit', false, { netId = NetworkGetNetworkIdFromEntity(veh) })
    if res and res.success then
        VH.notify(locale('notify.tagged'), 'success', 'fa-solid fa-satellite-dish')
    else
        VH.notify(res and res.message or locale('errors.no_response'), 'error', 'fa-solid fa-triangle-exclamation')
    end
end)

-- ---------------------------------------------------------------------------------------------
-- Character switch and cleanup
-- ---------------------------------------------------------------------------------------------

Bridge.OnPlayerUnload(function()
    tagged, aimedNetId, pendingPick = {}, nil, nil
    closeStandalone()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= RESOURCE then return end
    if standaloneOpen then SetNuiFocus(false, false) end
    aiming = false
end)
