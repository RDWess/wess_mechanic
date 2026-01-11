-- Cliente principal

local isTabletOpen = false
local currentBusiness = nil
local workPoints = {}
local safeZones = {}
local currentInvoiceHUD = nil
local inSafeZone = false

-- Inicialización
Citizen.CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do
        Citizen.Wait(100)
    end
    
    print('[MECANICO] Cliente inicializado')
    
    -- Cargar puntos del negocio
    LoadBusinessData()
    
    -- Crear blips y marcadores
    CreateBlips()
    
    -- Iniciar bucles
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(0)
            HandleWorkPoints()
            HandleSafeZones()
            HandleTabletKeybind()
        end
    end)
end)

-- Cargar datos del negocio
function LoadBusinessData()
    lib.callback('mechanic:getBusinessData', false, function(businessData)
        if businessData then
            currentBusiness = businessData
            print('[MECANICO] Negocio cargado: ' .. businessData.name)
            
            -- Solicitar sincronización de puntos
            TriggerServerEvent('mechanic:requestSyncPoints')
        else
            print('[MECANICO] No eres miembro de un negocio')
        end
    end)
end

-- Crear blips
function CreateBlips()
    if not currentBusiness then return end
    
    -- Blip del negocio
    local blip = AddBlipForCoord(0.0, 0.0, 0.0) -- Coordenadas se actualizarán con puntos
    SetBlipSprite(blip, 446)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, 0.8)
    SetBlipColour(blip, 5)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(currentBusiness.name)
    EndTextCommandSetBlipName(blip)
end

-- Manejar puntos de trabajo
function HandleWorkPoints()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    
    for _, point in ipairs(workPoints) do
        if point.point_type == 'work' then
            local distance = #(playerCoords - point.coords)
            
            if distance < point.radius then
                DrawMarker(Config.MarkerType, point.coords.x, point.coords.y, point.coords.z - 0.98,
                    0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                    Config.MarkerSize.x, Config.MarkerSize.y, Config.MarkerSize.z,
                    Config.MarkerColor.r, Config.MarkerColor.g, Config.MarkerColor.b, Config.MarkerColor.a,
                    false, true, 2, false, nil, nil, false)
                
                if distance < 1.5 then
                    ShowHelpNotification("Presiona ~INPUT_CONTEXT~ para personalizar vehículo")
                    
                    if IsControlJustReleased(0, 38) then -- E key
                        if IsPedInAnyVehicle(playerPed, false) then
                            OpenVehicleEditor()
                        else
                            ShowNotification("Debes estar en un vehículo", 'error')
                        end
                    end
                end
            end
        end
    end
end

-- Manejar zonas seguras
function HandleSafeZones()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local wasInSafeZone = inSafeZone
    
    inSafeZone = false
    
    for _, zone in ipairs(safeZones) do
        if IsPointInPolygon(playerCoords, zone.coords) then
            inSafeZone = true
            
            -- Control de velocidad
            if IsPedInAnyVehicle(playerPed, false) then
                local vehicle = GetVehiclePedIsIn(playerPed, false)
                local speed = GetEntitySpeed(vehicle) * 3.6 -- Convertir a km/h
                
                if speed > Config.SafeZoneSpeed then
                    SetVehicleMaxSpeed(vehicle, Config.SafeZoneSpeed / 3.6)
                end
            end
            
            -- Deshabilitar armas
            if Config.DisableWeaponsInZone then
                DisablePlayerFiring(PlayerId(), true)
                SetCurrentPedWeapon(playerPed, `WEAPON_UNARMED`, true)
            end
            
            -- Remover máscara
            if Config.RemoveMaskInZone then
                ClearPedProp(playerPed, 0)
            end
            
            break
        end
    end
    
    -- Restaurar velocidad al salir
    if wasInSafeZone and not inSafeZone then
        if IsPedInAnyVehicle(playerPed, false) then
            local vehicle = GetVehiclePedIsIn(playerPed, false)
            SetVehicleMaxSpeed(vehicle, 0.0) -- 0.0 = sin límite
        end
    end
    
    -- Notificaciones de entrada/salida
    if inSafeZone and not wasInSafeZone then
        ShowNotification(Locale['safe_zone_entered'], 'info')
        if Config.DisableWeaponsInZone then
            ShowNotification(Locale['weapons_disabled'], 'warning')
        end
        ShowNotification(Locale['speed_limit']:format(Config.SafeZoneSpeed), 'info')
    elseif not inSafeZone and wasInSafeZone then
        ShowNotification(Locale['safe_zone_exited'], 'info')
    end
end

-- Manejar tecla de tablet
function HandleTabletKeybind()
    if IsControlJustReleased(0, 167) then -- F6
        if not isTabletOpen then
            OpenMechanicTablet()
        else
            CloseMechanicTablet()
        end
    end
end

-- Abrir editor de vehículo
function OpenVehicleEditor()
    local playerPed = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(playerPed, false)
    
    if not vehicle or vehicle == 0 then
        ShowNotification(Locale['error_no_vehicle'], 'error')
        return
    end
    
    -- Verificar que el vehículo no esté dañado
    if GetVehicleEngineHealth(vehicle) < 0 or GetVehicleBodyHealth(vehicle) < 0 then
        ShowNotification(Locale['error_vehicle_damaged'], 'error')
        return
    end
    
    -- Obtener personalización actual
    local currentCustomization = lib.getVehicleProperties(vehicle)
    
    -- Configurar opciones del menú
    local options = {
        {
            label = "Pintura",
            description = "Cambiar color del vehículo",
            icon = "palette",
            args = { category = 'color' }
        },
        {
            label = "Neumáticos",
            description = "Cambiar tipo de neumáticos",
            icon = "tire",
            args = { category = 'tires' }
        },
        {
            label = "Ventanas",
            description = "Tinte de ventanas",
            icon = "car",
            args = { category = 'windows' }
        },
        {
            label = "Placa",
            description = "Personalizar placa",
            icon = "id-card",
            args = { category = 'plate' }
        }
    }
    
    -- Mostrar menú de categorías
    lib.registerContext({
        id = 'vehicle_editor_categories',
        title = Locale['vehicle_editor'],
        options = options
    })
    
    lib.showContext('vehicle_editor_categories')
    
    -- Esperar selección
    while true do
        Citizen.Wait(0)
        local selected = lib.getOpenContextMenu()
        
        if not selected then
            -- Menú cerrado, preguntar si enviar factura
            SendInvoicePrompt(currentCustomization)
            break
        end
    end
end

-- Enviar factura
function SendInvoicePrompt(customization)
    local input = lib.inputDialog('Enviar Factura', {
        {type = 'number', label = 'Monto ($)', required = true, min = Config.MinInvoiceAmount, max = Config.MaxInvoiceAmount}
    })
    
    if not input then return end
    
    local amount = input[1]
    
    if not currentBusiness then
        ShowNotification("No hay negocio disponible", 'error')
        return
    end
    
    -- Enviar al servidor
    TriggerServerEvent('mechanic:sendInvoice', currentBusiness.id, customization, amount)
    
    ShowNotification(Locale['invoice_sent'], 'success')
end

-- Abrir tablet de mecánico
function OpenMechanicTablet()
    if isTabletOpen then return end
    
    -- Verificar si es mecánico
    if not currentBusiness then
        ShowNotification(Locale['not_mechanic'], 'error')
        return
    end
    
    -- Cargar datos
    TriggerServerEvent('mechanic:getBusinessInfo')
    
    -- Abrir interfaz
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openTablet',
        business = currentBusiness,
        apps = GetTabletApps()
    })
    
    isTabletOpen = true
    PlaySoundFrontend(-1, Config.Sounds.open_tablet, "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
    
    -- Mostrar HUD si hay factura reclamada
    if currentInvoiceHUD then
        ShowWorkHUD(currentInvoiceHUD)
    end
end

-- Cerrar tablet
function CloseMechanicTablet()
    if not isTabletOpen then return end
    
    SetNuiFocus(false, false)
    SendNUIMessage({action = 'closeTablet'})
    
    isTabletOpen = false
    PlaySoundFrontend(-1, Config.Sounds.close_tablet, "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
end

-- Obtener aplicaciones de la tablet
function GetTabletApps()
    return {
        {id = 'facturas', label = Locale['app_facturas'], icon = 'receipt', color = '#4299E1'},
        {id = 'reparaciones', label = Locale['app_reparaciones'], icon = 'wrench', color = '#48BB78'},
        {id = 'rendimiento', label = Locale['app_rendimiento'], icon = 'tachometer-alt', color = '#ED8936'},
        {id = 'suspension', label = Locale['app_suspension'], icon = 'car-side', color = '#9F7AEA'},
        {id = 'miembros', label = Locale['app_miembros'], icon = 'users', color = '#38B2AC'},
        {id = 'banco', label = Locale['app_banco'], icon = 'university', color = '#ECC94B'},
        {id = 'pagos', label = Locale['app_pagos'], icon = 'money-bill-wave', color: '#F56565'},
        {id = 'config', label = Locale['app_config'], icon = 'cog', color: '#A0AEC0'}
    }
end

-- Mostrar HUD de trabajo
function ShowWorkHUD(invoice)
    currentInvoiceHUD = invoice
    
    SendNUIMessage({
        action = 'showWorkHUD',
        invoice = invoice
    })
    
    -- También mostrar en pantalla del juego
    Citizen.CreateThread(function()
        while currentInvoiceHUD do
            Citizen.Wait(0)
            
            -- Mostrar información en pantalla
            DrawTextOnScreen(string.format("Trabajo Activo: %s", invoice.vehicle_model), 0.5, 0.1, 0.4)
            DrawTextOnScreen(string.format("Cliente: %s", invoice.customer_name), 0.5, 0.13, 0.3)
            DrawTextOnScreen(string.format("Monto: $%s", invoice.amount), 0.5, 0.16, 0.3)
            DrawTextOnScreen("Presiona ~INPUT_CELLPHONE_UP~ para completar", 0.5, 0.19, 0.25)
            
            -- Completar trabajo con tecla
            if IsControlJustReleased(0, 172) then -- Flecha arriba
                CompleteCurrentWork()
            end
        end
    end)
end

-- Ocultar HUD de trabajo
function HideWorkHUD()
    currentInvoiceHUD = nil
    SendNUIMessage({action = 'hideWorkHUD'})
end

-- Completar trabajo actual
function CompleteCurrentWork()
    if not currentInvoiceHUD then return end
    
    TriggerServerEvent('mechanic:completeInvoice', currentInvoiceHUD.id)
    HideWorkHUD()
end

-- Aplicar personalización
function ApplyCustomization(customization)
    local playerPed = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(playerPed, false)
    
    if vehicle and vehicle ~= 0 then
        lib.setVehicleProperties(vehicle, customization)
        ShowNotification("Personalización aplicada", 'success')
    end
end

-- Función para verificar si un punto está dentro de un polígono
function IsPointInPolygon(point, polygon)
    local oddNodes = false
    local j = #polygon
    
    for i = 1, #polygon do
        if (polygon[i].y < point.y and polygon[j].y >= point.y) or (polygon[j].y < point.y and polygon[i].y >= point.y) then
            if (polygon[i].x + (point.y - polygon[i].y) / (polygon[j].y - polygon[i].y) * (polygon[j].x - polygon[i].x) < point.x) then
                oddNodes = not oddNodes
            end
        end
        j = i
    end
    
    return oddNodes
end

-- Funciones de utilidad
function ShowNotification(message, type)
    if Config.Notify == 'ox' then
        lib.notify({
            title = 'Mecánico',
            description = message,
            type = type or 'info'
        })
    else
        -- Usar framework nativo
        Framework.Notify(message, type)
    end
end

function ShowHelpNotification(text)
    BeginTextCommandDisplayHelp("STRING")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

function DrawTextOnScreen(text, x, y, scale)
    SetTextFont(4)
    SetTextProportional(true)
    SetTextScale(scale, scale)
    SetTextColour(255, 255, 255, 255)
    SetTextDropShadow(0, 0, 0, 0, 255)
    SetTextEdge(2, 0, 0, 0, 255)
    SetTextDropShadow()
    SetTextOutline()
    SetTextEntry("STRING")
    AddTextComponentString(text)
    DrawText(x, y)
end

-- Eventos del servidor
RegisterNetEvent('mechanic:updateJob')
AddEventHandler('mechanic:updateJob', function(jobName, rank)
    -- Actualizar trabajo localmente
    if Config.Framework == 'qbox' or Config.Framework == 'qb' then
        LocalPlayer.state:set('job', {name = jobName, grade = {name = rank}}, true)
    elseif Config.Framework == 'esx' then
        -- Para ESX, se maneja diferente
    end
    
    ShowNotification("Ahora trabajas como: " .. jobName .. " (" .. rank .. ")", 'success')
    LoadBusinessData()
end)

RegisterNetEvent('mechanic:removeJob')
AddEventHandler('mechanic:removeJob', function()
    -- Remover trabajo
    if Config.Framework == 'qbox' or Config.Framework == 'qb' then
        LocalPlayer.state:set('job', {name = 'unemployed', grade = {name = 'unemployed'}}, true)
    end
    
    currentBusiness = nil
    workPoints = {}
    safeZones = {}
    
    ShowNotification("Ya no eres mecánico", 'info')
end)

RegisterNetEvent('mechanic:syncPoints')
AddEventHandler('mechanic:syncPoints', function(points)
    workPoints = points
    print('[MECANICO] Puntos sincronizados: ' .. #points)
end)

RegisterNetEvent('mechanic:syncSafeZones')
AddEventHandler('mechanic:syncSafeZones', function(zones)
    safeZones = zones
    print('[MECANICO] Zonas seguras sincronizadas: ' .. #zones)
end)

RegisterNetEvent('mechanic:invoiceSent')
AddEventHandler('mechanic:invoiceSent', function(invoiceId)
    ShowNotification("Factura #" .. invoiceId .. " enviada al mecánico", 'success')
end)

RegisterNetEvent('mechanic:invoiceClaimed')
AddEventHandler('mechanic:invoiceClaimed', function(invoice)
    ShowWorkHUD(invoice)
end)

RegisterNetEvent('mechanic:showWorkHUD')
AddEventHandler('mechanic:showWorkHUD', function(invoice)
    ShowWorkHUD(invoice)
end)

RegisterNetEvent('mechanic:hideWorkHUD')
AddEventHandler('mechanic:hideWorkHUD', function()
    HideWorkHUD()
end)

RegisterNetEvent('mechanic:applyCustomization')
AddEventHandler('mechanic:applyCustomization', function(customization)
    ApplyCustomization(customization)
end)

RegisterNetEvent('mechanic:receiveBusinessInfo')
AddEventHandler('mechanic:receiveBusinessInfo', function(data)
    SendNUIMessage({
        action = 'updateBusinessInfo',
        data = data
    })
end)

RegisterNetEvent('mechanic:businessMessage')
AddEventHandler('mechanic:businessMessage', function(messageData)
    -- Mostrar notificación de chat
    ShowNotification(string.format("[%s] %s: %s", 
        messageData.business, messageData.sender, messageData.message), 'chat')
    
    -- Enviar a la tablet si está abierta
    if isTabletOpen then
        SendNUIMessage({
            action = 'receiveChatMessage',
            message = messageData
        })
    end
end)

-- Comandos
RegisterCommand('tablet', function()
    OpenMechanicTablet()
end, false)

-- Exportaciones
exports('GetCurrentBusiness', function()
    return currentBusiness
end)

exports('IsInSafeZone', function()
    return inSafeZone
end)

exports('GetWorkPoints', function()
    return workPoints
end)