package com.katasticho.erp.inventory.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.common.service.DocumentPdfService;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.entity.StockBatch;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.inventory.repository.StockBatchRepository;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDate;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class FoodLabelPdfServiceTest {

    @Mock private ItemRepository itemRepository;
    @Mock private StockBatchRepository stockBatchRepository;
    @Mock private OrganisationRepository organisationRepository;
    @Mock private DocumentPdfService pdfService;

    private FoodLabelPdfService service;

    private final UUID orgId = UUID.randomUUID();
    private final UUID itemId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        service = new FoodLabelPdfService(itemRepository, stockBatchRepository,
                organisationRepository, pdfService);
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(UUID.randomUUID());
    }

    @AfterEach
    void tearDown() { TenantContext.clear(); }

    private Item item(String name, String veg, List<String> allergens,
                      String dateMarking, Integer shelfLifeDays,
                      String fssaiLicense) {
        Item i = Item.builder()
                .sku("FOOD-1")
                .name(name)
                .unitOfMeasure("250g")
                .composition("Wheat, sugar, milk solids, edible vegetable oils")
                .vegClassification(veg)
                .allergens(allergens)
                .dateMarkingType(dateMarking)
                .shelfLifeDays(shelfLifeDays)
                .fssaiLicense(fssaiLicense)
                .build();
        i.setId(itemId);
        i.setOrgId(orgId);
        return i;
    }

    private Organisation org() {
        Organisation o = Organisation.builder()
                .name("Acme Foods Pvt Ltd")
                .addressLine1("Plot 42, MIDC")
                .addressLine2("Pune 411019")
                .gstin("27AAAAA0000A1Z5")
                .fssaiLicense("10012345678901")
                .build();
        o.setId(orgId);
        return o;
    }

    @Test
    void generateLabel_compliantItem_renderHasAllMandatoryFssaiSections() {
        Map<String, Object> nutrition = new LinkedHashMap<>();
        nutrition.put("calories_kcal", 250);
        nutrition.put("protein_g", 8);
        nutrition.put("fat_g", 12);

        Item it = item("Choco Wafers", "VEGETARIAN",
                List.of("MILK", "WHEAT_GLUTEN"), "BEST_BEFORE", 180,
                "10012345678901");
        it.setNutritionalInfo(nutrition);

        when(itemRepository.findByIdAndOrgIdAndIsDeletedFalse(itemId, orgId))
                .thenReturn(Optional.of(it));
        when(organisationRepository.findById(orgId)).thenReturn(Optional.of(org()));
        when(pdfService.render(any())).thenReturn(new byte[]{1, 2, 3});

        byte[] pdf = service.generateLabel(itemId, null);
        assertArrayEquals(new byte[]{1, 2, 3}, pdf);

        ArgumentCaptor<String> html = ArgumentCaptor.forClass(String.class);
        org.mockito.Mockito.verify(pdfService).render(html.capture());
        String body = html.getValue();

        // Product header
        assertTrue(body.contains("Choco Wafers"));
        // Veg dot/label (FSSAI 2.2.2.4)
        assertTrue(body.contains("Vegetarian"));
        // Allergen "Contains:" line (the regulator's headline check)
        assertTrue(body.contains("Contains:"));
        assertTrue(body.contains("Milk"));
        assertTrue(body.contains("Wheat / Gluten"));
        // Nutritional info table renders pretty keys
        assertTrue(body.contains("Energy (kcal)"));
        assertTrue(body.contains("Protein (g)"));
        // Date marking + shelf life
        assertTrue(body.contains("BEST BEFORE") || body.contains("Best Before"));
        // FBO license
        assertTrue(body.contains("10012345678901"));
        // Manufacturer + address
        assertTrue(body.contains("Acme Foods Pvt Ltd"));
        assertTrue(body.contains("Plot 42, MIDC"));
        assertTrue(body.contains("Pune 411019"));
    }

    @Test
    void generateLabel_withBatch_carriesBatchNumberAndExpiry() {
        UUID batchId = UUID.randomUUID();
        StockBatch batch = StockBatch.builder()
                .itemId(itemId)
                .batchNumber("CHW-2026-04")
                .manufacturingDate(LocalDate.of(2026, 4, 1))
                .expiryDate(LocalDate.of(2026, 10, 1))
                .build();
        batch.setId(batchId);
        batch.setOrgId(orgId);

        Item it = item("Choco Wafers", "VEGETARIAN", List.of("MILK"),
                "BEST_BEFORE", 180, "10012345678901");

        when(itemRepository.findByIdAndOrgIdAndIsDeletedFalse(itemId, orgId))
                .thenReturn(Optional.of(it));
        when(stockBatchRepository.findByIdAndOrgIdAndIsDeletedFalse(batchId, orgId))
                .thenReturn(Optional.of(batch));
        when(organisationRepository.findById(orgId)).thenReturn(Optional.of(org()));
        when(pdfService.render(any())).thenReturn(new byte[]{0});

        service.generateLabel(itemId, batchId);

        ArgumentCaptor<String> html = ArgumentCaptor.forClass(String.class);
        org.mockito.Mockito.verify(pdfService).render(html.capture());
        String body = html.getValue();
        assertTrue(body.contains("CHW-2026-04"));
        assertTrue(body.contains("01 Apr 2026"));    // MFG
        assertTrue(body.contains("01 Oct 2026"));    // Expiry
    }

    @Test
    void generateLabel_batchFromDifferentItem_throws() {
        UUID batchId = UUID.randomUUID();
        UUID otherItem = UUID.randomUUID();
        StockBatch batch = StockBatch.builder().itemId(otherItem).batchNumber("X").build();
        batch.setId(batchId);
        batch.setOrgId(orgId);

        when(itemRepository.findByIdAndOrgIdAndIsDeletedFalse(itemId, orgId))
                .thenReturn(Optional.of(item("X", "VEGETARIAN", List.of(), "BEST_BEFORE", 30, "10012345678901")));
        when(organisationRepository.findById(orgId)).thenReturn(Optional.of(org()));
        when(stockBatchRepository.findByIdAndOrgIdAndIsDeletedFalse(batchId, orgId))
                .thenReturn(Optional.of(batch));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.generateLabel(itemId, batchId));
        assertEquals("FSSAI_LABEL_BATCH_ITEM_MISMATCH", ex.getErrorCode());
    }

    @Test
    void generateLabel_missingDeclarations_rendersFssaiRequiredWarnings() {
        Item bare = item("Mystery Snack", null, null, null, null, null);
        when(itemRepository.findByIdAndOrgIdAndIsDeletedFalse(itemId, orgId))
                .thenReturn(Optional.of(bare));
        when(organisationRepository.findById(orgId))
                .thenReturn(Optional.of(Organisation.builder().name("Plant").build()));
        when(pdfService.render(any())).thenReturn(new byte[]{0});

        service.generateLabel(itemId, null);

        ArgumentCaptor<String> html = ArgumentCaptor.forClass(String.class);
        org.mockito.Mockito.verify(pdfService).render(html.capture());
        String body = html.getValue();

        // Auditor sees explicit "Not declared — required by …" warnings
        // rather than blank sections (silent omissions are worse than
        // visible non-compliance, which prompts the fix).
        assertTrue(body.contains("Veg classification not declared"));
        assertTrue(body.contains("required by FSSAI 2.2.2.4"));
        assertTrue(body.contains("required by FSSAI 2.2.2.1"));
        assertTrue(body.contains("Regulation 2.2.2.7"));
    }

    @Test
    void generateLabel_emptyAllergensList_rendersExplicitNoneMessage() {
        Item it = item("Plain Toast", "VEGETARIAN", List.of(),
                "BEST_BEFORE", 30, "10012345678901");
        when(itemRepository.findByIdAndOrgIdAndIsDeletedFalse(itemId, orgId))
                .thenReturn(Optional.of(it));
        when(organisationRepository.findById(orgId)).thenReturn(Optional.of(org()));
        when(pdfService.render(any())).thenReturn(new byte[]{0});

        service.generateLabel(itemId, null);

        ArgumentCaptor<String> html = ArgumentCaptor.forClass(String.class);
        org.mockito.Mockito.verify(pdfService).render(html.capture());
        String body = html.getValue();
        // The empty list means "explicitly cleared, none of the majors"
        // and is FSSAI-compliant — distinct from "not declared".
        assertTrue(body.contains("None of the major allergens"));
        assertFalse(body.contains("required by FSSAI 2.2.2.4"));
    }

    @Test
    void generateLabel_escapesUserSuppliedStrings() {
        Item dodgy = item("<script>alert(1)</script>", "NON_VEGETARIAN",
                List.of("MILK"), "BEST_BEFORE", 60, "10012345678901");
        dodgy.setComposition("Bad & <chars>");
        when(itemRepository.findByIdAndOrgIdAndIsDeletedFalse(itemId, orgId))
                .thenReturn(Optional.of(dodgy));
        when(organisationRepository.findById(orgId)).thenReturn(Optional.of(org()));
        when(pdfService.render(any())).thenReturn(new byte[]{0});

        service.generateLabel(itemId, null);

        ArgumentCaptor<String> html = ArgumentCaptor.forClass(String.class);
        org.mockito.Mockito.verify(pdfService).render(html.capture());
        String body = html.getValue();
        assertFalse(body.contains("<script>alert(1)</script>"));
        assertTrue(body.contains("&lt;script&gt;alert(1)&lt;/script&gt;"));
        assertTrue(body.contains("Bad &amp; &lt;chars&gt;"));
    }

    @Test
    void generateLabel_useshelflifeIfNoExplicitExpiry() {
        UUID batchId = UUID.randomUUID();
        // Batch has MFG date but no explicit expiry — service should
        // compute MFG + shelf_life as the date-marking row.
        StockBatch batch = StockBatch.builder()
                .itemId(itemId).batchNumber("X-1")
                .manufacturingDate(LocalDate.of(2026, 1, 1))
                .expiryDate(null)
                .build();
        batch.setId(batchId);
        batch.setOrgId(orgId);

        Item it = item("Cookies", "VEGETARIAN", List.of(), "BEST_BEFORE", 90,
                "10012345678901");
        when(itemRepository.findByIdAndOrgIdAndIsDeletedFalse(itemId, orgId))
                .thenReturn(Optional.of(it));
        when(stockBatchRepository.findByIdAndOrgIdAndIsDeletedFalse(batchId, orgId))
                .thenReturn(Optional.of(batch));
        when(organisationRepository.findById(orgId)).thenReturn(Optional.of(org()));
        when(pdfService.render(any())).thenReturn(new byte[]{0});

        service.generateLabel(itemId, batchId);

        ArgumentCaptor<String> html = ArgumentCaptor.forClass(String.class);
        org.mockito.Mockito.verify(pdfService).render(html.capture());
        // 01 Jan 2026 + 90 days = 01 Apr 2026
        assertTrue(html.getValue().contains("01 Apr 2026"));
    }

    @Test
    void filename_stripsReservedChars_andIncludesBatch() {
        Item it = item("Choco / Wafer?", "VEGETARIAN", List.of(),
                "BEST_BEFORE", 30, "10012345678901");
        StockBatch batch = StockBatch.builder().batchNumber("LOT/2026:04").build();

        assertEquals("label-Choco - Wafer-.pdf", FoodLabelPdfService.filename(it, null));
        assertEquals("label-Choco - Wafer--LOT-2026-04.pdf",
                FoodLabelPdfService.filename(it, batch));
    }
}
