-- q02.sql: Roll-up - ยอดขายรวมทั้งหมด (Grand Total)
SELECT
    SUM(amount) AS total_revenue
FROM sales;
