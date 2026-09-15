# รายงานแลป OLTP OLAP และ Pivot

ชื่อ: นายจิรัฐติกุล งามขำ  รหัส: 67160322  กลุ่ม: 2

---

## 1 OLTP

### โค้ด oltp_demo.py (ส่วนที่แก้ไข)

```python
cur = con.execute(
    "UPDATE orders SET status='PAID' WHERE order_id='O1004' AND status='PENDING'"
)
print(f'Rows affected: {cur.rowcount}')
```

### ผลรันรอบที่ 1 (สถานะเริ่มต้น PENDING)

```
Before: [('O1004', 'PENDING')]
Rows affected: 1
After:  [('O1004', 'PAID')]
```

### ผลรันรอบที่ 2 (สถานะเป็น PAID แล้ว)

```
Before: [('O1004', 'PAID')]
Rows affected: 0
After:  [('O1004', 'PAID')]
```

### คำอธิบายสถานะและ ETL

**คำถาม**: รอบแรกและรอบสองต่างกันเพราะเหตุใดจึงต้องมีเงื่อนไข `status`?

**คำตอบ**: รอบแรก `status='PENDING'` ตรงกับเงื่อนไข WHERE จึง UPDATE สำเร็จ rowcount=1  
รอบสอง `status='PAID'` ไม่ตรง WHERE แล้ว → rowcount=0 ไม่มีการเปลี่ยนแปลงซ้ำ  
นี่คือหลักการ **Idempotent Guard** ของ OLTP: ป้องกัน double-processing เช่น ชำระเงินซ้ำ

**อธิบายเพิ่ม**: การเปลี่ยน `oltp.db` ไม่ทำให้ยอดใน `warehouse.db` เปลี่ยนทันที เพราะเป็นคนละฐานข้อมูล ระบบจริงต้องมีกระบวนการ ETL (Extract → Transform → Load) เพื่อนำข้อมูลจาก OLTP ไปอัปเดตใน Data Warehouse OLTP ไม่ค่อยใช้ SELECT วิเคราะห์สถานะตรง ๆ เนื่องจากออกแบบมาเพื่อ write throughput สูง ไม่ใช่วิเคราะห์

---

## 2 Grain และ Star Schema

### Star Schema ของ warehouse.db

```
                    ┌──────────────────┐
                    │   dim_date       │
                    │  PK: date_key    │
                    │  full_date       │
                    │  year            │
                    │  month           │
                    └────────┬─────────┘
                             │ 1:N
         ┌───────────────────┼────────────────────┐
         │                   │                    │
┌────────┴──────┐   ┌────────▼──────────┐   ┌────┴──────────┐
│  dim_product  │   │    fact_sales     │   │  dim_store    │
│ PK: prod_key  │1:N│ PK: order_id,     │N:1│ PK: store_key │
│ product_name  ├───│      line_no      ├───│ store_name    │
│ category      │   │ FK: date_key      │   │ province      │
└───────────────┘   │ FK: product_key   │   │ region        │
                    │ FK: store_key     │   └───────────────┘
                    │ quantity          │
                    │ unit_price        │
                    └───────────────────┘
```

**ความหมายของ 1 แถวใน fact_sales**: คือรายการสินค้า 1 ชนิด ใน 1 ออเดอร์ ที่ขายในวันและสาขาหนึ่ง  
ตัวอย่าง O1001 มี 2 แถว (Tea และ Cookie) เพราะ Grain = (order_id, line_no)

### ผล q01

```
line_count  order_count  units  revenue
8           6            23     1390
```

| ข้อมูล | ค่า |
|--------|-----|
| จำนวนรายการ | 8 |
| จำนวนออเดอร์ | 6 |
| จำนวนชิ้น | 23 |
| ยอดขายรวม | 1,390 บาท |

### Grain และ Dimensions

- **Grain**: 1 รายการสินค้า ต่อ 1 ออเดอร์ (order_id + line_no)
- **3 Dimensions**: `dim_date` (วัน/เดือน/ปี), `dim_product` (ชื่อสินค้า/หมวดหมู่), `dim_store` (สาขา/จังหวัด/ภาค)
- **2 Measures (Additive)**: `quantity` (จำนวนชิ้น), `amount` (ยอดขาย = quantity × unit_price)
- **Hierarchy เวลา**: year → month → full_date
- **Hierarchy สถานที่**: region → province → store_name
- **เหตุผลที่ unit_price ไม่ควร SUM**: unit_price เป็นราคาต่อหน่วย ถ้านำมา SUM จะได้ตัวเลขไม่มีความหมาย ต้องใช้ AVG หรือดูเป็นรายสินค้า เป็น **Non-additive measure**

---

## 3 OLAP

### q02 — Roll-up (Grand Total)

```sql
SELECT SUM(amount) AS total_revenue FROM sales;
```

**ผล**: `total_revenue = 1390`  
**Operation**: Roll-up ทั้งหมด ยุบทุกมิติเหลือยอดรวมเดียว

---

### q03 — Roll-up by Month

```sql
SELECT month, SUM(amount) AS revenue FROM sales GROUP BY month ORDER BY month;
```

**ผล**:
```
month    revenue
2026-08  490
2026-09  900
```
**Operation**: Roll-up โดยจัดกลุ่มตามเดือน (มิติเวลาระดับเดือน)

---

### q04 — Drill-down to Date

```sql
SELECT full_date, SUM(amount) AS revenue FROM sales GROUP BY full_date ORDER BY full_date;
```

**ผล**:
```
full_date   revenue
2026-08-08  180
2026-08-09  150
2026-08-10  160
2026-09-09  360
2026-09-10  300
2026-09-11  240
```
**Operation**: Drill-down จากระดับเดือน → วัน  
**q03 vs q04**: q03 เห็นภาพรวมรายเดือน q04 เห็นรายละเอียดรายวัน ช่วยวิเคราะห์ว่าวันไหนขายดีภายในเดือน

---

### q05 — Slice (September only)

```sql
SELECT full_date, province, product_name, SUM(amount) AS revenue
FROM sales WHERE month = '2026-09'
GROUP BY full_date, province, product_name ORDER BY full_date, province;
```

**ผล**:
```
full_date   province  product_name  revenue
2026-09-09  Chonburi  Cookie        160
2026-09-09  Chonburi  Tea           200
2026-09-10  Bangkok   Tea           300
2026-09-11  Bangkok   Cookie        240
```
**Operation**: Slice ตัดเฉพาะกันยายน (WHERE ใน dimension เวลา)

---

### q06 — Dice (Chonburi + August)

```sql
SELECT full_date, province, product_name, SUM(amount) AS revenue
FROM sales WHERE province = 'Chonburi' AND month = '2026-08'
GROUP BY full_date, province, product_name ORDER BY full_date;
```

**ผล**:
```
full_date   province  product_name  revenue
2026-08-08  Chonburi  Cookie        80
2026-08-08  Chonburi  Tea           100
```
**Operation**: Dice กรองสองมิติ (province AND month) พร้อมกัน

---

### q07 — HAVING กรองกลุ่มที่มียอดสูง

```sql
SELECT province, month, SUM(amount) AS revenue
FROM sales GROUP BY province, month HAVING SUM(amount) > 200 ORDER BY province, month;
```

**ผล**:
```
province  month    revenue
Bangkok   2026-08  310
Bangkok   2026-09  540
Chonburi  2026-09  360
```
**Operation**: Roll-up by province+month แล้วกรองด้วย HAVING  
**WHERE vs HAVING**: WHERE กรองแถวก่อน GROUP BY (ระดับ row) ส่วน HAVING กรองหลัง GROUP BY (ระดับกลุ่ม) ยอด SUM(amount) ต้องกรองที่ HAVING เพราะยังไม่มีค่า aggregate ก่อน GROUP BY

---

### q12 — Drill-down รายวันใน September

```sql
SELECT full_date, SUM(amount) AS revenue FROM sales WHERE month = '2026-09'
GROUP BY full_date ORDER BY full_date;
```

**ผล**:
```
full_date   revenue
2026-09-09  360
2026-09-10  300
2026-09-11  240
```
ผลรวม 360+300+240 = **900** ตรงกับยอด q03 เดือน 2026-09 (ผ่านจุดตรวจ ✓)

---

## 4 Pivot

### q08 — SQL Pivot (province × month)

```sql
SELECT province,
    SUM(CASE WHEN month = '2026-08' THEN amount ELSE 0 END) AS aug,
    SUM(CASE WHEN month = '2026-09' THEN amount ELSE 0 END) AS sep,
    SUM(amount) AS total
FROM sales GROUP BY province ORDER BY province;
```

**ผล**:
```
province  aug  sep  total
Bangkok   310  540  850
Chonburi  180  360  540
```

---

### P1 — Python Pivot: province × month

```python
p1 = pd.pivot_table(df, index='province', columns='month',
    values='amount', aggfunc='sum', fill_value=0,
    margins=True, margins_name='Total')
```

**ผล**:
```
month     2026-08  2026-09  Total
province
Bangkok       310      540    850
Chonburi      180      360    540
Total         490      900   1390
```

---

### P2 — Python Pivot September: category × province

```python
df_sep = df[df['month'] == '2026-09']
p2 = pd.pivot_table(df_sep, index='category', columns='province',
    values='amount', aggfunc='sum', fill_value=0)
```

**ผล**:
```
province  Bangkok  Chonburi
category
Drink         300       200
Snack         240       160
```

---

### Assert Grand Total P1

```python
grand_total_p1 = p1.loc['Total', 'Total']  # 1390
assert grand_total_p1 == df['amount'].sum()  # ✓ PASS
```

**ผล**: `Assert OK: Grand Total P1 = 1390 == df['amount'].sum() = 1390`

---

### ทดลองข้อผิดพลาด: ลบ aggfunc

เมื่อลบ `aggfunc='sum'` pandas ใช้ **mean** เป็นค่าเริ่มต้น  
Bangkok กันยายนมี 2 รายการ: 300 (Tea) และ 240 (Cookie)  
→ mean = (300 + 240) / 2 = **270**

**ก่อนแก้** (mean): Bangkok ก.ย. = 270  
**หลังแก้** (sum): Bangkok ก.ย. = 540

ข้อแตกต่าง sum vs mean: `sum` รวมยอดขายทั้งหมดในกลุ่ม (ใช้วิเคราะห์รายได้รวม), `mean` คำนวณค่าเฉลี่ยต่อรายการ — ในบริบทยอดขายต้องใช้ sum

---

### Drink PivotTable (กรณีไม่มี Excel)

```python
df_drink = df[df['category'] == 'Drink']
p_drink = pd.pivot_table(df_drink, index='province', columns='month',
    values='amount', aggfunc='sum', fill_value=0, margins=True, margins_name='Total')
```

**ยอดรวมหลังกรอง Drink = 750 บาท**  
แกน Rows = province  Columns = month  Values = amount (sum)

```
month     2026-08  2026-09  Total
province
Bangkok       150      300    450
Chonburi      100      200    300
Total         250      500    750
```

---

## 5 ตรวจความถูกต้อง

### q09 — UNION ALL

```sql
SELECT month, SUM(amount) AS revenue FROM sales GROUP BY month
UNION ALL
SELECT 'ALL', SUM(amount) FROM sales ORDER BY month;
```

**ผล**:
```
month    revenue
2026-08  490
2026-09  900
ALL      1390
```
การนำทุกแถวกลับมาบวกซ้ำ (490 + 900 + 1390) จะทำให้เกิด **double-counting** เพราะแถว ALL นับข้อมูลซ้ำทุกแถวที่รวมไว้แล้วในเดือน

---

### q10 — AOV และ avg_line

```sql
SELECT SUM(amount) AS revenue, COUNT(DISTINCT order_id) AS orders,
    ROUND(CAST(SUM(amount) AS REAL) / COUNT(DISTINCT order_id), 2) AS aov,
    ROUND(AVG(amount), 2) AS avg_line
FROM sales;
```

**ผล**:
```
revenue  orders  aov     avg_line
1390     6       231.67  173.75
```

- **AOV** = 231.67 บาท/ออเดอร์ — ลูกค้าจ่ายเฉลี่ยต่อครั้งที่ซื้อ
- **AVG(amount)** = 173.75 บาท/รายการ — ต่ำกว่า AOV เพราะ 1 ออเดอร์อาจมีหลายรายการ
- ใช้ `CAST(... AS REAL)` เพราะ SQLite ทำ integer division

---

### q11 — ตรวจ JOIN

```sql
SELECT 'fact_sales', COUNT(*), SUM(quantity*unit_price) FROM fact_sales
UNION ALL
SELECT 'sales (after JOIN)', COUNT(*), SUM(amount) FROM sales;
```

**ผล**:
```
source              row_count  total_amount
fact_sales          8          1390
sales (after JOIN)  8          1390
```

จำนวนแถวและยอดรวมตรงกัน → ไม่มี FK หาย  
`PRAGMA foreign_key_check;` → ผลว่าง (ไม่พบปัญหา ✓)

---

### 5.4 ชนิด Measure

| ชนิด | ตัวอย่าง | วิธีรวมที่เหมาะสม |
|------|----------|-------------------|
| **Additive** | `amount` (ยอดขาย) | SUM ได้ทุกมิติ |
| **Semi-additive** | สต็อกสิ้นวัน | SUM ตามสาขาได้ แต่ SUM ข้ามวันไม่ได้ → ใช้ AVG หรือ snapshot ล่าสุด |
| **Non-additive** | AOV ข้ามเดือน, unit_price | ห้าม SUM → คำนวณใหม่จาก fact เสมอ |

---

## 6 สรุป

### ข้อค้นพบ 2 ข้อ

1. **กันยายนมียอดขายสูงกว่าสิงหาคมเกือบเท่าตัว** (900 vs 490 บาท) โดย Bangkok เป็น province ที่มียอดสูงสุดทั้งสองเดือน (850 บาท) แสดงว่าสาขาในกรุงเทพฯ มีกำลังซื้อสูงกว่าชลบุรีอย่างชัดเจน

2. **AOV (231.67 บาท) สูงกว่า AVG per line (173.75 บาท)** เพราะบางออเดอร์มีสินค้าหลายรายการ (O1001 และ O1004 มี 2 รายการต่อออเดอร์) แสดงว่ากลยุทธ์ Cross-selling ได้ผล

### ข้อจำกัด 1 ข้อ

ข้อมูลมีเพียง 8 รายการ 6 ออเดอร์ ใน 2 เดือน จาก 2 จังหวัดเท่านั้น ไม่เพียงพอสำหรับการสรุปภาพรวมที่น่าเชื่อถือ ต้องใช้ extended.db (3,649 รายการ) สำหรับการวิเคราะห์จริง

### การใช้ AI

ใช้ AI ช่วยออกแบบโครงสร้าง SQL query สำหรับ CASE WHEN pivot และตรวจสอบ logic ของ assert grand total  
จุดที่ตรวจแก้ด้วยตนเอง: ยืนยันว่า `AND status='PENDING'` ใน WHERE clause ทำให้ rowcount รอบสองเป็น 0 ซึ่งถูกต้องตามหลัก Idempotent Guard
