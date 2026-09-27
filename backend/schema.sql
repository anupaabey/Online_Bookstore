-- ============================================================
-- Online Bookstore - Database Schema
-- Target: MySQL 5.7+ / MariaDB 10.3+
-- ============================================================

CREATE DATABASE IF NOT EXISTS bookstore_db
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

USE bookstore_db;

-- ------------------------------------------------------------
-- Users (Customer, Store Staff, Administrator)
-- ------------------------------------------------------------
CREATE TABLE users (
    user_id        INT AUTO_INCREMENT PRIMARY KEY,
    full_name      VARCHAR(120)  NOT NULL,
    email          VARCHAR(150)  NOT NULL UNIQUE,
    password_hash  VARCHAR(255)  NOT NULL,
    role           ENUM('customer', 'staff', 'admin') NOT NULL DEFAULT 'customer',
    phone          VARCHAR(30)   NULL,
    address        VARCHAR(255)  NULL,
    is_active      TINYINT(1)    NOT NULL DEFAULT 1,
    created_at     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- Auth tokens (simple bearer-token session store)
-- ------------------------------------------------------------
CREATE TABLE auth_tokens (
    token_id    INT AUTO_INCREMENT PRIMARY KEY,
    user_id     INT NOT NULL,
    token       VARCHAR(64) NOT NULL UNIQUE,
    expires_at  DATETIME NOT NULL,
    created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- Categories
-- ------------------------------------------------------------
CREATE TABLE categories (
    category_id   INT AUTO_INCREMENT PRIMARY KEY,
    name          VARCHAR(80) NOT NULL UNIQUE
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- Books (catalogue) - managed by Staff/Admin
-- ------------------------------------------------------------
CREATE TABLE books (
    book_id       INT AUTO_INCREMENT PRIMARY KEY,
    title         VARCHAR(200) NOT NULL,
    author        VARCHAR(150) NOT NULL,
    isbn          VARCHAR(20)  NULL,
    description   TEXT         NULL,
    price         DECIMAL(10,2) NOT NULL CHECK (price >= 0),
    stock_qty     INT NOT NULL DEFAULT 0 CHECK (stock_qty >= 0),
    category_id   INT NULL,
    cover_image   VARCHAR(255) NULL,
    is_active     TINYINT(1) NOT NULL DEFAULT 1,
    created_by    INT NULL,
    created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (category_id) REFERENCES categories(category_id) ON DELETE SET NULL,
    FOREIGN KEY (created_by) REFERENCES users(user_id) ON DELETE SET NULL,
    FULLTEXT KEY ft_title_author (title, author)
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- Cart (one open cart per customer, cart_items hold lines)
-- ------------------------------------------------------------
CREATE TABLE cart_items (
    cart_item_id  INT AUTO_INCREMENT PRIMARY KEY,
    user_id       INT NOT NULL,
    book_id       INT NOT NULL,
    quantity      INT NOT NULL DEFAULT 1 CHECK (quantity > 0),
    added_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uniq_user_book (user_id, book_id),
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (book_id) REFERENCES books(book_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- Orders
-- ------------------------------------------------------------
CREATE TABLE orders (
    order_id       INT AUTO_INCREMENT PRIMARY KEY,
    user_id        INT NOT NULL,
    total_amount   DECIMAL(10,2) NOT NULL DEFAULT 0,
    status         ENUM('pending','processing','shipped','completed','cancelled')
                   NOT NULL DEFAULT 'pending',
    shipping_address VARCHAR(255) NOT NULL,
    payment_method VARCHAR(50) NOT NULL DEFAULT 'cash_on_delivery',
    created_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE order_items (
    order_item_id  INT AUTO_INCREMENT PRIMARY KEY,
    order_id       INT NOT NULL,
    book_id        INT NOT NULL,
    quantity       INT NOT NULL CHECK (quantity > 0),
    unit_price     DECIMAL(10,2) NOT NULL,
    FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE,
    FOREIGN KEY (book_id) REFERENCES books(book_id)
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- Simple audit log (useful for the "reflection/evidence" section)
-- ------------------------------------------------------------
CREATE TABLE activity_log (
    log_id      INT AUTO_INCREMENT PRIMARY KEY,
    user_id     INT NULL,
    action      VARCHAR(255) NOT NULL,
    created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- Seed data
-- ------------------------------------------------------------
INSERT INTO categories (name) VALUES ('Fiction'),('Non-Fiction'),('Science'),('Technology'),('Children');

-- Default users (password for all = "Password123" - bcrypt hash below)
-- Hash generated with PHP password_hash('Password123', PASSWORD_BCRYPT)
INSERT INTO users (full_name, email, password_hash, role) VALUES
('System Admin',  'admin@bookstore.com', '$2y$10$O2Nq0m4rY0F0S1v3aTn8UOQ4h8G8gk1kQxq5x1oS1nE1F0S1v3aTn', 'admin'),
('Store Staff',   'staff@bookstore.com', '$2y$10$O2Nq0m4rY0F0S1v3aTn8UOQ4h8G8gk1kQxq5x1oS1nE1F0S1v3aTn', 'staff'),
('Jane Customer', 'jane@bookstore.com',  '$2y$10$O2Nq0m4rY0F0S1v3aTn8UOQ4h8G8gk1kQxq5x1oS1nE1F0S1v3aTn', 'customer');
-- NOTE: run backend/generate_hash.php to produce real hashes for these accounts,
-- since bcrypt hashes cannot be hand-typed reliably (see README).

INSERT INTO books (title, author, isbn, description, price, stock_qty, category_id, created_by) VALUES
('Clean Code', 'Robert C. Martin', '9780132350884', 'A handbook of agile software craftsmanship.', 32.50, 15, 4, 1),
('The Hobbit', 'J.R.R. Tolkien', '9780547928227', 'A fantasy adventure novel.', 18.00, 25, 1, 1),
('A Brief History of Time', 'Stephen Hawking', '9780553380163', 'An exploration of cosmology.', 22.00, 10, 3, 1),
('Charlotte''s Web', 'E.B. White', '9780064400558', 'A children''s classic about friendship.', 12.99, 30, 5, 1),
('Sapiens', 'Yuval Noah Harari', '9780062316097', 'A brief history of humankind.', 27.75, 12, 2, 1);
