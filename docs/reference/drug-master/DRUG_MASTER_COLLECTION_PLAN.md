# Drug Master Collection Plan

Goal: build Katixo's pharmacy reference drug master gradually to 2000+ candidate medicines.

## Current Count

- Base repo seeds before day-01 import: V28 plus V34.
- Day-01 accepted import: 178 new candidate medicines.
- Day-01 skipped duplicates: 22.

## Batch Rules

1. Use one incremental Flyway migration per batch.
2. Never reuse an existing migration version.
3. Keep CSV columns aligned to:
   - brand_name
   - generic_name
   - salt_composition
   - manufacturer
   - hsn_code
   - gst_rate
   - drug_schedule
   - dosage_form
   - pack_size
   - mrp
   - prescription_required
   - therapeutic_category
   - source
   - verification_status
   - notes
4. Keep `verification_status = NEEDS_REVIEW` until data is verified from reliable commercial or regulatory sources.
5. Keep MRP nullable unless verified, because MRP changes by pack, batch, and time.
6. Dedupe by brand name + salt composition + manufacturer.
7. Use `ON CONFLICT (name) DO NOTHING` for salt master rows.
8. Use `NOT EXISTS` duplicate protection for drug master rows.

## Next Batch

Next batch should use:

- CSV source label: `STARTER_SEED_DAY_02`
- Migration version: next available after V36
- Target size: 200-300 clean rows

Preferred day-02 categories:

- Antibiotics
- Antidiabetics
- Antihypertensives
- Lipid lowering medicines
- Respiratory medicines
- Gastro medicines
- Vitamins and supplements

Avoid importing:

- Long page descriptions
- Directions for use
- Reviews/ratings
- Source website metadata
- Duplicates with changed spelling only
- Unverified MRP values
