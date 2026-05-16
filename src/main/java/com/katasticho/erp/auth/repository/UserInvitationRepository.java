package com.katasticho.erp.auth.repository;

import com.katasticho.erp.auth.entity.UserInvitation;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface UserInvitationRepository extends JpaRepository<UserInvitation, UUID> {

    Optional<UserInvitation> findByTokenAndAcceptedAtIsNull(String token);

    List<UserInvitation> findByOrgIdAndAcceptedAtIsNullOrderByCreatedAtDesc(UUID orgId);
}
