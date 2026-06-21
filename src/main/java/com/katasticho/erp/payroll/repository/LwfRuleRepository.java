package com.katasticho.erp.payroll.repository;

import com.katasticho.erp.payroll.entity.LwfRule;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

@Repository
public interface LwfRuleRepository extends JpaRepository<LwfRule, UUID> {

    /** Active rules for the state, effective on or before {@code asOf}, ordered by gross_from. */
    @Query("""
            SELECT r FROM LwfRule r
            WHERE r.active = true
              AND r.stateCode = :stateCode
              AND r.effectiveFrom <= :asOf
            ORDER BY r.grossFrom ASC
            """)
    List<LwfRule> findApplicable(@Param("stateCode") String stateCode,
                                 @Param("asOf") LocalDate asOf);
}
