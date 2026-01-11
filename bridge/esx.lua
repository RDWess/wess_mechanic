if Config.Framework == 'esx' then
    ESX = nil
    
    Citizen.CreateThread(function()
        while ESX == nil do
            TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
            Citizen.Wait(100)
        end
    end)
    
    Framework.GetPlayer = function()
        return ESX.GetPlayerData()
    end
    
    Framework.GetPlayerByIdentifier = function(identifier)
        return ESX.GetPlayerFromIdentifier(identifier)
    end
    
    Framework.GetPlayerBySource = function(source)
        return ESX.GetPlayerFromId(source)
    end
    
    Framework.GetPlayers = function()
        return ESX.GetPlayers()
    end
    
    Framework.GetIdentifier = function(player)
        return player.identifier
    end
    
    Framework.GetJob = function(player)
        return player.job.name, player.job.grade, player.job.label
    end
    
    Framework.HasJob = function(jobName)
        local player = Framework.GetPlayer()
        return player.job.name == jobName
    end
    
    Framework.IsBoss = function(jobName)
        local player = Framework.GetPlayer()
        return player.job.name == jobName and player.job.grade_name == "boss"
    end
    
    Framework.AddMoney = function(source, account, amount)
        local player = Framework.GetPlayerBySource(source)
        if player then
            if account == "money" then
                player.addMoney(amount)
            else
                player.addAccountMoney(account, amount)
            end
            return true
        end
        return false
    end
    
    Framework.RemoveMoney = function(source, account, amount)
        local player = Framework.GetPlayerBySource(source)
        if player then
            if account == "money" then
                return player.removeMoney(amount)
            else
                return player.removeAccountMoney(account, amount)
            end
        end
        return false
    end
    
    Framework.GetMoney = function(source, account)
        local player = Framework.GetPlayerBySource(source)
        if player then
            if account == "money" then
                return player.getMoney()
            else
                return player.getAccount(account).money
            end
        end
        return 0
    end
    
    Framework.Notify = function(source, message, type, length)
        TriggerClientEvent('esx:showNotification', source, message)
    end
    
    Framework.ItemCount = function(source, item)
        local player = Framework.GetPlayerBySource(source)
        if player then
            local itemData = player.getInventoryItem(item)
            return itemData and itemData.count or 0
        end
        return 0
    end
    
    Framework.AddItem = function(source, item, amount)
        local player = Framework.GetPlayerBySource(source)
        if player then
            player.addInventoryItem(item, amount)
            return true
        end
        return false
    end
    
    Framework.RemoveItem = function(source, item, amount)
        local player = Framework.GetPlayerBySource(source)
        if player then
            player.removeInventoryItem(item, amount)
            return true
        end
        return false
    end
    
    Framework.GetPlayerName = function(source)
        local player = Framework.GetPlayerBySource(source)
        return player and player.getName() or "Desconocido"
    end
    
    Framework.CreateJob = function(jobName, jobLabel)
        -- Para ESX, se añadiría a la base de datos
    end
    
    Framework.IsAdmin = function(source)
        local player = Framework.GetPlayerBySource(source)
        local group = player and player.getGroup() or "user"
        return group == "admin" or group == "superadmin"
    end
end