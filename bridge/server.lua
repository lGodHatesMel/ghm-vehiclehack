-- Server-side half of the bridge, normalized across qbx_core, legacy QBCore and ESX: money
-- get/remove/add (the charge for an action and its refund) and the character's identifier (so a
-- target or a tag never follows a player to another character).

local Framework = Bridge.Framework

local ESX = nil
if Framework == 'esx' then
    ESX = exports['es_extended']:getSharedObject()
end

local QBCore = nil
if Framework == 'qbcore' then
    QBCore = exports['qb-core']:GetCoreObject()
end

-- The live core objects, for the inventory bridge (bridge/inventory.lua) to reach the framework's own
-- item and usable-item calls. Nil on the frameworks that have none.
Bridge.ESX = ESX
Bridge.QBCore = QBCore

---The framework's player object for a source, or nil when no character is loaded.
---@param source integer
---@return table|nil
function Bridge.GetPlayerObject(source)
    if Framework == 'qbx' then
        return exports.qbx_core:GetPlayer(source)
    elseif Framework == 'qbcore' then
        return QBCore.Functions.GetPlayer(source)
    elseif Framework == 'esx' then
        return ESX.GetPlayerFromId(source)
    end
    return nil
end

---Config.Currency.Type is authored against qbx_core/QBCore money type names ('cash', 'bank',
---'crypto', or a custom type). ESX's cash-equivalent isn't an account at all - it's a special
---xPlayer.getMoney()/removeMoney() pair - so 'cash' maps to that path there. Every other name
---(bank, crypto, a custom account) passes through unchanged to xPlayer.getAccount(name).
---@param moneyType string
---@return string
local function normalizeMoneyType(moneyType)
    if Framework == 'esx' and moneyType == 'cash' then
        return 'money'
    end
    return moneyType
end

---Whether the framework tracks this money type for this player. A type nobody added to the framework is
---"not available", which is different from an empty balance and must not be charged against.
---@param source integer
---@param moneyType string
---@return boolean
function Bridge.HasMoneyType(source, moneyType)
    local mt = normalizeMoneyType(moneyType)

    if Framework == 'qbx' then
        local player = exports.qbx_core:GetPlayer(source)
        return player ~= nil and type(player.PlayerData.money) == 'table' and player.PlayerData.money[mt] ~= nil
    elseif Framework == 'qbcore' then
        local player = QBCore.Functions.GetPlayer(source)
        return player ~= nil and type(player.PlayerData.money) == 'table' and player.PlayerData.money[mt] ~= nil
    elseif Framework == 'esx' then
        local xPlayer = ESX.GetPlayerFromId(source)
        if not xPlayer then return false end
        if mt == 'money' then return true end
        local ok, account = pcall(xPlayer.getAccount, mt)
        return ok and account ~= nil
    end

    return false
end

---How the currency is shown, from Config.Currency: its name, its short form, and whether the short form goes
---before the amount ("$150") or after it ("150 SCR"). Anything left out is worked out from the type: cash and
---bank are dollars; any other type is named after itself, with a short form of its first three letters (one
---word) or the initials (several words).
---@return { type: string, label: string, symbol: string, symbolFirst: boolean, decimals: integer }
function Bridge.CurrencyInfo()
    local cfg = Config.Currency or {}
    local moneyType = type(cfg.Type) == 'string' and cfg.Type ~= '' and cfg.Type or 'cash'
    local dollars = moneyType == 'cash' or moneyType == 'bank' or moneyType == 'money'

    local label = type(cfg.Label) == 'string' and cfg.Label ~= '' and cfg.Label
        or (moneyType:sub(1, 1):upper() .. moneyType:sub(2):gsub('_', ' '))

    local symbol = type(cfg.Symbol) == 'string' and cfg.Symbol ~= '' and cfg.Symbol or nil
    if not symbol then
        if dollars then
            symbol = '$'
        else
            local parts = {}
            for word in label:gmatch('%w+') do parts[#parts + 1] = word end
            if #parts > 1 then
                local initials = {}
                for i = 1, math.min(#parts, 4) do initials[i] = parts[i]:sub(1, 1) end
                symbol = table.concat(initials):upper()
            elseif #parts == 1 then
                symbol = parts[1]:sub(1, 3):upper()
            else
                symbol = moneyType:upper()
            end
        end
    end

    return {
        type = moneyType,
        label = label,
        symbol = symbol,
        symbolFirst = cfg.SymbolFirst == nil and dollars or cfg.SymbolFirst == true,
        decimals = math.max(0, math.min(8, math.floor(tonumber(cfg.Decimals) or 0))),
    }
end

---Reads a player's balance for one money type.
---@param source integer
---@param moneyType string
---@return number|false balance false when the player or money type can't be resolved
function Bridge.GetMoney(source, moneyType)
    local mt = normalizeMoneyType(moneyType)

    if Framework == 'qbx' then
        local player = exports.qbx_core:GetPlayer(source)
        return player and player.Functions.GetMoney(mt) or false
    elseif Framework == 'qbcore' then
        local player = QBCore.Functions.GetPlayer(source)
        return player and player.Functions.GetMoney(mt) or false
    elseif Framework == 'esx' then
        local xPlayer = ESX.GetPlayerFromId(source)
        if not xPlayer then return false end
        if mt == 'money' then return xPlayer.getMoney() end
        local account = xPlayer.getAccount(mt)
        return account and account.money or false
    end

    return false
end

---Removes `amount` of `moneyType` from a player. Only ever true when the full amount left
---the player - nothing is partially consumed on a refusal.
---@param source integer
---@param moneyType string
---@param amount number
---@param reason string
---@return boolean
function Bridge.RemoveMoney(source, moneyType, amount, reason)
    local mt = normalizeMoneyType(moneyType)

    if Framework == 'qbx' then
        local player = exports.qbx_core:GetPlayer(source)
        return player ~= nil and player.Functions.RemoveMoney(mt, amount, reason) ~= false
    elseif Framework == 'qbcore' then
        local player = QBCore.Functions.GetPlayer(source)
        return player ~= nil and player.Functions.RemoveMoney(mt, amount, reason) ~= false
    elseif Framework == 'esx' then
        local xPlayer = ESX.GetPlayerFromId(source)
        if not xPlayer then return false end

        if mt == 'money' then
            if xPlayer.getMoney() < amount then return false end
            xPlayer.removeMoney(amount, reason)
            return true
        end

        local account = xPlayer.getAccount(mt)
        if not account or account.money < amount then return false end
        xPlayer.removeAccountMoney(mt, amount)
        return true
    end

    return false
end

---Credits `amount` of `moneyType` back to a player (the refund when an action could not run).
---@param source integer
---@param moneyType string
---@param amount number
---@param reason string
function Bridge.AddMoney(source, moneyType, amount, reason)
    local mt = normalizeMoneyType(moneyType)

    if Framework == 'qbx' then
        local player = exports.qbx_core:GetPlayer(source)
        if player then player.Functions.AddMoney(mt, amount, reason) end
    elseif Framework == 'qbcore' then
        local player = QBCore.Functions.GetPlayer(source)
        if player then player.Functions.AddMoney(mt, amount, reason) end
    elseif Framework == 'esx' then
        local xPlayer = ESX.GetPlayerFromId(source)
        if not xPlayer then return end
        if mt == 'money' then
            xPlayer.addMoney(amount, reason)
        else
            xPlayer.addAccountMoney(mt, amount)
        end
    end
end

---The identifier of the character the player is playing right now (citizenid / ESX identifier),
---or nil when none is loaded.
---@param source integer
---@return string|nil
function Bridge.GetIdentifier(source)
    if Framework == 'qbx' then
        local player = exports.qbx_core:GetPlayer(source)
        return player and player.PlayerData.citizenid or nil
    elseif Framework == 'qbcore' then
        local player = QBCore.Functions.GetPlayer(source)
        return player and player.PlayerData.citizenid or nil
    elseif Framework == 'esx' then
        local xPlayer = ESX.GetPlayerFromId(source)
        return xPlayer and xPlayer.identifier or nil
    end

    return nil
end
