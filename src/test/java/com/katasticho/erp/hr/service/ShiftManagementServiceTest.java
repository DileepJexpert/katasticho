package com.katasticho.erp.hr.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.hr.entity.Shift;
import com.katasticho.erp.hr.entity.ShiftAssignment;
import com.katasticho.erp.hr.repository.ShiftAssignmentRepository;
import com.katasticho.erp.hr.repository.ShiftRepository;
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
class ShiftManagementServiceTest {

    @Mock private ShiftRepository shiftRepo;
    @Mock private ShiftAssignmentRepository assignmentRepo;

    private ShiftManagementService service;

    private final UUID orgId = UUID.randomUUID();
    private final UUID userId = UUID.randomUUID();
    private final UUID shiftId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        service = new ShiftManagementService(shiftRepo, assignmentRepo);
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(UUID.randomUUID());
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    void assignShift_closesPriorOpenAssignment() {
        when(shiftRepo.findByIdAndOrgIdAndIsDeletedFalse(shiftId, orgId))
                .thenReturn(Optional.of(Shift.builder().id(shiftId).orgId(orgId).build()));
        ShiftAssignment open = ShiftAssignment.builder()
                .id(UUID.randomUUID()).orgId(orgId).userId(userId).shiftId(UUID.randomUUID())
                .effectiveFrom(LocalDate.of(2026, 1, 1)).effectiveTo(null).build();
        when(assignmentRepo.findByOrgIdAndUserIdAndEffectiveToIsNullAndIsDeletedFalse(orgId, userId))
                .thenReturn(List.of(open));
        when(assignmentRepo.save(any())).thenAnswer(i -> i.getArgument(0));

        LocalDate newFrom = LocalDate.of(2026, 6, 1);
        service.assignShift(userId, shiftId, newFrom, null);

        // prior open assignment closed the day before the new one
        assertEquals(LocalDate.of(2026, 5, 31), open.getEffectiveTo());
    }

    @Test
    void shiftOn_returnsAssignmentCoveringDate() {
        ShiftAssignment current = ShiftAssignment.builder()
                .orgId(orgId).userId(userId).shiftId(shiftId)
                .effectiveFrom(LocalDate.of(2026, 6, 1)).effectiveTo(null).build();
        ShiftAssignment past = ShiftAssignment.builder()
                .orgId(orgId).userId(userId).shiftId(UUID.randomUUID())
                .effectiveFrom(LocalDate.of(2026, 1, 1)).effectiveTo(LocalDate.of(2026, 5, 31)).build();
        when(assignmentRepo
                .findByOrgIdAndUserIdAndEffectiveFromLessThanEqualAndIsDeletedFalseOrderByEffectiveFromDesc(
                        eq(orgId), eq(userId), any()))
                .thenReturn(List.of(current, past));   // newest first
        when(shiftRepo.findByIdAndOrgIdAndIsDeletedFalse(shiftId, orgId))
                .thenReturn(Optional.of(Shift.builder().id(shiftId).code("GEN").build()));

        Optional<Shift> resolved = service.shiftOn(userId, LocalDate.of(2026, 6, 15));

        assertTrue(resolved.isPresent());
        assertEquals("GEN", resolved.get().getCode());
    }

    @Test
    void shiftOn_noCoveringAssignment_empty() {
        ShiftAssignment past = ShiftAssignment.builder()
                .orgId(orgId).userId(userId).shiftId(UUID.randomUUID())
                .effectiveFrom(LocalDate.of(2026, 1, 1)).effectiveTo(LocalDate.of(2026, 5, 31)).build();
        when(assignmentRepo
                .findByOrgIdAndUserIdAndEffectiveFromLessThanEqualAndIsDeletedFalseOrderByEffectiveFromDesc(
                        eq(orgId), eq(userId), any()))
                .thenReturn(List.of(past));

        assertTrue(service.shiftOn(userId, LocalDate.of(2026, 6, 15)).isEmpty());
    }
}
