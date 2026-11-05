
-- АНАЛИТИЧЕСКИЕ ЗАПРОСЫ ДЛЯ Учета розничных продаж

-- Запрос 1. (Аналог ТОП-5 заемщиков). Запрос с CTE и JOIN.
-- Цель: Вывести ТОП-5 самых продаваемых товаров по объему выручки 
-- за последний месяц с указанием их категории.

WITH product_revenue AS (
    SELECT
        p.product_id,
        p.name AS product_name,
        c.name AS category_name,
        SUM(ri.quantity * ri.price_at_sale) AS total_revenue
    FROM receipt_items ri
    JOIN products p ON ri.product_id = p.product_id
    JOIN categories c ON p.category_id = c.category_id
    JOIN receipts r ON ri.receipt_id = r.receipt_id
    WHERE r.created_at >= NOW() - INTERVAL '30 days'
    GROUP BY p.product_id, p.name, c.name
)
SELECT * 
FROM product_revenue
ORDER BY total_revenue DESC
LIMIT 5;


-- Запрос 2. (Аналог поиска договоров с залогом < 80%). 
-- Запрос с оконными функциями или подзапросами.
-- Цель: Найти все чеки, где итоговая сумма чека (total_amount) 
-- отличается от суммы позиций в чеке более чем на 10% (например, из-за скидок).

WITH receipt_sums AS (
    SELECT
        r.receipt_id,
        r.total_amount AS receipt_total,
        SUM(ri.quantity * ri.price_at_sale) AS items_total
    FROM receipts r
    JOIN receipt_items ri ON r.receipt_id = ri.receipt_id
    GROUP BY r.receipt_id, r.total_amount
)
SELECT 
    receipt_id, 
    receipt_total, 
    items_total,
    (items_total - receipt_total) AS discount_amount
FROM receipt_sums
WHERE receipt_total < (items_total * 0.8); -- Скидка больше 20%


-- Запрос 3. (Запрос на ваш выбор). 
-- Должен использовать JOIN и GROUP BY.
-- Цель: Вывести выручку по каждому магазину за последнюю неделю.

SELECT
    s.store_id,
    s.address,
    COUNT(r.receipt_id) AS total_receipts,
    SUM(r.total_amount) AS total_revenue
FROM receipts r
JOIN shifts sh ON r.shift_id = sh.shift_id
JOIN stores s ON sh.store_id = s.store_id
WHERE r.created_at >= NOW() - INTERVAL '7 days'
GROUP BY s.store_id, s.address
ORDER BY total_revenue DESC;


-- Запрос 4. (Аналог создания витрины данных). 
-- Создание и работа с материализованным представлением.
-- Цель: Создать витрину данных для отдела маркетинга, 
-- объединяющую информацию о продажах по категориям и дням.

-- Создаем MATERIALIZED VIEW
CREATE MATERIALIZED VIEW mv_sales_by_category AS
SELECT
    c.name AS category_name,
    DATE_TRUNC('day', r.created_at)::DATE AS sale_date,
    SUM(ri.quantity) AS total_items_sold,
    SUM(ri.quantity * ri.price_at_sale) AS total_revenue,
    COUNT(DISTINCT r.receipt_id) AS receipts_count
FROM receipt_items ri
JOIN products p ON ri.product_id = p.product_id
JOIN categories c ON p.category_id = c.category_id
JOIN receipts r ON ri.receipt_id = r.receipt_id
GROUP BY c.name, DATE_TRUNC('day', r.created_at)::DATE;

-- Команда для обновления (refresh) витрины данных (запускается по расписанию)
-- REFRESH MATERIALIZED VIEW mv_sales_by_category;