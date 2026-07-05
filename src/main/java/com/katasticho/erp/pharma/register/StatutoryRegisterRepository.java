package com.katasticho.erp.pharma.register;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface StatutoryRegisterRepository extends JpaRepository<StatutoryRegisterEntry, UUID> {

    Optional<StatutoryRegisterEntry> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    List<StatutoryRegisterEntry> findByOrgIdAndSaleReceiptIdAndIsDeletedFalse(UUID orgId, UUID saleReceiptId);

    Page<StatutoryRegisterEntry> findByOrgIdAndRegisterTypeAndSaleDateBetweenAndIsDeletedFalseOrderBySaleDateDescCreatedAtDesc(
            UUID orgId, RegisterType registerType, LocalDate from, LocalDate to, Pageable pageable);

    List<StatutoryRegisterEntry> findByOrgIdAndRegisterTypeAndSaleDateBetweenAndIsDeletedFalseOrderBySaleDateAscCreatedAtAsc(
            UUID orgId, RegisterType registerType, LocalDate from, LocalDate to);

    long countByOrgIdAndRegisterTypeAndIsDeletedFalse(UUID orgId, RegisterType registerType);

    long countByOrgIdAndRegisterTypeAndSaleDateBetweenAndIsDeletedFalse(
            UUID orgId, RegisterType registerType, LocalDate from, LocalDate to);

    List<StatutoryRegisterEntry> findTop10ByOrgIdAndRegisterTypeAndRetentionUntilBetweenAndIsDeletedFalseOrderByRetentionUntilAsc(
            UUID orgId, RegisterType registerType, LocalDate from, LocalDate to);
}
