package com.katasticho.erp.hr.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.hr.entity.HrTicket;
import com.katasticho.erp.hr.repository.HrTicketCommentRepository;
import com.katasticho.erp.hr.repository.HrTicketRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class HrHelpDeskServiceTest {

    @Mock private HrTicketRepository ticketRepo;
    @Mock private HrTicketCommentRepository commentRepo;
    private HrHelpDeskService service;

    private final UUID orgId = UUID.randomUUID();
    private final UUID userId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        service = new HrHelpDeskService(ticketRepo, commentRepo);
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(userId);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    void raise_createsOpenTicketStampedToUser() {
        when(ticketRepo.save(any())).thenAnswer(i -> i.getArgument(0));

        HrTicket t = service.raise("PAYROLL", "Payslip missing", "May payslip not visible", "high");

        assertEquals("OPEN", t.getStatus());
        assertEquals("HIGH", t.getPriority());
        assertEquals("PAYROLL", t.getCategory());
        assertEquals(userId, t.getRaisedByUserId());
        assertEquals(orgId, t.getOrgId());
    }

    @Test
    void assign_movesOpenToInProgress() {
        UUID id = UUID.randomUUID();
        UUID assignee = UUID.randomUUID();
        HrTicket t = HrTicket.builder().id(id).orgId(orgId).status("OPEN")
                .raisedByUserId(userId).subject("x").build();
        when(ticketRepo.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)).thenReturn(Optional.of(t));
        when(ticketRepo.save(any())).thenAnswer(i -> i.getArgument(0));

        HrTicket result = service.assign(id, assignee);

        assertEquals("IN_PROGRESS", result.getStatus());
        assertEquals(assignee, result.getAssignedToUserId());
    }

    @Test
    void setStatus_resolvedStoresResolution() {
        UUID id = UUID.randomUUID();
        HrTicket t = HrTicket.builder().id(id).orgId(orgId).status("IN_PROGRESS")
                .raisedByUserId(userId).subject("x").build();
        when(ticketRepo.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)).thenReturn(Optional.of(t));
        when(ticketRepo.save(any())).thenAnswer(i -> i.getArgument(0));

        HrTicket result = service.setStatus(id, "resolved", "Re-shared the payslip");

        assertEquals("RESOLVED", result.getStatus());
        assertEquals("Re-shared the payslip", result.getResolution());
    }

    @Test
    void setStatus_unknownStatus_throws() {
        UUID id = UUID.randomUUID();
        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.setStatus(id, "PARKED", null));
        assertEquals("HR_TICKET_BAD_STATUS", ex.getErrorCode());
    }
}
