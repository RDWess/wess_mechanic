local Database = {}

-- Tablas SQL
local businessTable = [[
    CREATE TABLE IF NOT EXISTS `mechanic_businesses` (
        `id` INT AUTO_INCREMENT PRIMARY KEY,
        `name` VARCHAR(100) NOT NULL UNIQUE,
        `job_name` VARCHAR(50) NOT NULL UNIQUE,
        `boss_identifier` VARCHAR(100) NOT NULL,
        `bank_balance` INT DEFAULT 0,
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        `active` BOOLEAN DEFAULT TRUE
    )
]]

local pointsTable = [[
    CREATE TABLE IF NOT EXISTS `mechanic_points` (
        `id` INT AUTO_INCREMENT PRIMARY KEY,
        `business_id` INT,
        `point_type` ENUM('work', 'storage', 'safe_zone') NOT NULL,
        `coords` TEXT NOT NULL,
        `radius` FLOAT DEFAULT 3.0,
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (`business_id`) REFERENCES `mechanic_businesses`(`id`) ON DELETE CASCADE
    )
]]

local invoicesTable = [[
    CREATE TABLE IF NOT EXISTS `mechanic_invoices` (
        `id` INT AUTO_INCREMENT PRIMARY KEY,
        `business_id` INT,
        `customer_identifier` VARCHAR(100),
        `customer_name` VARCHAR(100),
        `vehicle_model` VARCHAR(50),
        `vehicle_plate` VARCHAR(20),
        `customization` LONGTEXT,
        `amount` INT NOT NULL,
        `status` ENUM('pending', 'claimed', 'completed', 'cancelled') DEFAULT 'pending',
        `claimed_by` VARCHAR(100),
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        `completed_at` TIMESTAMP NULL,
        FOREIGN KEY (`business_id`) REFERENCES `mechanic_businesses`(`id`) ON DELETE CASCADE
    )
]]

local membersTable = [[
    CREATE TABLE IF NOT EXISTS `mechanic_members` (
        `id` INT AUTO_INCREMENT PRIMARY KEY,
        `business_id` INT,
        `member_identifier` VARCHAR(100) NOT NULL,
        `member_name` VARCHAR(100),
        `rank` ENUM('boss', 'manager', 'employee', 'recruit') DEFAULT 'recruit',
        `completed_invoices` INT DEFAULT 0,
        `total_earned` INT DEFAULT 0,
        `joined_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        `active` BOOLEAN DEFAULT TRUE,
        UNIQUE KEY `unique_member` (`business_id`, `member_identifier`),
        FOREIGN KEY (`business_id`) REFERENCES `mechanic_businesses`(`id`) ON DELETE CASCADE
    )
]]

local transactionsTable = [[
    CREATE TABLE IF NOT EXISTS `mechanic_transactions` (
        `id` INT AUTO_INCREMENT PRIMARY KEY,
        `business_id` INT,
        `member_identifier` VARCHAR(100),
        `transaction_type` ENUM('deposit', 'withdraw', 'invoice', 'salary') NOT NULL,
        `amount` INT NOT NULL,
        `description` VARCHAR(255),
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (`business_id`) REFERENCES `mechanic_businesses`(`id`) ON DELETE CASCADE
    )
]]

-- Inicializar tablas
MySQL.ready(function()
    MySQL.query(businessTable)
    MySQL.query(pointsTable)
    MySQL.query(invoicesTable)
    MySQL.query(membersTable)
    MySQL.query(transactionsTable)
    print('[MECANICO] Tablas de base de datos inicializadas')
end)

-- Funciones de negocio
Database.CreateBusiness = function(name, bossIdentifier, bossName)
    local jobName = "mec_" .. string.lower(string.gsub(name, "%s+", "_"))
    
    local result = MySQL.query.await('INSERT INTO mechanic_businesses (name, job_name, boss_identifier) VALUES (?, ?, ?)',
        {name, jobName, bossIdentifier})
    
    if result and result.insertId then
        -- Añadir al jefe como miembro
        MySQL.query.await('INSERT INTO mechanic_members (business_id, member_identifier, member_name, rank) VALUES (?, ?, ?, ?)',
            {result.insertId, bossIdentifier, bossName, 'boss'})
        
        return result.insertId, jobName
    end
    return nil
end

Database.GetBusiness = function(businessId)
    return MySQL.query.await('SELECT * FROM mechanic_businesses WHERE id = ?', {businessId})
end

Database.GetBusinessByName = function(name)
    return MySQL.query.await('SELECT * FROM mechanic_businesses WHERE name = ?', {name})[1]
end

Database.GetBusinessByJobName = function(jobName)
    return MySQL.query.await('SELECT * FROM mechanic_businesses WHERE job_name = ?', {jobName})[1]
end

Database.GetBusinessByBoss = function(identifier)
    return MySQL.query.await('SELECT * FROM mechanic_businesses WHERE boss_identifier = ?', {identifier})[1]
end

Database.GetMemberBusiness = function(identifier)
    local result = MySQL.query.await([[
        SELECT b.*, m.rank 
        FROM mechanic_businesses b
        JOIN mechanic_members m ON b.id = m.business_id
        WHERE m.member_identifier = ? AND m.active = TRUE
    ]], {identifier})
    
    return result[1]
end

-- Funciones de puntos
Database.AddPoint = function(businessId, pointType, coords, radius)
    local coordsStr = json.encode(coords)
    return MySQL.query.await('INSERT INTO mechanic_points (business_id, point_type, coords, radius) VALUES (?, ?, ?, ?)',
        {businessId, pointType, coordsStr, radius})
end

Database.GetBusinessPoints = function(businessId)
    local points = MySQL.query.await('SELECT * FROM mechanic_points WHERE business_id = ?', {businessId})
    
    for _, point in ipairs(points) do
        point.coords = json.decode(point.coords)
    end
    
    return points
end

Database.DeletePoint = function(pointId)
    return MySQL.query.await('DELETE FROM mechanic_points WHERE id = ?', {pointId})
end

Database.DeleteNearbyPoints = function(coords, radius)
    -- Esta función sería más compleja, requiere cálculo de distancia
    -- Se implementaría buscando puntos cercanos
end

-- Funciones de facturas
Database.CreateInvoice = function(businessId, customerData, vehicleData, customization, amount)
    local customizationStr = json.encode(customization)
    
    return MySQL.query.await([[
        INSERT INTO mechanic_invoices 
        (business_id, customer_identifier, customer_name, vehicle_model, vehicle_plate, customization, amount)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ]], {
        businessId,
        customerData.identifier,
        customerData.name,
        vehicleData.model,
        vehicleData.plate,
        customizationStr,
        amount
    })
end

Database.GetBusinessInvoices = function(businessId, status)
    local query = 'SELECT * FROM mechanic_invoices WHERE business_id = ?'
    local params = {businessId}
    
    if status then
        query = query .. ' AND status = ?'
        table.insert(params, status)
    end
    
    query = query .. ' ORDER BY created_at DESC'
    
    local invoices = MySQL.query.await(query, params)
    
    for _, invoice in ipairs(invoices) do
        if invoice.customization then
            invoice.customization = json.decode(invoice.customization)
        end
    end
    
    return invoices
end

Database.ClaimInvoice = function(invoiceId, mechanicIdentifier)
    return MySQL.query.await([[
        UPDATE mechanic_invoices 
        SET status = 'claimed', claimed_by = ? 
        WHERE id = ? AND status = 'pending'
    ]], {mechanicIdentifier, invoiceId})
end

Database.CompleteInvoice = function(invoiceId)
    return MySQL.query.await([[
        UPDATE mechanic_invoices 
        SET status = 'completed', completed_at = CURRENT_TIMESTAMP 
        WHERE id = ?
    ]], {invoiceId})
end

Database.GetInvoice = function(invoiceId)
    local result = MySQL.query.await('SELECT * FROM mechanic_invoices WHERE id = ?', {invoiceId})
    
    if result[1] and result[1].customization then
        result[1].customization = json.decode(result[1].customization)
    end
    
    return result[1]
end

-- Funciones de miembros
Database.AddMember = function(businessId, memberIdentifier, memberName, rank)
    return MySQL.query.await([[
        INSERT INTO mechanic_members (business_id, member_identifier, member_name, rank)
        VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE 
        rank = VALUES(rank), active = TRUE
    ]], {businessId, memberIdentifier, memberName, rank})
end

Database.RemoveMember = function(businessId, memberIdentifier)
    return MySQL.query.await([[
        UPDATE mechanic_members 
        SET active = FALSE 
        WHERE business_id = ? AND member_identifier = ?
    ]], {businessId, memberIdentifier})
end

Database.GetBusinessMembers = function(businessId)
    return MySQL.query.await([[
        SELECT * FROM mechanic_members 
        WHERE business_id = ? AND active = TRUE 
        ORDER BY 
            CASE rank 
                WHEN 'boss' THEN 1
                WHEN 'manager' THEN 2
                WHEN 'employee' THEN 3
                WHEN 'recruit' THEN 4
            END
    ]], {businessId})
end

Database.UpdateMemberStats = function(memberIdentifier, businessId, amount)
    return MySQL.query.await([[
        UPDATE mechanic_members 
        SET completed_invoices = completed_invoices + 1, 
            total_earned = total_earned + ?
        WHERE member_identifier = ? AND business_id = ?
    ]], {amount, memberIdentifier, businessId})
end

-- Funciones de banco
Database.UpdateBankBalance = function(businessId, amount, transactionType, description, memberIdentifier)
    -- Actualizar balance
    MySQL.query.await([[
        UPDATE mechanic_businesses 
        SET bank_balance = bank_balance + ? 
        WHERE id = ?
    ]], {amount, businessId})
    
    -- Registrar transacción
    MySQL.query.await([[
        INSERT INTO mechanic_transactions 
        (business_id, member_identifier, transaction_type, amount, description)
        VALUES (?, ?, ?, ?, ?)
    ]], {businessId, memberIdentifier, transactionType, amount, description})
    
    return true
end

Database.GetBankBalance = function(businessId)
    local result = MySQL.query.await('SELECT bank_balance FROM mechanic_businesses WHERE id = ?', {businessId})
    return result[1] and result[1].bank_balance or 0
end

Database.GetTransactionHistory = function(businessId, limit)
    return MySQL.query.await([[
        SELECT * FROM mechanic_transactions 
        WHERE business_id = ? 
        ORDER BY created_at DESC 
        LIMIT ?
    ]], {businessId, limit or 50})
end

-- Funciones de zonas seguras
Database.CreateSafeZone = function(businessId, corners)
    local cornersStr = json.encode(corners)
    return MySQL.query.await([[
        INSERT INTO mechanic_points 
        (business_id, point_type, coords, radius)
        VALUES (?, 'safe_zone', ?, 0)
    ]], {businessId, cornersStr})
end

Database.GetBusinessSafeZones = function(businessId)
    local result = MySQL.query.await([[
        SELECT * FROM mechanic_points 
        WHERE business_id = ? AND point_type = 'safe_zone'
    ]], {businessId})
    
    for _, zone in ipairs(result) do
        zone.coords = json.decode(zone.coords)
    end
    
    return result
end

return Database