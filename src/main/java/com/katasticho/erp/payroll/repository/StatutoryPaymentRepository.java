package com.katasticho.erp.payroll.repository;

import com.katasticho.erp.payroll.entity.StatutoryPayment;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface StatutoryPaymentRepository extends JpaRepository<StatutoryPayment, UUID> {

    List<StatutoryPayment> findByOrgIdAndStatusOrderByDueDateAsc(UUID orgId, String status);

    List<StatutoryPayment> findByOrgIdAndStatutoryTypeAndPeriodLabel(UUID orgId, String type, String period);
}
