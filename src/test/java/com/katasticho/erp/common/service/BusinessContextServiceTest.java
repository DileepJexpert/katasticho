package com.katasticho.erp.common.service;

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

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class BusinessContextServiceTest {

    @Mock private OrganisationRepository organisationRepository;

    private BusinessContextService service;
    private final UUID orgId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        service = new BusinessContextService(organisationRepository);
        TenantContext.setCurrentOrgId(orgId);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    void preferredHsnCategories_grocery_prefersGroceryFirst() {
        Organisation org = Organisation.builder()
                .name("Grocer")
                .businessType("RETAILER")
                .industryCode("GROCERY")
                .countryCode("IN")
                .build();
        when(organisationRepository.findById(orgId)).thenReturn(Optional.of(org));

        assertEquals(List.of("GROCERY", "FOOD_BEVERAGE", "PERSONAL_CARE", "HOUSEHOLD"),
                service.preferredHsnCategories());
    }

    @Test
    void preferredHsnCategories_pharma_prefersMedicalCategories() {
        Organisation org = Organisation.builder()
                .name("Pharma")
                .businessType("RETAILER")
                .industryCode("PHARMACY")
                .countryCode("IN")
                .build();
        when(organisationRepository.findById(orgId)).thenReturn(Optional.of(org));

        assertEquals(List.of("PHARMA", "MEDICAL", "SURGICAL", "PERSONAL_CARE"),
                service.preferredHsnCategories());
    }

    @Test
    void profile_is_cached_after_first_lookup() {
        Organisation org = Organisation.builder()
                .name("Cached")
                .businessType("RETAILER")
                .industryCode("GROCERY")
                .countryCode("IN")
                .build();
        when(organisationRepository.findById(orgId)).thenReturn(Optional.of(org));

        service.currentProfile();
        service.currentProfile();

        verify(organisationRepository, times(1)).findById(orgId);
    }

    @Test
    void missingTenantContext_throws() {
        TenantContext.clear();
        BusinessException ex = assertThrows(BusinessException.class, () -> service.currentProfile());
        assertEquals("ORG_CONTEXT_REQUIRED", ex.getErrorCode());
    }
}
