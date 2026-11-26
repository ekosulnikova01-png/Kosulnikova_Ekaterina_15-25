-- Аналитические запросы для Учета розничных продаж

-- Запрос 1. (CTE + JOIN)
-- Цель: ТОП-5 магазинов по выручке за последние 30 дней
WITH store_revenue AS (
    SELECT
        s.store_id,
        s.address AS store_address,
        SUM(r.total_amount) AS total_revenue,
        COUNT(r.receipt_id) AS receipts_count
    FROM receipts r
    JOIN shifts sh ON r.shift_id = sh.shift_id
    JOIN stores s  ON sh.store_id = s.store_id
    WHERE r.created_at >= NOW() - INTERVAL '30 days'
    GROUP BY s.store_id, s.address
)
SELECT *
FROM store_revenue
ORDER BY total_revenue DESC
LIMIT 5;


-- Запрос 2. (Оконные функции)
-- Цель: Для каждого магазина вывести чеки и ранг чека по сумме внутри магазина
SELECT
    s.address AS store_address,
    r.receipt_id,
    r.total_amount,
    RANK() OVER (PARTITION BY s.store_id ORDER BY r.total_amount DESC) AS rank_in_store
FROM receipts r
JOIN shifts sh ON r.shift_id = sh.shift_id
JOIN stores s  ON sh.store_id = s.store_id
WHERE r.created_at >= NOW() - INTERVAL '7 days';


-- Запрос 3. (JOIN + GROUP BY)
-- Цель: Выручка по сотрудникам (кассирам) за всё время
SELECT
    e.full_name,
    e.role,
    s.address AS store_address,
    COUNT(r.receipt_id) AS receipts_count,
    SUM(r.total_amount) AS total_revenue,
    ROUND(AVG(r.total_amount), 2) AS avg_receipt
FROM employees e
JOIN shifts sh ON e.employee_id = sh.employee_id
JOIN stores s  ON sh.store_id = s.store_id
JOIN receipts r ON sh.shift_id = r.shift_id
GROUP BY e.employee_id, e.full_name, e.role, s.address
ORDER BY total_revenue DESC;


-- Запрос 4. MATERIALIZED VIEW
-- Цель: Создать витрину ежедневной выручки по магазинам
-- (для отдела аналитики / маркетинга)

-- Если представление уже создано в schema.sql — сначала удаляем
DROP MATERIALIZED VIEW IF EXISTS mv_daily_sales;

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
GROUP BY s.store_id, s.address, DATE_TRUNC('day', r.created_at)::DATE;

-- Команда обновления витрины:
-- REFRESH MATERIALIZED VIEW mv_daily_sales;

-- Пример использования витрины:
SELECT * FROM mv_daily_sales
ORDER BY sale_date DESC, total_revenue DESC
LIMIT 20;


-- Запрос 5.
-- Цель: Найти кассиров, чья средняя сумма чека выше средней по всей сети
SELECT
    e.full_name,
    AVG(r.total_amount) AS avg_receipt_amount
FROM employees e
JOIN shifts sh ON e.employee_id = sh.employee_id
JOIN receipts r ON sh.shift_id = r.shift_id
GROUP BY e.employee_id, e.full_name
HAVING AVG(r.total_amount) > (SELECT AVG(total_amount) FROM receipts);


-- Запрос 6. (Анализ возвратов)
-- Цель: Магазины с наибольшей суммой возвратов
SELECT
    s.address AS store_address,
    COUNT(ret.return_id) AS return_count,
    SUM(ret.refund_amount) AS total_refunded
FROM returns ret
JOIN receipts r ON ret.receipt_id = r.receipt_id
JOIN shifts sh ON r.shift_id = sh.shift_id
JOIN stores s ON sh.store_id = s.store_id
GROUP BY s.store_id, s.address
ORDER BY total_refunded DESC;


-- Запрос 7. (LAG — временные ряды)
-- Цель: Ежедневная выручка по сети и разница с предыдущим днём
WITH daily_sales AS (
    SELECT
        DATE_TRUNC('day', created_at)::DATE AS sale_day,
        SUM(total_amount) AS daily_total
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
