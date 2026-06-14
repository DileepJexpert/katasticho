package com.katasticho.erp.hr.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.hr.entity.Offboarding;
import com.katasticho.erp.hr.entity.OffboardingTask;
import com.katasticho.erp.hr.repository.OffboardingRepository;
import com.katasticho.erp.hr.repository.OffboardingTaskRepository;
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
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class OffboardingServiceTest {

    @Mock private OffboardingRepository offboardingRepo;
    @Mock private OffboardingTaskRepository taskRepo;
    @Mock private EmployeeRepository employeeRepo;
    private OffboardingService service;

    private final UUID orgId = UUID.randomUUID();
    private final UUID userId = UUID.randomUUID();
    private final UUID empUserId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        service = new OffboardingService(offboardingRepo, taskRepo, employeeRepo);
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(userId);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    void initiate_seedsClearanceChecklist() {
        when(offboardingRepo.save(any())).thenAnswer(i -> {
            Offboarding o = i.getArgument(0);
            if (o.getId() == null) o.setId(UUID.randomUUID());
            return o;
        });
        when(taskRepo.save(any())).thenAnswer(i -> i.getArgument(0));
        when(taskRepo.findByOrgIdAndOffboardingIdAndIsDeletedFalseOrderByCategoryAsc(eq(orgId), any()))
                .thenReturn(List.of());

        service.initiate(empUserId, LocalDate.of(2026, 5, 1), LocalDate.of(2026, 5, 31), "New role");

        // 5 default clearance tasks seeded
        verify(taskRepo, times(5)).save(any());
    }

    @Test
    void complete_withPendingTasks_throws() {
        UUID id = UUID.randomUUID();
        Offboarding ob = Offboarding.builder().id(id).orgId(orgId).employeeUserId(empUserId)
                .status("INITIATED").build();
        when(offboardingRepo.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)).thenReturn(Optional.of(ob));
        when(taskRepo.findByOrgIdAndOffboardingIdAndIsDeletedFalseOrderByCategoryAsc(orgId, id))
                .thenReturn(List.of(
                        OffboardingTask.builder().completed(true).build(),
                        OffboardingTask.builder().completed(false).build()));

        BusinessException ex = assertThrows(BusinessException.class, () -> service.complete(id));
        assertEquals("OFFB_TASKS_PENDING", ex.getErrorCode());
    }

    @Test
    void complete_allTasksDone_marksEmployeeExited() {
        UUID id = UUID.randomUUID();
        Offboarding ob = Offboarding.builder().id(id).orgId(orgId).employeeUserId(empUserId)
                .status("INITIATED").lastWorkingDay(LocalDate.of(2026, 5, 31)).build();
        when(offboardingRepo.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)).thenReturn(Optional.of(ob));
        when(taskRepo.findByOrgIdAndOffboardingIdAndIsDeletedFalseOrderByCategoryAsc(orgId, id))
                .thenReturn(List.of(
                        OffboardingTask.builder().completed(true).build(),
                        OffboardingTask.builder().completed(true).build()));
        when(offboardingRepo.save(any())).thenAnswer(i -> i.getArgument(0));
        Employee emp = Employee.builder().userId(empUserId).employmentStatus("ACTIVE").build();
        when(employeeRepo.findByOrgIdAndUserIdAndIsDeletedFalse(orgId, empUserId))
                .thenReturn(Optional.of(emp));
        when(employeeRepo.save(any())).thenAnswer(i -> i.getArgument(0));

        Offboarding result = service.complete(id);

        assertEquals("COMPLETED", result.getStatus());
        ArgumentCaptor<Employee> cap = ArgumentCaptor.forClass(Employee.class);
        verify(employeeRepo).save(cap.capture());
        assertEquals("EXITED", cap.getValue().getEmploymentStatus());
        assertEquals(LocalDate.of(2026, 5, 31), cap.getValue().getDateOfExit());
    }
}
