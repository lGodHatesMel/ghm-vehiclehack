# Changelog

## 2.0.0

A rewrite of how the resource works. Players see the same idea (link to a vehicle, run an action) with a new, simpler
app, and the server is now in charge of everything that matters.

### Security

- The server decides every action. It checks that the player has the app, that the vehicle is one of their own targets,
  that it is in range, that it is not protected or the vehicle they are in, and the cooldown, and it takes the payment.
  Before, the player's own client ran the action and the server only charged for it, so a modified client could hack
  any vehicle for free.
- The effect is sent to the vehicle's network owner (and to the players inside it) instead of being run by whoever
  pressed the button.
- Tagging is timed and verified by the server and the tag item is spent only when the tag lands (it used to be spent even
  when the attempt failed).
- The sd-phone unlock is checked on every request, not only when drawing the icon.
- Removed the `vh_*` debug commands, which let any player tag and hack vehicles without the items or the app.

### New

- A redesigned app: two steps (target, action), a confirmation sheet with effect length, risk, price and balance, live
  distance and status of the linked vehicle, a countdown on running effects and a cooldown bar.
- Aim with the phone's own camera in sd-phone: the phone stays open and unlocked instead of closing and asking for the
  passcode again. The crosshair is still used standalone and on an sd-phone without `useCamera`.
- Tagged and Aim targeting can both be on at once.
- The action list, prices and durations come from the server, so the app can no longer drift from `config.lua`.
- Translations: `locales/<code>.json`, following ox_lib's language setting. No rebuild needed to translate.
- Standalone mode uses the same app, as a flat panel.
- Refunds when an action could not be carried out.
- A wallet row under the title always shows the player's balance of the currency actions are paid in. `Config.Currency`
  picks any money type your framework has (cash, bank, crypto, script, a custom one) and how it is written; a type the
  framework does not have shows a dash and refuses paid actions instead of running them for free.

- Inventory bridge (`bridge/inventory.lua`, `Config.Inventory`): ox_inventory, qs-inventory(-pro), tgiann-inventory,
  jaksam_inventory, origen_inventory, codem-inventory, one_inventory and qb-inventory are supported directly; ps-inventory,
  lj-inventory, qbx and ESX's own inventory go through the framework. `ox_inventory` is no longer a hard dependency.

- Fuel bridge (`bridge/fuel.lua`, `Config.Fuel`): Fuel Leak works with ox_fuel, LegacyFuel, cdn-fuel, ps-fuel, lj-fuel, okokFuel
  and stg-vanaheimfuel instead of fighting them.

### Fixed

- The Vehicle Hacker stayed on screen over the game after the sd-phone app was closed (and at server start). The page now
  follows sd-phone's `appOpen` / `appClose` messages from the moment it loads, and is hidden until the app is in front.
- "Hacker unavailable" stayed on screen when sd-phone's SDK arrived after the app had loaded. The app now waits for the
  SDK (up to 15 s) before it calls the game or subscribes to the phone's app events.
- Force Left / Force Right pulled the wrong way (the steer bias is +1 left, -1 right).
- Lock Steering disabled the hacker's own steering keys; it now disables the driver's.
- Force Left / Right, Eject Occupants, Lock Doors and Disable Brakes now reach the players inside the vehicle on their own
  clients, where their input and seat can actually be changed.
- Burst Tires called `SetVehicleTireBurst`, which is not a native; it is `SetVehicleTyreBurst`.
- The durations shown in the app are the durations that run (they used to be hard-coded differently in Lua).
- Engine Kill no longer smashes windows; Force Doors opens the doors instead of breaking them; Boost Launch uses the
  vehicle's forward vector; Fuel Leak drains over its duration; Flip tips the vehicle onto its side.
- The crosshair read an asynchronous shape test in the frame it started it, so it could miss vehicles.
- The Speed Bomb no longer lives on one player's client, so it survives the vehicle changing owner.

### Changed

- Item entries: handlers are server exports and `consume` is `0` (see the README).
- Config: `TargetingMode` -> `Targeting`, `Raycast` -> `Aim`, `HackCooldown` -> `Cooldown`, `CurrencyType` ->
  `Currency.Type`, `TagRange` / `TagDuration` -> `Tag`. `Config.Debug` added.
- Files are split into `client/`, `server/`, `locales/` and `ui/`.

### Removed

- Commands `/untag`, `/checktags`, `/cleartags` (the app lists and removes tags) and the `vh_*` debug commands.
- Exports `tagVehicle`, `untagVehicle` (client). `isTagged` is now a server export taking the player.
