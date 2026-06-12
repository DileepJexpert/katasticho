package com.katasticho.erp.fieldsales.repository;

import com.katasticho.erp.fieldsales.entity.VisitProductLog;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Collection;
import java.util.List;
import java.util.UUID;

@Repository
public interface VisitProductLogRepository extends JpaRepository<VisitProductLog, UUID> {

    List<VisitProductLog> findByOrgIdAndFieldVisitId(UUID orgId, UUID fieldVisitId);

    List<VisitProductLog> findByOrgIdAndFieldVisitIdIn(UUID orgId, Collection<UUID> fieldVisitIds);

    void deleteByOrgIdAndFieldVisitId(UUID orgId, UUID fieldVisitId);

    /** Total samples distributed per product by a salesperson (via their executions). */
    @Query(value = """
            SELECT vpl.product_name, COALESCE(SUM(vpl.sample_qty), 0)
            FROM visit_product_log vpl
            JOIN field_visit fv ON fv.id = vpl.field_visit_id
            JOIN route_execution re ON re.id = fv.route_execution_id
            WHERE vpl.org_id = :orgId AND re.salesperson_id = :salespersonId
            GROUP BY vpl.product_name
            """, nativeQuery = true)
    List<Object[]> sumDistributedByProduct(@Param("orgId") UUID orgId,
                                           @Param("salespersonId") UUID salespersonId);
}
