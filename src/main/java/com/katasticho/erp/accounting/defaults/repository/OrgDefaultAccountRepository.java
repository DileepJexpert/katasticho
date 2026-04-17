package com.katasticho.erp.accounting.defaults.repository;

import com.katasticho.erp.accounting.defaults.DefaultAccountPurpose;
import com.katasticho.erp.accounting.defaults.entity.OrgDefaultAccount;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface OrgDefaultAccountRepository extends JpaRepository<OrgDefaultAccount, UUID> {

    List<OrgDefaultAccount> findByOrgId(UUID orgId);

    Optional<OrgDefaultAccount> findByOrgIdAndPurpose(UUID orgId, DefaultAccountPurpose purpose);

    boolean existsByOrgIdAndPurpose(UUID orgId, DefaultAccountPurpose purpose);
}
