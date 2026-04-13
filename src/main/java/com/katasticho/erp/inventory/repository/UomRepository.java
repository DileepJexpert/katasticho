package com.katasticho.erp.inventory.repository;

import com.katasticho.erp.inventory.entity.Uom;
import com.katasticho.erp.inventory.entity.UomCategory;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface UomRepository extends JpaRepository<Uom, UUID> {

    Optional<Uom> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    Optional<Uom> findByOrgIdAndAbbreviationIgnoreCaseAndIsDeletedFalse(
            UUID orgId, String abbreviation);

    List<Uom> findByOrgIdAndIsDeletedFalseOrderByCategoryAscAbbreviationAsc(UUID orgId);

    List<Uom> findByOrgIdAndCategoryAndIsDeletedFalseOrderByAbbreviationAsc(
            UUID orgId, UomCategory category);

    boolean existsByOrgIdAndAbbreviationIgnoreCaseAndIsDeletedFalse(
            UUID orgId, String abbreviation);
}
