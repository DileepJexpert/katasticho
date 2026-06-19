package com.katasticho.erp.portal.repository;

import com.katasticho.erp.portal.entity.PortalUser;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface PortalUserRepository extends JpaRepository<PortalUser, UUID> {

    Optional<PortalUser> findByIdAndIsDeletedFalse(UUID id);

    Optional<PortalUser> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    Optional<PortalUser> findByEmailIgnoreCaseAndIsDeletedFalse(String email);

    Optional<PortalUser> findByInviteTokenHashAndIsDeletedFalse(String inviteTokenHash);

    Optional<PortalUser> findByOrgIdAndContactIdAndIsDeletedFalse(UUID orgId, UUID contactId);

    List<PortalUser> findByOrgIdAndIsDeletedFalseOrderByCreatedAtDesc(UUID orgId);

    boolean existsByEmailIgnoreCaseAndIsDeletedFalse(String email);
}
