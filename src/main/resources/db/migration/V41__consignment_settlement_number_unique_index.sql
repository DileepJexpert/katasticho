-- V41 — Per-org uniqueness backstop for consignment settlement numbers.
--
-- ConsignmentService.generateSettlementNumber derived the number from a GLOBAL
-- row count() — colliding across orgs under concurrency and leaking tenant
-- volume. The service is switched to a per-org MAX+1 sequence (mirroring
-- TransferOrderRepository.nextSequence). This partial unique index is the
-- concurrency backstop (MAX+1 still has a residual race window): the losing
-- concurrent insert now fails loudly on a unique violation instead of
-- persisting a duplicate number. Matches the V21 pattern for
-- network_order / job_work_order / non_conformance_report.

CREATE UNIQUE INDEX uq_consignment_settlement_org_number
    ON consignment_settlement (org_id, settlement_number)
    WHERE settlement_number IS NOT NULL AND NOT is_deleted;
