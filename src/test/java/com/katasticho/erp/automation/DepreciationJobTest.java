package com.katasticho.erp.automation;

import com.katasticho.erp.asset.service.FixedAssetService;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrgSettingsService;
import com.katasticho.erp.organisation.OrganisationRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

import java.util.List;
import java.util.UUID;

import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class DepreciationJobTest {

    @Mock private OrganisationRepository orgRepository;
    @Mock private OrgSettingsService orgSettingsService;
    @Mock private FixedAssetService fixedAssetService;

    private DepreciationJob job;

    private final UUID orgIn = UUID.randomUUID();      // opted in
    private final UUID orgOut = UUID.randomUUID();     // opted out
    private final UUID orgThrows = UUID.randomUUID();  // opted in but runDepreciation throws

    @BeforeEach
    void setUp() {
        job = new DepreciationJob(orgRepository, orgSettingsService, fixedAssetService);
        when(orgRepository.findByIsDeletedFalseAndActiveTrue())
                .thenReturn(List.of(org(orgIn), org(orgOut), org(orgThrows)));
        when(orgSettingsService.get(orgIn, "assets.auto_depreciation", "false")).thenReturn("true");
        when(orgSettingsService.get(orgOut, "assets.auto_depreciation", "false")).thenReturn("false");
        when(orgSettingsService.get(orgThrows, "assets.auto_depreciation", "false")).thenReturn("true");
    }

    private Organisation org(UUID id) {
        return Organisation.builder().id(id).build();
    }

    @Test
    void runs_only_for_opted_in_orgs_and_swallows_per_org_errors() {
        when(fixedAssetService.runDepreciation(anyInt(), anyInt()))
                .thenReturn(java.util.Map.of())            // orgIn succeeds
                .thenThrow(new RuntimeException("closed period")); // orgThrows fails

        job.run(); // must not throw despite orgThrows failing

        // opted-in orgs both attempted (2 calls), opted-out never — verified by
        // the total call count being exactly 2 (orgOut is skipped before the call).
        verify(fixedAssetService, times(2)).runDepreciation(anyInt(), anyInt());
    }

    @Test
    void skips_all_when_none_opted_in() {
        when(orgSettingsService.get(orgIn, "assets.auto_depreciation", "false")).thenReturn("false");
        when(orgSettingsService.get(orgThrows, "assets.auto_depreciation", "false")).thenReturn("false");

        job.run();

        verify(fixedAssetService, never()).runDepreciation(anyInt(), anyInt());
    }
}
