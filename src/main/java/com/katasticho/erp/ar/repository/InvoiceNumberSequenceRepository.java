package com.katasticho.erp.ar.repository;

import com.katasticho.erp.ar.entity.InvoiceNumberSequence;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface InvoiceNumberSequenceRepository extends JpaRepository<InvoiceNumberSequence, InvoiceNumberSequence.InvoiceNumberSequenceId> {

    /**
     * Pessimistically locked: every document-number generator does
     * read-nextValue-then-increment in two statements, so two concurrent
     * creates on the same (org, prefix, year) used to read the SAME value and
     * collide on the unique number index. SELECT ... FOR UPDATE serializes
     * them on the sequence row for the rest of the transaction. The only
     * residual race is the very first number of a new (org, prefix, year) -
     * both see no row and one insert loses on the primary key, which surfaces
     * as a retryable error instead of a silent duplicate.
     */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT s FROM InvoiceNumberSequence s WHERE s.id.orgId = :orgId AND s.id.prefix = :prefix AND s.id.year = :year")
    Optional<InvoiceNumberSequence> findByOrgIdAndPrefixAndYear(UUID orgId, String prefix, int year);

    @Modifying
    @Query("UPDATE InvoiceNumberSequence s SET s.nextValue = s.nextValue + 1 WHERE s.id.orgId = :orgId AND s.id.prefix = :prefix AND s.id.year = :year")
    void incrementAndGet(UUID orgId, String prefix, int year);
}
