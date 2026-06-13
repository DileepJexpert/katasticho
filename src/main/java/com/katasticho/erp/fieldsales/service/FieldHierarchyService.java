package com.katasticho.erp.fieldsales.service;

import com.katasticho.erp.auth.entity.AppUser;
import com.katasticho.erp.auth.repository.AppUserRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.*;

/**
 * Field reporting hierarchy (MR -> ABM -> RBM -> ...). A self-referencing
 * {@code app_user.reports_to_user_id} forms an arbitrary-depth tree. Powers
 * manager-based approvals and downline-scoped rollup reporting.
 */
@Service
@RequiredArgsConstructor
public class FieldHierarchyService {

    private final AppUserRepository appUserRepository;

    /** Set (or clear, when managerId is null) a user's reporting manager. */
    @Transactional
    public AppUser assignManager(UUID userId, UUID managerId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        AppUser user = appUserRepository.findByIdAndOrgIdAndIsDeletedFalse(userId, orgId)
                .orElseThrow(() -> BusinessException.notFound("AppUser", userId));

        if (managerId != null) {
            if (managerId.equals(userId)) {
                throw new BusinessException("A user cannot report to themselves",
                        "FH_SELF_MANAGER", HttpStatus.BAD_REQUEST);
            }
            appUserRepository.findByIdAndOrgIdAndIsDeletedFalse(managerId, orgId)
                    .orElseThrow(() -> BusinessException.notFound("AppUser", managerId));
            // The proposed manager must not be in this user's own downline (cycle).
            if (downlineUserIds(userId).contains(managerId)) {
                throw new BusinessException(
                        "That user reports (directly or indirectly) to this user — would create a cycle",
                        "FH_CYCLE", HttpStatus.BAD_REQUEST);
            }
        }

        user.setReportsToUserId(managerId);
        return appUserRepository.save(user);
    }

    @Transactional(readOnly = true)
    public List<AppUser> directReports(UUID managerId) {
        return appUserRepository.findByOrgIdAndReportsToUserIdAndIsDeletedFalseOrderByFullNameAsc(
                TenantContext.getCurrentOrgId(), managerId);
    }

    /** All user ids that report to the manager, transitively (excludes the manager). */
    @Transactional(readOnly = true)
    public Set<UUID> downlineUserIds(UUID managerId) {
        Set<UUID> result = new LinkedHashSet<>();
        Deque<UUID> queue = new ArrayDeque<>();
        queue.add(managerId);
        while (!queue.isEmpty()) {
            UUID current = queue.poll();
            for (AppUser child : directReports(current)) {
                if (result.add(child.getId())) {   // guards against malformed cycles
                    queue.add(child.getId());
                }
            }
        }
        return result;
    }

    /** True if ancestorId sits anywhere above userId in the reporting chain. */
    @Transactional(readOnly = true)
    public boolean isAncestor(UUID ancestorId, UUID userId) {
        if (ancestorId == null || userId == null) return false;
        UUID orgId = TenantContext.getCurrentOrgId();
        Set<UUID> seen = new HashSet<>();
        UUID cursor = userId;
        while (cursor != null && seen.add(cursor)) {
            AppUser u = appUserRepository.findByIdAndOrgIdAndIsDeletedFalse(cursor, orgId).orElse(null);
            if (u == null) return false;
            UUID mgr = u.getReportsToUserId();
            if (ancestorId.equals(mgr)) return true;
            cursor = mgr;
        }
        return false;
    }

    /** Flat org chart for the current org: each user with its manager id. */
    @Transactional(readOnly = true)
    public List<Map<String, Object>> orgChart() {
        List<Map<String, Object>> rows = new ArrayList<>();
        for (AppUser u : appUserRepository.findByOrgIdAndIsDeletedFalseOrderByRoleAscFullNameAsc(
                TenantContext.getCurrentOrgId())) {
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("userId", u.getId());
            row.put("fullName", u.getFullName());
            row.put("role", u.getRole());
            row.put("reportsToUserId", u.getReportsToUserId());
            rows.add(row);
        }
        return rows;
    }
}
