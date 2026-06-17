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
}
