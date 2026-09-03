package com.katasticho.erp.reporting;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.reporting.dto.ReportScheduleRequest;
import com.katasticho.erp.reporting.dto.SavedReportRequest;
import com.katasticho.erp.reporting.entity.ReportSchedule;
import com.katasticho.erp.reporting.entity.SavedReport;
import com.katasticho.erp.reporting.repository.ReportScheduleRepository;
import com.katasticho.erp.reporting.repository.SavedReportRepository;
import com.katasticho.erp.reporting.service.SavedReportService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class SavedReportServiceTest {

    @Mock private SavedReportRepository savedReportRepository;
    @Mock private ReportScheduleRepository reportScheduleRepository;

    private SavedReportService service;

    private final UUID orgId   = UUID.randomUUID();
    private final UUID ownerId = UUID.randomUUID();
    private final UUID otherId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        service = new SavedReportService(savedReportRepository, reportScheduleRepository,
                new ObjectMapper());
    }

    // -------------------------------------------------------------------------
    // create – saves with correct orgId and columnKeys JSON
    // -------------------------------------------------------------------------

    @Test
    void create_savesWithCorrectOrgIdAndColumnKeysJson() {
        SavedReportRequest req = new SavedReportRequest();
        req.setName("Monthly Sales");
        req.setBaseReportKey("sales_register");
        req.setColumnKeys(List.of("date", "customer", "amount"));
        req.setPublic(false);

        ArgumentCaptor<SavedReport> captor = ArgumentCaptor.forClass(SavedReport.class);
        when(savedReportRepository.save(captor.capture()))
                .thenAnswer(inv -> inv.getArgument(0));

        SavedReport result = service.create(orgId, ownerId, req);

        SavedReport saved = captor.getValue();
        assertThat(saved.getOrgId()).isEqualTo(orgId);
        assertThat(saved.getCreatedBy()).isEqualTo(ownerId);
        assertThat(saved.getName()).isEqualTo("Monthly Sales");
        // columnKeys must be persisted as a JSON array string
        assertThat(saved.getColumnKeys()).isEqualTo("[\"date\",\"customer\",\"amount\"]");
        assertThat(saved.isDeleted()).isFalse();

        assertThat(result).isSameAs(saved);
    }

    // -------------------------------------------------------------------------
    // update – owner succeeds
    // -------------------------------------------------------------------------

    @Test
    void update_byOwner_succeeds() {
        SavedReport existing = buildReport(ownerId);
        when(savedReportRepository.findById(existing.getId())).thenReturn(Optional.of(existing));
        when(savedReportRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        SavedReportRequest req = new SavedReportRequest();
        req.setName("Updated Name");
        req.setBaseReportKey("purchase_register");
        req.setColumnKeys(List.of("date", "vendor"));
        req.setPublic(true);

        SavedReport updated = service.update(orgId, ownerId, existing.getId(), req);

        assertThat(updated.getName()).isEqualTo("Updated Name");
        assertThat(updated.isPublic()).isTrue();
        assertThat(updated.getColumnKeys()).isEqualTo("[\"date\",\"vendor\"]");
    }

    // -------------------------------------------------------------------------
    // delete – non-owner throws BusinessException
    // -------------------------------------------------------------------------

    @Test
    void delete_byNonOwner_throwsBusinessException() {
        SavedReport existing = buildReport(ownerId);
        when(savedReportRepository.findById(existing.getId())).thenReturn(Optional.of(existing));

        assertThatThrownBy(() -> service.delete(orgId, otherId, existing.getId()))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("owner");

        verify(savedReportRepository, never()).save(any());
    }

    // -------------------------------------------------------------------------
    // addSchedule – creates schedule with correct savedReportId
    // -------------------------------------------------------------------------

    @Test
    void addSchedule_createsScheduleWithCorrectSavedReportId() {
        SavedReport report = buildReport(ownerId);
        when(savedReportRepository.findById(report.getId())).thenReturn(Optional.of(report));

        ReportScheduleRequest req = new ReportScheduleRequest();
        req.setFrequency("WEEKLY");
        req.setDayOfWeek((short) 1);
        req.setSendTime("08:00");
        req.setRecipientEmails(List.of("alice@example.com", "bob@example.com"));
        req.setActive(true);

        ArgumentCaptor<ReportSchedule> captor = ArgumentCaptor.forClass(ReportSchedule.class);
        when(reportScheduleRepository.save(captor.capture()))
                .thenAnswer(inv -> inv.getArgument(0));

        ReportSchedule schedule = service.addSchedule(orgId, report.getId(), req);

        ReportSchedule saved = captor.getValue();
        assertThat(saved.getSavedReportId()).isEqualTo(report.getId());
        assertThat(saved.getOrgId()).isEqualTo(orgId);
        assertThat(saved.getFrequency()).isEqualTo("WEEKLY");
        assertThat(saved.getDayOfWeek()).isEqualTo((short) 1);
        assertThat(saved.getRecipientEmails())
                .isEqualTo("[\"alice@example.com\",\"bob@example.com\"]");
        assertThat(saved.isActive()).isTrue();

        assertThat(schedule).isSameAs(saved);
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    private SavedReport buildReport(UUID createdBy) {
        return SavedReport.builder()
                .id(UUID.randomUUID())
                .orgId(orgId)
                .createdBy(createdBy)
                .name("Test Report")
                .baseReportKey("sales_register")
                .columnKeys("[\"date\"]")
                .deleted(false)
                .build();
    }
}
