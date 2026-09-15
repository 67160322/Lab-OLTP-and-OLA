-- q04.sql: Drill-down by full_date (เพิ่มรายละเอียดภายในมิติเวลา) - ยอดขายรายวัน
SELECT
    full_date,
    SUM(amount) AS revenue
FROM sales
GROUP BY full_date
ORDER BY full_date;
