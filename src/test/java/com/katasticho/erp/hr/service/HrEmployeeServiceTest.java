package com.katasticho.erp.hr.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.hr.entity.EmployeeEducation;
import com.katasticho.erp.hr.entity.EmployeeExperience;
import com.katasticho.erp.hr.entity.EmployeeFamily;
import com.katasticho.erp.hr.repository.EmployeeEducationRepository;
import com.katasticho.erp.hr.repository.EmployeeExperienceRepository;
import com.katasticho.erp.hr.repository.EmployeeFamilyRepository;
import com.katasticho.erp.payroll.entity.Employee;
import com.katasticho.erp.payroll.repository.EmployeeRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDate;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class HrEmployeeServiceTest {

    @Mock private EmployeeRepository employeeRepo;
    @Mock private EmployeeFamilyRepository familyRepo;
    @Mock private EmployeeEducationRepository educationRepo;
    @Mock private EmployeeExperienceRepository experienceRepo;
    private HrEmployeeService service;

    private final UUID orgId = UUID.randomUUID();
    private final UUID userId = UUID.randomUUID();
    private final UUID employeeId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        service = new HrEmployeeService(employeeRepo, familyRepo, educationRepo, experienceRepo);
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(userId);

        Employee emp = Employee.builder().id(employeeId).orgId(orgId).fullName("Anita").build();
        // Used only by add/list paths; update/delete look up the subresource directly.
        lenient().when(employeeRepo.findByIdAndOrgIdAndIsDeletedFalse(employeeId, orgId))
                .thenReturn(Optional.of(emp));
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    // ───── Family ─────

    @Test
    void addFamily_stampsOrgEmployeeAndPersists() {
        when(familyRepo.save(any(EmployeeFamily.class))).thenAnswer(inv -> inv.getArgument(0));

        EmployeeFamily input = EmployeeFamily.builder()
                .name("Ravi")
                .relationship("SPOUSE")
                .dependent(true)
                .id(UUID.randomUUID())   // caller may have set id — service must drop it
                .build();

        EmployeeFamily saved = service.addFamily(employeeId, input);

        ArgumentCaptor<EmployeeFamily> cap = ArgumentCaptor.forClass(EmployeeFamily.class);
        verify(familyRepo).save(cap.capture());
        EmployeeFamily persisted = cap.getValue();

        assertEquals(orgId, persisted.getOrgId());
        assertEquals(employeeId, persisted.getEmployeeId());
        assertNull(persisted.getId(), "service must null caller-supplied id");
        assertFalse(persisted.isDeleted());
        assertEquals("Ravi", saved.getName());
    }

    @Test
    void addFamily_unknownEmployee_throws() {
        UUID stranger = UUID.randomUUID();
        when(employeeRepo.findByIdAndOrgIdAndIsDeletedFalse(stranger, orgId)).thenReturn(Optional.empty());
        assertThrows(BusinessException.class,
                () -> service.addFamily(stranger, EmployeeFamily.builder()
                        .name("X").relationship("OTHER").build()));
        verifyNoInteractions(familyRepo);
    }

    @Test
    void updateFamily_overwritesEditableFields() {
        UUID famId = UUID.randomUUID();
        EmployeeFamily existing = EmployeeFamily.builder()
                .id(famId).orgId(orgId).employeeId(employeeId)
                .name("Old").relationship("CHILD").dependent(false)
                .build();
        when(familyRepo.findByIdAndOrgIdAndIsDeletedFalse(famId, orgId))
                .thenReturn(Optional.of(existing));
        when(familyRepo.save(any(EmployeeFamily.class))).thenAnswer(inv -> inv.getArgument(0));

        EmployeeFamily updated = service.updateFamily(famId, EmployeeFamily.builder()
                .name("New").relationship("SPOUSE").dependent(true)
                .phone("9876543210")
                .build());

        assertEquals("New", updated.getName());
        assertEquals("SPOUSE", updated.getRelationship());
        assertTrue(updated.isDependent());
        assertEquals("9876543210", updated.getPhone());
        // id+orgId+employeeId are preserved
        assertEquals(famId, updated.getId());
        assertEquals(employeeId, updated.getEmployeeId());
    }

    @Test
    void deleteFamily_softDeletes() {
        UUID famId = UUID.randomUUID();
        EmployeeFamily existing = EmployeeFamily.builder()
                .id(famId).orgId(orgId).employeeId(employeeId)
                .name("Y").relationship("OTHER")
                .build();
        when(familyRepo.findByIdAndOrgIdAndIsDeletedFalse(famId, orgId))
                .thenReturn(Optional.of(existing));
        when(familyRepo.save(any(EmployeeFamily.class))).thenAnswer(inv -> inv.getArgument(0));

        service.deleteFamily(famId);

        ArgumentCaptor<EmployeeFamily> cap = ArgumentCaptor.forClass(EmployeeFamily.class);
        verify(familyRepo).save(cap.capture());
        assertTrue(cap.getValue().isDeleted());
    }

    // ───── Education ─────

    @Test
    void addEducation_stampsOrgEmployeeAndPersists() {
        when(educationRepo.save(any(EmployeeEducation.class))).thenAnswer(inv -> inv.getArgument(0));

        EmployeeEducation input = EmployeeEducation.builder()
                .degree("B.Tech")
                .fieldOfStudy("Computer Science")
                .institution("IIT Bombay")
                .startYear(2010).endYear(2014)
                .grade("8.5 CGPA")
                .build();

        EmployeeEducation saved = service.addEducation(employeeId, input);

        assertEquals(orgId, saved.getOrgId());
        assertEquals(employeeId, saved.getEmployeeId());
        assertEquals("B.Tech", saved.getDegree());
        assertEquals("IIT Bombay", saved.getInstitution());
    }

    @Test
    void updateEducation_overwritesEditableFields() {
        UUID eduId = UUID.randomUUID();
        EmployeeEducation existing = EmployeeEducation.builder()
                .id(eduId).orgId(orgId).employeeId(employeeId)
                .degree("BSc").startYear(2008)
                .build();
        when(educationRepo.findByIdAndOrgIdAndIsDeletedFalse(eduId, orgId))
                .thenReturn(Optional.of(existing));
        when(educationRepo.save(any(EmployeeEducation.class))).thenAnswer(inv -> inv.getArgument(0));

        EmployeeEducation updated = service.updateEducation(eduId, EmployeeEducation.builder()
                .degree("MSc").fieldOfStudy("Math").institution("BITS")
                .startYear(2012).endYear(2014).grade("First class")
                .build());

        assertEquals("MSc", updated.getDegree());
        assertEquals("BITS", updated.getInstitution());
        assertEquals(2014, updated.getEndYear());
    }

    // ───── Experience ─────

    @Test
    void addExperience_stampsOrgEmployeeAndPersists() {
        when(experienceRepo.save(any(EmployeeExperience.class))).thenAnswer(inv -> inv.getArgument(0));

        EmployeeExperience input = EmployeeExperience.builder()
                .companyName("Infosys")
                .designation("Senior Engineer")
                .fromDate(LocalDate.of(2014, 7, 1))
                .toDate(LocalDate.of(2018, 12, 31))
                .location("Bengaluru")
                .build();

        EmployeeExperience saved = service.addExperience(employeeId, input);

        assertEquals(orgId, saved.getOrgId());
        assertEquals(employeeId, saved.getEmployeeId());
        assertEquals("Infosys", saved.getCompanyName());
        assertEquals("Bengaluru", saved.getLocation());
    }

    @Test
    void listExperience_ordersByFromDateDesc_perRepoMethod() {
        service.listExperience(employeeId);
        verify(experienceRepo).findByOrgIdAndEmployeeIdAndIsDeletedFalseOrderByFromDateDesc(orgId, employeeId);
    }

    // ───── Self-service /me ─────

    @Test
    void me_returnsEmployeeLinkedToCurrentUser() {
        Employee linked = Employee.builder().id(UUID.randomUUID()).orgId(orgId).userId(userId)
                .fullName("Anita").build();
        when(employeeRepo.findByOrgIdAndUserIdAndIsDeletedFalse(orgId, userId))
                .thenReturn(Optional.of(linked));

        Employee me = service.me();

        assertEquals(linked.getId(), me.getId());
        assertEquals("Anita", me.getFullName());
    }

    @Test
    void me_userNotLinked_throwsHrEmployeeNotLinked() {
        when(employeeRepo.findByOrgIdAndUserIdAndIsDeletedFalse(orgId, userId))
                .thenReturn(Optional.empty());
        BusinessException ex = assertThrows(BusinessException.class, () -> service.me());
        assertEquals("HR_EMPLOYEE_NOT_LINKED", ex.getErrorCode());
    }

    @Test
    void updateMe_overwritesOnlySelfEditableFields_locksManagerFields() {
        UUID myId = UUID.randomUUID();
        Employee me = Employee.builder()
                .id(myId).orgId(orgId).userId(userId)
                .fullName("Anita")
                .designation("Senior Engineer")   // manager-set; must be preserved
                .department("Engineering")        // manager-set; must be preserved
                .employmentStatus("ACTIVE")       // manager-set
                .employmentType("FULL_TIME")      // manager-set
                .pan("ABCDE1234F")                // statutory; must be preserved
                .bankAccountNumber("12345678")    // payment; must be preserved
                .build();
        when(employeeRepo.findByOrgIdAndUserIdAndIsDeletedFalse(orgId, userId))
                .thenReturn(Optional.of(me));
        when(employeeRepo.save(any(Employee.class))).thenAnswer(inv -> inv.getArgument(0));

        Employee selfEdit = Employee.builder()
                // self-editable
                .dateOfBirth(LocalDate.of(1990, 5, 12))
                .gender("FEMALE")
                .maritalStatus("MARRIED")
                .bloodGroup("O+")
                .nationality("Indian")
                .personalEmail("priya@personal.com")
                .phone("9999000000")
                .currentAddressLine1("12 MG Road")
                .currentCity("Bengaluru")
                .emergencyContactName("Ravi")
                .emergencyContactPhone("9876543210")
                .photoAttachmentId(UUID.randomUUID())
                // attempts to change manager fields — must be IGNORED
                .designation("CEO")
                .department("Finance")
                .employmentStatus("EXITED")
                .pan("ZZZZZ9999Z")
                .bankAccountNumber("99999999")
                .build();

        Employee saved = service.updateMe(selfEdit);

        // Self-editable fields applied
        assertEquals(LocalDate.of(1990, 5, 12), saved.getDateOfBirth());
        assertEquals("FEMALE", saved.getGender());
        assertEquals("MARRIED", saved.getMaritalStatus());
        assertEquals("priya@personal.com", saved.getPersonalEmail());
        assertEquals("9999000000", saved.getPhone());
        assertEquals("Bengaluru", saved.getCurrentCity());
        assertEquals("Ravi", saved.getEmergencyContactName());
        assertNotNull(saved.getPhotoAttachmentId());

        // Manager-controlled fields NOT overwritten
        assertEquals("Senior Engineer", saved.getDesignation());
        assertEquals("Engineering", saved.getDepartment());
        assertEquals("ACTIVE", saved.getEmploymentStatus());
        assertEquals("FULL_TIME", saved.getEmploymentType());
        assertEquals("ABCDE1234F", saved.getPan());
        assertEquals("12345678", saved.getBankAccountNumber());
        assertEquals("Anita", saved.getFullName());
    }

    @Test
    void myProfile_returnsEmployeePlusSubresources() {
        UUID myId = UUID.randomUUID();
        Employee me = Employee.builder().id(myId).orgId(orgId).userId(userId).fullName("Anita").build();
        when(employeeRepo.findByOrgIdAndUserIdAndIsDeletedFalse(orgId, userId))
                .thenReturn(Optional.of(me));
        when(familyRepo.findByOrgIdAndEmployeeIdAndIsDeletedFalseOrderByCreatedAtAsc(orgId, myId))
                .thenReturn(java.util.List.of(EmployeeFamily.builder().name("Ravi").relationship("SPOUSE").build()));
        when(educationRepo.findByOrgIdAndEmployeeIdAndIsDeletedFalseOrderByStartYearDesc(orgId, myId))
                .thenReturn(java.util.List.of(EmployeeEducation.builder().degree("B.Tech").build()));
        when(experienceRepo.findByOrgIdAndEmployeeIdAndIsDeletedFalseOrderByFromDateDesc(orgId, myId))
                .thenReturn(java.util.List.of(EmployeeExperience.builder().companyName("Infosys").build()));

        var profile = service.myProfile();

        assertSame(me, profile.get("employee"));
        assertEquals(1, ((java.util.List<?>) profile.get("family")).size());
        assertEquals(1, ((java.util.List<?>) profile.get("education")).size());
        assertEquals(1, ((java.util.List<?>) profile.get("experience")).size());
    }
}
