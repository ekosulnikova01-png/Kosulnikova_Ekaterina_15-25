-- Роли и права доступа

-- Создание ролей
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'pos_cashier') THEN
        CREATE ROLE pos_cashier NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'store_manager') THEN
        CREATE ROLE store_manager NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'analyst') THEN
        CREATE ROLE analyst NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'db_admin') THEN
        CREATE ROLE db_admin NOLOGIN;
    END IF;
END
$$;

-- Доступ к схеме
GRANT USAGE ON SCHEMA public TO pos_cashier, store_manager, analyst, db_admin;

-- Кассир
GRANT SELECT, INSERT ON receipts TO pos_cashier;
GRANT SELECT, INSERT ON payments TO pos_cashier;
GRANT SELECT ON products, shifts, stores TO pos_cashier;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO pos_cashier;

-- Аналитик (без прямого доступа к ПДн)
GRANT SELECT ON v_customers_anonymized TO analyst;
GRANT SELECT ON receipts, payments, products, stores, shifts, returns, mv_daily_sales TO analyst;

-- Менеджер
GRANT SELECT, UPDATE ON products TO store_manager;
GRANT SELECT ON shifts, receipts, stores, mv_daily_sales TO store_manager;

-- Админ
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO db_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO db_admin;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO db_admin;
