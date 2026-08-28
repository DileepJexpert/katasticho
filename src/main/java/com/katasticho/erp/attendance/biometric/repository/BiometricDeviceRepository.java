package com.katasticho.erp.attendance.biometric.repository;

import com.katasticho.erp.attendance.biometric.entity.BiometricDevice;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface BiometricDeviceRepository extends JpaRepository<BiometricDevice, UUID> {

    List<BiometricDevice> findByOrgIdAndIsDeletedFalseOrderByDeviceNameAsc(UUID orgId);

    Optional<BiometricDevice> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    Optional<BiometricDevice> findFirstByCloudWebhookTokenAndIsDeletedFalse(String cloudWebhookToken);

    Optional<BiometricDevice> findFirstBySerialNumberAndIsDeletedFalse(String serialNumber);
}
