from pathlib import Path
import sqlite3
import pandas as pd

ROOT = Path(__file__).resolve().parent

with sqlite3.connect((ROOT/'data'/'warehouse.db').as_uri()+'?mode=ro', uri=True) as con:
    df = pd.read_sql_query('SELECT * FROM sales', con)

print("=== Head of data ===")
print(df.head())
print()

# --- P1: province x month, sum(amount), fill_value=0, margins=True ---
p1 = pd.pivot_table(
    df,
    index='province',
    columns='month',
    values='amount',
    aggfunc='sum',
    fill_value=0,
    margins=True,
    margins_name='Total'
)
print("=== P1: Province x Month (sum) ===")
print(p1)
p1.to_csv(ROOT/'pivot_province_month.csv')
print("-> Saved pivot_province_month.csv")
print()

# --- P2: กรองกันยายนก่อน แล้ว Pivot: category x province ---
df_sep = df[df['month'] == '2026-09']
p2 = pd.pivot_table(
    df_sep,
    index='category',
    columns='province',
    values='amount',
    aggfunc='sum',
    fill_value=0
)
print("=== P2: September - Category x Province (sum) ===")
print(p2)
p2.to_csv(ROOT/'pivot_september.csv')
print("-> Saved pivot_september.csv")
print()

# --- P3: assert Grand Total ของ P1 == df['amount'].sum() ---
grand_total_p1 = p1.loc['Total', 'Total']
actual_total = df['amount'].sum()
assert grand_total_p1 == actual_total, (
    f"Grand Total mismatch: P1 Total={grand_total_p1}, df.sum={actual_total}"
)
print(f"=== Assert OK: Grand Total P1 = {grand_total_p1} == df['amount'].sum() = {actual_total} ===")
print()

# --- ทดลองข้อผิดพลาด: ลบ aggfunc (ใช้ mean แทน) ---
p_mean = pd.pivot_table(
    df,
    index='province',
    columns='month',
    values='amount',
    # aggfunc='sum' <- ถูก comment ออกเพื่อทดสอบ (จะใช้ mean)
)
print("=== ทดลอง: pivot ด้วย mean (aggfunc ถูกลบออก) ===")
print(p_mean)
print("Bangkok กันยายน =", p_mean.loc['Bangkok', '2026-09'])
print("(270 = mean ของ 300 และ 240 ซึ่งเป็นสองรายการใน September)")
print()

# --- Drink filter (กรณีไม่มี Excel) ---
df_drink = df[df['category'] == 'Drink']
p_drink = pd.pivot_table(
    df_drink,
    index='province',
    columns='month',
    values='amount',
    aggfunc='sum',
    fill_value=0,
    margins=True,
    margins_name='Total'
)
print("=== Drink Pivot: Province x Month ===")
print(p_drink)
drink_total = df_drink['amount'].sum()
print(f"ยอดรวมหลังกรอง Drink = {drink_total} บาท")
p_drink.to_csv(ROOT/'pivot_drink.csv')
print("-> Saved pivot_drink.csv")
