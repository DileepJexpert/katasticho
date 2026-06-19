package com.katasticho.erp.hr.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.hr.entity.EmployeeProfile;
import com.katasticho.erp.hr.repository.EmployeeProfileRepository;
import com.katasticho.erp.payroll.entity.Employee;
import com.katasticho.erp.payroll.repository.EmployeeRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.UUID;

/**
 * Employee management — Core HR module 2. A self-service profile (personal +
 * emergency details) layered on the payroll {@link Employee} master, plus a
 * combined "My Profile" view that surfaces the employee basics already captured
 * by payroll. The employee edits their own profile; HR (OWNER/ADMIN) may edit
 * anyone's via the {userId} endpoints.
 */
@Service
@RequiredArgsConstructor
public class EmployeeProfileService {

    private final EmployeeProfileRepository profileRepository;
    private final EmployeeRepository employeeRepository;

    /** The signed-in user's combined profile view (employee basics + personal details). */
    @Transactional(readOnly = true)
    public Map<String, Object> getMyProfile() {
        return profileView(TenantContext.getCurrentUserId());
    }

    /** HR view of any user's combined profile. */
    @Transactional(readOnly = true)
    public Map<String, Object> getProfile(UUID userId) {
        return profileView(userId);
    }

    /** The signed-in user updates their own personal/emergency details. */
    @Transactional
    public EmployeeProfile upsertMine(Map<String, Object> body) {
        return upsert(TenantContext.getCurrentUserId(), body);
    }

    /** HR updates another user's personal/emergency details. */
    @Transactional
    public EmployeeProfile upsertFor(UUID userId, Map<String, Object> body) {
        if (userId == null) {
            throw new BusinessException("userId is required", "HR_PROFILE_USER_REQUIRED",
                    HttpStatus.BAD_REQUEST);
        }
        return upsert(userId, body);
    }

    // ── helpers ──────────────────────────────────────────────────────────

    private EmployeeProfile upsert(UUID userId, Map<String, Object> body) {
        UUID orgId = TenantContext.getCurrentOrgId();
        EmployeeProfile p = profileRepository.findByOrgIdAndUserIdAndIsDeletedFalse(orgId, userId)
                .orElseGet(() -> EmployeeProfile.builder().orgId(orgId).userId(userId).build());

        p.setDateOfBirth(date(body.get("dateOfBirth")));
        p.setGender(str(body.get("gender")));
        p.setBloodGroup(str(body.get("bloodGroup")));
        p.setMaritalStatus(str(body.get("maritalStatus")));
        p.setPersonalEmail(str(body.get("personalEmail")));
        p.setPersonalPhone(str(body.get("personalPhone")));
        p.setCurrentAddress(str(body.get("currentAddress")));
        p.setEmergencyContactName(str(body.get("emergencyContactName")));
        p.setEmergencyContactPhone(str(body.get("emergencyContactPhone")));
        p.setEmergencyContactRelation(str(body.get("emergencyContactRelation")));
        return profileRepository.save(p);
    }

    private Map<String, Object> profileView(UUID userId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("userId", userId);

        // Payroll employee basics (designation/department/DOJ/bank/statutory ids).
        Employee emp = employeeRepository.findByOrgIdAndUserIdAndIsDeletedFalse(orgId, userId).orElse(null);
        if (emp != null) {
            Map<String, Object> e = new LinkedHashMap<>();
            e.put("id", emp.getId());
            e.put("employeeCode", emp.getEmployeeCode());
            e.put("fullName", emp.getFullName());
            e.put("phone", emp.getPhone());
            e.put("email", emp.getEmail());
            e.put("designation", emp.getDesignation());
            e.put("department", emp.getDepartment());
            e.put("dateOfJoining", emp.getDateOfJoining());
            e.put("employmentStatus", emp.getEmploymentStatus());
            out.put("employee", e);
        } else {
            out.put("employee", null);
        }

        out.put("profile",
                profileRepository.findByOrgIdAndUserIdAndIsDeletedFalse(orgId, userId).orElse(null));
        return out;
    }

    private static String str(Object o) {
        if (o == null) return null;
        String s = o.toString().trim();
        return s.isEmpty() ? null : s;
    }

    private static LocalDate date(Object o) {
        String s = str(o);
        return s == null ? null : LocalDate.parse(s);
    }
}
