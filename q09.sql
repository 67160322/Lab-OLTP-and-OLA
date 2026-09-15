-- q09.sql: UNION ALL แสดงยอดรายเดือน + แถว ALL
-- การนำทุกแถวกลับมาบวกซ้ำทำให้ยอด ALL นับซ้ำ (double-counting)
SELECT month, SUM(amount) AS revenue
FROM sales
GROUP BY month
UNION ALL
SELECT 'ALL' AS month, SUM(amount) AS revenue
FROM sales
ORDER BY month;
