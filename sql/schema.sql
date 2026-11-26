-- Учёт розничных продаж

DROP MATERIALIZED VIEW IF EXISTS mv_daily_sales CASCADE;
DROP VIEW IF EXISTS v_customers_anonymized CASCADE;
DROP TABLE IF EXISTS audit_log CASCADE;
DROP TABLE IF EXISTS product_price_history CASCADE;
DROP TABLE IF EXISTS returns CASCADE;
DROP TABLE IF EXISTS payments CASCADE;
DROP TABLE IF EXISTS receipts CASCADE;
DROP TABLE IF EXISTS shifts CASCADE;
DROP TABLE IF EXISTS customers CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS employees CASCADE;
DROP TABLE IF EXISTS stores CASCADE;

-- 1. Магазины
CREATE TABLE stores (
    store_id    SERIAL PRIMARY KEY,
    address     TEXT        NOT NULL,
    phone       VARCHAR(20),
    is_active   BOOLEAN     NOT NULL DEFAULT TRUE
);

-- 2. Сотрудники
CREATE TABLE employees (
    employee_id SERIAL PRIMARY KEY,
    full_name   VARCHAR(100) NOT NULL,
    role        VARCHAR(20)  NOT NULL CHECK (role IN ('cashier', 'admin', 'manager')),
    store_id    INT          NOT NULL REFERENCES stores(store_id) ON DELETE CASCADE,
    hire_date   DATE         NOT NULL DEFAULT CURRENT_DATE
);

-- 3. Товары 
CREATE TABLE products (
    product_id  SERIAL PRIMARY KEY,
    sku         VARCHAR(50)   NOT NULL UNIQUE,
    name        VARCHAR(150)  NOT NULL,
    price       NUMERIC(10,2) NOT NULL CHECK (price >= 0),
    is_active   BOOLEAN       NOT NULL DEFAULT TRUE
);

-- 4. Клиенты (ПДн — телефон)
CREATE TABLE customers (
    customer_id   SERIAL PRIMARY KEY,
    phone         VARCHAR(20) UNIQUE,
    bonus_points  INT         NOT NULL DEFAULT 0 CHECK (bonus_points >= 0),
    registered_at TIMESTAMP   NOT NULL DEFAULT NOW()
);

-- 5. Кассовые смены
CREATE TABLE shifts (
    shift_id    SERIAL PRIMARY KEY,
    store_id    INT       NOT NULL REFERENCES stores(store_id),
    employee_id INT       NOT NULL REFERENCES employees(employee_id),
    open_time   TIMESTAMP NOT NULL DEFAULT NOW(),
    close_time  TIMESTAMP,
    CONSTRAINT chk_shift_times CHECK (close_time IS NULL OR close_time > open_time)
);

-- 6. Чеки
CREATE TABLE receipts (
    receipt_id   BIGSERIAL PRIMARY KEY,
    shift_id     INT            NOT NULL REFERENCES shifts(shift_id),
    customer_id  INT            REFERENCES customers(customer_id),
    created_at   TIMESTAMP      NOT NULL DEFAULT NOW(),
    total_amount NUMERIC(12,2)  NOT NULL DEFAULT 0 CHECK (total_amount >= 0)
);

-- 7. Оплаты
CREATE TABLE payments (
    payment_id   BIGSERIAL PRIMARY KEY,
    receipt_id   BIGINT        NOT NULL REFERENCES receipts(receipt_id) ON DELETE CASCADE,
    payment_type VARCHAR(10)   NOT NULL CHECK (payment_type IN ('cash', 'card')),
    amount       NUMERIC(12,2) NOT NULL CHECK (amount > 0)
);

-- 8. Возвраты
CREATE TABLE returns (
    return_id     BIGSERIAL PRIMARY KEY,
    receipt_id    BIGINT        NOT NULL REFERENCES receipts(receipt_id),
    reason        TEXT,
    refund_amount NUMERIC(12,2) NOT NULL CHECK (refund_amount > 0),
    created_at    TIMESTAMP     NOT NULL DEFAULT NOW()
);

-- 9. Журнал аудита (152-ФЗ)
CREATE TABLE audit_log (
    log_id      BIGSERIAL PRIMARY KEY,
    table_name  TEXT        NOT NULL,
    operation   TEXT        NOT NULL,
    old_data    JSONB,
    new_data    JSONB,
    changed_by  TEXT        NOT NULL DEFAULT current_user,
    changed_at  TIMESTAMP   NOT NULL DEFAULT NOW()
);

-- 10. История цен (паттерн версионирования SCD Type 2)
CREATE TABLE product_price_history (
    history_id  BIGSERIAL PRIMARY KEY,
    product_id  INT           NOT NULL REFERENCES products(product_id),
    price       NUMERIC(10,2) NOT NULL,
    valid_from  TIMESTAMP     NOT NULL DEFAULT NOW(),
    valid_to    TIMESTAMP,
    CONSTRAINT chk_price_history_dates
        CHECK (valid_to IS NULL OR valid_to > valid_from)
);

-- ИНДЕКСЫ (минимум 3 B-tree)
CREATE INDEX idx_receipts_shift_id     ON receipts(shift_id);
CREATE INDEX idx_receipts_created_at   ON receipts(created_at);
CREATE INDEX idx_receipts_customer_id  ON receipts(customer_id);
CREATE INDEX idx_payments_receipt      ON payments(receipt_id);
CREATE INDEX idx_returns_receipt       ON returns(receipt_id);
CREATE INDEX idx_shifts_store_employee ON shifts(store_id, employee_id);
CREATE INDEX idx_price_hist_product    ON product_price_history(product_id, valid_from);

-- VIEW: обезличенные клиенты (для аналитиков, 152-ФЗ)
CREATE OR REPLACE VIEW v_customers_anonymized AS
SELECT
    customer_id,
    CASE
        WHEN phone IS NOT NULL THEN '***-***-' || RIGHT(phone, 4)
        ELSE NULL
    END AS phone_masked,
    bonus_points,
    registered_at
FROM customers;

-- MATERIALIZED VIEW: ежедневная выручка по магазинам
CREATE MATERIALIZED VIEW mv_daily_sales AS
SELECT
    s.store_id,
    s.address AS store_address,
    DATE_TRUNC('day', r.created_at)::DATE AS sale_date,
    COUNT(r.receipt_id) AS receipts_count,
    SUM(r.total_amount) AS total_revenue,
    AVG(r.total_amount) AS avg_receipt
FROM receipts r
JOIN shifts sh ON r.shift_id = sh.shift_id
JOIN stores s  ON sh.store_id = s.store_id
GROUP BY s.store_id, s.address, DATE_TRUNC('day', r.created_at)::DATE
WITH NO DATA;

CREATE INDEX idx_mv_daily_sales_date ON mv_daily_sales(sale_date, store_id);

COMMENT ON MATERIALIZED VIEW mv_daily_sales IS
    'Витрина: ежедневная выручка по магазинам. Обновлять: REFRESH MATERIALIZED VIEW mv_daily_sales;';
