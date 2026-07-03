package com.katasticho.erp.paymentterm.repository;

import com.katasticho.erp.paymentterm.entity.PaymentTermLine;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

public interface PaymentTermLineRepository extends JpaRepository<PaymentTermLine, UUID> {

    List<PaymentTermLine> findByPaymentTermIdAndIsDeletedFalseOrderBySeqAsc(UUID paymentTermId);

    /** Replace-style: term update hard-deletes existing lines then re-inserts. */
    @Transactional
    void deleteByPaymentTermId(UUID paymentTermId);
}
