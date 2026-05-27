package com.katasticho.erp.organisation;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Repository
public interface OrganisationRepository extends JpaRepository<Organisation, UUID> {

    List<Organisation> findByIsDeletedFalseAndActiveTrue();

    List<Organisation> findByIsDeletedFalseOrderByCreatedAtDesc();

    List<Organisation> findByApprovalStatusAndIsDeletedFalseOrderByCreatedAtDesc(String approvalStatus);

    @Query(value = """
            select *
            from public.organisation o
            where o.is_deleted = false
              and (:status is null or o.approval_status = :status)
              and (
                cast(:query as text) is null
                or lower(o.name) like concat('%', cast(:query as text), '%')
                or lower(coalesce(o.phone, '')) like concat('%', cast(:query as text), '%')
                or lower(coalesce(o.email, '')) like concat('%', cast(:query as text), '%')
              )
            order by o.created_at desc
            """, nativeQuery = true)
    List<Organisation> searchForPlatformAdmin(@Param("status") String status, @Param("query") String query);

    long countByApprovalStatus(String approvalStatus);

    long countByCreatedAtAfter(Instant after);
}
