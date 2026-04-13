package com.katasticho.erp.inventory.repository;

import com.katasticho.erp.inventory.entity.ItemGroup;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

/**
 * Repository for {@link ItemGroup}. Groups are pure metadata — no
 * stock, no movements — so this repo only powers the CRUD screens and
 * the picker enrichment that joins items to their group name.
 */
@Repository
public interface ItemGroupRepository extends JpaRepository<ItemGroup, UUID> {

    /** Single tenant-scoped row lookup for detail / update / delete. */
    Optional<ItemGroup> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    /** Listing for the group management screen (no search). */
    Page<ItemGroup> findByOrgIdAndIsDeletedFalseOrderByNameAsc(UUID orgId, Pageable pageable);

    /**
     * Case-insensitive duplicate check used by create and rename. The
     * {@code idx_item_group_org_name} partial unique index will reject
     * anyway, but the service surfaces a friendlier
     * {@code GROUP_DUPLICATE_NAME} error first.
     */
    boolean existsByOrgIdAndNameIgnoreCaseAndIsDeletedFalse(UUID orgId, String name);
}
