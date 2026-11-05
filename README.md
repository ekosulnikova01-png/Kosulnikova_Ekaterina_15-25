## Обоснование серверного кода

1. **Функция get_customer_loyalty_level**: Используется для сегментации клиентов. Бизнесу важно понимать, кто приносит больше денег, чтобы отправлять им персональные скидки, а кто покупает мало. Функция инкапсулирует логику расчета, чтобы аналитики не писали сложные запросы каждый раз.
2. **Триггер trg_check_sale_price (BEFORE)**: Защищает бизнес от ошибок кассира или сбоев системы. Если кассир вручную введет слишком большую скидку, триггер отменит операцию и выбросит исключение, предотвратив убыток магазина.
3. **Триггер trg_audit_customers (AFTER)**: Обязателен для соблюдения 152-ФЗ. Любое изменение или удаление персональных данных клиента должно фиксироваться. Триггер сохраняет слепок старых и новых данных в формате JSON, а также логирует, какой пользователь БД внес изменения. Это защищает от мошеннических атак.

4. ## Мониторинг и статистика

Для сбора подробной статистики по использованию таблиц в PostgreSQL используется официальное расширение pg_stat_statements.

### 1. Самые частые и ресурсоемкие запросы

**SQL-запрос:**
```sql
SELECT 
    query, 
    calls, 
    total_exec_time, 
    mean_exec_time 
FROM pg_stat_statements 
ORDER BY total_exec_time DESC 
LIMIT 5;
```
**Использования индексов**
```sql
SELECT 
    relname AS table_name,
    indexrelname AS index_name,
    idx_scan AS scans_count,
    idx_tup_read AS tuples_read
FROM pg_stat_user_indexes
ORDER BY idx_scan DESC;
```
**Использование диска** 
```sql
    relname AS table_name,
    pg_size_pretty(pg_total_relation_size(relid)) AS total_size,
    pg_size_pretty(pg_relation_size(relid)) AS table_size_only,
    pg_size_pretty(pg_total_relation_size(relid) - pg_relation_size(relid)) AS indexes_size
FROM pg_catalog.pg_statio_user_tables
ORDER BY pg_total_relation_size(relid) DESC;
```
