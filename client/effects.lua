-- Effects. Everything here is told to this client by the server: the owner of a vehicle is asked to
-- change it, and the players sitting in it are asked to lose their input or their seat. Nothing in this
-- file can be started by the player.


---Runs `step` every `interval` ms until `ms` has passed or the vehicle is gone.
---@param veh integer
---@param ms integer
---@param interval integer
---@param step fun(elapsed: integer)
local function every(veh, ms, interval, step)
    local started <const> = GetGameTimer()
    while DoesEntityExist(veh) do
        local elapsed <const> = GetGameTimer() - started
        if elapsed >= ms then break end
        step(elapsed)
        Wait(interval)
    end
end

---A ped that is a computer-controlled driver, or nil.
---@param veh integer
---@return integer|nil
local function npcDriver(veh)
    local ped <const> = GetPedInVehicleSeat(veh, -1)
    if ped ~= 0 and not IsPedAPlayer(ped) then return ped end
    return nil
end

---@type table<string, fun(veh: integer, ms: integer)> What each action does to the vehicle itself.
local EFFECTS <const> = {
    engine_kill = function(veh)
        SetVehicleEngineHealth(veh, -4000.0)
        SetVehicleEngineOn(veh, false, true, true)
    end,

    brake_lock = function(veh, ms)
        every(veh, ms, 0, function() SetVehicleHandbrake(veh, true) end)
        if DoesEntityExist(veh) then SetVehicleHandbrake(veh, false) end
    end,

    -- A player driver's pedals are taken on their own client (occupant event); there is nothing to
    -- do to the vehicle itself, and a computer-controlled driver never reads the pedals.
    disable_brakes = function() end,

    tire_burst = function(veh)
        for wheel = 0, 5 do SetVehicleTyreBurst(veh, wheel, true, 1000.0) end
    end,

    fuel_leak = function(veh, ms)
        local start <const> = Bridge.Fuel.Get(veh)
        every(veh, ms, 250, function(elapsed)
            Bridge.Fuel.Set(veh, math.max(0.0, start * (1.0 - elapsed / ms)))
        end)
        if DoesEntityExist(veh) then Bridge.Fuel.Set(veh, 0.0) end
    end,

    -- A player driver is steered on their own client; a computer-controlled one here.
    steer_left = function(veh, ms)
        local driver <const> = npcDriver(veh)
        if driver then every(veh, ms, 0, function() TaskVehicleTempAction(driver, veh, 7, math.ceil(ms / 1000)) end) end
    end,
    steer_right = function(veh, ms)
        local driver <const> = npcDriver(veh)
        if driver then every(veh, ms, 0, function() TaskVehicleTempAction(driver, veh, 8, math.ceil(ms / 1000)) end) end
    end,
    lock_steering = function() end,

    open_doors = function(veh)
        SetVehicleDoorsLocked(veh, 1)
        SetVehicleDoorsLockedForAllPlayers(veh, false)
        for door = 0, 5 do SetVehicleDoorOpen(veh, door, false, false) end
    end,

    eject_occupants = function(veh)
        -- Players are thrown out on their own client; this is everyone else.
        for seat = -1, GetVehicleModelNumberOfSeats(GetEntityModel(veh)) - 2 do
            local ped <const> = GetPedInVehicleSeat(veh, seat)
            if ped ~= 0 and not IsPedAPlayer(ped) then
                ClearPedTasksImmediately(ped)
                TaskLeaveVehicle(ped, veh, 4160) -- 4160: warp out, no exit animation
            end
        end
    end,

    -- Re-asserted every half second so a key script or the driver's own unlock key cannot undo it.
    lock_doors = function(veh, ms)
        every(veh, ms, 500, function() SetVehicleDoorsLocked(veh, 2) end)
        if DoesEntityExist(veh) then SetVehicleDoorsLocked(veh, 1) end
    end,

    random_spin = function(veh, ms)
        every(veh, ms, 50, function() SetEntityAngularVelocity(veh, 0.0, 0.0, 9.0) end)
    end,

    boost_launch = function(veh)
        local forward <const> = GetEntityForwardVector(veh)
        local velocity <const> = GetEntityVelocity(veh)
        SetEntityVelocity(veh, velocity.x + forward.x * 30.0, velocity.y + forward.y * 30.0, velocity.z + 8.0)
    end,

    flip_vehicle = function(veh)
        local rotation <const> = GetEntityRotation(veh, 2)
        local velocity <const> = GetEntityVelocity(veh)
        SetEntityRotation(veh, rotation.x, rotation.y + 90.0, rotation.z, 2, true)
        SetEntityVelocity(veh, velocity.x, velocity.y, velocity.z + 6.0)
    end,

    horn_spam = function(veh, ms)
        every(veh, ms, 300, function() SoundVehicleHornOnce(veh) end)
    end,
}

---Server push to the vehicle's owner: carry out an action.
---@param netId integer
---@param id string
---@param seconds number
RegisterNetEvent('ghm-vehiclehack:client:apply', function(netId, id, seconds)
    local effect <const> = EFFECTS[id]
    if not effect or type(seconds) ~= 'number' then return end

    local veh <const> = VH.vehicleFromNetId(netId)
    if not veh or not VH.takeControl(veh) then return end

    -- Long effects loop; run them off the event so a second push is not queued behind them.
    CreateThread(function() effect(veh, math.floor(math.max(0, seconds) * 1000)) end)
end)

---Server push to someone sitting in the vehicle: take their input, steer them, or throw them out.
---@param netId integer
---@param spec { controls?: integer[], steer?: number, eject?: boolean }
---@param ms integer
RegisterNetEvent('ghm-vehiclehack:client:occupant', function(netId, spec, ms)
    if type(spec) ~= 'table' or type(ms) ~= 'number' then return end
    local veh <const> = VH.vehicleFromNetId(netId)
    if not veh then return end
    ms = math.min(math.max(ms, 0), 30000)

    if spec.eject and GetVehiclePedIsIn(cache.ped, false) == veh then
        ClearPedTasksImmediately(cache.ped)
        TaskLeaveVehicle(cache.ped, veh, 4160)
    end

    if type(spec.controls) == 'table' and ms > 0 then
        CreateThread(function()
            local until_ <const> = GetGameTimer() + ms
            while GetGameTimer() < until_ do
                for i = 1, #spec.controls do DisableControlAction(0, spec.controls[i], true) end
                Wait(0)
            end
        end)
    end

    if type(spec.steer) == 'number' and ms > 0 then
        CreateThread(function()
            local until_ <const> = GetGameTimer() + ms
            while GetGameTimer() < until_ and DoesEntityExist(veh) and GetVehiclePedIsIn(cache.ped, false) == veh do
                DisableControlAction(0, 59, true)
                DisableControlAction(0, 60, true)
                SetVehicleSteerBias(veh, spec.steer)
                Wait(0)
            end
            if DoesEntityExist(veh) then SetVehicleSteerBias(veh, 0.0) end
        end)
    end
end)

---Server push to the vehicle's owner: the speed bomb went off.
RegisterNetEvent('ghm-vehiclehack:client:explode', function(netId)
    local veh <const> = VH.vehicleFromNetId(netId)
    if not veh then return end
    VH.takeControl(veh)
    -- Network-safe: every client sees the blast, no ownership gymnastics needed.
    NetworkExplodeVehicle(veh, true, false, false)
end)

