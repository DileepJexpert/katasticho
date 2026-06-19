package com.katasticho.erp.courier.repository;

import com.katasticho.erp.courier.entity.CodRemittance;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface CodRemittanceRepository extends JpaRepository<CodRemittance, UUID> {

    Optional<CodRemittance> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    List<CodRemittance> findByOrgIdAndIsDeletedFalseOrderByRemittanceDateDesc(UUID orgId);

    long countByOrgIdAndIsDeletedFalse(UUID orgId);
}
