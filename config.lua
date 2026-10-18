Config = {}

-- ─────────────────────────────────────────────────────────────────────────────
-- GENERAL
-- ─────────────────────────────────────────────────────────────────────────────

-- Framework: 'auto' | 'qbx' | 'qbcore' | 'esx'
-- 'auto' uses whichever of qbx_core / qb-core / es_extended is running (checked in that order).
-- Only set it by hand if you run more than one of them side by side.
Config.Framework = 'auto'

-- Language. Follows ox_lib's convar (`setr ox:locale "en"` in server.cfg), English is always the
-- fallback. To add a language copy locales/en.json to locales/<code>.json and translate the values.
-- The names and descriptions of the actions (Config.Actions below) are edited right here.

-- Prints what the resource is doing to the console when something is refused.
Config.Debug = false

-- ─────────────────────────────────────────────────────────────────────────────
-- WHERE THE APP LIVES
-- ─────────────────────────────────────────────────────────────────────────────

-- true  = an app inside sd-phone. It is installed by using `Config.UnlockItem`, once, per character.
-- false = a standalone screen. It opens when the player uses `Config.StandaloneItem`, and the item
--         has to stay in their inventory while they use it.
Config.UseSdPhone = true

-- How the app is registered with sd-phone (Config.UseSdPhone = true).
Config.Identifier  = 'ghm-vehiclehack'
Config.Name        = 'Vehicle Hacker'
Config.Description = 'Remote vehicle sabotage, control and chaos toolkit.'
Config.Developer   = 'GHM Development'
Config.DefaultApp  = false -- true installs it on every phone without the unlock item

-- Which inventory holds the items: 'auto' uses the first supported one that is started (ox_inventory,
-- qs-inventory, tgiann-inventory, ...). Or name the resource. With none of them, the framework's own
-- item calls are used, which is what qb-inventory, ps-inventory, lj-inventory and ESX do.
Config.Inventory = 'auto'

-- Which fuel script the Fuel Leak action talks to, so the script does not refill the tank behind it:
-- 'auto' uses the first supported one that is started (ox_fuel, LegacyFuel, cdn-fuel, ps-fuel, lj-fuel,
-- okokFuel, stg-vanaheimfuel). Or name the resource, or 'none' to only change the GTA fuel level.
Config.Fuel = 'auto'

-- Items. Add them to your inventory (see the README). All three are usable items whose handler is in
-- this resource.
Config.UnlockItem     = 'vehicle_hacker_unlock_usb' -- sd-phone mode: spent once to install the app
Config.StandaloneItem = 'vehicle_hacker_device'     -- standalone mode: opens the screen
Config.TagItem        = 'vehicle_tag'               -- tags a vehicle (Config.Targeting.Tagged)

-- ─────────────────────────────────────────────────────────────────────────────
-- TARGETING
-- ─────────────────────────────────────────────────────────────────────────────

-- How a player picks the vehicle to hack. Turn either off to remove it from the app.
Config.Targeting = {
    -- Tagged: stick a Vehicle Tag on a vehicle, then pick it from the list in the app for as long
    -- as it stays within Config.ScanRadius.
    Tagged = true,
    -- Aim: look at a vehicle and click. In sd-phone the phone's own camera is the viewfinder; on an
    -- older sd-phone, or standalone, the screen is put away and a crosshair is shown instead.
    Aim = true,
}

Config.Aim = {
    MaxDistance = 50.0,   -- metres the crosshair can reach
    Window      = 600000, -- ms an aimed vehicle stays usable after the click
    Timeout     = 60000,  -- ms before the crosshair gives up (crosshair mode only)
    Outline     = { r = 100, g = 255, b = 140, a = 220 }, -- outline on the vehicle under the crosshair
}

-- Vehicle Tag item (Config.Targeting.Tagged)
Config.Tag = {
    Range    = 3.0,   -- metres, how close you must stand to tag a vehicle
    Duration = 3000,  -- ms, the tagging animation; the server times it as well
    Max      = 10,    -- most vehicles one player can have tagged at once
    Consume  = true,  -- spend one tag item per vehicle, only after the tag actually lands
}

-- A target has to be within this many metres of the player when an action runs.
Config.ScanRadius = 100.0

-- Vehicle models nobody can hack, by spawn name: { 'police', 'ambulance' }.
Config.ProtectedModels = {}

-- ─────────────────────────────────────────────────────────────────────────────
-- COST AND LIMITS
-- ─────────────────────────────────────────────────────────────────────────────

-- Milliseconds between two actions from the same player. Enforced on the server.
Config.Cooldown = 2000

-- true  = every action is free.
-- false = every action charges its `cost` (Config.Actions below) in Config.Currency, on the server, before it
--         runs. A short balance refuses the action.
Config.FreeMode = true

-- What an action costs is paid in one framework money type, and the app always shows the player's balance of
-- it. There is no crypto system here: `crypto` and `script` are just money types your framework may have.
--   qbx_core / QBCore  the money types in your core's config (`moneyTypes` / `Config.Money.MoneyTypes`):
--                      'cash', 'bank', 'crypto', or any you added.
--   ESX                'cash' (the money account), 'bank', or the name of an account you created.
-- A type the framework does not have is not charged against: the app shows no balance and, with free mode off,
-- refuses every action rather than running it for free.
Config.Currency = {
    Type = 'cash',
    -- How it is shown. Leave these out and they are made from the type: cash and bank are dollars ("$150"), any
    -- other type is named after itself with a short form of its first three letters, or the initials of several
    -- words ("script" -> Script / SCR, "maze coin" -> MC).
    Label = nil,       -- the name shown in the app
    Symbol = nil,      -- the short form next to an amount
    SymbolFirst = nil, -- true: "$150", false: "150 SCR"
    Decimals = 0,      -- places shown and kept (0 = whole units); action costs are rounded to this
}

-- ─────────────────────────────────────────────────────────────────────────────
-- ACTIONS
-- ─────────────────────────────────────────────────────────────────────────────

-- 'mph' or 'kmh'. Used by the Speed Bomb threshold and shown in the app.
Config.SpeedUnit = 'mph'

-- Speed Bomb: explodes the vehicle once its speed falls under Threshold.
Config.SpeedBomb = {
    Threshold        = 20,    -- in Config.SpeedUnit
    ArmDelay         = 3000,  -- ms of grace after arming, so a parked vehicle is not detonated at once
    MaxArmedDuration = 60000, -- ms; the bomb disarms itself after this long
}

-- The tabs of the app, in order. `actions` are ids from Config.Actions.
Config.Categories = {
    { id = 'sabotage', label = 'Sabotage', description = 'Disable and damage vehicle systems',
      actions = { 'engine_kill', 'brake_lock', 'disable_brakes', 'tire_burst', 'fuel_leak' } },
    { id = 'control', label = 'Control', description = 'Take over steering, doors and seats',
      actions = { 'steer_left', 'steer_right', 'lock_steering', 'open_doors', 'eject_occupants', 'lock_doors' } },
    { id = 'chaos', label = 'Chaos', description = 'Unpredictable vehicle effects',
      actions = { 'random_spin', 'boost_launch', 'flip_vehicle', 'horn_spam', 'speed_bomb' } },
}

-- One row per action.
--   duration   seconds the effect lasts (0 = instant). The app shows it and the server runs it.
--   risk       'low' | 'medium' | 'high'
--   cost       charged only when Config.FreeMode is false
--   enabled    false hides the action everywhere
-- Leave an action out of Config.Categories to hide it from the app as well.
Config.Actions = {
    engine_kill     = { label = 'Kill Engine',     description = 'Shuts the engine down for good.',                   duration = 0,   risk = 'high',   cost = 150 },
    brake_lock      = { label = 'Lock Brakes',     description = 'Forces the handbrake on.',                          duration = 8,   risk = 'high',   cost = 120 },
    disable_brakes  = { label = 'Disable Brakes',  description = "The driver's brake and handbrake stop responding.", duration = 10,  risk = 'high',   cost = 140 },
    tire_burst      = { label = 'Burst Tires',     description = 'Blows out all four tires.',                         duration = 0,   risk = 'medium', cost = 60 },
    fuel_leak       = { label = 'Fuel Leak',       description = 'Drains the tank until it is empty.',                duration = 15,  risk = 'medium', cost = 80 },

    steer_left      = { label = 'Force Left',      description = 'Pulls the wheel hard to the left.',                 duration = 1.5, risk = 'medium', cost = 40 },
    steer_right     = { label = 'Force Right',     description = 'Pulls the wheel hard to the right.',                duration = 1.5, risk = 'medium', cost = 40 },
    lock_steering   = { label = 'Lock Steering',   description = 'The driver can no longer turn the wheel.',          duration = 5,   risk = 'high',   cost = 90 },
    open_doors      = { label = 'Force Doors',     description = 'Unlocks the vehicle and swings every door open.',   duration = 0,   risk = 'low',    cost = 20 },
    eject_occupants = { label = 'Eject Occupants', description = 'Throws everyone out of the vehicle.',               duration = 0,   risk = 'medium', cost = 100 },
    lock_doors      = { label = 'Lock Doors',      description = 'Locks the doors and traps everyone inside.',        duration = 20,  risk = 'high',   cost = 130 },

    random_spin     = { label = 'Spin Out',        description = 'Spins the vehicle around.',                         duration = 2,   risk = 'high',   cost = 100 },
    boost_launch    = { label = 'Boost Launch',    description = 'Launches the vehicle forward.',                     duration = 0,   risk = 'high',   cost = 130 },
    flip_vehicle    = { label = 'Flip Vehicle',    description = 'Tips the vehicle onto its side.',                   duration = 0,   risk = 'high',   cost = 150 },
    horn_spam       = { label = 'Horn Spam',       description = 'Leans on the horn.',                                duration = 5,   risk = 'low',    cost = 15 },
    -- The app writes the threshold into this text itself; this is the fallback.
    speed_bomb      = { label = 'Speed Bomb',      description = 'Explodes the vehicle when it slows down.',          duration = 0,   risk = 'high',   cost = 250 },
}
