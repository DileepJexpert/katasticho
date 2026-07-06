-- V39 — Carry the load-leg cost on the van so a van round-trip is value-neutral.
--
-- FieldSalesService.confirmVanReturn re-enters returned stock into the warehouse
-- at the item's CURRENT purchasePrice, not the cost the goods carried when loaded
-- onto the van. On a FIFO org (or after any price change) a load→return round-trip
-- then mints or destroys inventory value. Mirror how stock_balance carries an
-- average cost: add a nullable average_cost to van_stock_balance so confirmVanLoad
-- can stamp the true load cost and confirmVanReturn can re-open the warehouse lot
-- at that same basis. Nullable so legacy rows fall back to purchasePrice (current
-- behaviour) with no NPE.

ALTER TABLE van_stock_balance ADD COLUMN average_cost NUMERIC(15,4);
