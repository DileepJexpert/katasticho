package com.katasticho.erp.inventory.service;

import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.inventory.dto.DrugMasterImportResult;
import com.katasticho.erp.inventory.entity.DrugMaster;
import com.katasticho.erp.inventory.entity.ManufacturerMaster;
import com.katasticho.erp.inventory.entity.SaltMaster;
import com.katasticho.erp.inventory.repository.DrugMasterRepository;
import com.katasticho.erp.inventory.repository.ManufacturerMasterRepository;
import com.katasticho.erp.inventory.repository.SaltMasterRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.mock.web.MockMultipartFile;

import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class DrugMasterImportServiceTest {

    @Mock private DrugMasterRepository drugMasterRepository;
    @Mock private SaltMasterRepository saltMasterRepository;
    @Mock private ManufacturerMasterRepository manufacturerMasterRepository;

    private DrugMasterImportService service;

    @BeforeEach
    void setUp() {
        service = new DrugMasterImportService(
                drugMasterRepository, saltMasterRepository, manufacturerMasterRepository);
    }

    private MockMultipartFile csv(String content) {
        return new MockMultipartFile("file", "drugs.csv", "text/csv",
                content.getBytes(StandardCharsets.UTF_8));
    }

    private SaltMaster salt(String name) {
        SaltMaster s = new SaltMaster();
        s.setId(UUID.randomUUID());
        s.setName(name);
        return s;
    }

    @Test
    void importsRowsMapsFieldsLinksSaltAndCreatesManufacturer() {
        when(drugMasterRepository.findAllBrandNamesLower()).thenReturn(List.of());
        SaltMaster paracetamol = salt("Paracetamol");
        when(saltMasterRepository.findByNameIgnoreCaseIn(anyCollection()))
                .thenReturn(List.of(paracetamol));
        when(manufacturerMasterRepository.findByNameIgnoreCaseAndActiveTrue("Getz Pharma"))
                .thenReturn(Optional.empty());

        DrugMasterImportResult result = service.importCsv(csv("""
                brand_name,generic_name,salt_composition,manufacturer,hsn_code,gst_rate,drug_schedule,dosage_form,pack_size,mrp,prescription_required
                Febrol 500,Paracetamol,Paracetamol 500mg,Getz Pharma,3004,5,GENERAL,Tablet,10 Tablets,25.50,false
                "Combi, Plus",Paracetamol,"Paracetamol 325mg, Caffeine 30mg",Getz Pharma,,,H,Tablet,10 Tablets,,
                """), false);

        assertEquals(2, result.totalDataRows());
        assertEquals(2, result.imported());
        assertEquals(0, result.skippedDuplicates());
        assertEquals(0, result.errorCount());
        assertEquals(2, result.saltLinked());
        assertEquals(1, result.manufacturersCreated());

        ArgumentCaptor<List<DrugMaster>> captor = ArgumentCaptor.forClass(List.class);
        verify(drugMasterRepository).saveAll(captor.capture());
        List<DrugMaster> saved = captor.getValue();
        assertEquals(2, saved.size());

        DrugMaster first = saved.get(0);
        assertEquals("Febrol 500", first.getBrandName());
        assertEquals(paracetamol.getId(), first.getSaltId());
        assertEquals("3004", first.getHsnCode());
        assertEquals(0, new BigDecimal("5").compareTo(first.getGstRate()));
        assertEquals(0, new BigDecimal("25.50").compareTo(first.getMrp()));
        assertFalse(first.isPrescriptionRequired());
        assertTrue(first.isActive());

        // quoted comma fields survive; blank hsn/gst take defaults; blank rx
        // defaults from the schedule (H -> prescription required)
        DrugMaster second = saved.get(1);
        assertEquals("Combi, Plus", second.getBrandName());
        assertEquals("Paracetamol 325mg, Caffeine 30mg", second.getSaltComposition());
        assertEquals("3004", second.getHsnCode());
        assertEquals(0, new BigDecimal("5").compareTo(second.getGstRate()));
        assertNull(second.getMrp());
        assertEquals("H", second.getDrugSchedule());
        assertTrue(second.isPrescriptionRequired());

        ArgumentCaptor<ManufacturerMaster> mfg = ArgumentCaptor.forClass(ManufacturerMaster.class);
        verify(manufacturerMasterRepository, times(1)).save(mfg.capture());
        assertEquals("Getz Pharma", mfg.getValue().getName());
    }

    @Test
    void skipsDuplicatesAgainstDbAndWithinFile() {
        when(drugMasterRepository.findAllBrandNamesLower()).thenReturn(List.of("dolo 650"));
        when(saltMasterRepository.findByNameIgnoreCaseIn(anyCollection())).thenReturn(List.of());

        DrugMasterImportResult result = service.importCsv(csv("""
                brand_name,generic_name,manufacturer
                DOLO 650,Paracetamol,Micro Labs
                Fresh Brand,Paracetamol,Micro Labs
                fresh brand,Paracetamol,Micro Labs
                """), false);

        assertEquals(1, result.imported());
        assertEquals(2, result.skippedDuplicates());

        ArgumentCaptor<List<DrugMaster>> captor = ArgumentCaptor.forClass(List.class);
        verify(drugMasterRepository).saveAll(captor.capture());
        assertEquals(1, captor.getValue().size());
        assertEquals("Fresh Brand", captor.getValue().get(0).getBrandName());
    }

    @Test
    void dryRunParsesButSavesNothing() {
        when(drugMasterRepository.findAllBrandNamesLower()).thenReturn(List.of());
        when(saltMasterRepository.findByNameIgnoreCaseIn(anyCollection())).thenReturn(List.of());
        when(manufacturerMasterRepository.findByNameIgnoreCaseAndActiveTrue("New Co"))
                .thenReturn(Optional.empty());

        DrugMasterImportResult result = service.importCsv(csv("""
                brand_name,generic_name,manufacturer
                Dry Brand,Paracetamol,New Co
                """), true);

        assertTrue(result.dryRun());
        assertEquals(1, result.imported());
        assertEquals(1, result.manufacturersCreated());
        verify(drugMasterRepository, never()).saveAll(anyList());
        verify(manufacturerMasterRepository, never()).save(any());
    }

    @Test
    void collectsRowErrorsAndStillImportsGoodRows() {
        when(drugMasterRepository.findAllBrandNamesLower()).thenReturn(List.of());
        when(saltMasterRepository.findByNameIgnoreCaseIn(anyCollection())).thenReturn(List.of());
        when(manufacturerMasterRepository.findByNameIgnoreCaseAndActiveTrue(any()))
                .thenReturn(Optional.of(new ManufacturerMaster()));

        DrugMasterImportResult result = service.importCsv(csv("""
                brand_name,generic_name,manufacturer,mrp
                ,Paracetamol,Cipla,10
                Bad Price,Paracetamol,Cipla,abc
                Good Brand,Paracetamol,Cipla,42
                """), false);

        assertEquals(3, result.totalDataRows());
        assertEquals(1, result.imported());
        assertEquals(2, result.errorCount());
        assertEquals(2, result.errors().size());
        assertTrue(result.errors().get(0).contains("row 2"));
        assertTrue(result.errors().get(1).contains("invalid mrp"));

        ArgumentCaptor<List<DrugMaster>> captor = ArgumentCaptor.forClass(List.class);
        verify(drugMasterRepository).saveAll(captor.capture());
        assertEquals("Good Brand", captor.getValue().get(0).getBrandName());
    }

    @Test
    void normalizesScheduleSpellingsAndDefaultsPrescription() {
        assertEquals("H1", DrugMasterImportService.normalizeSchedule("Sch H1"));
        assertEquals("H1", DrugMasterImportService.normalizeSchedule("Schedule-H1"));
        assertEquals("H1", DrugMasterImportService.normalizeSchedule("h1"));
        assertEquals("H", DrugMasterImportService.normalizeSchedule("h"));
        assertEquals("X", DrugMasterImportService.normalizeSchedule("Schedule X"));
        assertEquals("NARCOTICS", DrugMasterImportService.normalizeSchedule("NDPS"));
        assertEquals("GENERAL", DrugMasterImportService.normalizeSchedule("OTC"));
        assertEquals("GENERAL", DrugMasterImportService.normalizeSchedule(null));
        assertEquals("GENERAL", DrugMasterImportService.normalizeSchedule("whatever"));

        when(drugMasterRepository.findAllBrandNamesLower()).thenReturn(List.of());

        DrugMasterImportResult result = service.importCsv(csv("""
                brand_name,schedule
                Rx Brand,Sch H1
                Otc Brand,
                """), false);
        assertEquals(2, result.imported());

        ArgumentCaptor<List<DrugMaster>> captor = ArgumentCaptor.forClass(List.class);
        verify(drugMasterRepository).saveAll(captor.capture());
        assertEquals("H1", captor.getValue().get(0).getDrugSchedule());
        assertTrue(captor.getValue().get(0).isPrescriptionRequired());
        assertEquals("GENERAL", captor.getValue().get(1).getDrugSchedule());
        assertFalse(captor.getValue().get(1).isPrescriptionRequired());
    }

    @Test
    void acceptsHeaderAliasesInAnyOrder() {
        when(drugMasterRepository.findAllBrandNamesLower()).thenReturn(List.of());
        when(saltMasterRepository.findByNameIgnoreCaseIn(anyCollection())).thenReturn(List.of());
        when(manufacturerMasterRepository.findByNameIgnoreCaseAndActiveTrue(any()))
                .thenReturn(Optional.of(new ManufacturerMaster()));

        DrugMasterImportResult result = service.importCsv(csv("""
                Company,Price,Brand,Generic,Pack
                GSK,99.00,Alias Brand,Paracetamol,10 Tab
                """), false);

        assertEquals(1, result.imported());
        ArgumentCaptor<List<DrugMaster>> captor = ArgumentCaptor.forClass(List.class);
        verify(drugMasterRepository).saveAll(captor.capture());
        DrugMaster saved = captor.getValue().get(0);
        assertEquals("Alias Brand", saved.getBrandName());
        assertEquals("GSK", saved.getManufacturer());
        assertEquals(0, new BigDecimal("99.00").compareTo(saved.getMrp()));
        assertEquals("10 Tab", saved.getPackSize());
    }

    @Test
    void rejectsCsvWithoutBrandColumnOrEmptyFile() {
        BusinessException noBrand = assertThrows(BusinessException.class,
                () -> service.importCsv(csv("generic_name,manufacturer\nParacetamol,Cipla\n"), false));
        assertEquals("DRUG_IMPORT_NO_BRAND_COLUMN", noBrand.getErrorCode());

        BusinessException empty = assertThrows(BusinessException.class,
                () -> service.importCsv(csv(""), false));
        assertEquals("DRUG_IMPORT_EMPTY", empty.getErrorCode());
    }
}
