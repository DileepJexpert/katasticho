# Drug Master Day 01 Import Summary

Generated from local candidate files on 2026-06-03.

## Input Files Checked

- `C:\Users\dileepkm\Downloads\katixo_drug_master_day01_200.csv`
- `C:\Users\dileepkm\Downloads\katixo_salt_master_day01.csv`
- `C:\Users\dileepkm\Downloads\katixo_drug_master_day01_summary.txt`
- `C:\Users\dileepkm\Downloads\V30__seed_drug_master_day01_200.sql`

## Result

- Input drug rows: 200
- Unique input keys: 200
- Existing repo seed keys checked: 279
- New rows added to repo migration: 178
- Skipped duplicates: 22
- Unique salts/categories inserted if missing: 121

## Repo Files Created

- `src/main/resources/db/migration/V36__seed_drug_master_day01_unique.sql`
- `docs/reference/drug-master/katixo_drug_master_day01_unique_178.csv`

## Notes

- The downloaded `V30__seed_drug_master_day01_200.sql` was not copied because repo migration `V30__fix_pharmacy_master_timestamps.sql` already exists.
- Rows are candidate reference/demo data and keep MRP as NULL where the input was blank.
- Duplicate guard uses brand name + salt composition + manufacturer.
- Continue day-02/day-03 batches with the next Flyway version and the same dedupe key.
