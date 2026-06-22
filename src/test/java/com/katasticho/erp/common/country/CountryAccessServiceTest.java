package com.katasticho.erp.common.country;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class CountryAccessServiceTest {

    @Mock private OrganisationRepository organisationRepository;
    @Mock private CountryRegistry countryRegistry;
    private CountryAccessService service;

    private final UUID orgId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        service = new CountryAccessService(organisationRepository, countryRegistry);
        TenantContext.setCurrentOrgId(orgId);
    }

    @AfterEach
    void clear() { TenantContext.clear(); }

    private void stubCountry(String code) {
        Organisation org = Organisation.builder().name("X").countryCode(code).build();
        when(organisationRepository.findById(orgId)).thenReturn(Optional.of(org));
    }

    @Test
    void india_org_passes_a_requirescountry_IN_gate() {
        stubCountry("IN");
        assertDoesNotThrow(() -> service.requireCountry("IN"));
        assertEquals("IN", service.currentCountry());
    }

    @Test
    void uae_org_is_blocked_from_india_only_features() {
        stubCountry("AE");
        var ex = assertThrows(BusinessException.class, () -> service.requireCountry("IN"));
        assertEquals("FEATURE_NOT_AVAILABLE_IN_COUNTRY", ex.getErrorCode());
    }

    @Test
    void multi_country_gate_allows_any_listed() {
        stubCountry("OM");
        assertDoesNotThrow(() -> service.requireCountry("AE", "OM"));
    }

    @Test
    void country_is_cached_so_repeated_calls_hit_db_once() {
        stubCountry("AE");
        service.currentCountry();
        service.currentCountry();
        service.requireCountry("AE");
        verify(organisationRepository, times(1)).findById(orgId);
    }

    @Test
    void blank_or_missing_country_defaults_to_IN() {
        Organisation org = Organisation.builder().name("X").countryCode("  ").build();
        when(organisationRepository.findById(orgId)).thenReturn(Optional.of(org));
        assertEquals("IN", service.currentCountry());
    }

    @Test
    void no_org_context_throws() {
        TenantContext.clear();
        var ex = assertThrows(BusinessException.class, () -> service.currentCountry());
        assertEquals("ORG_CONTEXT_REQUIRED", ex.getErrorCode());
    }
}
