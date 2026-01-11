Framework = {}

-- Detectar framework
if GetResourceState('qbx_core') == 'started' then
    Config.Framework = 'qbox'
elseif GetResourceState('qb-core') == 'started' then
    Config.Framework = 'qb'
elseif GetResourceState('es_extended') == 'started' then
    Config.Framework = 'esx'
end

if Config.Framework == 'qbox' or Config.Framework == 'qb' then
    local QBCore = exports['qb-core']:GetCoreObject()
    
    Framework.GetPlayer = function()
        return QBCore.Functions.GetPlayerData()
    end
    
    Framework.GetPlayerByCitizenId = function(citizenid)
        return QBCore.Functions.GetPlayerByCitizenId(citizenid)
    end
    
    Framework.GetPlayerBySource = function(source)
        return QBCore.Functions.GetPlayer(source)
    end
    
    Framework.GetPlayers = function()
        return QBCore.Functions.GetPlayers()
    end
    
    Framework.GetIdentifier = function(player)
        return player.citizenid
    end
    
    Framework.GetJob = function(player)
        return player.job.name, player.job.grade.level, player.job.grade.name
    end
    
    Framework.HasJob = function(jobName)
        local player = Framework.GetPlayer()
        return player.job.name == jobName
    end
    
    Framework.IsBoss = function(jobName)
        local player = Framework.GetPlayer()
        return player.job.name == jobName and player.job.isboss
    end
    
    Framework.AddMoney = function(source, account, amount)
        local player = Framework.GetPlayerBySource(source)
        if player then
            player.Functions.AddMoney(account, amount)
            return true
        end
        return false
    end
    
    Framework.RemoveMoney = function(source, account, amount)
        local player = Framework.GetPlayerBySource(source)
        if player then
            return player.Functions.RemoveMoney(account, amount)
        end
        return false
    end
    
    Framework.GetMoney = function(source, account)
        local player = Framework.GetPlayerBySource(source)
        if player then
            return player.PlayerData.money[account] or 0
        end
        return 0
    end
    
    Framework.Notify = function(source, message, type, length)
        TriggerClientEvent('QBCore:Notify', source, message, type, length)
    end
    
    Framework.ItemCount = function(source, item)
        local player = Framework.GetPlayerBySource(source)
        if player then
            return player.Functions.GetItemByName(item)?.amount or 0
        end
        return 0
    end
    
    Framework.AddItem = function(source, item, amount)
        local player = Framework.GetPlayerBySource(source)
        if player then
            player.Functions.AddItem(item, amount)
            return true
        end
        return false
    end
    
    Framework.RemoveItem = function(source, item, amount)
        local player = Framework.GetPlayerBySource(source)
        if player then
            player.Functions.RemoveItem(item, amount)
            return true
        end
        return false
    end
    
    Framework.GetPlayerName = function(source)
        local player = Framework.GetPlayerBySource(source)
        return player and player.PlayerData.charinfo.firstname .. " " .. player.PlayerData.charinfo.lastname or "Desconocido"
    end
    
    -- Crear trabajo dinámico
    Framework.CreateJob = function(jobName, jobLabel)
        -- El trabajo se crea dinámicamente en la base de datos
        -- No se modifica qb-core directamente
    end
    
    -- Verificar si es admin
    Framework.IsAdmin = function(source)
        local player = Framework.GetPlayerBySource(source)
        return player and player.PlayerData.permission_level >= 4
    end
end