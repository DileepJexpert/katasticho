package com.katasticho.erp.common.service;

import com.katasticho.erp.common.entity.OrgFeatureFlag;
import com.katasticho.erp.common.module.ModuleCode;
import com.katasticho.erp.common.repository.OrgFeatureFlagRepository;
import com.katasticho.erp.organisation.IndustryFeatureConfigRepository;
import com.katasticho.erp.organisation.IndustrySubCategoryRepository;
import com.katasticho.erp.organisation.IndustryTemplate;
import com.katasticho.erp.organisation.IndustryTemplateRepository;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.redis.core.StringRedisTemplate;

import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class FeatureFlagServiceTest {

    @Mock private OrgFeatureFlagRepository flagRepository;
    @Mock private StringRedisTemplate redisTemplate;
    @Mock private IndustryTemplateRepository industryTemplateRepository;
    @Mock private IndustrySubCategoryRepository subCategoryRepository;
    @Mock private IndustryFeatureConfigRepository featureConfigRepository;
    @Mock private OrganisationRepository organisationRepository;

    @Test
    void distributorLegacyRetailIndustryCodeUsesDistributorCapabilities() {
        UUID orgId = UUID.randomUUID();
        Organisation org = Organisation.builder()
                .id(orgId)
                .businessType("DISTRIBUTOR")
                .industryCode("OTHER_RETAIL")
                .build();
        IndustryTemplate retailerTemplate = IndustryTemplate.builder()
                .id(UUID.randomUUID())
                .businessType("RETAILER")
                .industryCode("OTHER_RETAIL")
                .build();
        IndustryTemplate distributorTemplate = IndustryTemplate.builder()
                .id(UUID.randomUUID())
                .businessType("DISTRIBUTOR")
                .industryCode("OTHER_DISTRIBUTOR")
                .build();

        when(organisationRepository.findById(orgId)).thenReturn(Optional.of(org));
        when(industryTemplateRepository.findByIndustryCode("OTHER_RETAIL"))
                .thenReturn(Optional.of(retailerTemplate));
        when(industryTemplateRepository.findByIndustryCode("OTHER_DISTRIBUTOR"))
                .thenReturn(Optional.of(distributorTemplate));
        when(featureConfigRepository.findByIndustryTemplateIdAndSubCategoryCodeIsNull(any()))
                .thenReturn(Optional.empty());
        when(featureConfigRepository.findByIndustryTemplateIdAndSubCategoryCodeIn(any(), any()))
                .thenReturn(java.util.List.of());
        when(flagRepository.save(any(OrgFeatureFlag.class)))
                .thenAnswer(invocation -> invocation.getArgument(0));

        FeatureFlagService service = new FeatureFlagService(
                flagRepository,
                redisTemplate,
                industryTemplateRepository,
                subCategoryRepository,
                featureConfigRepository,
                organisationRepository);

        service.seedForIndustry(orgId, "OTHER_RETAIL");

        ArgumentCaptor<OrgFeatureFlag> captor = ArgumentCaptor.forClass(OrgFeatureFlag.class);
        verify(flagRepository, atLeastOnce()).save(captor.capture());
        assertTrue(captor.getAllValues().stream()
                .anyMatch(flag -> ModuleCode.FIELD_SALES.equals(flag.getFeature()) && flag.isEnabled()));
    }
}