package com.katasticho.erp.inventory.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.dto.PagedResponse;
import com.katasticho.erp.inventory.dto.GenerateVariantsRequest;
import com.katasticho.erp.inventory.dto.GenerateVariantsResponse;
import com.katasticho.erp.inventory.dto.ItemGroupRequest;
import com.katasticho.erp.inventory.dto.ItemGroupResponse;
import com.katasticho.erp.inventory.dto.ItemResponse;
import com.katasticho.erp.inventory.service.ItemGroupService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

/**
 * REST surface for {@link com.katasticho.erp.inventory.entity.ItemGroup}.
 * The matrix bulk-create endpoint is the most distinctive piece —
 * everything else is straight CRUD.
 */
@RestController
@RequestMapping("/api/v1/item-groups")
@RequiredArgsConstructor
public class ItemGroupController {

    private final ItemGroupService itemGroupService;

    @PostMapping
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<ItemGroupResponse>> createGroup(
            @Valid @RequestBody ItemGroupRequest request) {
        ItemGroupResponse group = itemGroupService.createGroup(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.created(group));
    }

    @GetMapping
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<PagedResponse<ItemGroupResponse>>> listGroups(Pageable pageable) {
        Page<ItemGroupResponse> page = itemGroupService.listGroups(pageable);
        return ResponseEntity.ok(ApiResponse.ok(PagedResponse.from(page)));
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<ItemGroupResponse>> getGroup(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(itemGroupService.getGroup(id)));
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<ItemGroupResponse>> updateGroup(
            @PathVariable UUID id,
            @Valid @RequestBody ItemGroupRequest request) {
        return ResponseEntity.ok(
                ApiResponse.ok(itemGroupService.updateGroup(id, request), "Group updated"));
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<Void>> deleteGroup(@PathVariable UUID id) {
        itemGroupService.deleteGroup(id);
        return ResponseEntity.ok(ApiResponse.ok(null, "Group deleted"));
    }

    /**
     * List every variant under a group. Ordered by SKU so the detail
     * screen's grid is deterministic. Returns a flat list (not paged)
     * because v1 caps a group at a few dozen variants in practice.
     */
    @GetMapping("/{id}/items")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR','VIEWER')")
    public ResponseEntity<ApiResponse<List<ItemResponse>>> listVariants(@PathVariable UUID id) {
        return ResponseEntity.ok(ApiResponse.ok(itemGroupService.listVariants(id)));
    }

    /**
     * Matrix bulk-create. Body is a list of attribute maps; the
     * service mints SKUs, validates each combination against the
     * group's attribute_definitions, skips duplicates, and inherits
     * the group's defaults onto each new item. Idempotent — re-running
     * with the same body is safe.
     */
    @PostMapping("/{id}/generate-variants")
    @PreAuthorize("hasAnyRole('OWNER','ACCOUNTANT','OPERATOR')")
    public ResponseEntity<ApiResponse<GenerateVariantsResponse>> generateVariants(
            @PathVariable UUID id,
            @Valid @RequestBody GenerateVariantsRequest request) {
        GenerateVariantsResponse response = itemGroupService.generateVariants(id, request);
        String msg = response.created().size() + " variants created, "
                + response.skippedReasons().size() + " skipped";
        return ResponseEntity.ok(ApiResponse.ok(response, msg));
    }
}
