
-- Аналитические запросы для Учета розничных продаж


-- Запрос 1. (Обязательный: CTE и JOIN)
-- Цель: Вывести ТОП-5 самых продаваемых товаров по объему выручки за последний месяц с указанием их категории.

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


-- Запрос 2. (Обязательный: Оконные функции)
-- Цель: Для каждого магазина вывести чеки и их сумму, а также присвоить ранг чека по сумме внутри конкретного магазина.

SELECT
    s.address AS store_address,
    r.receipt_id,
    r.total_amount,
    RANK() OVER (PARTITION BY s.store_id ORDER BY r.total_amount DESC) as rank_in_store
FROM receipts r
JOIN shifts sh ON r.shift_id = sh.shift_id
JOIN stores s ON sh.store_id = s.store_id
WHERE r.created_at >= NOW() - INTERVAL '7 days';

-- Запрос 3. ( на наш выбор JOIN и GROUP BY)
-- Цель: Вывести выручку по категориям товаров за всё время.

SELECT
    c.name AS category_name,
    COUNT(ri.item_id) AS items_sold,
    SUM(ri.quantity * ri.price_at_sale) AS total_revenue
FROM receipt_items ri
JOIN products p ON ri.product_id = p.product_id
JOIN categories c ON p.category_id = c.category_id
JOIN receipts r ON ri.receipt_id = r.receipt_id
GROUP BY c.name
ORDER BY total_revenue DESC;


-- Запрос 4. (Обязательный: Создание MATERIALIZED VIEW)
-- Цель: Создать витрину данных для отдела маркетинга, объединяющую информацию о продажах по категориям и дням.

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

-- Команда для обновления (refresh) витрины данных
-- REFRESH MATERIALIZED VIEW mv_sales_by_category;


-- Запрос 5.
-- Цель: Найти кассиров, чья средняя сумма чека выше средней по всей сети.

SELECT 
    e.full_name, 
    AVG(r.total_amount) AS avg_receipt_amount
FROM employees e
JOIN shifts sh ON e.employee_id = sh.employee_id
JOIN receipts r ON sh.shift_id = r.shift_id
GROUP BY e.employee_id, e.full_name
HAVING AVG(r.total_amount) > (
    SELECT AVG(total_amount) FROM receipts
);


-- Запрос 6. (Анализ возвратов)
-- Цель: Найти товары, которые чаще всего возвращают.

SELECT
    p.name AS product_name,
    COUNT(ret.return_id) AS return_count,
    SUM(ret.refund_amount) AS total_refunded
FROM returns ret
JOIN receipts r ON ret.receipt_id = r.receipt_id
JOIN receipt_items ri ON r.receipt_id = ri.receipt_id
JOIN products p ON ri.product_id = p.product_id
GROUP BY p.name
ORDER BY return_count DESC
LIMIT 10;


-- Запрос 7. ( Использование LAG/LEAD - временные ряды)
-- Цель: Показать ежедневную выручку и разницу с предыдущим днем.

WITH daily_sales AS (
    SELECT 
        DATE_TRUNC('day', created_at)::DATE as sale_day,
        SUM(total_amount) as daily_total
    FROM receipts
    GROUP BY DATE_TRUNC('day', created_at)::DATE
)
SELECT 
    sale_day,
    daily_total,
    daily_total - LAG(daily_total) OVER (ORDER BY sale_day) AS diff_from_prev_day
FROM daily_sales
ORDER BY sale_day DESC
LIMIT 10;