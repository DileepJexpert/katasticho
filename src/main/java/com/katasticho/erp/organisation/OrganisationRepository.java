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

    @Query("""
            select o from Organisation o
            where o.isDeleted = false
              and (:status is null or o.approvalStatus = :status)
              and (:query is null or lower(o.name) like lower(concat('%', :query, '%'))
                   or lower(coalesce(o.phone, '')) like lower(concat('%', :query, '%'))
                   or lower(coalesce(o.email, '')) like lower(concat('%', :query, '%')))
            order by o.createdAt desc
            """)
    List<Organisation> searchForPlatformAdmin(@Param("status") String status, @Param("query") String query);

    long countByApprovalStatus(String approvalStatus);

    long countByCreatedAtAfter(Instant after);
}
