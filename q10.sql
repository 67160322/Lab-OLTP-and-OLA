-- q10.sql: คำนวณ revenue, orders, aov (Average Order Value) และ avg_line
-- AOV = SUM(amount) / COUNT(DISTINCT order_id) ปัด 2 ตำแหน่ง
-- ใช้ CAST เพื่อให้เป็นการหารทศนิยม (SQLite ปกติทำ integer division)
SELECT
    SUM(amount) AS revenue,
    COUNT(DISTINCT order_id) AS orders,
    ROUND(CAST(SUM(amount) AS REAL) / COUNT(DISTINCT order_id), 2) AS aov,
    ROUND(AVG(amount), 2) AS avg_line
FROM sales;
