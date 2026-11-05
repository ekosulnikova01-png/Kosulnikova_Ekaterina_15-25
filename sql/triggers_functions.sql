-- ЭТАП 4. СЕРВЕРНЫЙ КОД: ФУНКЦИИ, ПРОЦЕДУРЫ, ТРИГГЕРЫ

-- 1. Функция: Расчет "Уровня лояльности" клиента
-- Принимает ID клиента, считает его средний чек и возвращает статус.

CREATE OR REPLACE FUNCTION get_customer_loyalty_level(p_customer_id INT)
RETURNS VARCHAR AS $$
DECLARE
    v_avg_receipt NUMERIC;
    v_level VARCHAR(10);
BEGIN
    -- Считаем среднюю сумму чека клиента
    SELECT COALESCE(AVG(total_amount), 0) INTO v_avg_receipt
    FROM receipts
    WHERE customer_id = p_customer_id;
    -- Определяем уровень
    IF v_avg_receipt > 5000 THEN
        v_level := 'HIGH';
    ELSIF v_avg_receipt >= 1500 THEN
        v_level := 'MEDIUM';
    ELSE
        v_level := 'LOW';
    END IF;

    RETURN v_level;
END;
$$ LANGUAGE plpgsql;

-- Пример вывода функции:
-- SELECT get_customer_loyalty_level(1);

-- 2. Триггер: Автоматическое начисление бонусов клиенту при покупке
-- Срабатывает после добавления нового чека (AFTER INSERT ON receipts)

-- 1. Создаем функцию, которую будет вызывать триггер
CREATE OR REPLACE FUNCTION add_bonus_points()
RETURNS TRIGGER AS $$
DECLARE
    v_bonus_amount INT;
BEGIN
    -- Проверяем, привязан ли чек к клиенту 
    -- Если customer_id равен NULL, то ничего не делаем
    IF NEW.customer_id IS NOT NULL THEN
        
        -- Рассчитываем бонусы
        -- Функция ROUND округляет до целого числа
        v_bonus_amount := ROUND(NEW.total_amount * 0.5);

        UPDATE customers
        SET bonus_points = bonus_points + v_bonus_amount
        WHERE customer_id = NEW.customer_id;
        
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_add_bonus_after_receipt
AFTER INSERT ON receipts
FOR EACH ROW
EXECUTE FUNCTION add_bonus_points();

-- 3. Триггер аудита
-- Логирует UPDATE и DELETE в таблице audit_log.
-- Создаем таблицу для логов

CREATE TABLE IF NOT EXISTS audit_log (
    log_id SERIAL PRIMARY KEY,
    table_name TEXT,
    operation TEXT,
    old_data JSONB,
    new_data JSONB,
    changed_by TEXT,
    changed_at TIMESTAMP DEFAULT NOW()
);

CREATE OR REPLACE FUNCTION audit_customers_changes()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        INSERT INTO audit_log(table_name, operation, old_data, changed_by)
        VALUES ('customers', 'DELETE', row_to_json(OLD)::jsonb, current_user);
        RETURN OLD;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO audit_log(table_name, operation, old_data, new_data, changed_by)
        VALUES ('customers', 'UPDATE', row_to_json(OLD)::jsonb, row_to_json(NEW)::jsonb, current_user);
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_audit_customers
AFTER UPDATE OR DELETE ON customers
FOR EACH ROW EXECUTE FUNCTION audit_customers_changes();

-- Демонстрация работы аудита:
-- UPDATE customers SET bonus_points = 500 WHERE customer_id = 1;
-- SELECT * FROM audit_log;
