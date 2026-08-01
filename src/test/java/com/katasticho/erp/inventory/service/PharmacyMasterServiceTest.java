package com.katasticho.erp.inventory.service;

import com.katasticho.erp.common.module.ModuleAccessService;
import com.katasticho.erp.common.service.BusinessContextService;
import com.katasticho.erp.inventory.entity.HsnGstMaster;
import com.katasticho.erp.inventory.repository.*;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.Clock;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.doNothing;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class PharmacyMasterServiceTest {

    @Mock private BusinessContextService businessContextService;
    @Mock private ModuleAccessService moduleAccessService;
    @Mock private ManufacturerMasterRepository manufacturerRepository;
    @Mock private HsnGstMasterRepository hsnRepository;
    @Mock private HsnGstRateHistoryRepository rateHistoryRepository;
    @Mock private RackLocationRepository rackRepository;
    @Mock private GenericSubstitutionRepository substitutionRepository;
    @Mock private DrugInteractionRepository interactionRepository;
    @Mock private DrugMasterRepository drugMasterRepository;
    @Mock private SaltMasterRepository saltMasterRepository;
    @Mock private WarehouseRepository warehouseRepository;

    private PharmacyMasterService service;

    @BeforeEach
    void setUp() {
        service = new PharmacyMasterService(
                businessContextService,
                moduleAccessService,
                manufacturerRepository,
                hsnRepository,
                rateHistoryRepository,
                rackRepository,
                substitutionRepository,
                interactionRepository,
                drugMasterRepository,
                saltMasterRepository,
                warehouseRepository,
                Clock.systemUTC());
    }

    @Test
    void searchHsn_ranksPreferredCategoriesFirst() {
        HsnGstMaster pharma = new HsnGstMaster();
        pharma.setHsnCode("3004");
        pharma.setDescription("Medicaments for therapeutic use");
        pharma.setCategory("PHARMA");
        pharma.setGstRate(new BigDecimal("5.00"));

        HsnGstMaster grocery = new HsnGstMaster();
        grocery.setHsnCode("1701");
        grocery.setDescription("Cane or beet sugar, refined");
        grocery.setCategory("GROCERY");
        grocery.setGstRate(new BigDecimal("5.00"));

        when(businessContextService.preferredHsnCategories()).thenReturn(List.of("GROCERY", "FOOD_BEVERAGE"));
        when(hsnRepository.search(anyString(), any())).thenReturn(List.of(pharma, grocery));

        var results = service.searchHsn("sugar", 10);

        assertEquals("1701", results.get(0).hsnCode());
        assertEquals("3004", results.get(1).hsnCode());
    }

    @Test
    void searchManufacturers_requiresPharmaModule() {
        doNothing().when(moduleAccessService).requireEnabled("PHARMA");
        when(manufacturerRepository.findByNameContainingIgnoreCaseAndActiveTrueOrderByNameAsc(anyString(), any()))
                .thenReturn(List.of());

        service.searchManufacturers("cipla", 10);

        verify(moduleAccessService).requireEnabled("PHARMA");
    }
}
