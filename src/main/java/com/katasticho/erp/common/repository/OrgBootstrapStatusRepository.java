package com.katasticho.erp.common.repository;

import com.katasticho.erp.common.entity.OrgBootstrapStatus;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.UUID;

public interface OrgBootstrapStatusRepository extends JpaRepository<OrgBootstrapStatus, UUID> {
}
