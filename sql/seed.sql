-- Базовые тестовые данные 

-- 1. Магазины
INSERT INTO stores (address, phone) VALUES
    ('ул. Ленина, д. 1',   '+79175389853'),
    ('пр. Мира, д. 10',    '+70871235696'),
    ('ул. Гагарина, д. 5', '+79991112233'),
    ('пр. Победы, д. 22',  '+79005554433');

-- 2. Сотрудники
INSERT INTO employees (full_name, role, store_id) VALUES
    ('Голубева Раиса',      'cashier', 1),
    ('Березовая Елена',     'manager', 1),
    ('Иванов Пётр',         'cashier', 2),
    ('Смирнова Анна',       'cashier', 2),
    ('Козлов Дмитрий',      'manager', 3),
    ('Морозова Ольга',      'cashier', 3),
    ('Васильев Сергей',     'cashier', 4),
    ('Новикова Мария',      'admin',   1);

-- 3. Товары
INSERT INTO products (sku, name, price) VALUES
    ('SKU-001', 'Хлеб белый',           45.50),
    ('SKU-002', 'Молоко 3.2% 1л',       80.00),
    ('SKU-003', 'Кола 0.5л',           120.00),
    ('SKU-004', 'Сыр Российский 200г', 250.00),
    ('SKU-005', 'Чипсы Lays 150г',     150.00),
    ('SKU-006', 'Стиральный порошок',  450.00),
    ('SKU-007', 'Йогурт питьевой',      55.00),
    ('SKU-008', 'Печенье Юбилейное',    90.00),
    ('SKU-009', 'Вода минеральная 1л',  40.00),
    ('SKU-010', 'Пельмени 800г',       320.00),
    ('SKU-011', 'Сок апельсиновый 1л', 130.00),
    ('SKU-012', 'Творог 9%',           110.00),
    ('SKU-013', 'Шоколад Snickers',     75.00),
    ('SKU-014', 'Средство для мытья',  180.00),
    ('SKU-015', 'Батон нарезной',       42.00);

-- 4. Клиенты
INSERT INTO customers (phone, bonus_points) VALUES
    ('+79991234567', 0),
    ('+79997654321', 150),
    ('+79001112233', 320),
    ('+79165554433', 50),
    ('+79267778899', 0),
    ('+79330001122', 780),
    ('+79441112233', 210),
    ('+79552223344', 45);

-- 5. Смены
INSERT INTO shifts (store_id, employee_id, open_time, close_time) VALUES
    (1, 1, NOW() - INTERVAL '2 days', NOW() - INTERVAL '1 day 16 hours'),
    (1, 1, NOW() - INTERVAL '1 day',  NULL),
    (2, 3, NOW() - INTERVAL '3 days', NOW() - INTERVAL '2 days 15 hours'),
    (2, 4, NOW() - INTERVAL '1 day',  NULL),
    (3, 6, NOW() - INTERVAL '5 hours', NULL),
    (4, 7, NOW() - INTERVAL '8 hours', NULL);

-- 6. Чеки
INSERT INTO receipts (shift_id, customer_id, created_at, total_amount) VALUES
    (1, 1, NOW() - INTERVAL '2 days', 125.50),
    (1, 2, NOW() - INTERVAL '2 days', 370.00),
    (2, 3, NOW() - INTERVAL '20 hours', 215.00),
    (3, 4, NOW() - INTERVAL '3 days', 450.00),
    (4, NULL, NOW() - INTERVAL '10 hours', 80.00),
    (5, 5, NOW() - INTERVAL '3 hours', 560.00),
    (6, 6, NOW() - INTERVAL '4 hours', 195.00);

-- 7. Оплаты
INSERT INTO payments (receipt_id, payment_type, amount) VALUES
    (1, 'card', 125.50),
    (2, 'cash', 370.00),
    (3, 'card', 215.00),
    (4, 'card', 450.00),
    (5, 'cash',  80.00),
    (6, 'card', 560.00),
    (7, 'cash', 195.00);

-- 8. Возвраты
INSERT INTO returns (receipt_id, reason, refund_amount) VALUES
    (2, 'Истёкший срок годности', 120.00),
    (4, 'Повреждённая упаковка', 450.00);

-- История цен 
INSERT INTO product_price_history (product_id, price, valid_from, valid_to)
SELECT product_id, price, NOW() - INTERVAL '30 days', NULL
FROM products;

-- Обновляем витрину
REFRESH MATERIALIZED VIEW mv_daily_sales;
