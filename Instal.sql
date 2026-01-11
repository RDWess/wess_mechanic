-- SQL para Mecánico System - Base de datos: Qbox_6360D9
USE Qbox_6360D9;

-- --------------------------------------------------------
-- Tabla de negocios de mecánico
-- --------------------------------------------------------
CREATE TABLE IF NOT EXISTS `mechanic_businesses` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `name` VARCHAR(100) NOT NULL UNIQUE,
    `job_name` VARCHAR(50) NOT NULL UNIQUE,
    `boss_identifier` VARCHAR(100) NOT NULL,
    `bank_balance` INT DEFAULT 0,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `active` BOOLEAN DEFAULT TRUE,
    INDEX `idx_boss` (`boss_identifier`),
    INDEX `idx_job_name` (`job_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------
-- Tabla de puntos de trabajo
-- --------------------------------------------------------
CREATE TABLE IF NOT EXISTS `mechanic_points` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `business_id` INT,
    `point_type` ENUM('work', 'storage', 'safe_zone') NOT NULL,
    `coords` TEXT NOT NULL,
    `radius` FLOAT DEFAULT 3.0,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (`business_id`) REFERENCES `mechanic_businesses`(`id`) ON DELETE CASCADE,
    INDEX `idx_business` (`business_id`),
    INDEX `idx_type` (`point_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------
-- Tabla de facturas
-- --------------------------------------------------------
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
    FOREIGN KEY (`business_id`) REFERENCES `mechanic_businesses`(`id`) ON DELETE CASCADE,
    INDEX `idx_business_status` (`business_id`, `status`),
    INDEX `idx_customer` (`customer_identifier`),
    INDEX `idx_claimed` (`claimed_by`),
    INDEX `idx_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------
-- Tabla de miembros
-- --------------------------------------------------------
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
    FOREIGN KEY (`business_id`) REFERENCES `mechanic_businesses`(`id`) ON DELETE CASCADE,
    INDEX `idx_business` (`business_id`),
    INDEX `idx_member` (`member_identifier`),
    INDEX `idx_rank` (`rank`),
    INDEX `idx_active` (`active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------
-- Tabla de transacciones bancarias
-- --------------------------------------------------------
CREATE TABLE IF NOT EXISTS `mechanic_transactions` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `business_id` INT,
    `member_identifier` VARCHAR(100),
    `transaction_type` ENUM('deposit', 'withdraw', 'invoice', 'salary') NOT NULL,
    `amount` INT NOT NULL,
    `description` VARCHAR(255),
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (`business_id`) REFERENCES `mechanic_businesses`(`id`) ON DELETE CASCADE,
    INDEX `idx_business` (`business_id`),
    INDEX `idx_member` (`member_identifier`),
    INDEX `idx_type` (`transaction_type`),
    INDEX `idx_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

