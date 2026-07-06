-- V40 — Destination state (place of supply) on POS receipts for GSTR-1.
--
-- An inter-state POS sale (igst > 0) must report the DESTINATION state as its
-- place of supply in GSTR-1 B2CS, and that state must differ from the supplier
-- state. GstService.buildPosB2cs currently hardcodes the org's own state for
-- every POS-derived row, producing invalid INTER rows whose place of supply
-- equals the filer's state. Give SalesReceipt a nullable place_of_supply (the
-- 2-char GST state code) so an inter-state receipt can carry its real
-- destination, resolved from the linked contact's state at create time.
-- Nullable; existing rows are treated as intra-state (org state) at read time.

ALTER TABLE sales_receipt ADD COLUMN place_of_supply VARCHAR(2);
