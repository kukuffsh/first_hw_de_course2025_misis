```sql
-- 1. Создание таблиц
CREATE TABLE users (
    id INTEGER PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL,
    created_at TIMESTAMP NOT NULL
);

CREATE TABLE categories (
    id INTEGER PRIMARY KEY,
    name VARCHAR(100) UNIQUE NOT NULL
);

CREATE TABLE products (
    id INTEGER PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    price NUMERIC(10,2) CHECK (price >= 0),
    category_id INTEGER REFERENCES categories(id) NOT NULL
);

CREATE TABLE orders (
    id INTEGER PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) NOT NULL,
    status VARCHAR(50) CHECK (status IN ('Оплачен', 'Ожидает оплаты', 'Доставлен')),
    created_at TIMESTAMP NOT NULL
);

CREATE TABLE order_items (
    id INTEGER PRIMARY KEY,
    order_id INTEGER REFERENCES orders(id) NOT NULL,
    product_id INTEGER REFERENCES products(id) NOT NULL,
    quantity INTEGER CHECK (quantity > 0) NOT NULL
);

CREATE TABLE payments (
    id INTEGER PRIMARY KEY,
    order_id INTEGER REFERENCES orders(id) NOT NULL,
    amount NUMERIC(10,2) CHECK (amount >= 0),
    payment_date TIMESTAMP
);

-- 2. Заполнение таблиц (пропускаем, как указано в задании)

-- Задача 1. Средняя стоимость заказа по категориям товаров
SELECT 
    c.name AS category_name,
    ROUND(AVG(oi.quantity * p.price), 2) AS avg_order_amount
FROM orders o
JOIN order_items oi ON o.id = oi.order_id
JOIN products p ON oi.product_id = p.id
JOIN categories c ON p.category_id = c.id
WHERE o.created_at >= '2023-03-01' AND o.created_at < '2023-04-01'
GROUP BY c.id
ORDER BY avg_order_amount DESC;

-- Задача 2. Рейтинг пользователей по сумме оплаченных заказов
WITH user_spending AS (
    SELECT 
        u.id,
        SUM(oi.quantity * p.price) AS total_spent
    FROM users u
    JOIN orders o ON u.id = o.user_id AND o.status = 'Оплачен'
    JOIN order_items oi ON o.id = oi.order_id
    JOIN products p ON oi.product_id = p.id
    GROUP BY u.id
)
SELECT 
    u.name AS user_name,
    us.total_spent,
    RANK() OVER (ORDER BY us.total_spent DESC) AS user_rank
FROM user_spending us
JOIN users u ON us.id = u.id
ORDER BY user_rank
LIMIT 3;

-- Задача 3. Количество заказов и сумма платежей по месяцам
SELECT 
    TO_CHAR(o.created_at, 'YYYY-MM') AS month,
    COUNT(DISTINCT o.id) AS total_orders,
    ROUND(SUM(p.amount)::numeric, 2) AS total_payments
FROM orders o
LEFT JOIN payments p ON o.id = p.order_id
WHERE EXTRACT(YEAR FROM o.created_at) = 2023
GROUP BY month
ORDER BY month;

-- Задача 4. Рейтинг товаров по количеству продаж
WITH total_sales AS (
    SELECT SUM(quantity) AS total FROM order_items
)
SELECT 
    p.name AS product_name,
    SUM(oi.quantity) AS total_sold,
    ROUND(SUM(oi.quantity) * 100.0 / (SELECT total FROM total_sales), 2) AS sales_percentage
FROM order_items oi
JOIN products p ON oi.product_id = p.id
GROUP BY p.id
ORDER BY total_sold DESC
LIMIT 5;

-- Задача 5. Пользователи, которые сделали заказы на сумму выше среднего
WITH user_spending AS (
    SELECT 
        u.id,
        SUM(oi.quantity * p.price) AS total_spent
    FROM users u
    JOIN orders o ON u.id = o.user_id AND o.status = 'Оплачен'
    JOIN order_items oi ON o.id = oi.order_id
    JOIN products p ON oi.product_id = p.id
    GROUP BY u.id
)
SELECT 
    u.name AS user_name,
    us.total_spent
FROM user_spending us
JOIN users u ON us.id = u.id
WHERE us.total_spent > (SELECT AVG(total_spent) FROM user_spending);

-- Задача 6. Рейтинг товаров по количеству продаж в каждой категории
WITH ranked_products AS (
    SELECT 
        p.category_id,
        p.id AS product_id,
        SUM(oi.quantity) AS total_sold,
        RANK() OVER (PARTITION BY p.category_id ORDER BY SUM(oi.quantity) DESC) AS rank
    FROM order_items oi
    JOIN products p ON oi.product_id = p.id
    GROUP BY p.category_id, p.id
)
SELECT 
    c.name AS category_name,
    p.name AS product_name,
    rp.total_sold
FROM ranked_products rp
JOIN categories c ON rp.category_id = c.id
JOIN products p ON rp.product_id = p.id
WHERE rank <= 3
ORDER BY category_name, total_sold DESC;

-- Задача 7. Категории товаров с максимальной выручкой в каждом месяце
WITH monthly_revenue AS (
    SELECT 
        TO_CHAR(o.created_at, 'YYYY-MM') AS month,
        c.name AS category_name,
        SUM(oi.quantity * p.price) AS total_revenue,
        RANK() OVER (PARTITION BY TO_CHAR(o.created_at, 'YYYY-MM') ORDER BY SUM(oi.quantity * p.price) DESC) AS rank
    FROM orders o
    JOIN order_items oi ON o.id = oi.order_id
    JOIN products p ON oi.product_id = p.id
    JOIN categories c ON p.category_id = c.id
    WHERE o.created_at >= '2023-01-01' AND o.created_at < '2023-07-01'
    GROUP BY month, c.name
)
SELECT 
    month,
    category_name,
    total_revenue
FROM monthly_revenue
WHERE rank = 1
ORDER BY month;

-- Задача 8. Накопительная сумма платежей по месяцам
SELECT 
    TO_CHAR(o.created_at, 'YYYY-MM') AS month,
    ROUND(SUM(p.amount)::numeric, 2) AS monthly_payments,
    ROUND(SUM(SUM(p.amount)) OVER (ORDER BY TO_CHAR(o.created_at, 'YYYY-MM'))::numeric, 2) AS cumulative_payments
FROM payments p
JOIN orders o ON p.order_id = o.id
WHERE EXTRACT(YEAR FROM o.created_at) = 2023
GROUP BY month
ORDER BY month;
```