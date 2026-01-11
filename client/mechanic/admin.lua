-- Sistema de administración para mecánicos

-- Comando para crear negocio
RegisterCommand(Config.AdminCommands.crear_mecanico, function(source, args)
    if not Framework.IsAdmin(source) then
        ShowNotification(Locale['no_permission'], 'error')
        return
    end
    
    CreateBusinessMenu()
end, false)

-- Comando para gestionar puntos
RegisterCommand(Config.AdminCommands.puntos_mecanico, function(source, args)
    local business = exports['mechanicsystem']:GetCurrentBusiness()
    if not business then
        ShowNotification(Locale['no_business'], 'error')
        return
    end
    
    ManagePointsMenu()
end, false)

-- Menú para crear negocio
function CreateBusinessMenu()
    local input = lib.inputDialog(Locale['create_business_title'], {
        {type = 'input', label = Locale['business_name'], required = true, min = 3, max = 50},
        {type = 'number', label = Locale['boss_id'], required = true, min = 1}
    })
    
    if not input then return end
    
    local businessName = input[1]
    local bossId = input[2]
    
    -- Verificar que el jugador objetivo exista
    local targetPlayer = GetPlayerFromServerId(bossId)
    if not targetPlayer or targetPlayer == -1 then
        ShowNotification(Locale['error_invalid_id'], 'error')
        return
    end
    
    -- Obtener identificador del jugador
    local targetIdentifier = GetPlayerIdentifier(bossId)
    if not targetIdentifier then
        ShowNotification("No se pudo obtener identificador del jugador", 'error')
        return
    end
    
    -- Crear negocio
    TriggerServerEvent('mechanic:createBusiness', businessName, targetIdentifier)
end

-- Menú para gestionar puntos
function ManagePointsMenu()
    local options = {
        {
            label = Locale['add_point'],
            description = "Añadir nuevo punto de trabajo",
            icon = "map-marker-alt",
            args = { action = 'add_point' }
        },
        {
            label = Locale['delete_nearby'],
            description = "Eliminar punto cercano",
            icon = "trash-alt",
            args = { action = 'delete_nearby' }
        },
        {
            label = Locale['create_zone'],
            description = "Crear zona segura (4 esquinas)",
            icon = "draw-polygon",
            args = { action = 'create_zone' }
        }
    }
    
    lib.registerContext({
        id = 'manage_points_menu',
        title = Locale['manage_points'],
        options = options
    })
    
    lib.showContext('manage_points_menu')
    
    -- Manejar selección
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(0)
            local selected = lib.getOpenContextMenu()
            
            if not selected then break end
            
            local action = selected.args.action
            
            if action == 'add_point' then
                AddWorkPoint()
                break
            elseif action == 'delete_nearby' then
                DeleteNearbyPoint()
                break
            elseif action == 'create_zone' then
                CreateSafeZone()
                break
            end
        end
    end)
end

-- Añadir punto de trabajo
function AddWorkPoint()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    
    local input = lib.inputDialog("Tipo de Punto", {
        {type = 'select', label = 'Tipo', options = {
            {value = 'work', label = 'Punto de Trabajo'},
            {value = 'storage', label = 'Almacenamiento'}
        }, required = true},
        {type = 'number', label = 'Radio (metros)', default = 3.0, required = true, min = 1.0, max = 10.0}
    })
    
    if not input then return end
    
    local pointType = input[1]
    local radius = input[2]
    
    -- Crear punto
    TriggerServerEvent('mechanic:addWorkPoint', pointType, {
        x = playerCoords.x,
        y = playerCoords.y,
        z = playerCoords.z
    })
    
    ShowNotification("Punto añadido en tu ubicación actual", 'success')
end

-- Eliminar punto cercano
function DeleteNearbyPoint()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local nearbyPoints = {}
    
    -- Obtener puntos del negocio
    local business = exports['mechanicsystem']:GetCurrentBusiness()
    if not business then return end
    
    local points = exports['mechanicsystem']:GetWorkPoints()
    
    -- Buscar puntos cercanos
    for _, point in ipairs(points) do
        local distance = #(playerCoords - point.coords)
        if distance < 10.0 then
            table.insert(nearbyPoints, {
                label = string.format("Punto #%s (%s) - %.1fm", 
                    point.id, point.point_type, distance),
                value = point.id
            })
        end
    end
    
    if #nearbyPoints == 0 then
        ShowNotification("No hay puntos cercanos", 'info')
        return
    end
    
    -- Mostrar menú de selección
    local input = lib.inputDialog("Eliminar Punto Cercano", {
        {type = 'select', label = 'Seleccionar Punto', options = nearbyPoints, required = true}
    })
    
    if not input then return end
    
    local pointId = input[1]
    
    -- Eliminar punto (esto requeriría un evento del servidor)
    TriggerServerEvent('mechanic:deletePoint', pointId)
    ShowNotification("Punto eliminado", 'success')
end

-- Crear zona segura
function CreateSafeZone()
    ShowNotification(Locale['set_corners'], 'info')
    
    local corners = {}
    local markerPoints = {}
    
    -- Función para dibujar marcadores
    local function DrawZoneMarkers()
        for i, corner in ipairs(corners) do
            DrawMarker(1, corner.x, corner.y, corner.z - 1.0,
                0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                1.0, 1.0, 1.0,
                0, 255, 0, 100,
                false, true, 2, false, nil, nil, false)
            
            -- Dibujar líneas entre puntos
            if i > 1 then
                local prevCorner = corners[i-1]
                DrawLine(prevCorner.x, prevCorner.y, prevCorner.z,
                         corner.x, corner.y, corner.z,
                         0, 255, 0, 255)
            end
        end
        
        -- Conectar último con primero
        if #corners >= 4 then
            DrawLine(corners[#corners].x, corners[#corners].y, corners[#corners].z,
                     corners[1].x, corners[1].y, corners[1].z,
                     0, 255, 0, 255)
        end
    end
    
    -- Bucle principal
    Citizen.CreateThread(function()
        while #corners < 4 do
            Citizen.Wait(0)
            
            -- Dibujar instrucciones
            DrawTextOnScreen(string.format("Marcar esquina %s/4", #corners + 1), 0.5, 0.2, 0.4)
            DrawTextOnScreen("Presiona ~INPUT_ATTACK~ para marcar", 0.5, 0.23, 0.3)
            DrawTextOnScreen("Presiona ~INPUT_CELLPHONE_CANCEL~ para cancelar", 0.5, 0.26, 0.3)
            
            -- Dibujar marcadores existentes
            DrawZoneMarkers()
            
            -- Control para marcar punto
            if IsControlJustReleased(0, 24) then -- ATTACK
                local playerPed = PlayerPedId()
                local playerCoords = GetEntityCoords(playerPed)
                
                table.insert(corners, {
                    x = playerCoords.x,
                    y = playerCoords.y,
                    z = playerCoords.z
                })
                
                PlaySoundFrontend(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
                ShowNotification(string.format("Esquina %s marcada", #corners), 'success')
            end
            
            -- Cancelar
            if IsControlJustReleased(0, 177) then -- BACKSPACE/CANCEL
                ShowNotification("Creación de zona cancelada", 'error')
                return
            end
        end
        
        -- Confirmar creación
        local confirm = lib.alertDialog({
            header = "Confirmar Zona Segura",
            content = "¿Crear zona segura con los 4 puntos marcados?",
            centered = true,
            cancel = true
        })
        
        if confirm == 'confirm' then
            TriggerServerEvent('mechanic:createSafeZone', corners)
            ShowNotification(Locale['zone_created'], 'success')
        else
            ShowNotification("Creación cancelada", 'info')
        end
    end)
end

-- Función auxiliar para obtener identificador
function GetPlayerIdentifier(serverId)
    local players = GetPlayers()
    for _, player in ipairs(players) do
        if GetPlayerServerId(player) == serverId then
            return GetPlayerIdentifier(player)
        end
    end
    return nil
end