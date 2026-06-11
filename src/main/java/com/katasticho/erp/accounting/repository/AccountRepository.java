package com.katasticho.erp.accounting.repository;

import com.katasticho.erp.accounting.entity.Account;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface AccountRepository extends JpaRepository<Account, UUID> {

    List<Account> findByOrgIdAndIsDeletedFalseOrderByCode(UUID orgId);

    Optional<Account> findByOrgIdAndCodeAndIsDeletedFalse(UUID orgId, String code);

    /** Name match for migration imports (Tally ledgers have no codes). */
    Optional<Account> findFirstByOrgIdAndNameIgnoreCaseAndIsDeletedFalse(UUID orgId, String name);

    Optional<Account> findByOrgIdAndIdAndIsDeletedFalse(UUID orgId, UUID id);

    boolean existsByOrgIdAndCodeAndIsDeletedFalse(UUID orgId, String code);

    Long countByOrgIdAndParentIdAndIsDeletedFalse(UUID orgId, UUID parentId);

    @Query("SELECT a FROM Account a WHERE a.orgId = :orgId AND a.type = :type AND a.isDeleted = false ORDER BY a.code")
    List<Account> findByOrgIdAndType(UUID orgId, String type);
}
