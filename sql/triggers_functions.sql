-- ЭТАП 4. СЕРВЕРНЫЙ КОД: ФУНКЦИИ, ПРОЦЕДУРЫ, ТРИГГЕРЫ

-- 1. Функция: уровень лояльности клиента по среднему чеку
-- Принимает ID клиента, считает его средний чек и возвращает статус.
CREATE OR REPLACE FUNCTION get_customer_loyalty_level(p_customer_id INT)
RETURNS VARCHAR AS $$
DECLARE
    v_avg_receipt NUMERIC;
    v_level VARCHAR(10);
BEGIN
    SELECT COALESCE(AVG(total_amount), 0) INTO v_avg_receipt
    FROM receipts
    WHERE customer_id = p_customer_id;

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

-- Пример: SELECT get_customer_loyalty_level(1);


-- 2. Триггер: Автоматическое начисление бонусов клиенту при покупке
-- Срабатывает после добавления нового чека (AFTER INSERT ON receipts)
CREATE OR REPLACE FUNCTION add_bonus_points()
RETURNS TRIGGER AS $$
DECLARE
    v_bonus_amount INT;
BEGIN
    IF NEW.customer_id IS NOT NULL THEN
        v_bonus_amount := ROUND(NEW.total_amount * 0.05);  -- 5% бонусами
        UPDATE customers
        SET bonus_points = bonus_points + v_bonus_amount
        WHERE customer_id = NEW.customer_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_add_bonus_after_receipt ON receipts;
CREATE TRIGGER trg_add_bonus_after_receipt
AFTER INSERT ON receipts
FOR EACH ROW
EXECUTE FUNCTION add_bonus_points();


-- 3. Триггер аудита изменений клиентов (152-ФЗ)
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

DROP TRIGGER IF EXISTS trg_audit_customers ON customers;
CREATE TRIGGER trg_audit_customers
AFTER UPDATE OR DELETE ON customers
FOR EACH ROW
EXECUTE FUNCTION audit_customers_changes();

-- Демонстрация:
-- UPDATE customers SET bonus_points = 500 WHERE customer_id = 1;
-- SELECT * FROM audit_log;
