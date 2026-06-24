package com.katasticho.erp.vat;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.country.CountryAccessService;
import com.katasticho.erp.hr.entity.Offboarding;
import com.katasticho.erp.hr.repository.OffboardingRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class GulfComplianceCalendarServiceTest {

    private final CountryAccessService countryAccessService = mock(CountryAccessService.class);
    private final OffboardingRepository offboardingRepository = mock(OffboardingRepository.class);

    private final UUID orgId = UUID.randomUUID();

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    private GulfComplianceCalendarService serviceAt(String isoInstant, String country) {
        TenantContext.setCurrentOrgId(orgId);
        when(countryAccessService.countryOf(orgId)).thenReturn(country);
        Clock fixed = Clock.fixed(Instant.parse(isoInstant), ZoneOffset.UTC);
        return new GulfComplianceCalendarService(countryAccessService, offboardingRepository, fixed);
    }

    @Test
    void uaeVat201DueSoonOnQ2Filing() {
        // 2026-07-25: Q2 (Apr–Jun) ended Jun 30, VAT201 due Jul 28 → DUE_SOON (3 days left).
        GulfComplianceCalendarService service = serviceAt("2026-07-25T06:00:00Z", "AE");
        when(offboardingRepository.findByOrgIdAndStatusAndIsDeletedFalseOrderByCreatedAtDesc(orgId, "INITIATED"))
                .thenReturn(List.of());

        List<Map<String, Object>> items = service.calendar();

        Map<String, Object> vat = byCode(items, "VAT201");
        assertThat(vat).isNotNull();
        assertThat(vat.get("status")).isEqualTo("DUE_SOON");
        assertThat(vat.get("daysLeft")).isEqualTo(3L);
        assertThat(vat.get("dueDate")).isEqualTo(LocalDate.of(2026, 7, 28));
        assertThat(vat.get("period")).isEqualTo("Quarter ending 2026-06-30");
    }

    @Test
    void omanVatDueDayIs30NotUaes28() {
        // Same Q2 ending Jun 30, but Oman's deadline is the 30th (per Art. 72 OM VAT Law).
        GulfComplianceCalendarService service = serviceAt("2026-07-25T06:00:00Z", "OM");
        when(offboardingRepository.findByOrgIdAndStatusAndIsDeletedFalseOrderByCreatedAtDesc(orgId, "INITIATED"))
                .thenReturn(List.of());

        List<Map<String, Object>> items = service.calendar();

        Map<String, Object> vat = byCode(items, "OMAN_VAT_RETURN");
        assertThat(vat).isNotNull();
        assertThat(vat.get("dueDate")).isEqualTo(LocalDate.of(2026, 7, 30));
        assertThat(vat.get("daysLeft")).isEqualTo(5L);
        assertThat(vat.get("status")).isEqualTo("DUE_SOON");
    }

    @Test
    void overdueVat201AfterDeadline() {
        // 2026-08-05: Q2 deadline Jul 28 has passed → OVERDUE.
        GulfComplianceCalendarService service = serviceAt("2026-08-05T06:00:00Z", "AE");
        when(offboardingRepository.findByOrgIdAndStatusAndIsDeletedFalseOrderByCreatedAtDesc(orgId, "INITIATED"))
                .thenReturn(List.of());

        Map<String, Object> vat = byCode(service.calendar(), "VAT201");
        assertThat(vat.get("status")).isEqualTo("OVERDUE");
        assertThat((long) vat.get("daysLeft")).isLessThan(0);
    }

    @Test
    void pendingGratuitySurfacesWhenLastWorkingDayHasPassed() {
        GulfComplianceCalendarService service = serviceAt("2026-07-10T06:00:00Z", "AE");
        Offboarding waitingPayout = Offboarding.builder()
                .id(UUID.randomUUID()).orgId(orgId)
                .employeeUserId(UUID.randomUUID())
                .lastWorkingDay(LocalDate.of(2026, 6, 30))
                .status("INITIATED")
                .build();
        Offboarding alreadyPaid = Offboarding.builder()
                .id(UUID.randomUUID()).orgId(orgId)
                .employeeUserId(UUID.randomUUID())
                .lastWorkingDay(LocalDate.of(2026, 6, 15))
                .status("INITIATED")
                .gratuityJournalEntryId(UUID.randomUUID())
                .build();
        Offboarding futureLwd = Offboarding.builder()
                .id(UUID.randomUUID()).orgId(orgId)
                .employeeUserId(UUID.randomUUID())
                .lastWorkingDay(LocalDate.of(2026, 8, 1))
                .status("INITIATED")
                .build();
        when(offboardingRepository.findByOrgIdAndStatusAndIsDeletedFalseOrderByCreatedAtDesc(orgId, "INITIATED"))
                .thenReturn(List.of(waitingPayout, alreadyPaid, futureLwd));

        List<Map<String, Object>> rows = service.calendar().stream()
                .filter(m -> "GRATUITY_PENDING".equals(m.get("code")))
                .toList();

        // Only the one whose LWD is past and journal not yet posted should surface.
        assertThat(rows).hasSize(1);
        Map<String, Object> r = rows.get(0);
        assertThat(r.get("offboardingId")).isEqualTo(waitingPayout.getId());
        assertThat(r.get("status")).isEqualTo("OVERDUE");
        assertThat(r.get("dueDate")).isEqualTo(LocalDate.of(2026, 6, 30));
    }

    @Test
    void gratuityRowsSuppressedForNonGulfCountry() {
        // Defensive: service trusts its caller, but if a non-Gulf country slips
        // through, gratuity rows must not be emitted (no statutory gratuity in IN).
        GulfComplianceCalendarService service = serviceAt("2026-07-10T06:00:00Z", "IN");
        // No call to the repo expected — the country gate short-circuits first.

        List<Map<String, Object>> items = service.calendar();

        assertThat(items).noneMatch(m -> "GRATUITY_PENDING".equals(m.get("code")));
    }

    private Map<String, Object> byCode(List<Map<String, Object>> items, String code) {
        return items.stream()
                .filter(m -> code.equals(m.get("code")))
                .findFirst()
                .orElse(null);
    }
}
