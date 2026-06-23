-- V12: GTIN column on drug_master for GS1 DataMatrix scanner lookup.
--
-- CDSCO Notification G.S.R. 823(E) mandates GS1 DataMatrix QR codes on the
-- top-300 pharma brands carrying AI (01) GTIN, (17) expiry, (10) batch,
-- (21) serial. Scanning resolves the printed GTIN → drug_master row →
-- linked org Item. Population is left to the org / vendor data team — no
-- seed values here.
--
-- Partial index because most rows will be NULL for orgs that don't carry
-- the top-300 brands. The lookup is `findByGtinIgnoreCase(gtin)`, called
-- only when the parser successfully extracts AI (01).

ALTER TABLE drug_master ADD COLUMN gtin VARCHAR(14);

CREATE INDEX idx_drug_master_gtin ON drug_master(gtin) WHERE gtin IS NOT NULL;
