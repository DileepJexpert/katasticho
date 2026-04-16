package com.katasticho.erp.tax;

import com.katasticho.erp.accounting.entity.Account;
import com.katasticho.erp.accounting.repository.AccountRepository;
import com.katasticho.erp.tax.entity.TaxGroup;
import com.katasticho.erp.tax.entity.TaxGroupRate;
import com.katasticho.erp.tax.entity.TaxRate;
import com.katasticho.erp.tax.repository.TaxGroupRateRepository;
import com.katasticho.erp.tax.repository.TaxGroupRepository;
import com.katasticho.erp.tax.repository.TaxRateRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

/**
 * Tests GenericTaxEngine — the database-driven tax engine that
 * replaced IndiaGSTEngine.
 */
@ExtendWith(MockitoExtension.class)
class IndiaGSTEngineTest {

    @Mock private TaxGroupRepository groupRepository;
    @Mock private TaxGroupRateRepository groupRateRepository;
    @Mock private TaxRateRepository rateRepository;
    @Mock private AccountRepository accountRepository;

    private GenericTaxEngine engine;
    private UUID orgId;

    @BeforeEach
    void setUp() {
        engine = new GenericTaxEngine(groupRepository, groupRateRepository, rateRepository, accountRepository);
        orgId = UUID.randomUUID();
    }

    @Test
    void shouldCalculateCgstSgstForIntraState() {
        UUID groupId = UUID.randomUUID();
        UUID cgstRateId = UUID.randomUUID();
        UUID sgstRateId = UUID.randomUUID();
        UUID cgstAccountId = UUID.randomUUID();
        UUID sgstAccountId = UUID.randomUUID();

        when(groupRateRepository.findByTaxGroupId(groupId)).thenReturn(List.of(
                TaxGroupRate.builder().taxGroupId(groupId).taxRateId(cgstRateId).build(),
                TaxGroupRate.builder().taxGroupId(groupId).taxRateId(sgstRateId).build()));

        TaxRate cgst = TaxRate.builder().orgId(orgId).name("CGST 9%").rateCode("CGST")
                .percentage(new BigDecimal("9.00")).taxType("BOTH")
                .glOutputAccountId(cgstAccountId).glInputAccountId(UUID.randomUUID()).build();
        cgst.setId(cgstRateId);
        when(rateRepository.findById(cgstRateId)).thenReturn(Optional.of(cgst));

        TaxRate sgst = TaxRate.builder().orgId(orgId).name("SGST 9%").rateCode("SGST")
                .percentage(new BigDecimal("9.00")).taxType("BOTH")
                .glOutputAccountId(sgstAccountId).glInputAccountId(UUID.randomUUID()).build();
        sgst.setId(sgstRateId);
        when(rateRepository.findById(sgstRateId)).thenReturn(Optional.of(sgst));

        Account cgstAccount = Account.builder().code("2020").name("CGST Payable").build();
        when(accountRepository.findById(cgstAccountId)).thenReturn(Optional.of(cgstAccount));
        Account sgstAccount = Account.builder().code("2021").name("SGST Payable").build();
        when(accountRepository.findById(sgstAccountId)).thenReturn(Optional.of(sgstAccount));

        TaxEngine.TaxCalculationResult result = engine.calculate(
                orgId, groupId, new BigDecimal("10000"), TaxEngine.TransactionType.SALE);

        assertEquals(2, result.components().size());
        assertEquals("CGST", result.components().get(0).rateCode());
        assertEquals("SGST", result.components().get(1).rateCode());
        assertEquals(new BigDecimal("9.00"), result.components().get(0).percentage());
        assertEquals(new BigDecimal("900.00"), result.components().get(0).amount());
        assertEquals(new BigDecimal("900.00"), result.components().get(1).amount());
        assertEquals(new BigDecimal("1800.00"), result.totalTaxAmount());
        assertEquals("2020", result.components().get(0).glAccountCode());
        assertEquals("2021", result.components().get(1).glAccountCode());
    }

    @Test
    void shouldCalculateIgstForInterState() {
        UUID groupId = UUID.randomUUID();
        UUID igstRateId = UUID.randomUUID();
        UUID igstAccountId = UUID.randomUUID();

        when(groupRateRepository.findByTaxGroupId(groupId)).thenReturn(List.of(
                TaxGroupRate.builder().taxGroupId(groupId).taxRateId(igstRateId).build()));

        TaxRate igst = TaxRate.builder().orgId(orgId).name("IGST 18%").rateCode("IGST")
                .percentage(new BigDecimal("18.00")).taxType("BOTH")
                .glOutputAccountId(igstAccountId).glInputAccountId(UUID.randomUUID()).build();
        igst.setId(igstRateId);
        when(rateRepository.findById(igstRateId)).thenReturn(Optional.of(igst));

        Account igstAccount = Account.builder().code("2022").name("IGST Payable").build();
        when(accountRepository.findById(igstAccountId)).thenReturn(Optional.of(igstAccount));

        TaxEngine.TaxCalculationResult result = engine.calculate(
                orgId, groupId, new BigDecimal("10000"), TaxEngine.TransactionType.SALE);

        assertEquals(1, result.components().size());
        assertEquals("IGST", result.components().get(0).rateCode());
        assertEquals(0, new BigDecimal("18").compareTo(result.components().get(0).percentage()));
        assertEquals(new BigDecimal("1800.00"), result.components().get(0).amount());
        assertEquals(new BigDecimal("1800.00"), result.totalTaxAmount());
    }

    @Test
    void shouldReturnZeroForNullTaxGroup() {
        TaxEngine.TaxCalculationResult result = engine.calculate(
                orgId, null, new BigDecimal("5000"), TaxEngine.TransactionType.SALE);

        assertTrue(result.components().isEmpty());
        assertEquals(BigDecimal.ZERO, result.totalTaxAmount());
    }

    @Test
    void shouldReturnZeroForEmptyGroupRates() {
        UUID groupId = UUID.randomUUID();
        when(groupRateRepository.findByTaxGroupId(groupId)).thenReturn(List.of());

        TaxEngine.TaxCalculationResult result = engine.calculate(
                orgId, groupId, new BigDecimal("5000"), TaxEngine.TransactionType.SALE);

        assertTrue(result.components().isEmpty());
        assertEquals(BigDecimal.ZERO, result.totalTaxAmount());
    }

    @Test
    void shouldResolveIntraStateGstGroup() {
        UUID gstGroupId = UUID.randomUUID();
        TaxGroup gstGroup = TaxGroup.builder().orgId(orgId).name("GST 18%").build();
        gstGroup.setId(gstGroupId);

        when(groupRepository.findByOrgIdAndNameAndActiveTrue(orgId, "GST 18%"))
                .thenReturn(Optional.of(gstGroup));

        Optional<UUID> result = engine.resolveGroupId(orgId, new BigDecimal("18"), "MH", "MH");

        assertTrue(result.isPresent());
        assertEquals(gstGroupId, result.get());
    }
}
