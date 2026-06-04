package com.katasticho.erp.inventory.repository;

import com.katasticho.erp.inventory.entity.SaltMaster;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Collection;
import java.util.List;
import java.util.UUID;

@Repository
public interface SaltMasterRepository extends JpaRepository<SaltMaster, UUID> {

    List<SaltMaster> findByNameContainingIgnoreCaseOrderByNameAsc(String name, Pageable pageable);

    List<SaltMaster> findByNameIgnoreCaseIn(Collection<String> names);
}
