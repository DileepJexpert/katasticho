package com.katasticho.erp.fieldsales.repository;

import com.katasticho.erp.fieldsales.entity.BeatCustomer;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface BeatCustomerRepository extends JpaRepository<BeatCustomer, UUID> {

    List<BeatCustomer> findByOrgIdAndBeatId(UUID orgId, UUID beatId);

    List<BeatCustomer> findByOrgIdAndContactId(UUID orgId, UUID contactId);

    List<BeatCustomer> findByOrgIdAndBeatIdAndIsActiveTrue(UUID orgId, UUID beatId);

    Optional<BeatCustomer> findFirstByOrgIdAndBeatIdAndContactId(UUID orgId, UUID beatId, UUID contactId);

    void deleteByOrgIdAndBeatIdAndContactId(UUID orgId, UUID beatId, UUID contactId);
}
