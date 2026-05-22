package com.katasticho.erp.ca.repository;

import com.katasticho.erp.ca.entity.DelegatedAccessToken;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.UUID;

public interface DelegatedAccessTokenRepository extends JpaRepository<DelegatedAccessToken, UUID> {
}
