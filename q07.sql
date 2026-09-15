-- q07.sql: Roll-up by province + month, กรองเฉพาะกลุ่มที่มียอดรวม > 200 บาท
-- กรอง WHERE สำหรับเงื่อนไขแถว, HAVING สำหรับกรองผลรวมของกลุ่ม
SELECT
    province,
    month,
    SUM(amount) AS revenue
FROM sales
GROUP BY province, month
HAVING SUM(amount) > 200
ORDER BY province, month;
