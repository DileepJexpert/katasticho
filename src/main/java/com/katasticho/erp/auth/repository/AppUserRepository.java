package com.katasticho.erp.auth.repository;

import com.katasticho.erp.auth.entity.AppUser;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface AppUserRepository extends JpaRepository<AppUser, UUID> {

    Optional<AppUser> findByPhoneAndIsDeletedFalse(String phone);

    Optional<AppUser> findByEmailAndOrgIdAndIsDeletedFalse(String email, UUID orgId);

    Optional<AppUser> findByPhoneAndOrgIdAndIsDeletedFalse(String phone, UUID orgId);

    Optional<AppUser> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    boolean existsByPhoneAndIsDeletedFalse(String phone);

    boolean existsByEmailAndOrgIdAndIsDeletedFalse(String email, UUID orgId);

    Optional<AppUser> findFirstByOrgIdAndRoleAndIsDeletedFalse(UUID orgId, String role);

    List<AppUser> findByOrgIdAndRoleAndIsDeletedFalse(UUID orgId, String role);

    List<AppUser> findAllByPhoneAndIsDeletedFalse(String phone);

    List<AppUser> findAllByEmailAndIsDeletedFalse(String email);
}
