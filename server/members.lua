local Members = {}

-- Obtener miembros del negocio
Members.GetAll = function(businessId)
    return Database.GetBusinessMembers(businessId)
end

-- Cambiar rango de miembro
Members.ChangeRank = function(source, targetIdentifier, newRank)
    local business = Business.GetPlayerBusiness(source)
    if not business then return false, "No tienes un negocio" end
    
    if business.rank ~= 'boss' then
        return false, "Solo el jefe puede cambiar rangos"
    end
    
    -- No permitir cambiar el rango del jefe
    if targetIdentifier == business.boss_identifier then
        return false, "No puedes cambiar el rango del jefe"
    end
    
    -- Verificar rangos válidos
    local validRanks = {'boss', 'manager', 'employee', 'recruit'}
    if not table.contains(validRanks, newRank) then
        return false, "Rango inválido"
    end
    
    -- Actualizar rango
    local success = MySQL.query.await([[
        UPDATE mechanic_members 
        SET rank = ? 
        WHERE business_id = ? AND member_identifier = ?
    ]], {newRank, business.id, targetIdentifier})
    
    if success then
        -- Actualizar trabajo del jugador si está en línea
        local players = Framework.GetPlayers()
        for _, playerId in ipairs(players) do
            local player = Framework.GetPlayerBySource(playerId)
            if player and Framework.GetIdentifier(player) == targetIdentifier then
                TriggerClientEvent('mechanic:updateJob', playerId, business.job_name, newRank)
                Framework.Notify(playerId, "Tu rango ha sido cambiado a: " .. newRank, 'info')
                break
            end
        end
        
        Framework.Notify(source, "Rango actualizado", 'success')
        return true
    end
    
    return false, "Error al actualizar rango"
end

-- Obtener estadísticas del miembro
Members.GetStats = function(memberIdentifier, businessId)
    return MySQL.query.await([[
        SELECT completed_invoices, total_earned, rank, joined_at
        FROM mechanic_members
        WHERE member_identifier = ? AND business_id = ?
    ]], {memberIdentifier, businessId})[1]
end

-- Chat de negocio
local BusinessChat = {}

Members.SendBusinessMessage = function(source, message)
    local business = Business.GetPlayerBusiness(source)
    if not business then return false, "No tienes un negocio" end
    
    local playerName = Framework.GetPlayerName(source)
    local formattedMessage = string.format("[%s] %s: %s", 
        business.name, playerName, message)
    
    -- Enviar a todos los miembros en línea
    local members = Database.GetBusinessMembers(business.id)
    local onlineCount = 0
    
    for _, member in ipairs(members) do
        local players = Framework.GetPlayers()
        for _, playerId in ipairs(players) do
            local player = Framework.GetPlayerBySource(playerId)
            if player and Framework.GetIdentifier(player) == member.member_identifier then
                TriggerClientEvent('mechanic:businessMessage', playerId, {
                    business = business.name,
                    sender = playerName,
                    message = message,
                    rank = business.rank
                })
                onlineCount = onlineCount + 1
                break
            end
        end
    end
    
    -- Guardar en registro (opcional)
    if BusinessChat[business.id] then
        table.insert(BusinessChat[business.id], {
            sender = playerName,
            message = message,
            timestamp = os.time()
        })
        
        -- Mantener solo los últimos 100 mensajes
        if #BusinessChat[business.id] > 100 then
            table.remove(BusinessChat[business.id], 1)
        end
    else
        BusinessChat[business.id] = {{
            sender = playerName,
            message = message,
            timestamp = os.time()
        }}
    end
    
    return true, onlineCount
end

Members.GetChatHistory = function(businessId, limit)
    return BusinessChat[businessId] or {}
end

-- Sistema de almacenamiento personal
Members.GetPersonalStorage = function(source)
    local business = Business.GetPlayerBusiness(source)
    if not business then return nil end
    
    local player = Framework.GetPlayerBySource(source)
    local identifier = Framework.GetIdentifier(player)
    
    -- Cada miembro tiene su propio almacén identificado por business_id + member_identifier
    local storageId = "mechanic_storage_" .. business.id .. "_" .. identifier
    
    return {
        id = storageId,
        label = "Almacén Personal - " .. Framework.GetPlayerName(source),
        slots = Config.StorageSlots,
        weight = Config.StorageWeight,
        owner = identifier
    }
end

-- Verificar permisos
Members.HasPermission = function(source, permission)
    local business = Business.GetPlayerBusiness(source)
    if not business then return false end
    
    return Config.Permissions[business.rank] and 
           Config.Permissions[business.rank][permission] or false
end

-- Obtener información completa del miembro
Members.GetFullInfo = function(source)
    local business = Business.GetPlayerBusiness(source)
    if not business then return nil end
    
    local player = Framework.GetPlayerBySource(source)
    local identifier = Framework.GetIdentifier(player)
    
    local stats = Members.GetStats(identifier, business.id)
    local storage = Members.GetPersonalStorage(source)
    
    return {
        business = business,
        stats = stats,
        storage = storage,
        permissions = Config.Permissions[business.rank] or {}
    }
end

return Members