-- Заполнение базовыми тестовыми данными для проверки

-- 1. Магазины
INSERT INTO stores (address, phone) VALUES 
('ул. Ленина, д. 1', '+79175389853'),
('пр. Мира, д. 10', '+70871235696');

-- 2. Сотрудники
INSERT INTO employees (full_name, role, store_id) VALUES 
('Голубева Раиса (Кассир)', 'cashier', 1),
('Березовая Елена (Менеджер)', 'manager', 1);

-- 3. Категории
INSERT INTO categories (name) VALUES 
('Продукты'), ('Напитки'), ('Бытовая химия');

-- 4. Товары
INSERT INTO products (sku, name, price, category_id) VALUES 
('SKU-001', 'Хлеб', 45.50, 1),
('SKU-002', 'Молоко 3.2%', 80.00, 1),
('SKU-003', 'Кола 0.5л', 120.00, 2);

-- 5. Клиенты
INSERT INTO customers (phone, bonus_points) VALUES 
('+79991234567', 0),
('+79997654321', 150);

-- 6. Смена
INSERT INTO shifts (store_id, employee_id, open_time) VALUES 
(1, 1, NOW());

-- 7. Чек
INSERT INTO receipts (shift_id, customer_id, total_amount) VALUES 
(1, 1, 125.50);

-- 8. Позиции чека
INSERT INTO receipt_items (receipt_id, product_id, quantity, price_at_sale) VALUES 
(1, 1, 1, 45.50),
(1, 2, 1, 80.00);