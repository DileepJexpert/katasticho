package com.katasticho.erp.ar.repository;

import com.katasticho.erp.ar.entity.InvoiceNumberSequence;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface InvoiceNumberSequenceRepository extends JpaRepository<InvoiceNumberSequence, InvoiceNumberSequence.InvoiceNumberSequenceId> {

    @Query("SELECT s FROM InvoiceNumberSequence s WHERE s.id.orgId = :orgId AND s.id.prefix = :prefix AND s.id.year = :year")
    Optional<InvoiceNumberSequence> findByOrgIdAndPrefixAndYear(UUID orgId, String prefix, int year);

    @Modifying
    @Query("UPDATE InvoiceNumberSequence s SET s.nextValue = s.nextValue + 1 WHERE s.id.orgId = :orgId AND s.id.prefix = :prefix AND s.id.year = :year")
    void incrementAndGet(UUID orgId, String prefix, int year);
}
