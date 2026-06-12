package com.katasticho.erp.fieldsales.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.fieldsales.entity.*;
import com.katasticho.erp.fieldsales.repository.*;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class DetailAidServiceTest {

    @Mock private DetailAidRepository aidRepo;
    @Mock private VisitDetailAidLogRepository logRepo;
    @Mock private FieldVisitRepository fieldVisitRepo;
    @Mock private RouteExecutionRepository routeExecutionRepo;

    private DetailAidService service;

    private final UUID orgId = UUID.randomUUID();
    private final UUID userId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        service = new DetailAidService(aidRepo, logRepo, fieldVisitRepo, routeExecutionRepo);
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(userId);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    void create_validAid_stampsOrgAndCreator() {
        when(aidRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        DetailAid aid = service.create("Crocin Brochure", "Latest visual aid",
                "https://example.com/crocin.pdf", "pdf", "Crocin");

        assertEquals(orgId, aid.getOrgId());
        assertEquals(userId, aid.getCreatedBy());
        assertEquals("PDF", aid.getMediaType());
        assertTrue(aid.isActive());
    }

    @Test
    void create_nonHttpUrl_throws() {
        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.create("Aid", null, "ftp://x/y.pdf", "PDF", null));
        assertEquals("DA_URL_INVALID", ex.getErrorCode());
    }

    @Test
    void create_unknownMediaType_fallsBackToLink() {
        when(aidRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        DetailAid aid = service.create("Aid", null, "https://x/y", "POWERPOINT", null);

        assertEquals("LINK", aid.getMediaType());
    }

    @Test
    void logShown_beforeCheckIn_throws() {
        FieldVisit visit = visitOwnedByUser("PLANNED");

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.logShown(visit.getId(), List.of(UUID.randomUUID())));
        assertEquals("MR_VISIT_NOT_STARTED", ex.getErrorCode());
    }

    @Test
    void logShown_replacesLogAndValidatesAidOwnership() {
        FieldVisit visit = visitOwnedByUser("IN_PROGRESS");
        DetailAid aid = DetailAid.builder().id(UUID.randomUUID()).orgId(orgId)
                .name("Aid").mediaUrl("https://x/y").build();
        when(aidRepo.findByIdAndOrgIdAndIsDeletedFalse(aid.getId(), orgId))
                .thenReturn(Optional.of(aid));
        when(logRepo.saveAll(any())).thenAnswer(inv -> inv.getArgument(0));

        List<VisitDetailAidLog> rows = service.logShown(visit.getId(), List.of(aid.getId()));

        verify(logRepo).deleteByOrgIdAndFieldVisitId(orgId, visit.getId());
        assertEquals(1, rows.size());
        assertEquals(aid.getId(), rows.get(0).getDetailAidId());
    }

    @Test
    void logShown_byOtherSalesperson_throws() {
        UUID execId = UUID.randomUUID();
        FieldVisit visit = FieldVisit.builder()
                .id(UUID.randomUUID()).orgId(orgId)
                .routeExecutionId(execId).contactId(UUID.randomUUID())
                .status("IN_PROGRESS").build();
        RouteExecution exec = RouteExecution.builder()
                .salespersonId(UUID.randomUUID()).status("IN_PROGRESS")
                .routeId(UUID.randomUUID()).executionDate(LocalDate.now()).build();
        exec.setId(execId);
        exec.setOrgId(orgId);
        when(fieldVisitRepo.findByIdAndOrgIdAndIsDeletedFalse(visit.getId(), orgId))
                .thenReturn(Optional.of(visit));
        when(routeExecutionRepo.findByIdAndOrgIdAndIsDeletedFalse(execId, orgId))
                .thenReturn(Optional.of(exec));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.logShown(visit.getId(), List.of()));
        assertEquals("FS_NOT_ASSIGNED_SALESPERSON", ex.getErrorCode());
    }

    @Test
    void listWithUsage_includesShownCounts() {
        DetailAid aid = DetailAid.builder().id(UUID.randomUUID()).orgId(orgId)
                .name("Aid").mediaUrl("https://x/y").build();
        when(aidRepo.findByOrgIdAndIsDeletedFalseOrderByNameAsc(orgId)).thenReturn(List.of(aid));
        when(logRepo.countShownByAid(orgId))
                .thenReturn(List.<Object[]>of(new Object[]{aid.getId(), 7L}));

        var rows = service.listWithUsage();

        assertEquals(1, rows.size());
        assertEquals(7L, rows.get(0).get("timesShown"));
    }

    private FieldVisit visitOwnedByUser(String status) {
        UUID execId = UUID.randomUUID();
        FieldVisit visit = FieldVisit.builder()
                .id(UUID.randomUUID()).orgId(orgId)
                .routeExecutionId(execId).contactId(UUID.randomUUID())
                .status(status).build();
        RouteExecution exec = RouteExecution.builder()
                .salespersonId(userId).status("IN_PROGRESS")
                .routeId(UUID.randomUUID()).executionDate(LocalDate.now()).build();
        exec.setId(execId);
        exec.setOrgId(orgId);
        when(fieldVisitRepo.findByIdAndOrgIdAndIsDeletedFalse(visit.getId(), orgId))
                .thenReturn(Optional.of(visit));
        lenient().when(routeExecutionRepo.findByIdAndOrgIdAndIsDeletedFalse(execId, orgId))
                .thenReturn(Optional.of(exec));
        return visit;
    }
}
