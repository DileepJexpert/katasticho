package com.katasticho.erp.ap.match;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface BillMatchResultLineRepository extends JpaRepository<BillMatchResultLine, UUID> {

    List<BillMatchResultLine> findByOrgIdAndBillId(UUID orgId, UUID billId);

    void deleteByOrgIdAndBillId(UUID orgId, UUID billId);

    Page<BillMatchResultLine> findByOrgIdAndStatus(UUID orgId, String status, Pageable pageable);

    Page<BillMatchResultLine> findByOrgIdAndStatusIn(UUID orgId, List<String> statuses, Pageable pageable);
}
