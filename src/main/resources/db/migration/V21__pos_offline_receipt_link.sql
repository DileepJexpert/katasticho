-- ============================================================================
-- V21: Offline POS audit link.
--
-- When a sale is rung up offline (no network at the counter), the client app
-- gives the customer a temporary bill number (OFF-xxxx) and prints it. When
-- the queued receipt later syncs, the server assigns the real receipt number;
-- this column keeps the offline number on the posted receipt so a paper bill
-- can be traced back to its synced record.
-- ============================================================================

ALTER TABLE public.sales_receipt
    ADD COLUMN offline_receipt_number character varying(30);
