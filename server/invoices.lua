local Invoices = {}

-- Crear nueva factura
Invoices.CreateNew = function(source, businessId, customization, amount)
    local player = Framework.GetPlayerBySource(source)
    if not player then return false, "Jugador no encontrado" end
    
    -- Obtener información del vehículo
    local ped = GetPlayerPed(source)
    local vehicle = GetVehiclePedIsIn(ped, false)
    
    if not vehicle or vehicle == 0 then
        return false, "Debes estar en un vehículo"
    end
    
    local vehicleModel = GetEntityModel(vehicle)
    local vehiclePlate = GetVehicleNumberPlateText(vehicle)
    
    -- Obtener información del cliente
    local customerData = {
        identifier = Framework.GetIdentifier(player),
        name = Framework.GetPlayerName(source),
        source = source
    }
    
    local vehicleData = {
        model = vehicleModel,
        plate = vehiclePlate,
        entity = vehicle
    }
    
    -- Crear factura en base de datos
    local result = Database.CreateInvoice(businessId, customerData, vehicleData, customization, amount)
    
    if result then
        -- Notificar a todos los mecánicos del negocio
        local members = Database.GetBusinessMembers(businessId)
        for _, member in ipairs(members) do
            local players = Framework.GetPlayers()
            for _, playerId in ipairs(players) do
                local memberPlayer = Framework.GetPlayerBySource(playerId)
                if memberPlayer and Framework.GetIdentifier(memberPlayer) == member.member_identifier then
                    Framework.Notify(playerId, "Nueva factura recibida: $" .. amount, 'info')
                    break
                end
            end
        end
        
        return true, result.insertId
    end
    
    return false, "Error al crear factura"
end

-- Reclamar factura
Invoices.Claim = function(source, invoiceId)
    local player = Framework.GetPlayerBySource(source)
    if not player then return false, "Jugador no encontrado" end
    
    local identifier = Framework.GetIdentifier(player)
    
    -- Verificar que la factura esté pendiente
    local invoice = Database.GetInvoice(invoiceId)
    if not invoice then
        return false, "Factura no encontrada"
    end
    
    if invoice.status ~= 'pending' then
        return false, "Factura ya reclamada o completada"
    end
    
    -- Verificar que el jugador sea del mismo negocio
    local business = Database.GetMemberBusiness(identifier)
    if not business or business.id ~= invoice.business_id then
        return false, "No eres miembro de este negocio"
    end
    
    -- Reclamar factura
    local success = Database.ClaimInvoice(invoiceId, identifier)
    
    if success then
        -- Obtener datos actualizados
        invoice = Database.GetInvoice(invoiceId)
        
        -- Notificar al cliente
        local players = Framework.GetPlayers()
        for _, playerId in ipairs(players) do
            local targetPlayer = Framework.GetPlayerBySource(playerId)
            if targetPlayer and Framework.GetIdentifier(targetPlayer) == invoice.customer_identifier then
                Framework.Notify(playerId, "Tu factura ha sido reclamada por un mecánico", 'info')
                break
            end
        end
        
        -- Enviar datos al cliente para el HUD
        TriggerClientEvent('mechanic:invoiceClaimed', source, invoice)
        
        return true, invoice
    end
    
    return false, "Error al reclamar factura"
end

-- Completar factura
Invoices.Complete = function(source, invoiceId)
    local player = Framework.GetPlayerBySource(source)
    if not player then return false, "Jugador no encontrado" end
    
    local identifier = Framework.GetIdentifier(player)
    
    -- Verificar que la factura esté reclamada por este mecánico
    local invoice = Database.GetInvoice(invoiceId)
    if not invoice then
        return false, "Factura no encontrada"
    end
    
    if invoice.status ~= 'claimed' then
        return false, "Factura no está reclamada"
    end
    
    if invoice.claimed_by ~= identifier then
        return false, "No reclamaste esta factura"
    end
    
    -- Completar factura
    local success = Database.CompleteInvoice(invoiceId)
    
    if success then
        -- Actualizar estadísticas del miembro
        Database.UpdateMemberStats(identifier, invoice.business_id, invoice.amount)
        
        -- Depositar dinero en el banco del negocio
        Database.UpdateBankBalance(invoice.business_id, invoice.amount, 'invoice', 
            "Factura completada #" .. invoiceId, identifier)
        
        -- Notificar al cliente
        local players = Framework.GetPlayers()
        for _, playerId in ipairs(players) do
            local targetPlayer = Framework.GetPlayerBySource(playerId)
            if targetPlayer and Framework.GetIdentifier(targetPlayer) == invoice.customer_identifier then
                Framework.Notify(playerId, "Tu factura ha sido completada: $" .. invoice.amount, 'success')
                
                -- Opcional: Aplicar personalización al vehículo
                -- Esto requeriría que el cliente esté en su vehículo
                TriggerClientEvent('mechanic:applyCustomization', playerId, invoice.customization)
                break
            end
        end
        
        -- Notificar al mecánico
        Framework.Notify(source, "Factura completada: $" .. invoice.amount, 'success')
        
        return true
    end
    
    return false, "Error al completar factura"
end

-- Obtener facturas del negocio
Invoices.GetBusinessInvoices = function(businessId, status)
    return Database.GetBusinessInvoices(businessId, status)
end

-- Obtener facturas del cliente
Invoices.GetCustomerInvoices = function(customerIdentifier)
    return MySQL.query.await([[
        SELECT i.*, b.name as business_name
        FROM mechanic_invoices i
        JOIN mechanic_businesses b ON i.business_id = b.id
        WHERE i.customer_identifier = ?
        ORDER BY i.created_at DESC
    ]], {customerIdentifier})
end

-- Cancelar factura
Invoices.Cancel = function(source, invoiceId)
    local player = Framework.GetPlayerBySource(source)
    if not player then return false, "Jugador no encontrado" end
    
    local identifier = Framework.GetIdentifier(player)
    
    -- Verificar que sea el cliente o un mecánico con permisos
    local invoice = Database.GetInvoice(invoiceId)
    if not invoice then
        return false, "Factura no encontrada"
    end
    
    if invoice.customer_identifier ~= identifier then
        -- Verificar si es mecánico del negocio
        local business = Database.GetMemberBusiness(identifier)
        if not business or business.id ~= invoice.business_id then
            return false, "No tienes permiso para cancelar esta factura"
        end
        
        if business.rank ~= 'boss' and business.rank ~= 'manager' then
            return false, "No tienes permiso para cancelar facturas"
        end
    end
    
    -- Solo se puede cancelar facturas pendientes
    if invoice.status ~= 'pending' then
        return false, "No se puede cancelar una factura en proceso"
    end
    
    -- Cancelar factura
    MySQL.query.await([[
        UPDATE mechanic_invoices 
        SET status = 'cancelled' 
        WHERE id = ?
    ]], {invoiceId})
    
    Framework.Notify(source, "Factura cancelada", 'info')
    
    return true
end

return Invoices