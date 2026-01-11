-- Sistema de tablet

local Tablet = {}

-- Inicializar NUI
function Tablet.Init()
    RegisterNUICallback('close', function(data, cb)
        CloseMechanicTablet()
        cb('ok')
    end)
    
    RegisterNUICallback('openApp', function(data, cb)
        Tablet.OpenApp(data.appId)
        cb('ok')
    end)
    
    RegisterNUICallback('claimInvoice', function(data, cb)
        TriggerServerEvent('mechanic:claimInvoice', data.invoiceId)
        cb('ok')
    end)
    
    RegisterNUICallback('completeInvoice', function(data, cb)
        TriggerServerEvent('mechanic:completeInvoice', data.invoiceId)
        cb('ok')
    end)
    
    RegisterNUICallback('sendMessage', function(data, cb)
        TriggerServerEvent('mechanic:sendBusinessMessage', data.message)
        cb('ok')
    end)
    
    RegisterNUICallback('depositMoney', function(data, cb)
        TriggerServerEvent('mechanic:depositToBank', data.amount)
        cb('ok')
    end)
    
    RegisterNUICallback('withdrawMoney', function(data, cb)
        TriggerServerEvent('mechanic:withdrawFromBank', data.amount)
        cb('ok')
    end)
    
    RegisterNUICallback('addMember', function(data, cb)
        -- Buscar jugador más cercano
        local closestPlayer = GetClosestPlayer()
        if closestPlayer then
            TriggerServerEvent('mechanic:addMember', GetPlayerServerId(closestPlayer), data.rank)
        else
            ShowNotification("No hay jugadores cercanos", 'error')
        end
        cb('ok')
    end)
    
    RegisterNUICallback('removeMember', function(data, cb)
        TriggerServerEvent('mechanic:removeMember', data.memberId)
        cb('ok')
    end)
    
    RegisterNUICallback('updatePayments', function(data, cb)
        TriggerServerEvent('mechanic:updateDailyPayments', data.rank, data.amount)
        cb('ok')
    end)
    
    print('[MECANICO] Tablet NUI inicializada')
end

-- Abrir aplicación específica
function Tablet.OpenApp(appId)
    if appId == 'facturas' then
        Tablet.OpenInvoicesApp()
    elseif appId == 'reparaciones' then
        Tablet.OpenRepairsApp()
    elseif appId == 'rendimiento' then
        Tablet.OpenPerformanceApp()
    elseif appId == 'suspension' then
        Tablet.OpenSuspensionApp()
    elseif appId == 'miembros' then
        Tablet.OpenMembersApp()
    elseif appId == 'banco' then
        Tablet.OpenBankApp()
    elseif appId == 'pagos' then
        Tablet.OpenPaymentsApp()
    elseif appId == 'config' then
        Tablet.OpenConfigApp()
    end
end

-- Aplicación de facturas
function Tablet.OpenInvoicesApp()
    lib.callback('mechanic:getInvoices', false, function(invoices)
        SendNUIMessage({
            action = 'openInvoices',
            invoices = invoices
        })
    end, 'pending')
end

-- Aplicación de reparaciones
function Tablet.OpenRepairsApp()
    local playerPed = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(playerPed, false)
    
    if not vehicle or vehicle == 0 then
        ShowNotification("Debes estar en un vehículo", 'error')
        return
    end
    
    local options = {
        {
            label = "Reparar Vehículo",
            description = "Reparar completamente el vehículo",
            icon = "wrench",
            args = { action = 'repair' }
        },
        {
            label = "Limpiar Vehículo",
            description = "Limpiar el vehículo por completo",
            icon = "spray-can",
            args = { action = 'clean' }
        },
        {
            label = "Reparar Motor",
            description = "Reparar solo el motor",
            icon = "cogs",
            args = { action = 'repair_engine' }
        },
        {
            label = "Reparar Carrocería",
            description = "Reparar solo la carrocería",
            icon = "car-crash",
            args = { action = 'repair_body' }
        }
    }
    
    lib.registerContext({
        id = 'repairs_menu',
        title = "Reparaciones",
        options = options
    })
    
    lib.showContext('repairs_menu')
    
    -- Manejar selección
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(0)
            local selected = lib.getOpenContextMenu()
            
            if not selected then break end
            
            local action = selected.args.action
            
            if action == 'repair' then
                SetVehicleFixed(vehicle)
                SetVehicleDeformationFixed(vehicle)
                SetVehicleUndriveable(vehicle, false)
                ShowNotification("Vehículo reparado", 'success')
            elseif action == 'clean' then
                SetVehicleDirtLevel(vehicle, 0.0)
                WashDecalsFromVehicle(vehicle, 1.0)
                ShowNotification("Vehículo limpiado", 'success')
            elseif action == 'repair_engine' then
                SetVehicleEngineHealth(vehicle, 1000.0)
                ShowNotification("Motor reparado", 'success')
            elseif action == 'repair_body' then
                SetVehicleBodyHealth(vehicle, 1000.0)
                ShowNotification("Carrocería reparada", 'success')
            end
            
            break
        end
    end)
end

-- Aplicación de rendimiento
function Tablet.OpenPerformanceApp()
    local playerPed = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(playerPed, false)
    
    if not vehicle or vehicle == 0 then
        ShowNotification("Debes estar en un vehículo", 'error')
        return
    end
    
    local currentTurbo = IsToggleModOn(vehicle, 18)
    local currentEngine = GetVehicleMod(vehicle, 11)
    local currentBrakes = GetVehicleMod(vehicle, 12)
    local currentTransmission = GetVehicleMod(vehicle, 13)
    
    local options = {
        {
            label = "Turbo: " .. (currentTurbo and "Instalado" or "No instalado"),
            description = "Instalar/remover turbo",
            icon = "bolt",
            args = { action = 'turbo' }
        },
        {
            label = "Motor Nivel: " .. currentEngine,
            description = "Mejorar motor",
            icon = "cogs",
            args = { action = 'engine' }
        },
        {
            label = "Frenos Nivel: " .. currentBrakes,
            description = "Mejorar frenos",
            icon = "stop-circle",
            args = { action = 'brakes' }
        },
        {
            label = "Transmisión Nivel: " .. currentTransmission,
            description = "Mejorar transmisión",
            icon = "exchange-alt",
            args = { action = 'transmission' }
        }
    }
    
    lib.registerContext({
        id = 'performance_menu',
        title = "Rendimiento",
        options = options
    })
    
    lib.showContext('performance_menu')
    
    -- Manejar selección
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(0)
            local selected = lib.getOpenContextMenu()
            
            if not selected then break end
            
            local action = selected.args.action
            local maxMod = GetNumVehicleMods(vehicle, 11) -- Usar motor como referencia
            
            if action == 'turbo' then
                ToggleVehicleMod(vehicle, 18, not currentTurbo)
                ShowNotification("Turbo " .. (not currentTurbo and "instalado" or "removido"), 'success')
            elseif action == 'engine' then
                local nextLevel = (currentEngine + 1) % (maxMod + 1)
                SetVehicleMod(vehicle, 11, nextLevel)
                ShowNotification("Motor mejorado a nivel " .. nextLevel, 'success')
            elseif action == 'brakes' then
                local nextLevel = (currentBrakes + 1) % (maxMod + 1)
                SetVehicleMod(vehicle, 12, nextLevel)
                ShowNotification("Frenos mejorados a nivel " .. nextLevel, 'success')
            elseif action == 'transmission' then
                local nextLevel = (currentTransmission + 1) % (maxMod + 1)
                SetVehicleMod(vehicle, 13, nextLevel)
                ShowNotification("Transmisión mejorada a nivel " .. nextLevel, 'success')
            end
            
            break
        end
    end)
end

-- Aplicación de suspensión
function Tablet.OpenSuspensionApp()
    local playerPed = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(playerPed, false)
    
    if not vehicle or vehicle == 0 then
        ShowNotification("Debes estar en un vehículo", 'error')
        return
    end
    
    local options = {
        {
            label = "Separación Llantas Delanteras",
            description = "Ajustar separación de llantas delanteras",
            icon = "expand-arrows-alt",
            args = { action = 'front_wheel_offset' }
        },
        {
            label = "Separación Llantas Traseras",
            description = "Ajustar separación de llantas traseras",
            icon = "expand-arrows-alt",
            args = { action = 'rear_wheel_offset' }
        },
        {
            label = "Inclinación Delantera",
            description = "Ajustar inclinación de llantas delanteras",
            icon = "tire-pressure-warning",
            args = { action = 'front_wheel_camber' }
        },
        {
            label = "Inclinación Trasera",
            description = "Ajustar inclinación de llantas traseras",
            icon = "tire-pressure-warning",
            args = { action = 'rear_wheel_camber' }
        },
        {
            label = "Altura Suspensión",
            description = "Ajustar altura del vehículo",
            icon = "car-side",
            args = { action = 'suspension_height' }
        }
    }
    
    lib.registerContext({
        id = 'suspension_menu',
        title = "Suspensión y Llantas",
        options = options
    })
    
    lib.showContext('suspension_menu')
    
    -- Manejar selección
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(0)
            local selected = lib.getOpenContextMenu()
            
            if not selected then break end
            
            local action = selected.args.action
            
            if action:find('offset') then
                AdjustWheelOffset(vehicle, action)
            elseif action:find('camber') then
                AdjustWheelCamber(vehicle, action)
            elseif action == 'suspension_height' then
                AdjustSuspensionHeight(vehicle)
            end
            
            break
        end
    end)
end

-- Ajustar separación de llantas
function AdjustWheelOffset(vehicle, wheelType)
    local input = lib.inputDialog("Separación de Llantas", {
        {type = 'number', label = 'Valor (-1.0 a 1.0)', default = 0.0, required = true, min = -1.0, max = 1.0, step = 0.1}
    })
    
    if not input then return end
    
    local value = input[1]
    
    if wheelType == 'front_wheel_offset' then
        SetVehicleWheelXOffset(vehicle, 0, value)
        SetVehicleWheelXOffset(vehicle, 1, value)
    else
        SetVehicleWheelXOffset(vehicle, 2, value)
        SetVehicleWheelXOffset(vehicle, 3, value)
    end
    
    ShowNotification("Separación ajustada: " .. value, 'success')
end

-- Ajustar inclinación de llantas
function AdjustWheelCamber(vehicle, wheelType)
    local input = lib.inputDialog("Inclinación de Llantas", {
        {type = 'number', label = 'Valor (-1.0 a 1.0)', default = 0.0, required = true, min = -1.0, max = 1.0, step = 0.1}
    })
    
    if not input then return end
    
    local value = input[1]
    
    if wheelType == 'front_wheel_camber' then
        SetVehicleWheelCamber(vehicle, 0, value)
        SetVehicleWheelCamber(vehicle, 1, value)
    else
        SetVehicleWheelCamber(vehicle, 2, value)
        SetVehicleWheelCamber(vehicle, 3, value)
    end
    
    ShowNotification("Inclinación ajustada: " .. value, 'success')
end

-- Ajustar altura de suspensión
function AdjustSuspensionHeight(vehicle)
    local input = lib.inputDialog("Altura de Suspensión", {
        {type = 'number', label = 'Nivel (-1 a 1)', default = 0, required = true, min = -1, max = 1}
    })
    
    if not input then return end
    
    local level = input[1]
    SetVehicleMod(vehicle, 15, level)
    ShowNotification("Altura de suspensión ajustada: " .. level, 'success')
end

-- Aplicación de miembros
function Tablet.OpenMembersApp()
    lib.callback('mechanic:getMembers', false, function(members)
        SendNUIMessage({
            action = 'openMembers',
            members = members
        })
    end)
end

-- Aplicación de banco
function Tablet.OpenBankApp()
    local business = exports['mechanicsystem']:GetCurrentBusiness()
    if not business then return end
    
    lib.callback('mechanic:getBusinessData', false, function(businessData)
        SendNUIMessage({
            action = 'openBank',
            business = businessData
        })
    end)
end

-- Aplicación de pagos
function Tablet.OpenPaymentsApp()
    SendNUIMessage({
        action = 'openPayments',
        defaultPayments = Config.DefaultDailyPay
    })
end

-- Aplicación de configuración
function Tablet.OpenConfigApp()
    -- Aquí irían opciones de configuración personal
    ShowNotification("Configuración - Próximamente", 'info')
end

-- Obtener jugador más cercano
function GetClosestPlayer()
    local players = GetPlayers()
    local closestDistance = -1
    local closestPlayer = -1
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    
    for _, player in ipairs(players) do
        local targetPed = GetPlayerPed(player)
        local targetCoords = GetEntityCoords(targetPed)
        local distance = #(playerCoords - targetCoords)
        
        if distance < 3.0 and (closestDistance == -1 or distance < closestDistance) then
            closestDistance = distance
            closestPlayer = player
        end
    end
    
    return closestPlayer
end

-- Inicializar al cargar
Citizen.CreateThread(function()
    Citizen.Wait(1000)
    Tablet.Init()
end)

return Tablet