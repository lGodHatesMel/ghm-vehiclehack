-- Inventory bridge: the three things this resource needs from an inventory, normalized across the
-- supported ones: how many of an item a player holds, taking one away, and making an item usable.
-- Everything else (item images, stashes, metadata) is the inventory's own business. Server side only.
--
-- Config.Inventory: 'auto' or the resource name. 'auto' uses the first of the list below that is started.
-- With no dedicated inventory (or one this file does not know) the framework's own item calls are used,
-- which is what qb-inventory, ps-inventory, lj-inventory and ESX's built-in inventory are.

---@type string[] Supported inventory resources, in detection order. one_inventory comes before
---ox_inventory because it provides the ox_inventory name, which then reads as started.
local CANDIDATES <const> = {
    'one_inventory', 'ox_inventory', 'tgiann-inventory', 'jaksam_inventory', 'qs-inventory-pro',
    'qs-inventory', 'origen_inventory', 'codem-inventory', 'qb-inventory', 'ps-inventory', 'lj-inventory',
}

local OX <const>, ONE <const>, TG <const>, JK <const> = 'ox_inventory', 'one_inventory', 'tgiann-inventory', 'jaksam_inventory'
local QSP <const>, QS <const>, OG <const>, CD <const>, QB <const> = 'qs-inventory-pro', 'qs-inventory', 'origen_inventory', 'codem-inventory', 'qb-inventory'

---@return string|nil
local function detect()
    if Config.Inventory ~= nil and Config.Inventory ~= 'auto' then return Config.Inventory end
    for i = 1, #CANDIDATES do
        if GetResourceState(CANDIDATES[i]) == 'started' then return CANDIDATES[i] end
    end
    return nil
end

---@type string|nil The inventory resource in use; nil means the framework's own item calls.
local active <const> = detect()
local Framework <const> = Bridge.Framework

---@class VehicleHackInventory
local Inventory = { name = active }

---How many of an item the player holds, across every slot. 0 (never nil) when unknown.
---@param source integer
---@param item string
---@return integer
function Inventory.Count(source, item)
    local ok, count = pcall(function()
        if active == OX then return exports[OX]:GetItemCount(source, item)
        elseif active == ONE then return exports[ONE]:GetItemCount(source, item)
        elseif active == TG then return exports[TG]:GetItemCount(source, item)
        elseif active == JK then return exports[JK]:getTotalItemAmount(source, item)
        elseif active == CD then return exports[CD]:GetItemsTotalAmount(source, item)
        elseif active == OG then return exports[OG]:getItemCount(source, item, false, false)
        elseif active == QB then return exports[QB]:GetItemCount(source, item)
        elseif active == QS or active == QSP then return exports[active]:GetItemTotalAmount(source, item)
        end

        local p = Bridge.GetPlayerObject(source)
        if not p then return 0 end
        if Framework == 'esx' then
            local data = p.getInventoryItem(item)
            return data and (data.count or data.amount) or 0
        end
        local data = p.Functions.GetItemByName(item)
        return data and (data.amount or data.count) or 0
    end)
    return ok and tonumber(count) or 0
end

---Whether the player holds at least `amount` of an item. Fails closed on a nil item.
---@param source integer
---@param item string
---@param amount? integer defaults to 1
---@return boolean
function Inventory.Has(source, item, amount)
    if type(item) ~= 'string' or item == '' then return false end
    return Inventory.Count(source, item) >= (amount or 1)
end

---Takes `amount` of an item from the player. True only when the full amount left them.
---@param source integer
---@param item string
---@param amount integer
---@return boolean
function Inventory.Remove(source, item, amount)
    if not Inventory.Has(source, item, amount) then return false end

    local ok, removed = pcall(function()
        if active == OX then return exports[OX]:RemoveItem(source, item, amount) == true
        elseif active == ONE then return exports[ONE]:RemoveItem(source, item, amount) == true
        elseif active == TG then return exports[TG]:RemoveItem(source, item, amount) == true
        elseif active == JK then return exports[JK]:removeItem(source, item, amount) == true
        elseif active == CD then return exports[CD]:RemoveItem(source, item, amount) == true
        elseif active == OG then return exports[OG]:removeItem(source, item, amount) == true
        elseif active == QB then return exports[QB]:RemoveItem(source, item, amount) == true
        elseif active == QS or active == QSP then return exports[active]:RemoveItem(source, item, amount) == true
        end

        local p = Bridge.GetPlayerObject(source)
        if not p then return false end
        if Framework == 'esx' then
            p.removeInventoryItem(item, amount)
            return true
        end
        return p.Functions.RemoveItem(item, amount) == true
    end)
    return ok and removed == true
end

---Makes an item usable: `handler(source)` runs when a player uses it. The handler spends the item itself
---(the inventory must not consume it), so a failed attempt never costs the player the item.
---
---ox_inventory is the exception: it calls a server export named in the item's definition, so this does
---nothing there and server/main.lua exports the handlers instead (see `Inventory.usesExports`).
---@param item string
---@param handler fun(source: integer)
---@return boolean registered false when there is no usable-item path for this inventory/framework
function Inventory.RegisterUsable(item, handler)
    if Inventory.usesExports then return true end

    local ok, err = pcall(function()
        local callback = function(source) handler(source) end
        if active == QSP then return exports[QSP]:CreateUsableItem(item, callback) end
        if active == OG then return exports[OG]:CreateUseableItem(item, callback) end
        -- one_inventory reads the framework's usable-item registry, so it takes the framework paths below.
        if Framework == 'esx' then return Bridge.ESX.RegisterUsableItem(item, callback) end
        if Framework == 'qbx' then return exports.qbx_core:CreateUseableItem(item, callback) end
        if Framework == 'qbcore' then return Bridge.QBCore.Functions.CreateUseableItem(item, callback) end
        error('no usable-item path')
    end)
    if not ok then
        print(('^1[%s]^0 could not make %q usable (%s)'):format(GetCurrentResourceName(), item, tostring(err)))
    end
    return ok
end

---True for the inventory that calls this resource's exports itself (ox_inventory).
Inventory.usesExports = (active == OX)

if not active and not Framework then
    print(('^1[%s]^0 no supported inventory or framework found; items cannot be counted, removed or used'):format(GetCurrentResourceName()))
end

if Config.Debug then
    print(('[%s] inventory: %s'):format(GetCurrentResourceName(), active or ('framework (' .. tostring(Framework) .. ')')))
end

Bridge.Inventory = Inventory
