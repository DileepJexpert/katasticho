package com.katasticho.erp.fieldsales.repository;

import com.katasticho.erp.fieldsales.entity.FieldSampleTxn;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface FieldSampleTxnRepository extends JpaRepository<FieldSampleTxn, UUID> {

    List<FieldSampleTxn> findByOrgIdAndSalespersonIdOrderByTxnDateDescCreatedAtDesc(
            UUID orgId, UUID salespersonId);

    /** Net issued (issues − returns) per product for a salesperson. */
    @Query("""
            SELECT t.productName,
                   SUM(CASE WHEN t.txnType = 'ISSUE' THEN t.quantity ELSE 0 END),
                   SUM(CASE WHEN t.txnType = 'RETURN' THEN t.quantity ELSE 0 END)
            FROM FieldSampleTxn t
            WHERE t.orgId = :orgId AND t.salespersonId = :salespersonId
            GROUP BY t.productName
            """)
    List<Object[]> sumByProduct(@Param("orgId") UUID orgId, @Param("salespersonId") UUID salespersonId);
}
