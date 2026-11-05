-- Создание ролей
CREATE ROLE pos_cashier NOLOGIN;
CREATE ROLE store_manager NOLOGIN;
CREATE ROLE analyst NOLOGIN;
CREATE ROLE db_admin NOLOGIN;

-- Доступ к схеме
GRANT USAGE ON SCHEMA public TO pos_cashier, store_manager, analyst, db_admin;

-- Роль: Кассир
GRANT INSERT, SELECT ON receipts TO pos_cashier;
GRANT INSERT ON receipt_items, payments TO pos_cashier;
GRANT SELECT ON products, shifts TO pos_cashier;

-- Роль: Аналитик (без ПДн)
GRANT SELECT (customer_id, bonus_points) ON customers TO analyst;
GRANT SELECT ON receipts, receipt_items, products, categories, stores TO analyst;

-- Роль: Менеджер
GRANT SELECT, UPDATE ON products TO store_manager;
GRANT SELECT ON shifts, receipts TO store_manager;

-- Администратор БД (полный доступ)
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO db_admin;
