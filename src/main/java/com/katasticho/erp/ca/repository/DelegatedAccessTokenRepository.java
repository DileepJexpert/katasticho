package com.katasticho.erp.ca.repository;

import com.katasticho.erp.ca.entity.DelegatedAccessToken;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

public interface DelegatedAccessTokenRepository extends JpaRepository<DelegatedAccessToken, UUID> {
    Optional<DelegatedAccessToken> findByTokenHashAndCaUserIdAndClientOrgIdAndUsedFalseAndExpiresAtAfter(
            String tokenHash, UUID caUserId, UUID clientOrgId, Instant now);
}
