package com.katasticho.erp.pos.service;

import com.katasticho.erp.accounting.entity.JournalEntry;
import com.katasticho.erp.accounting.service.JournalService;
import com.katasticho.erp.audit.AuditService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.inventory.service.InventoryService;
import com.katasticho.erp.pos.entity.PaymentMode;
import com.katasticho.erp.pos.entity.SalesReceipt;
import com.katasticho.erp.pos.entity.SalesReceiptLine;
import com.katasticho.erp.pos.repository.SalesReceiptRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

/**
 * Unit tests for {@link SalesReceiptService#voidReceipt}: a POS return reverses
 * the journal, restocks each SALE movement, flips the row to RETURNED, and is
 * idempotent. Only the four collaborators the method touches are mocked; the
 * other constructor deps are left null by {@code @InjectMocks} (never invoked
 * because the test receipt's lines carry no item/batch/contact ids, so the
 * response mapping makes zero repository calls).
 */
@ExtendWith(MockitoExtension.class)
class SalesReceiptReturnTest {

    @Mock private SalesReceiptRepository receiptRepository;
    @Mock private JournalService journalService;
    @Mock private InventoryService inventoryService;
    @Mock private AuditService auditService;

    @InjectMocks private SalesReceiptService service;

    private final UUID orgId = UUID.randomUUID();
    private final UUID userId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(userId);
        // voidReceipt now uses the pessimistic-locked finder — delegate it to the
        // plain finder so per-test stubs on the latter flow through.
        lenient().when(receiptRepository.findByIdAndOrgIdForUpdate(any(), any()))
                .thenAnswer(inv -> receiptRepository
                        .findByIdAndOrgIdAndIsDeletedFalse(inv.getArgument(0), inv.getArgument(1)));
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    /** A COMPLETED receipt with one line per supplied movement id (null id = non-inventory line). */
    private SalesReceipt completedReceipt(UUID journalEntryId, UUID... movementIds) {
        SalesReceipt r = SalesReceipt.builder()
                .receiptNumber("SR-2026-000001")
                .receiptDate(LocalDate.now())
                .paymentMode(PaymentMode.CASH)
                .status("COMPLETED")
                .journalEntryId(journalEntryId)
                .build();
        r.setOrgId(orgId);
        int ln = 1;
        for (UUID mid : movementIds) {
            r.getLines().add(SalesReceiptLine.builder()
                    .lineNumber(ln++)
                    .stockMovementId(mid)
                    .mrp(BigDecimal.TEN)
                    .rate(BigDecimal.TEN)
                    .quantity(BigDecimal.ONE)
                    .build());
        }
        return r;
    }

    @Test
    void returnReversesJournalRestocksAndFlipsStatus() {
        UUID rid = UUID.randomUUID();
        UUID jId = UUID.randomUUID();
        UUID m1 = UUID.randomUUID();
        // second line has no stock movement (non-inventory item) -> must be skipped
        SalesReceipt receipt = completedReceipt(jId, m1, null);
        when(receiptRepository.findByIdAndOrgIdAndIsDeletedFalse(rid, orgId))
                .thenReturn(Optional.of(receipt));
        JournalEntry reversal = mock(JournalEntry.class);
        UUID jrId = UUID.randomUUID();
        when(reversal.getId()).thenReturn(jrId);
        when(journalService.reverseEntry(jId)).thenReturn(reversal);

        service.voidReceipt(rid, "customer returned goods");

        verify(journalService).reverseEntry(jId);
        verify(inventoryService).reverseMovement(eq(m1), any());
        verify(inventoryService, times(1)).reverseMovement(any(), any());
        verify(receiptRepository).save(receipt);
        assertEquals("RETURNED", receipt.getStatus());
        assertEquals("customer returned goods", receipt.getReturnReason());
        assertEquals(userId, receipt.getReturnedBy());
        assertEquals(jrId, receipt.getReversalJournalEntryId());
        assertNotNull(receipt.getReturnedAt());
    }

    @Test
    void doubleReturnThrowsAndDoesNotReverseAgain() {
        UUID rid = UUID.randomUUID();
        SalesReceipt receipt = completedReceipt(UUID.randomUUID(), UUID.randomUUID());
        receipt.setStatus("RETURNED");
        when(receiptRepository.findByIdAndOrgIdAndIsDeletedFalse(rid, orgId))
                .thenReturn(Optional.of(receipt));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.voidReceipt(rid, "again"));
        assertEquals("SR_ALREADY_RETURNED", ex.getErrorCode());
        verify(journalService, never()).reverseEntry(any());
        verify(inventoryService, never()).reverseMovement(any(), any());
        verify(receiptRepository, never()).save(any());
    }

    @Test
    void returnWithoutJournalStillRestocks() {
        UUID rid = UUID.randomUUID();
        UUID m1 = UUID.randomUUID();
        SalesReceipt receipt = completedReceipt(null, m1); // no journal entry
        when(receiptRepository.findByIdAndOrgIdAndIsDeletedFalse(rid, orgId))
                .thenReturn(Optional.of(receipt));

        service.voidReceipt(rid, null);

        verify(journalService, never()).reverseEntry(any());
        verify(inventoryService).reverseMovement(eq(m1), any());
        assertEquals("RETURNED", receipt.getStatus());
        assertNull(receipt.getReversalJournalEntryId());
    }
}
