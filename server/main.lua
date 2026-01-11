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

-- Evento para registrar una nueva factura desde la Tablet
RegisterNetEvent('mechanic:createInvoice', function(data)
    local src = source
    local business = Business.GetPlayerBusiness(src) -- Obtenemos el negocio automáticamente
    
    if not business then return end

    MySQL.Async.insert('INSERT INTO mechanic_invoices (business_id, customer_name, vehicle_model, amount, status, created_at) VALUES (?, ?, ?, ?, ?, NOW())', {
        business.id,     
        data.clientName, 
        data.vehicle,    
        data.amount,     
        'pending'        
    }, function(id)
        if id then
            TriggerClientEvent('ox_lib:notify', src, {title = 'FACTURACIÓN', description = 'Factura #'..id..' enviada', type = 'success'})
        end
    end)
end)
    
    -- Insertamos en la tabla mechanic_invoices que creaste
    MySQL.Async.insert('INSERT INTO mechanic_invoices (business_id, customer_name, vehicle_model, amount, status, created_at) VALUES (?, ?, ?, ?, ?, NOW())', {
        data.businessId, -- El ID del taller
        data.clientName, -- El nombre que el mecánico escribió en el "Marco" de Figma
        data.vehicle,    -- El modelo del coche
        data.amount,     -- El precio que puso el mecánico
        'pending'        -- Estado inicial
    }, function(id)
        if id then
            TriggerClientEvent('ox_lib:notify', src, {title = 'FACTURACIÓN', description = 'Factura #'..id..' enviada correctamente', type = 'success'})
        end
    end)
end)

-- Callback para el Login de tu diseño de Figma
lib.callback.register('mechanic:tabletLogin', function(source, data)
    local xPlayer = exports.qbx_core:GetPlayer(source)
    local identifier = xPlayer.PlayerData.citizenid

    -- Buscamos si existe la cuenta en la tabla que añadimos al SQL
    local result = MySQL.Sync.fetchAll('SELECT * FROM mechanic_tablet_accounts WHERE identifier = @id AND username = @user AND password = @pass', {
        ['@id'] = identifier,
        ['@user'] = data.usuario,
        ['@pass'] = data.clave
    })

    if result[1] then
        return { success = true, name = result[1].username }
    else
        return { success = false, message = "Usuario o contraseña incorrectos" }
    end
end)

-- Registro de nueva cuenta desde la Tablet
RegisterNetEvent('mechanic:registerTabletAccount', function(data)
    local src = source
    local xPlayer = exports.qbx_core:GetPlayer(src)
    local identifier = xPlayer.PlayerData.citizenid

    -- Verificamos si ya es miembro del negocio antes de dejarlo crear cuenta
    local isMember = MySQL.Sync.fetchScalar('SELECT 1 FROM mechanic_members WHERE member_identifier = ?', {identifier})
    
    if isMember then
        MySQL.Async.execute('INSERT INTO mechanic_tablet_accounts (identifier, username, password) VALUES (?, ?, ?)', {
            identifier, data.usuario, data.clave
        }, function(affectedRows)
            if affectedRows > 0 then
                TriggerClientEvent('ox_lib:notify', src, {title = 'TABLET', description = 'Cuenta de acceso creada', type = 'success'})
            end
        end)
    else
        TriggerClientEvent('ox_lib:notify', src, {title = 'ERROR', description = 'No eres empleado de este taller', type = 'error'})
    end
end)

RegisterNetEvent('mechanic:payRepair', function(businessId, cost)
    local src = source
    local xPlayer = exports.qbx_core:GetPlayer(src)
    local citizenid = xPlayer.PlayerData.citizenid

    -- 1. Quitamos dinero al mecánico o al taller por los materiales
    -- 2. Registramos el movimiento en tu tabla de transacciones
    MySQL.Async.execute('INSERT INTO mechanic_transactions (business_id, member_identifier, transaction_type, amount, description) VALUES (?, ?, ?, ?, ?)', {
        businessId,
        citizenid,
        'withdraw',
        cost,
        'Gasto en materiales de reparación'
    })
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