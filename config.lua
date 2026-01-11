Config = {}

-- Detección automática de framework
Config.Framework = nil -- Se detectará automáticamente
Config.Debug = false

-- Configuración general
Config.JobName = "mechanic" -- Nombre del trabajo
Config.TabletItem = "mechanic_tablet" -- Item para abrir tablet
Config.Keybind = "F6" -- Tecla para abrir tablet
Config.Command = "tablet" -- Comando para abrir tablet

-- Configuración de puntos de trabajo
Config.MarkerType = 27
Config.MarkerColor = { r = 0, g = 150, b = 255, a = 100 }
Config.MarkerSize = { x = 1.5, y = 1.5, z = 1.0 }

-- Configuración de zonas seguras
Config.SafeZoneSpeed = 15 -- Velocidad máxima en zona segura (km/h)
Config.DisableWeaponsInZone = true
Config.RemoveMaskInZone = true

-- Configuración de facturas
Config.InvoiceExpire = 24 -- Horas para expirar factura
Config.MinInvoiceAmount = 100
Config.MaxInvoiceAmount = 10000

-- Configuración de pagos
Config.DefaultDailyPay = {
    ["boss"] = 500,
    ["manager"] = 350,
    ["employee"] = 250,
    ["recruit"] = 150
}

-- Configuración de almacenes
Config.StorageSlots = 50
Config.StorageWeight = 100000

-- Notificaciones
Config.Notify = "ox" -- ox, qb, esx

-- Idioma
Config.Locale = 'es'

-- Comandos de admin
Config.AdminCommands = {
    crear_mecanico = "crearmecanico",
    puntos_mecanico = "puntosmecanico"
}

-- Permisos
Config.Permissions = {
    boss = {
        withdraw_bank = true,
        edit_payments = true,
        add_members = true,
        remove_members = true,
        create_points = true,
        delete_points = true,
        create_zones = true
    },
    manager = {
        withdraw_bank = false,
        edit_payments = false,
        add_members = true,
        remove_members = false,
        create_points = true,
        delete_points = true,
        create_zones = false
    },
    employee = {
        withdraw_bank = false,
        edit_payments = false,
        add_members = false,
        remove_members = false,
        create_points = false,
        delete_points = false,
        create_zones = false
    }
}

-- Colores para UI (basados en Figma)
Config.Colors = {
    primary = "#2D3748",
    secondary = "#4A5568",
    accent = "#4299E1",
    success = "#48BB78",
    warning = "#ED8936",
    danger = "#F56565",
    dark = "#1A202C",
    light = "#F7FAFC"
}

-- Sonidos
Config.Sounds = {
    open_tablet = "SELECT",
    close_tablet = "BACK",
    button_click = "Click",
    notification = "CHALLENGE_UNLOCKED",
    payment_received = "HACKING_SUCCESS"
}