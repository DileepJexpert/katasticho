package com.katasticho.erp.auth.repository;

import com.katasticho.erp.auth.entity.AppUser;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface AppUserRepository extends JpaRepository<AppUser, UUID> {

    /** Platform-admin global user search across all orgs (excludes soft-deleted). */
    @Query("""
            SELECT u FROM AppUser u
            WHERE u.isDeleted = false
              AND (:q IS NULL
                   OR LOWER(u.fullName) LIKE LOWER(CONCAT('%', :q, '%'))
                   OR LOWER(u.email) LIKE LOWER(CONCAT('%', :q, '%'))
                   OR u.phone LIKE CONCAT('%', :q, '%'))
            ORDER BY u.createdAt DESC
            """)
    Page<AppUser> searchAllForPlatformAdmin(@Param("q") String q, Pageable pageable);

    Optional<AppUser> findByEmailAndOrgIdAndIsDeletedFalse(String email, UUID orgId);

    Optional<AppUser> findByPhoneAndOrgIdAndIsDeletedFalse(String phone, UUID orgId);

    Optional<AppUser> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    boolean existsByPhoneAndIsDeletedFalse(String phone);

    boolean existsByEmailAndOrgIdAndIsDeletedFalse(String email, UUID orgId);

    Optional<AppUser> findFirstByOrgIdAndRoleAndIsDeletedFalse(UUID orgId, String role);

    List<AppUser> findByOrgIdAndRoleAndIsDeletedFalse(UUID orgId, String role);

    List<AppUser> findAllByPhoneAndIsDeletedFalse(String phone);

    List<AppUser> findAllByEmailAndIsDeletedFalse(String email);

    List<AppUser> findByOrgIdAndIsDeletedFalseOrderByRoleAscFullNameAsc(UUID orgId);

    /** Direct reports of a manager (field hierarchy). */
    List<AppUser> findByOrgIdAndReportsToUserIdAndIsDeletedFalseOrderByFullNameAsc(
            UUID orgId, UUID reportsToUserId);

    List<AppUser> findByCaFirmIdAndIsDeletedFalseOrderByRoleAscFullNameAsc(UUID caFirmId);

    List<AppUser> findByIsDeletedFalseOrderByCreatedAtDesc();

    List<AppUser> findByOrgIdAndIsDeletedFalse(UUID orgId);
}
