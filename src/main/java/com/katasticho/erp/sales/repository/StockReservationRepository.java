package com.katasticho.erp.sales.repository;

import com.katasticho.erp.sales.entity.StockReservation;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface StockReservationRepository extends JpaRepository<StockReservation, UUID> {

    List<StockReservation> findBySourceTypeAndSourceId(String sourceType, UUID sourceId);

    Optional<StockReservation> findBySourceTypeAndSourceLineId(String sourceType, UUID sourceLineId);

    Optional<StockReservation> findBySourceTypeAndSourceLineIdAndStatus(String sourceType, UUID sourceLineId, String status);

    @Query("""
        SELECT COALESCE(SUM(sr.quantityReserved), 0) FROM StockReservation sr
        WHERE sr.itemId = :itemId
          AND sr.warehouseId = :warehouseId
          AND sr.status = 'ACTIVE'
    """)
    BigDecimal sumActiveReservations(UUID itemId, UUID warehouseId);
}
