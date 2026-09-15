-- q03.sql: Roll-up by month (เพิ่มมิติเวลา) - ยอดขายรายเดือน
SELECT
    month,
    SUM(amount) AS revenue
FROM sales
GROUP BY month
ORDER BY month;
