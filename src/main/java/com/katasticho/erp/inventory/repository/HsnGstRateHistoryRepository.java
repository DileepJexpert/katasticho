package com.katasticho.erp.inventory.repository;

import com.katasticho.erp.inventory.entity.HsnGstRateHistory;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDate;
import java.util.List;

public interface HsnGstRateHistoryRepository extends JpaRepository<HsnGstRateHistory, java.util.UUID> {

    List<HsnGstRateHistory> findByHsnCodeOrderByEffectiveFromDesc(String hsnCode);

    /**
     * The period covering {@code onDate}: effective_from &le; date AND
     * (effective_to IS NULL OR effective_to &ge; date), newest-first.
     * Caller takes the first element; empty = no history for that date
     * (fall back to the hsn_gst_master current rate).
     */
    @Query("SELECT h FROM HsnGstRateHistory h WHERE h.hsnCode = :code "
            + "AND h.effectiveFrom <= :date "
            + "AND (h.effectiveTo IS NULL OR h.effectiveTo >= :date) "
            + "ORDER BY h.effectiveFrom DESC")
    List<HsnGstRateHistory> findEffectiveOn(@Param("code") String code,
                                            @Param("date") LocalDate date,
                                            Pageable pageable);

    /** The current open-ended period for a code (effective_to IS NULL), if any. */
    List<HsnGstRateHistory> findByHsnCodeAndEffectiveToIsNull(String hsnCode);

    boolean existsByHsnCodeAndEffectiveFrom(String hsnCode, LocalDate effectiveFrom);
}
