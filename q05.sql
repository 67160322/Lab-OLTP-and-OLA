-- q05.sql: Slice - กรองเฉพาะกันยายน (Slice by month=September)
SELECT
    full_date,
    province,
    product_name,
    SUM(amount) AS revenue
FROM sales
WHERE month = '2026-09'
GROUP BY full_date, province, product_name
ORDER BY full_date, province;
