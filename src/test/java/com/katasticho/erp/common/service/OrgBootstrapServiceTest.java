package com.katasticho.erp.common.service;

import com.katasticho.erp.accounting.defaults.service.DefaultAccountService;
import com.katasticho.erp.accounting.service.AccountService;
import com.katasticho.erp.common.entity.OrgBootstrapStatus;
import com.katasticho.erp.common.repository.OrgBootstrapStatusRepository;
import com.katasticho.erp.inventory.service.UomService;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import com.katasticho.erp.tax.TaxSeedService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InOrder;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class OrgBootstrapServiceTest {

    @Mock private OrganisationRepository organisationRepository;
    @Mock private UomService uomService;
    @Mock private AccountService accountService;
    @Mock private DefaultAccountService defaultAccountService;
    @Mock private TaxSeedService taxSeedService;
    @Mock private OrgBootstrapStatusRepository statusRepository;

    private OrgBootstrapService bootstrapService;

    private Organisation org;
    private UUID orgId;

    @BeforeEach
    void setUp() {
        bootstrapService = new OrgBootstrapService(
                organisationRepository, uomService, accountService,
                defaultAccountService, taxSeedService, statusRepository);

        orgId = UUID.randomUUID();
        org = mock(Organisation.class);
        when(org.getId()).thenReturn(orgId);
        when(org.getIndustry()).thenReturn("TRADING");

        lenient().when(statusRepository.findById(any())).thenReturn(Optional.empty());
        lenient().when(statusRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));
    }

    @Test
    void bootstrap_freshOrg_allSeedersRunInOrder() {
        when(uomService.seedDefaultsForOrg(orgId)).thenReturn(SeedResult.CREATED_NEW);
        when(accountService.seedFromTemplate(orgId, "TRADING")).thenReturn(SeedResult.CREATED_NEW);
        when(defaultAccountService.seedDefaultsForOrg(orgId)).thenReturn(SeedResult.CREATED_NEW);
        when(taxSeedService.seedForOrg(org)).thenReturn(SeedResult.CREATED_NEW);

        BootstrapResult result = bootstrapService.bootstrap(org);

        assertTrue(result.allSucceeded());
        assertEquals(SeedResult.CREATED_NEW, result.uoms().result());
        assertEquals(SeedResult.CREATED_NEW, result.accounts().result());
        assertEquals(SeedResult.CREATED_NEW, result.defaultAccounts().result());
        assertEquals(SeedResult.CREATED_NEW, result.taxConfig().result());

        InOrder order = inOrder(uomService, accountService, defaultAccountService, taxSeedService);
        order.verify(uomService).seedDefaultsForOrg(orgId);
        order.verify(accountService).seedFromTemplate(orgId, "TRADING");
        order.verify(defaultAccountService).seedDefaultsForOrg(orgId);
        order.verify(taxSeedService).seedForOrg(org);
    }

    @Test
    void bootstrap_existingOrg_idempotent_noDuplicates() {
        when(uomService.seedDefaultsForOrg(orgId)).thenReturn(SeedResult.ALREADY_EXISTS);
        when(accountService.seedFromTemplate(orgId, "TRADING")).thenReturn(SeedResult.ALREADY_EXISTS);
        when(defaultAccountService.seedDefaultsForOrg(orgId)).thenReturn(SeedResult.ALREADY_EXISTS);
        when(taxSeedService.seedForOrg(org)).thenReturn(SeedResult.ALREADY_EXISTS);

        BootstrapResult first = bootstrapService.bootstrap(org);
        BootstrapResult second = bootstrapService.bootstrap(org);

        assertTrue(first.allSucceeded());
        assertTrue(second.allSucceeded());
        assertEquals(SeedResult.ALREADY_EXISTS, second.uoms().result());
        assertEquals(SeedResult.ALREADY_EXISTS, second.accounts().result());
        assertEquals(SeedResult.ALREADY_EXISTS, second.defaultAccounts().result());
        assertEquals(SeedResult.ALREADY_EXISTS, second.taxConfig().result());

        verify(uomService, times(2)).seedDefaultsForOrg(orgId);
        verify(accountService, times(2)).seedFromTemplate(orgId, "TRADING");
        verify(defaultAccountService, times(2)).seedDefaultsForOrg(orgId);
        verify(taxSeedService, times(2)).seedForOrg(org);
    }

    @Test
    void bootstrap_taxSeederFailure_otherSeedersSucceed_orgFlagged() {
        when(uomService.seedDefaultsForOrg(orgId)).thenReturn(SeedResult.CREATED_NEW);
        when(accountService.seedFromTemplate(orgId, "TRADING")).thenReturn(SeedResult.CREATED_NEW);
        when(defaultAccountService.seedDefaultsForOrg(orgId)).thenReturn(SeedResult.CREATED_NEW);
        when(taxSeedService.seedForOrg(org)).thenThrow(new RuntimeException("DB connection lost"));

        BootstrapResult result = bootstrapService.bootstrap(org);

        assertFalse(result.allSucceeded());
        assertTrue(result.uoms().succeeded());
        assertTrue(result.accounts().succeeded());
        assertTrue(result.defaultAccounts().succeeded());
        assertFalse(result.taxConfig().succeeded());
        assertEquals("DB connection lost", result.taxConfig().error());

        ArgumentCaptor<OrgBootstrapStatus> statusCaptor = ArgumentCaptor.forClass(OrgBootstrapStatus.class);
        verify(statusRepository).save(statusCaptor.capture());
        OrgBootstrapStatus status = statusCaptor.getValue();
        assertEquals("PARTIAL_FAILURE", status.getLastBootstrapStatus());
        assertNotNull(status.getUomsSeededAt());
        assertNotNull(status.getAccountsSeededAt());
        assertNotNull(status.getDefaultAccountsSeededAt());
        assertNull(status.getTaxConfigSeededAt());
        assertTrue(status.getLastErrorMessage().contains("TaxConfig"));
    }

    @Test
    void bootstrap_repair_afterPartialFailure_fixesRemaining() {
        when(uomService.seedDefaultsForOrg(orgId)).thenReturn(SeedResult.ALREADY_EXISTS);
        when(accountService.seedFromTemplate(orgId, "TRADING")).thenReturn(SeedResult.ALREADY_EXISTS);
        when(defaultAccountService.seedDefaultsForOrg(orgId)).thenReturn(SeedResult.ALREADY_EXISTS);
        when(taxSeedService.seedForOrg(org)).thenReturn(SeedResult.CREATED_NEW);

        BootstrapResult result = bootstrapService.bootstrap(org);

        assertTrue(result.allSucceeded());
        assertEquals(SeedResult.CREATED_NEW, result.taxConfig().result());

        ArgumentCaptor<OrgBootstrapStatus> statusCaptor = ArgumentCaptor.forClass(OrgBootstrapStatus.class);
        verify(statusRepository).save(statusCaptor.capture());
        assertEquals("SUCCESS", statusCaptor.getValue().getLastBootstrapStatus());
        assertNotNull(statusCaptor.getValue().getTaxConfigSeededAt());
    }

    @Test
    void bootstrapAll_mixedResults_correctCounts() {
        Organisation org2 = mock(Organisation.class);
        UUID orgId2 = UUID.randomUUID();
        when(org2.getId()).thenReturn(orgId2);
        when(org2.getIndustry()).thenReturn("RETAIL");

        Organisation org3 = mock(Organisation.class);
        UUID orgId3 = UUID.randomUUID();
        when(org3.getId()).thenReturn(orgId3);
        when(org3.getIndustry()).thenReturn("SERVICES");

        when(organisationRepository.findAll()).thenReturn(List.of(org, org2, org3));

        // org1: already exists (OK)
        when(uomService.seedDefaultsForOrg(orgId)).thenReturn(SeedResult.ALREADY_EXISTS);
        when(accountService.seedFromTemplate(orgId, "TRADING")).thenReturn(SeedResult.ALREADY_EXISTS);
        when(defaultAccountService.seedDefaultsForOrg(orgId)).thenReturn(SeedResult.ALREADY_EXISTS);
        when(taxSeedService.seedForOrg(org)).thenReturn(SeedResult.ALREADY_EXISTS);

        // org2: repaired (some new data seeded)
        when(uomService.seedDefaultsForOrg(orgId2)).thenReturn(SeedResult.ALREADY_EXISTS);
        when(accountService.seedFromTemplate(orgId2, "RETAIL")).thenReturn(SeedResult.REPAIRED_PARTIAL);
        when(defaultAccountService.seedDefaultsForOrg(orgId2)).thenReturn(SeedResult.REPAIRED_PARTIAL);
        when(taxSeedService.seedForOrg(org2)).thenReturn(SeedResult.REPAIRED_PARTIAL);

        // org3: failure (tax throws)
        when(uomService.seedDefaultsForOrg(orgId3)).thenReturn(SeedResult.CREATED_NEW);
        when(accountService.seedFromTemplate(orgId3, "SERVICES")).thenReturn(SeedResult.CREATED_NEW);
        when(defaultAccountService.seedDefaultsForOrg(orgId3)).thenReturn(SeedResult.CREATED_NEW);
        when(taxSeedService.seedForOrg(org3)).thenThrow(new RuntimeException("fail"));

        BootstrapAllResult allResult = bootstrapService.bootstrapAll();

        assertEquals(3, allResult.totalOrgs());
        assertEquals(1, allResult.succeeded());
        assertEquals(1, allResult.repaired());
        assertEquals(1, allResult.failed());
        assertEquals(3, allResult.results().size());
    }

    @Test
    void bootstrap_repairedPartial_reportedCorrectly() {
        when(uomService.seedDefaultsForOrg(orgId)).thenReturn(SeedResult.ALREADY_EXISTS);
        when(accountService.seedFromTemplate(orgId, "TRADING")).thenReturn(SeedResult.ALREADY_EXISTS);
        when(defaultAccountService.seedDefaultsForOrg(orgId)).thenReturn(SeedResult.REPAIRED_PARTIAL);
        when(taxSeedService.seedForOrg(org)).thenReturn(SeedResult.REPAIRED_PARTIAL);

        BootstrapResult result = bootstrapService.bootstrap(org);

        assertTrue(result.allSucceeded());
        assertEquals(SeedResult.REPAIRED_PARTIAL, result.defaultAccounts().result());
        assertEquals(SeedResult.REPAIRED_PARTIAL, result.taxConfig().result());
        assertTrue(result.summary().contains("REPAIRED_PARTIAL"));
    }
}
