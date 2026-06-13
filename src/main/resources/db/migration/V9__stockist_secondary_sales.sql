-- ============================================================================
-- V9: Stockist secondary-sales / Stock & Sales Statement (SSS).
--
-- Distribution gap: we record primary sales (company -> stockist) but not the
-- downstream secondary movement (stockist -> retailer). Stockists periodically
-- report a Stock & Sales Statement per product: opening stock, purchases (the
-- primary they received), secondary sales, returns and closing stock. This lets
-- the company see real downstream demand, stock lying at stockists, and pay/
-- assess on secondary (not just primary) sales.
--
-- Org-scoped (the distributor org tracking its own stockists).
-- ============================================================================

CREATE TABLE public.stockist_sales_statement (
    id                  uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id              uuid NOT NULL,
    stockist_contact_id uuid NOT NULL,
    period_month        date NOT NULL,               -- normalised to 1st of month
    status              character varying(20) DEFAULT 'DRAFT' NOT NULL,
    notes               text,
    is_deleted          boolean DEFAULT false NOT NULL,
    created_at          timestamp with time zone DEFAULT now() NOT NULL,
    updated_at          timestamp with time zone DEFAULT now() NOT NULL,
    created_by          uuid,
    CONSTRAINT stockist_sales_statement_pkey PRIMARY KEY (id)
);

CREATE UNIQUE INDEX uq_stockist_stmt_period
    ON public.stockist_sales_statement (org_id, stockist_contact_id, period_month)
    WHERE is_deleted = false;

CREATE TABLE public.stockist_sales_line (
    id            uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id        uuid NOT NULL,
    statement_id  uuid NOT NULL,
    item_id       uuid,
    product_name  character varying(255) NOT NULL,
    opening_qty   numeric(18,3) DEFAULT 0 NOT NULL,
    purchase_qty  numeric(18,3) DEFAULT 0 NOT NULL,   -- primary received this period
    sales_qty     numeric(18,3) DEFAULT 0 NOT NULL,   -- secondary sold to retailers
    return_qty    numeric(18,3) DEFAULT 0 NOT NULL,
    closing_qty   numeric(18,3) DEFAULT 0 NOT NULL,   -- opening + purchase - sales - return
    sales_value   numeric(18,2) DEFAULT 0 NOT NULL,
    is_deleted    boolean DEFAULT false NOT NULL,
    created_at    timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT stockist_sales_line_pkey PRIMARY KEY (id)
);

CREATE INDEX idx_stockist_line_stmt ON public.stockist_sales_line (org_id, statement_id);
CREATE INDEX idx_stockist_line_item ON public.stockist_sales_line (org_id, item_id);
