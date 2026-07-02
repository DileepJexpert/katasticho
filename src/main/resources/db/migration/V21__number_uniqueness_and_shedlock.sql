-- V21: document-number integrity + distributed scheduler lock table.
--
-- 1) network_order / job_work_order / non_conformance_report were the only
--    numbered documents WITHOUT a unique (org_id, number) index — their
--    MAX(...)+1 generators could silently mint duplicate numbers under
--    concurrency. Same partial-index convention as idx_invoice_org_number.
--    (The sequence-table documents — invoice, receipt, bill, payment, SO,
--    DC, GRN, estimate, expense — already had unique indexes; their
--    read-then-increment race is fixed in code by a PESSIMISTIC_WRITE lock
--    on InvoiceNumberSequenceRepository.findByOrgIdAndPrefixAndYear.)
--
-- 2) shedlock: standard net.javacrumbs.shedlock table so the 12 O(orgs)
--    @Scheduled automation jobs run on exactly ONE app instance. Without it,
--    a second replica double-sends SMS/push and doubles AI spend on every
--    cron firing.

-- network_order is cross-org (buyer/seller), and its MAX+1 generator scopes
-- numbering to the BUYING org — so uniqueness is per buyer.
CREATE UNIQUE INDEX IF NOT EXISTS uq_network_order_buyer_number
    ON public.network_order USING btree (buyer_org_id, order_number)
    WHERE (NOT is_deleted);

CREATE UNIQUE INDEX IF NOT EXISTS uq_job_work_order_org_number
    ON public.job_work_order USING btree (org_id, job_work_number)
    WHERE (NOT is_deleted);

CREATE UNIQUE INDEX IF NOT EXISTS uq_ncr_org_number
    ON public.non_conformance_report USING btree (org_id, ncr_number)
    WHERE (NOT is_deleted);

CREATE TABLE IF NOT EXISTS public.shedlock (
    name       VARCHAR(64)  NOT NULL,
    lock_until TIMESTAMPTZ  NOT NULL,
    locked_at  TIMESTAMPTZ  NOT NULL,
    locked_by  VARCHAR(255) NOT NULL,
    CONSTRAINT shedlock_pkey PRIMARY KEY (name)
);
