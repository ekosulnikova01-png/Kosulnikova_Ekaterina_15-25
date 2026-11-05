-- 1. Магазины
CREATE TABLE stores (
    store_id SERIAL PRIMARY KEY,
    address TEXT NOT NULL,
    phone VARCHAR(20)
);

-- 2. Сотрудники 
CREATE TABLE employees (
    employee_id SERIAL PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL, 
    role VARCHAR(20) CHECK (role IN ('cashier', 'admin', 'manager')),
    store_id INT REFERENCES stores(store_id) ON DELETE CASCADE
);

-- 3. Товары 
CREATE TABLE products (
    product_id SERIAL PRIMARY KEY,
    sku VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    price NUMERIC(10,2) NOT NULL CHECK (price >= 0),
    category_id INT REFERENCES categories(category_id)
);

-- 4. Клиенты 
CREATE TABLE customers (
    customer_id SERIAL PRIMARY KEY,
    phone VARCHAR(20) UNIQUE, 
    bonus_points INT DEFAULT 0 CHECK (bonus_points >= 0)
);

-- 5. Кассовые смены
CREATE TABLE shifts (
    shift_id SERIAL PRIMARY KEY,
    store_id INT REFERENCES stores(store_id),
    employee_id INT REFERENCES employees(employee_id),
    open_time TIMESTAMP NOT NULL DEFAULT NOW(),
    close_time TIMESTAMP,
    CHECK (close_time IS NULL OR close_time > open_time)
);

-- 6. Чеки
CREATE TABLE receipts (
    receipt_id BIGSERIAL PRIMARY KEY,
    shift_id INT REFERENCES shifts(shift_id),
    customer_id INT REFERENCES customers(customer_id),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    total_amount NUMERIC(10,2) NOT NULL DEFAULT 0 CHECK (total_amount >= 0)
);

-- 7. Оплаты
CREATE TABLE payments (
    payment_id BIGSERIAL PRIMARY KEY,
    receipt_id BIGINT REFERENCES receipts(receipt_id) ON DELETE CASCADE,
    payment_type VARCHAR(10) CHECK (payment_type IN ('cash', 'card')),
    amount NUMERIC(10,2) NOT NULL CHECK (amount > 0)
);

-- 8. Возвраты
CREATE TABLE returns (
    return_id BIGSERIAL PRIMARY KEY,
    receipt_id BIGINT REFERENCES receipts(receipt_id),
    reason TEXT,
    refund_amount NUMERIC(10,2) NOT NULL CHECK (refund_amount > 0),
    created_at TIMESTAMP DEFAULT NOW()
);

-- ИНДЕКСЫ (B-tree) для оптимизации запросов
CREATE INDEX idx_receipts_shift ON receipts(shift_id);
CREATE INDEX idx_receipts_created ON receipts(created_at);
CREATE INDEX idx_receipt_items_receipt ON receipt_items(receipt_id);
CREATE INDEX idx_products_category ON products(category_id);