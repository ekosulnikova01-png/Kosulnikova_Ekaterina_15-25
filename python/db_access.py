#!/usr/bin/env python3
"""
Программный доступ к БД «Учёт розничных продаж»
Роль: разработчик (Этап 6 + паттерн версионирования)
"""


from __future__ import annotations

import os
import logging
from typing import Any, Optional
from contextlib import contextmanager
from datetime import datetime, timedelta
import random

import psycopg
from psycopg.rows import dict_row
import pandas as pd
from dotenv import load_dotenv

load_dotenv()

DB_CONFIG = {
    "host": os.getenv("DB_HOST", "localhost"),
    "port": os.getenv("DB_PORT", "5432"),
    "dbname": os.getenv("DB_NAME", "retail_sales"),
    "user": os.getenv("DB_USER", "developer"),
    "password": os.getenv("DB_PASSWORD", "devpass"),
}

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%H:%M:%S",
)
logger = logging.getLogger(__name__)


# 1. Подключение
@contextmanager
def get_connection(autocommit: bool = False):
    """Контекстный менеджер подключения к PostgreSQL."""
    conn = None
    try:
        conn = psycopg.connect(**DB_CONFIG, row_factory=dict_row, autocommit=autocommit)
        logger.info("Подключение к БД установлено (%s@%s/%s)",
                    DB_CONFIG["user"], DB_CONFIG["host"], DB_CONFIG["dbname"])
        yield conn
    except psycopg.Error as e:
        logger.error("Ошибка подключения: %s", e)
        raise
    finally:
        if conn and not conn.closed:
            conn.close()
            logger.info("Соединение закрыто")


# 2. Параметризованный SELECT
def get_customer_by_id(customer_id: int) -> Optional[dict]:
    """Параметризованный SELECT клиента по ID (+ уровень лояльности)."""
    sql = """
        SELECT customer_id, phone, bonus_points, registered_at,
               get_customer_loyalty_level(customer_id) AS loyalty_level
        FROM customers
        WHERE customer_id = %s
    """
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(sql, (customer_id,))
            row = cur.fetchone()
            if row:
                logger.info("Найден клиент id=%s, loyalty=%s", customer_id, row["loyalty_level"])
            else:
                logger.warning("Клиент id=%s не найден", customer_id)
            return row


def get_receipts_by_customer(customer_id: int) -> list[dict]:
    """Параметризованный SELECT всех чеков клиента."""
    sql = """
        SELECT r.receipt_id, r.created_at, r.total_amount,
               s.address AS store_address
        FROM receipts r
        JOIN shifts sh ON r.shift_id = sh.shift_id
        JOIN stores s  ON sh.store_id = s.store_id
        WHERE r.customer_id = %s
        ORDER BY r.created_at DESC
    """
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(sql, (customer_id,))
            return cur.fetchall()


# 3. INSERT / UPDATE внутри транзакции
def create_receipt(
    shift_id: int,
    customer_id: Optional[int],
    total_amount: float,
    payment_type: str = "card",
) -> int:
    """
    Создаёт чек + оплату в одной транзакции.
    При ошибке — полный ROLLBACK.
    Возвращает receipt_id.
    """
    if total_amount <= 0:
        raise ValueError("Сумма чека должна быть положительной")

    with get_connection() as conn:
        try:
            with conn.transaction():
                with conn.cursor() as cur:
                    cur.execute(
                        """
                        INSERT INTO receipts (shift_id, customer_id, total_amount)
                        VALUES (%s, %s, %s)
                        RETURNING receipt_id
                        """,
                        (shift_id, customer_id, total_amount),
                    )
                    receipt_id = cur.fetchone()["receipt_id"]

                    cur.execute(
                        """
                        INSERT INTO payments (receipt_id, payment_type, amount)
                        VALUES (%s, %s, %s)
                        """,
                        (receipt_id, payment_type, total_amount),
                    )

            logger.info("Чек %s успешно создан на сумму %.2f", receipt_id, total_amount)
            return receipt_id

        except Exception as e:
            logger.error("Ошибка при создании чека → ROLLBACK: %s", e)
            raise


def update_product_price(product_id: int, new_price: float) -> bool:
    """
    Обновление цены товара + версионирование (SCD Type 2).
    Старая цена сохраняется в product_price_history.
    """
    with get_connection() as conn:
        try:
            with conn.transaction():
                with conn.cursor() as cur:
                    cur.execute(
                        "SELECT price FROM products WHERE product_id = %s FOR UPDATE",
                        (product_id,),
                    )
                    row = cur.fetchone()
                    if not row:
                        raise ValueError(f"Товар product_id={product_id} не найден")

                    old_price = float(row["price"])
                    if old_price == new_price:
                        logger.info("Цена не изменилась")
                        return False

                    # Закрываем предыдущую версию
                    cur.execute(
                        """
                        UPDATE product_price_history
                        SET valid_to = NOW()
                        WHERE product_id = %s AND valid_to IS NULL
                        """,
                        (product_id,),
                    )

                    # Новая версия
                    cur.execute(
                        """
                        INSERT INTO product_price_history
                            (product_id, price, valid_from, valid_to)
                        VALUES (%s, %s, NOW(), NULL)
                        """,
                        (product_id, new_price),
                    )

                    # Актуальная цена
                    cur.execute(
                        "UPDATE products SET price = %s WHERE product_id = %s",
                        (new_price, product_id),
                    )

            logger.info(
                "Цена товара %s изменена: %.2f → %.2f (версионировано)",
                product_id, old_price, new_price,
            )
            return True

        except Exception as e:
            logger.error("Ошибка обновления цены → ROLLBACK: %s", e)
            raise


# 4. Выгрузка MATERIALIZED VIEW → pandas → CSV
def export_mv_to_csv(output_path: str = "mv_daily_sales.csv") -> pd.DataFrame:
    """Выгружает витрину mv_daily_sales в pandas и CSV."""
    sql = """
        SELECT store_id, store_address, sale_date,
               receipts_count, total_revenue, avg_receipt
        FROM mv_daily_sales
        ORDER BY sale_date DESC, total_revenue DESC
    """
    uri = (
        f"postgresql+psycopg://{DB_CONFIG['user']}:{DB_CONFIG['password']}"
        f"@{DB_CONFIG['host']}:{DB_CONFIG['port']}/{DB_CONFIG['dbname']}"
    )
    df = pd.read_sql(sql, uri)
    df.to_csv(output_path, index=False, encoding="utf-8-sig")
    logger.info("Витрина выгружена: %d строк → %s", len(df), output_path)
    return df


# 5. Batch-загрузка
def batch_insert_products(products: list[dict]) -> int:
    """
    Пакетная вставка товаров.
    products = [{"sku": "...", "name": "...", "price": 10.0}, ...]
    """
    if not products:
        return 0

    sql = """
        INSERT INTO products (sku, name, price)
        VALUES (%(sku)s, %(name)s, %(price)s)
        ON CONFLICT (sku) DO NOTHING
    """
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.executemany(sql, products)
            inserted = cur.rowcount
        conn.commit()

    logger.info("Batch insert: обработано %d, вставлено %d", len(products), inserted)
    return inserted


def generate_and_load_demo_data(n_receipts: int = 500) -> None:
    """Генерирует тестовые чеки для реалистичных EXPLAIN ANALYZE."""
    logger.info("Генерация %d тестовых чеков...", n_receipts)

    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT shift_id FROM shifts")
            shift_ids = [r["shift_id"] for r in cur.fetchall()]
            cur.execute("SELECT customer_id FROM customers")
            customer_ids = [r["customer_id"] for r in cur.fetchall()] + [None]

            if not shift_ids:
                logger.error("Нет смен для генерации")
                return

            base_time = datetime.now() - timedelta(days=30)

            for i in range(n_receipts):
                shift_id = random.choice(shift_ids)
                customer_id = random.choice(customer_ids)
                created = base_time + timedelta(
                    days=random.randint(0, 29),
                    hours=random.randint(8, 21),
                    minutes=random.randint(0, 59),
                )
                total = round(random.uniform(50, 1500), 2)

                cur.execute(
                    """
                    INSERT INTO receipts (shift_id, customer_id, created_at, total_amount)
                    VALUES (%s, %s, %s, %s)
                    RETURNING receipt_id
                    """,
                    (shift_id, customer_id, created, total),
                )
                rid = cur.fetchone()["receipt_id"]

                cur.execute(
                    """
                    INSERT INTO payments (receipt_id, payment_type, amount)
                    VALUES (%s, %s, %s)
                    """,
                    (rid, random.choice(["cash", "card"]), total),
                )

                if (i + 1) % 100 == 0:
                    conn.commit()
                    logger.info("  ... загружено %d чеков", i + 1)

            conn.commit()

    with get_connection(autocommit=True) as conn:
        with conn.cursor() as cur:
            cur.execute("REFRESH MATERIALIZED VIEW mv_daily_sales")
    logger.info("Генерация завершена, MV обновлён")


# 6. Проверка качества данных
def check_data_quality() -> dict[str, Any]:
    """Количество строк, пропуски, дубликаты по ключевым полям."""
    report: dict[str, Any] = {"tables": {}, "issues": []}

    checks = {
        "stores": ("store_id", ["address"]),
        "products": ("product_id", ["sku", "name", "price"]),
        "customers": ("customer_id", ["phone"]),
        "receipts": ("receipt_id", ["shift_id", "total_amount"]),
        "payments": ("payment_id", ["receipt_id", "amount"]),
    }

    with get_connection() as conn:
        with conn.cursor() as cur:
            for table, (pk, required_cols) in checks.items():
                cur.execute(f"SELECT COUNT(*) AS cnt FROM {table}")
                cnt = cur.fetchone()["cnt"]
                report["tables"][table] = {"row_count": cnt}

                for col in required_cols:
                    cur.execute(
                        f"SELECT COUNT(*) AS nulls FROM {table} WHERE {col} IS NULL"
                    )
                    nulls = cur.fetchone()["nulls"]
                    if nulls > 0:
                        report["issues"].append(f"{table}.{col}: {nulls} NULL")

                cur.execute(
                    f"""
                    SELECT {pk}, COUNT(*) AS c
                    FROM {table}
                    GROUP BY {pk}
                    HAVING COUNT(*) > 1
                    """
                )
                if cur.fetchall():
                    report["issues"].append(f"{table}: дубликаты PK")

            cur.execute(
                """
                SELECT sku, COUNT(*) FROM products
                GROUP BY sku HAVING COUNT(*) > 1
                """
            )
            if cur.fetchall():
                report["issues"].append("products.sku: дубликаты")

    report["status"] = (
        "OK — критических проблем не обнаружено"
        if not report["issues"]
        else f"НАЙДЕНО ПРОБЛЕМ: {len(report['issues'])}"
    )
    logger.info("Проверка качества: %s", report["status"])
    for issue in report["issues"]:
        logger.warning("  • %s", issue)
    return report

# Демонстрация
def main():
    print("=" * 60)
    print("  db_access.py — демонстрация Этапа 6 (упрощённая схема)")
    print("=" * 60)

    print("\n--- 1. SELECT клиента ---")
    print(get_customer_by_id(1))

    print("\n--- 2. Чеки клиента ---")
    for r in get_receipts_by_customer(1)[:3]:
        print(r)

    print("\n--- 3. Создание чека в транзакции ---")
    try:
        new_id = create_receipt(shift_id=2, customer_id=1, total_amount=299.90, payment_type="card")
        print(f"Создан чек receipt_id = {new_id}")
    except Exception as e:
        print(f"Ошибка: {e}")

    print("\n--- 3b. Изменение цены с версионированием ---")
    update_product_price(1, 49.90)

    print("\n--- 4. Выгрузка MATERIALIZED VIEW ---")
    df = export_mv_to_csv("/home/workdir/artifacts/python/mv_daily_sales.csv")
    print(df.head(5).to_string(index=False))

    print("\n--- 5. Batch-загрузка товаров ---")
    batch_insert_products([
        {"sku": "SKU-100", "name": "Тестовый товар A", "price": 99.0},
        {"sku": "SKU-101", "name": "Тестовый товар B", "price": 149.0},
    ])

    print("\n--- 6. Проверка качества данных ---")
    report = check_data_quality()
    print("Статус:", report["status"])
    print("Строк:", report["tables"])

    print("\n--- 7. Генерация 500 тестовых чеков ---")
    generate_and_load_demo_data(500)

    print("\n" + "=" * 60)
    print("  Все пункты Этапа 6 выполнены")
    print("=" * 60)


if __name__ == "__main__":
    main()
