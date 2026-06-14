package com.katasticho.erp.hr.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.hr.entity.EmployeeProfile;
import com.katasticho.erp.hr.repository.EmployeeProfileRepository;
import com.katasticho.erp.payroll.entity.Employee;
import com.katasticho.erp.payroll.repository.EmployeeRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDate;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class EmployeeProfileServiceTest {

    @Mock private EmployeeProfileRepository profileRepo;
    @Mock private EmployeeRepository employeeRepo;
    private EmployeeProfileService service;

    private final UUID orgId = UUID.randomUUID();
    private final UUID userId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        service = new EmployeeProfileService(profileRepo, employeeRepo);
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(userId);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    void upsertMine_createsNewProfileForSignedInUser() {
        when(profileRepo.findByOrgIdAndUserIdAndIsDeletedFalse(orgId, userId)).thenReturn(Optional.empty());
        when(profileRepo.save(any())).thenAnswer(i -> i.getArgument(0));

        Map<String, Object> body = new LinkedHashMap<>();
        body.put("dateOfBirth", "1990-04-15");
        body.put("gender", "Male");
        body.put("bloodGroup", "O+");
        body.put("emergencyContactName", "Asha");
        body.put("emergencyContactPhone", "9876543210");

        EmployeeProfile saved = service.upsertMine(body);

        assertEquals(orgId, saved.getOrgId());
        assertEquals(userId, saved.getUserId());
        assertEquals(LocalDate.of(1990, 4, 15), saved.getDateOfBirth());
        assertEquals("Male", saved.getGender());
        assertEquals("O+", saved.getBloodGroup());
        assertEquals("Asha", saved.getEmergencyContactName());
    }

    @Test
    void upsertMine_updatesExistingProfileAndBlanksAreNulled() {
        EmployeeProfile existing = EmployeeProfile.builder()
                .id(UUID.randomUUID()).orgId(orgId).userId(userId)
                .gender("Male").bloodGroup("A+").build();
        when(profileRepo.findByOrgIdAndUserIdAndIsDeletedFalse(orgId, userId))
                .thenReturn(Optional.of(existing));
        when(profileRepo.save(any())).thenAnswer(i -> i.getArgument(0));

        Map<String, Object> body = new LinkedHashMap<>();
        body.put("gender", "Female");
        body.put("bloodGroup", "  ");   // blank -> nulled

        EmployeeProfile saved = service.upsertMine(body);

        assertEquals(existing.getId(), saved.getId());
        assertEquals("Female", saved.getGender());
        assertNull(saved.getBloodGroup());
    }

    @Test
    void getMyProfile_combinesEmployeeBasicsAndPersonalDetails() {
        Employee emp = Employee.builder()
                .id(UUID.randomUUID()).orgId(orgId).userId(userId)
                .fullName("Ramesh K").designation("MR").department("Sales")
                .employmentStatus("ACTIVE").build();
        when(employeeRepo.findByOrgIdAndUserIdAndIsDeletedFalse(orgId, userId))
                .thenReturn(Optional.of(emp));
        EmployeeProfile profile = EmployeeProfile.builder()
                .orgId(orgId).userId(userId).gender("Male").build();
        when(profileRepo.findByOrgIdAndUserIdAndIsDeletedFalse(orgId, userId))
                .thenReturn(Optional.of(profile));

        Map<String, Object> view = service.getMyProfile();

        assertEquals(userId, view.get("userId"));
        @SuppressWarnings("unchecked")
        Map<String, Object> e = (Map<String, Object>) view.get("employee");
        assertNotNull(e);
        assertEquals("Ramesh K", e.get("fullName"));
        assertEquals("Sales", e.get("department"));
        assertSame(profile, view.get("profile"));
    }

    @Test
    void getProfile_noPayrollEmployee_employeeIsNull() {
        UUID otherUser = UUID.randomUUID();
        when(employeeRepo.findByOrgIdAndUserIdAndIsDeletedFalse(orgId, otherUser))
                .thenReturn(Optional.empty());
        when(profileRepo.findByOrgIdAndUserIdAndIsDeletedFalse(orgId, otherUser))
                .thenReturn(Optional.empty());

        Map<String, Object> view = service.getProfile(otherUser);

        assertEquals(otherUser, view.get("userId"));
        assertNull(view.get("employee"));
        assertNull(view.get("profile"));
    }
}
