package com.katasticho.erp.hr.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.hr.entity.TimesheetEntry;
import com.katasticho.erp.hr.repository.TimesheetEntryRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class TimesheetServiceTest {

    @Mock private TimesheetEntryRepository repo;
    private TimesheetService service;

    private final UUID orgId = UUID.randomUUID();
    private final UUID userId = UUID.randomUUID();
    private final LocalDate day = LocalDate.of(2026, 5, 4);

    @BeforeEach
    void setUp() {
        service = new TimesheetService(repo);
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(userId);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    private TimesheetEntry entry(String project, String hours, boolean billable) {
        return TimesheetEntry.builder()
                .orgId(orgId).userId(userId).workDate(day).project(project)
                .hours(new BigDecimal(hours)).billable(billable).status("APPROVED").build();
    }

    @Test
    void log_rejectsInvalidHours() {
        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.log(day, "P", "T", new BigDecimal("30"), false, null));
        assertEquals("HR_TS_BAD_HOURS", ex.getErrorCode());
    }

    @Test
    void log_createsDraft() {
        when(repo.save(any())).thenAnswer(i -> i.getArgument(0));
        TimesheetEntry e = service.log(day, "Apollo", "API work", new BigDecimal("6"), true, "n");
        assertEquals("DRAFT", e.getStatus());
        assertTrue(e.isBillable());
        assertEquals(userId, e.getUserId());
    }

    @Test
    void submitRange_movesDraftsToSubmitted() {
        TimesheetEntry d1 = TimesheetEntry.builder().orgId(orgId).userId(userId)
                .workDate(day).hours(new BigDecimal("8")).status("DRAFT").build();
        TimesheetEntry d2 = TimesheetEntry.builder().orgId(orgId).userId(userId)
                .workDate(day.plusDays(1)).hours(new BigDecimal("8")).status("DRAFT").build();
        when(repo.findByOrgIdAndUserIdAndStatusAndWorkDateBetweenAndIsDeletedFalse(
                eq(orgId), eq(userId), eq("DRAFT"), any(), any())).thenReturn(List.of(d1, d2));
        when(repo.saveAll(any())).thenAnswer(i -> i.getArgument(0));

        int n = service.submitRange(day, day.plusDays(6));

        assertEquals(2, n);
        assertEquals("SUBMITTED", d1.getStatus());
        assertEquals("SUBMITTED", d2.getStatus());
    }

    @Test
    void approve_requiresSubmitted() {
        TimesheetEntry e = TimesheetEntry.builder().id(UUID.randomUUID()).orgId(orgId)
                .userId(userId).workDate(day).hours(new BigDecimal("8")).status("DRAFT").build();
        when(repo.findByIdAndOrgIdAndIsDeletedFalse(e.getId(), orgId)).thenReturn(Optional.of(e));

        BusinessException ex = assertThrows(BusinessException.class, () -> service.approve(e.getId()));
        assertEquals("HR_TS_NOT_SUBMITTED", ex.getErrorCode());
    }

    @Test
    void summary_totalsBillableAndByProject() {
        when(repo.findByOrgIdAndUserIdAndWorkDateBetweenAndIsDeletedFalseOrderByWorkDateDesc(
                eq(orgId), eq(userId), any(), any()))
                .thenReturn(List.of(
                        entry("Apollo", "6", true),
                        entry("Apollo", "2", false),
                        entry("Cipla", "4", true)));

        Map<String, Object> s = service.summary(null, day, day);

        assertEquals(0, ((BigDecimal) s.get("totalHours")).compareTo(new BigDecimal("12")));
        assertEquals(0, ((BigDecimal) s.get("billableHours")).compareTo(new BigDecimal("10")));
        assertEquals(0, ((BigDecimal) s.get("nonBillableHours")).compareTo(new BigDecimal("2")));
        @SuppressWarnings("unchecked")
        List<Map<String, Object>> byProject = (List<Map<String, Object>>) s.get("byProject");
        assertEquals("Apollo", byProject.get(0).get("project"));   // 8h, ranks first
        assertEquals(0, ((BigDecimal) byProject.get(0).get("hours")).compareTo(new BigDecimal("8")));
    }
}
