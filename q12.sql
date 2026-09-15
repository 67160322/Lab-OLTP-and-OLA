-- q12.sql: Drill-down - ยอดขายรายวันเฉพาะกันยายน (Slice + Drill-down)
-- ผลรวมของทุกแถวควรเท่ากับยอด revenue ของ q03 เดือน 2026-09 (900 บาท)
SELECT
    full_date,
    SUM(amount) AS revenue
FROM sales
WHERE month = '2026-09'
GROUP BY full_date
ORDER BY full_date;
