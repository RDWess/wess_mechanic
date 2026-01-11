-- Eventos principales del servidor

-- Inicialización
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    print('[MECANICO] Sistema de mecánico iniciado')
end)

-- Crear negocio (admin)
RegisterNetEvent('mechanic:createBusiness')
AddEventHandler('mechanic:createBusiness', function(businessName, bossIdentifier)
    local source = source
    
    if not Framework.IsAdmin(source) then
        Framework.Notify(source, "No tienes permisos de administrador", 'error')
        return
    end
    
    local success, result, jobName = Business.CreateNew(source, businessName, bossIdentifier)
    
    if success then
        Framework.Notify(source, string.format(Locale['business_created'], businessName), 'success')
        
        -- Enviar confirmación al admin
        TriggerClientEvent('mechanic:businessCreated', source, {
            id = result,
            name = businessName,
            jobName = jobName,
            bossIdentifier = bossIdentifier
        })
    else
        Framework.Notify(source, result, 'error')
    end
end)

-- Añadir punto de trabajo
RegisterNetEvent('mechanic:addWorkPoint')
AddEventHandler('mechanic:addWorkPoint', function(pointType, coords)
    local source = source
    local business = Business.GetPlayerBusiness(source)
    
    if not business then
        Framework.Notify(source, Locale['no_business'], 'error')
        return
    end
    
    if not Members.HasPermission(source, 'create_points') then
        Framework.Notify(source, Locale['no_permission'], 'error')
        return
    end
    
    local success = Database.AddPoint(business.id, pointType, coords, 3.0)
    
    if success then
        Framework.Notify(source, Locale['point_created'], 'success')
        
        -- Sincronizar con todos los miembros
        TriggerClientEvent('mechanic:syncPoints', -1, Database.GetBusinessPoints(business.id))
    else
        Framework.Notify(source, "Error al crear punto", 'error')
    end
end)

-- Crear zona segura
RegisterNetEvent('mechanic:createSafeZone')
AddEventHandler('mechanic:createSafeZone', function(corners)
    local source = source
    local business = Business.GetPlayerBusiness(source)
    
    if not business then
        Framework.Notify(source, Locale['no_business'], 'error')
        return
    end
    
    if not Members.HasPermission(source, 'create_zones') then
        Framework.Notify(source, Locale['no_permission'], 'error')
        return
    end
    
    local success = Database.CreateSafeZone(business.id, corners)
    
    if success then
        Framework.Notify(source, Locale['zone_created'], 'success')
        
        -- Sincronizar con todos los miembros
        TriggerClientEvent('mechanic:syncSafeZones', -1, Database.GetBusinessSafeZones(business.id))
    else
        Framework.Notify(source, "Error al crear zona", 'error')
    end
end)

-- Enviar factura
RegisterNetEvent('mechanic:sendInvoice')
AddEventHandler('mechanic:sendInvoice', function(businessId, customization, amount)
    local source = source
    
    local success, invoiceId = Invoices.CreateNew(source, businessId, customization, amount)
    
    if success then
        Framework.Notify(source, Locale['invoice_sent'], 'success')
        
        -- Enviar confirmación al cliente
        TriggerClientEvent('mechanic:invoiceSent', source, invoiceId)
    else
        Framework.Notify(source, invoiceId, 'error') -- invoiceId contiene el mensaje de error
    end
end)

-- Reclamar factura
RegisterNetEvent('mechanic:claimInvoice')
AddEventHandler('mechanic:claimInvoice', function(invoiceId)
    local source = source
    
    local success, invoice = Invoices.Claim(source, invoiceId)
    
    if success then
        Framework.Notify(source, "Factura reclamada", 'success')
        
        -- Enviar datos para el HUD
        TriggerClientEvent('mechanic:showWorkHUD', source, invoice)
    else
        Framework.Notify(source, invoice, 'error')
    end
end)

-- Completar factura
RegisterNetEvent('mechanic:completeInvoice')
AddEventHandler('mechanic:completeInvoice', function(invoiceId)
    local source = source
    
    local success = Invoices.Complete(source, invoiceId)
    
    if success then
        Framework.Notify(source, Locale['work_completed'], 'success')
        
        -- Ocultar HUD de trabajo
        TriggerClientEvent('mechanic:hideWorkHUD', source)
    else
        Framework.Notify(source, "Error al completar factura", 'error')
    end
end)

-- Añadir miembro
RegisterNetEvent('mechanic:addMember')
AddEventHandler('mechanic:addMember', function(targetSource, rank)
    local source = source
    
    local success, errorMsg = Business.AddMember(source, targetSource, rank)
    
    if not success then
        Framework.Notify(source, errorMsg, 'error')
    end
end)

-- Depositar en banco
RegisterNetEvent('mechanic:depositToBank')
AddEventHandler('mechanic:depositToBank', function(amount)
    local source = source
    
    local success, errorMsg = Business.DepositToBank(source, amount)
    
    if not success then
        Framework.Notify(source, errorMsg, 'error')
    end
end)

-- Retirar del banco
RegisterNetEvent('mechanic:withdrawFromBank')
AddEventHandler('mechanic:withdrawFromBank', function(amount)
    local source = source
    
    local success, errorMsg = Business.WithdrawFromBank(source, amount)
    
    if not success then
        Framework.Notify(source, errorMsg, 'error')
    end
end)

-- Enviar mensaje al chat del negocio
RegisterNetEvent('mechanic:sendBusinessMessage')
AddEventHandler('mechanic:sendBusinessMessage', function(message)
    local source = source
    
    local success, onlineCount = Members.SendBusinessMessage(source, message)
    
    if success then
        Framework.Notify(source, "Mensaje enviado a " .. onlineCount .. " miembros", 'info')
    else
        Framework.Notify(source, "Error al enviar mensaje", 'error')
    end
end)

-- Obtener información del negocio
RegisterNetEvent('mechanic:getBusinessInfo')
AddEventHandler('mechanic:getBusinessInfo', function()
    local source = source
    
    local business = Business.GetPlayerBusiness(source)
    if not business then
        TriggerClientEvent('mechanic:noBusiness', source)
        return
    end
    
    local members = Members.GetAll(business.id)
    local invoices = Invoices.GetBusinessInvoices(business.id, 'pending')
    local top = Business.GetInvoiceTop(business.id)
    local balance = Database.GetBankBalance(business.id)
    local transactions = Business.GetRecentTransactions(business.id, 10)
    local memberInfo = Members.GetFullInfo(source)
    
    TriggerClientEvent('mechanic:receiveBusinessInfo', source, {
        business = business,
        members = members,
        pendingInvoices = invoices,
        invoiceTop = top,
        bankBalance = balance,
        recentTransactions = transactions,
        memberInfo = memberInfo
    })
end)

-- Callbacks
lib.callback.register('mechanic:getBusinessData', function(source)
    local business = Business.GetPlayerBusiness(source)
    if not business then return nil end
    
    return {
        id = business.id,
        name = business.name,
        rank = business.rank,
        balance = Database.GetBankBalance(business.id)
    }
end)

lib.callback.register('mechanic:getInvoices', function(source, status)
    local business = Business.GetPlayerBusiness(source)
    if not business then return {} end
    
    return Invoices.GetBusinessInvoices(business.id, status)
end)

lib.callback.register('mechanic:getMembers', function(source)
    local business = Business.GetPlayerBusiness(source)
    if not business then return {} end
    
    return Members.GetAll(business.id)
end)

lib.callback.register('mechanic:getCustomerInvoices', function(source)
    local player = Framework.GetPlayerBySource(source)
    if not player then return {} end
    
    return Invoices.GetCustomerInvoices(Framework.GetIdentifier(player))
end)

-- Comandos de consola
RegisterCommand('paymechanics', function(source, args)
    if source == 0 then
        Business.PaySalaries()
        print('[MECANICO] Salarios pagados manualmente')
    end
end, true)

-- Exportaciones
exports('GetBusiness', Business.GetPlayerBusiness)
exports('GetInvoices', function(source, status)
    local business = Business.GetPlayerBusiness(source)
    if business then
        return Invoices.GetBusinessInvoices(business.id, status)
    end
    return {}
end)

exports('AddMember', Business.AddMember)
exports('RemoveMember', Business.RemoveMember)