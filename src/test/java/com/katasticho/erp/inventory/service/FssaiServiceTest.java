package com.katasticho.erp.inventory.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class FssaiServiceTest {

    @Mock private ItemRepository itemRepository;
    @Mock private OrganisationRepository organisationRepository;

    private FssaiService service;

    private final UUID orgId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        service = new FssaiService(itemRepository, organisationRepository);
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(UUID.randomUUID());
    }

    @AfterEach
    void tearDown() { TenantContext.clear(); }

    private Item item(UUID id, String name) {
        Item i = Item.builder().name(name).build();
        i.setId(id);
        i.setOrgId(orgId);
        return i;
    }

    @Test
    void updateItemFssai_normalisesAllergenCodesToUpperCase() {
        UUID id = UUID.randomUUID();
        when(itemRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId))
                .thenReturn(Optional.of(item(id, "Cookies")));
        when(itemRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        Item saved = service.updateItemFssai(id, new FssaiService.FssaiUpdateRequest(
                null, "VEGETARIAN",
                List.of("milk", "wheat_gluten", " soybeans"),
                Map.of("calories_kcal", 250),
                "BEST_BEFORE", 180));

        assertEquals(List.of("MILK", "WHEAT_GLUTEN", "SOYBEANS"), saved.getAllergens());
        assertEquals("VEGETARIAN", saved.getVegClassification());
        assertEquals("BEST_BEFORE", saved.getDateMarkingType());
        assertEquals(180, saved.getShelfLifeDays());
    }

    @Test
    void updateItemFssai_invalidLicense_throws() {
        UUID id = UUID.randomUUID();
        when(itemRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId))
                .thenReturn(Optional.of(item(id, "Cookies")));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.updateItemFssai(id, new FssaiService.FssaiUpdateRequest(
                        "12345", null, null, null, null, null)));
        assertEquals("FSSAI_INVALID_LICENSE", ex.getErrorCode());
    }

    @Test
    void updateItemFssai_acceptsValid14DigitLicense() {
        UUID id = UUID.randomUUID();
        when(itemRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId))
                .thenReturn(Optional.of(item(id, "Cookies")));
        when(itemRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        Item saved = service.updateItemFssai(id, new FssaiService.FssaiUpdateRequest(
                "10012345678901", null, null, null, null, null));

        assertEquals("10012345678901", saved.getFssaiLicense());
    }

    @Test
    void updateItemFssai_invalidVegClass_throws() {
        UUID id = UUID.randomUUID();
        when(itemRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId))
                .thenReturn(Optional.of(item(id, "Cookies")));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.updateItemFssai(id, new FssaiService.FssaiUpdateRequest(
                        null, "FLEXITARIAN", null, null, null, null)));
        assertEquals("FSSAI_INVALID_VEG_CLASS", ex.getErrorCode());
    }

    @Test
    void updateItemFssai_invalidDateMarking_throws() {
        UUID id = UUID.randomUUID();
        when(itemRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId))
                .thenReturn(Optional.of(item(id, "Cookies")));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.updateItemFssai(id, new FssaiService.FssaiUpdateRequest(
                        null, null, null, null, "SELL_BY", null)));
        assertEquals("FSSAI_INVALID_DATE_MARKING", ex.getErrorCode());
    }

    @Test
    void updateItemFssai_negativeShelfLife_throws() {
        UUID id = UUID.randomUUID();
        when(itemRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId))
                .thenReturn(Optional.of(item(id, "Cookies")));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.updateItemFssai(id, new FssaiService.FssaiUpdateRequest(
                        null, null, null, null, null, -7)));
        assertEquals("FSSAI_INVALID_SHELF_LIFE", ex.getErrorCode());
    }

    @Test
    void allergenExposureReport_returnsItemsContainingTheAllergen_caseInsensitive() {
        UUID milkyId = UUID.randomUUID();
        UUID milkyId2 = UUID.randomUUID();
        UUID nutFreeId = UUID.randomUUID();
        Item milky = item(milkyId, "Chocolate Bar");
        milky.setAllergens(List.of("MILK", "SOYBEANS"));
        Item nutty = item(milkyId2, "Peanut Cookies");
        nutty.setAllergens(List.of("PEANUTS", "WHEAT_GLUTEN", "MILK"));
        Item plain = item(nutFreeId, "Rice Crackers");
        plain.setAllergens(List.of("WHEAT_GLUTEN"));

        when(itemRepository.findByOrgIdAndIsDeletedFalseOrderByNameAsc(orgId))
                .thenReturn(List.of(milky, nutty, plain));

        // Lower-case input — normalised internally.
        List<Item> matches = service.allergenExposureReport("milk");
        assertEquals(2, matches.size());
        assertTrue(matches.stream().anyMatch(i -> i.getId().equals(milkyId)));
        assertTrue(matches.stream().anyMatch(i -> i.getId().equals(milkyId2)));
    }

    @Test
    void allergenExposureReport_unknownAllergen_returnsEmpty() {
        when(itemRepository.findByOrgIdAndIsDeletedFalseOrderByNameAsc(orgId))
                .thenReturn(List.of());

        assertTrue(service.allergenExposureReport("UNICORN_DUST").isEmpty());
    }

    @Test
    void allergenExposureReport_blankInput_throws() {
        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.allergenExposureReport(""));
        assertEquals("FSSAI_ALLERGEN_REQUIRED", ex.getErrorCode());
    }

    @Test
    void licenseRenewalReport_orgFboExpiringSoon_returnsOneOrganisationRow() {
        Organisation org = Organisation.builder().name("Plant").build();
        org.setId(orgId);
        org.setFssaiLicense("10012345678901");
        // Expires in 14 days → within a 60-day horizon.
        org.setFssaiLicenseExpiry(LocalDate.now().plusDays(14));
        when(organisationRepository.findById(orgId)).thenReturn(Optional.of(org));

        List<Map<String, Object>> rows = service.licenseRenewalReport(60);

        assertEquals(1, rows.size());
        assertEquals("ORGANISATION", rows.get(0).get("scope"));
        assertEquals("10012345678901", rows.get(0).get("license"));
        assertEquals(14L, rows.get(0).get("daysToExpiry"));
    }

    @Test
    void licenseRenewalReport_orgLicenseBeyondHorizon_returnsEmpty() {
        Organisation org = Organisation.builder().name("Plant").build();
        org.setId(orgId);
        org.setFssaiLicense("10012345678901");
        // Expires in 200 days → outside a 60-day horizon.
        org.setFssaiLicenseExpiry(LocalDate.now().plusDays(200));
        when(organisationRepository.findById(orgId)).thenReturn(Optional.of(org));

        List<Map<String, Object>> rows = service.licenseRenewalReport(60);

        assertTrue(rows.isEmpty());
    }

    @Test
    void majorAllergens_returnsCanonicalSortedList() {
        List<String> allergens = service.majorAllergens();

        // 14 standard allergens, sorted alphabetically.
        assertEquals(14, allergens.size());
        assertEquals("CELERY", allergens.get(0));
        assertTrue(allergens.contains("MILK"));
        assertTrue(allergens.contains("PEANUTS"));
        assertTrue(allergens.contains("WHEAT_GLUTEN"));
        // Sorted check:
        for (int i = 1; i < allergens.size(); i++) {
            assertTrue(allergens.get(i - 1).compareTo(allergens.get(i)) <= 0);
        }
    }
}
