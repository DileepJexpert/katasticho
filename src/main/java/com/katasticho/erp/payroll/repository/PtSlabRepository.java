package com.katasticho.erp.payroll.repository;

import com.katasticho.erp.payroll.entity.PtSlab;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

@Repository
public interface PtSlabRepository extends JpaRepository<PtSlab, UUID> {

    /**
     * All active slabs for {@code stateCode} that apply to {@code gender}
     * (matches rows where gender = supplied gender OR gender IS NULL — null
     * rows are the gender-neutral default and apply to everyone), effective
     * on or before {@code asOf}. Ordered by lower bound so a linear scan
     * picks the first bracket whose range contains the monthly gross.
     */
    @Query("""
            SELECT s FROM PtSlab s
            WHERE s.active = true
              AND s.stateCode = :stateCode
              AND (s.gender IS NULL OR s.gender = :gender)
              AND s.effectiveFrom <= :asOf
            ORDER BY s.grossFrom ASC
            """)
    List<PtSlab> findApplicable(@Param("stateCode") String stateCode,
                                @Param("gender") String gender,
                                @Param("asOf") LocalDate asOf);
}
