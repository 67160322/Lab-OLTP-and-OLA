-- q06.sql: Dice - กรองสองมิติ (Chonburi + สิงหาคม)
SELECT
    full_date,
    province,
    product_name,
    SUM(amount) AS revenue
FROM sales
WHERE province = 'Chonburi'
  AND month = '2026-08'
GROUP BY full_date, province, product_name
ORDER BY full_date;
