local Business = {}

-- Crear nuevo negocio
Business.CreateNew = function(source, businessName, bossIdentifier)
    local player = Framework.GetPlayerBySource(source)
    if not player then return false, "Jugador no encontrado" end
    
    -- Verificar si ya es jefe de un negocio
    local existingBusiness = Database.GetBusinessByBoss(Framework.GetIdentifier(player))
    if existingBusiness then
        return false, "Ya eres jefe de un negocio"
    end
    
    -- Verificar si el nombre ya existe
    local existingName = Database.GetBusinessByName(businessName)
    if existingName then
        return false, "Ya existe un negocio con ese nombre"
    end
    
    local playerName = Framework.GetPlayerName(source)
    local businessId, jobName = Database.CreateBusiness(businessName, bossIdentifier, playerName)
    
    if businessId then
        -- Actualizar trabajo del jugador
        TriggerClientEvent('mechanic:updateJob', source, jobName, 'boss')
        
        -- Crear puntos por defecto
        local pedCoords = GetEntityCoords(GetPlayerPed(source))
        Database.AddPoint(businessId, 'work', {x = pedCoords.x, y = pedCoords.y, z = pedCoords.z}, 3.0)
        
        return true, businessId, jobName
    end
    
    return false, "Error al crear negocio"
end

-- Obtener información del negocio
Business.GetPlayerBusiness = function(source)
    local player = Framework.GetPlayerBySource(source)
    if not player then return nil end
    
    local identifier = Framework.GetIdentifier(player)
    return Database.GetMemberBusiness(identifier)
end

-- Añadir miembro
Business.AddMember = function(source, targetSource, rank)
    local business = Business.GetPlayerBusiness(source)
    if not business then return false, "No tienes un negocio" end
    
    if business.rank ~= 'boss' and business.rank ~= 'manager' then
        return false, "No tienes permiso para añadir miembros"
    end
    
    local targetPlayer = Framework.GetPlayerBySource(targetSource)
    if not targetPlayer then return false, "Jugador objetivo no encontrado" end
    
    local targetIdentifier = Framework.GetIdentifier(targetPlayer)
    local targetName = Framework.GetPlayerName(targetSource)
    
    -- Verificar si ya es miembro
    local members = Database.GetBusinessMembers(business.id)
    for _, member in ipairs(members) do
        if member.member_identifier == targetIdentifier then
            return false, "Ya es miembro del negocio"
        end
    end
    
    local success = Database.AddMember(business.id, targetIdentifier, targetName, rank or 'recruit')
    
    if success then
        -- Actualizar trabajo del nuevo miembro
        TriggerClientEvent('mechanic:updateJob', targetSource, business.job_name, rank or 'recruit')
        
        -- Notificar
        Framework.Notify(source, Locale['member_added']:format(targetName), 'success')
        Framework.Notify(targetSource, "Has sido añadido al negocio: " .. business.name, 'success')
        
        return true
    end
    
    return false, "Error al añadir miembro"
end

-- Eliminar miembro
Business.RemoveMember = function(source, memberIdentifier)
    local business = Business.GetPlayerBusiness(source)
    if not business then return false, "No tienes un negocio" end
    
    if business.rank ~= 'boss' then
        return false, "Solo el jefe puede eliminar miembros"
    end
    
    -- No permitir eliminar al jefe
    if memberIdentifier == business.boss_identifier then
        return false, "No puedes eliminar al jefe"
    end
    
    local success = Database.RemoveMember(business.id, memberIdentifier)
    
    if success then
        -- Buscar jugador en línea y quitarle el trabajo
        local players = Framework.GetPlayers()
        for _, playerId in ipairs(players) do
            local player = Framework.GetPlayerBySource(playerId)
            if player and Framework.GetIdentifier(player) == memberIdentifier then
                TriggerClientEvent('mechanic:removeJob', playerId)
                Framework.Notify(playerId, "Has sido removido del negocio", 'error')
                break
            end
        end
        
        return true
    end
    
    return false, "Error al eliminar miembro"
end

-- Depositar en banco
Business.DepositToBank = function(source, amount)
    local business = Business.GetPlayerBusiness(source)
    if not business then return false, "No tienes un negocio" end
    
    amount = tonumber(amount)
    if not amount or amount <= 0 then
        return false, "Cantidad inválida"
    end
    
    -- Verificar que el jugador tenga el dinero
    local playerMoney = Framework.GetMoney(source, 'money')
    if playerMoney < amount then
        return false, "No tienes suficiente dinero"
    end
    
    -- Quitar dinero al jugador
    local removed = Framework.RemoveMoney(source, 'money', amount)
    if not removed then
        return false, "Error al retirar dinero"
    end
    
    -- Depositar en banco
    local player = Framework.GetPlayerBySource(source)
    local identifier = Framework.GetIdentifier(player)
    local playerName = Framework.GetPlayerName(source)
    
    Database.UpdateBankBalance(business.id, amount, 'deposit', 
        "Depósito de " .. playerName, identifier)
    
    Framework.Notify(source, Locale['bank_deposit']:format(amount), 'success')
    
    return true
end

-- Retirar del banco
Business.WithdrawFromBank = function(source, amount)
    local business = Business.GetPlayerBusiness(source)
    if not business then return false, "No tienes un negocio" end
    
    if business.rank ~= 'boss' then
        return false, "Solo el jefe puede retirar dinero"
    end
    
    amount = tonumber(amount)
    if not amount or amount <= 0 then
        return false, "Cantidad inválida"
    end
    
    -- Verificar que el negocio tenga el dinero
    local balance = Database.GetBankBalance(business.id)
    if balance < amount then
        return false, "El negocio no tiene suficiente dinero"
    end
    
    -- Retirar del banco
    local player = Framework.GetPlayerBySource(source)
    local identifier = Framework.GetIdentifier(player)
    local playerName = Framework.GetPlayerName(source)
    
    Database.UpdateBankBalance(business.id, -amount, 'withdraw', 
        "Retiro de " .. playerName, identifier)
    
    -- Dar dinero al jugador
    Framework.AddMoney(source, 'money', amount)
    
    Framework.Notify(source, Locale['bank_withdraw']:format(amount), 'success')
    
    return true
end

-- Obtener top de facturas
Business.GetInvoiceTop = function(businessId)
    return MySQL.query.await([[
        SELECT member_name, completed_invoices, total_earned
        FROM mechanic_members
        WHERE business_id = ? AND active = TRUE
        ORDER BY completed_invoices DESC
        LIMIT 10
    ]], {businessId})
end

-- Obtener transacciones recientes
Business.GetRecentTransactions = function(businessId, limit)
    return Database.GetTransactionHistory(businessId, limit)
end

-- Actualizar pagos diarios
Business.UpdateDailyPayments = function(source, rank, amount)
    local business = Business.GetPlayerBusiness(source)
    if not business then return false, "No tienes un negocio" end
    
    if business.rank ~= 'boss' then
        return false, "Solo el jefe puede editar pagos"
    end
    
    amount = tonumber(amount)
    if not amount or amount < 0 then
        return false, "Cantidad inválida"
    end
    
    -- Los pagos se guardan en memoria solo para esta sesión
    -- Se reinician al reiniciar el servidor
    if not Business.DailyPayments then
        Business.DailyPayments = {}
    end
    
    if not Business.DailyPayments[business.id] then
        Business.DailyPayments[business.id] = {}
    end
    
    Business.DailyPayments[business.id][rank] = amount
    
    Framework.Notify(source, "Pago diario para " .. rank .. " actualizado a: $" .. amount, 'success')
    
    return true
end

-- Obtener pago diario
Business.GetDailyPayment = function(businessId, rank)
    if Business.DailyPayments and Business.DailyPayments[businessId] then
        return Business.DailyPayments[businessId][rank] or Config.DefaultDailyPay[rank]
    end
    return Config.DefaultDailyPay[rank]
end

-- Pagar salarios
Business.PaySalaries = function()
    local businesses = MySQL.query.await('SELECT id FROM mechanic_businesses WHERE active = TRUE', {})
    
    for _, business in ipairs(businesses) do
        local members = Database.GetBusinessMembers(business.id)
        local balance = Database.GetBankBalance(business.id)
        local totalPay = 0
        
        -- Calcular total a pagar
        for _, member in ipairs(members) do
            local dailyPay = Business.GetDailyPayment(business.id, member.rank)
            totalPay = totalPay + dailyPay
        end
        
        -- Verificar si hay suficiente dinero
        if balance >= totalPay then
            for _, member in ipairs(members) do
                local dailyPay = Business.GetDailyPayment(business.id, member.rank)
                
                -- Retirar del banco
                Database.UpdateBankBalance(business.id, -dailyPay, 'salary', 
                    "Salario diario", member.member_identifier)
                
                -- Buscar jugador en línea para pagarle
                local players = Framework.GetPlayers()
                for _, playerId in ipairs(players) do
                    local player = Framework.GetPlayerBySource(playerId)
                    if player and Framework.GetIdentifier(player) == member.member_identifier then
                        Framework.AddMoney(playerId, 'money', dailyPay)
                        Framework.Notify(playerId, "Salario diario recibido: $" .. dailyPay, 'success')
                        break
                    end
                end
            end
        end
    end
end

-- Programar pagos diarios (cada 24 horas)
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(24 * 60 * 60 * 1000) -- 24 horas
        Business.PaySalaries()
    end
end)

return Business