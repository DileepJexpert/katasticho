package com.katasticho.erp.fieldsales.repository;

import com.katasticho.erp.fieldsales.entity.RcpaLine;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Collection;
import java.util.List;
import java.util.UUID;

@Repository
public interface RcpaLineRepository extends JpaRepository<RcpaLine, UUID> {

    List<RcpaLine> findByOrgIdAndAuditIdAndIsDeletedFalseOrderByBrandTypeAscProductNameAsc(
            UUID orgId, UUID auditId);

    List<RcpaLine> findByOrgIdAndAuditIdInAndIsDeletedFalse(
            UUID orgId, Collection<UUID> auditIds);

    void deleteByOrgIdAndAuditId(UUID orgId, UUID auditId);
}
