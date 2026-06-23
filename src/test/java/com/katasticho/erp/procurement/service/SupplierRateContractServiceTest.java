package com.katasticho.erp.procurement.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.entity.ContactType;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.organisation.OrganisationRepository;
import com.katasticho.erp.procurement.dto.CreateSupplierRateContractRequest;
import com.katasticho.erp.procurement.dto.PurchaseOrderRequest;
import com.katasticho.erp.procurement.dto.PurchaseOrderResponse;
import com.katasticho.erp.procurement.dto.SupplierRateContractResponse;
import com.katasticho.erp.procurement.entity.Supplier;
import com.katasticho.erp.procurement.entity.SupplierRateContract;
import com.katasticho.erp.procurement.entity.SupplierRateContractLine;
import com.katasticho.erp.procurement.repository.PurchaseOrderLineRepository;
import com.katasticho.erp.procurement.repository.PurchaseOrderRepository;
import com.katasticho.erp.procurement.repository.StockReceiptLineRepository;
import com.katasticho.erp.procurement.repository.SupplierRateContractLineRepository;
import com.katasticho.erp.procurement.repository.SupplierRateContractRepository;
import com.katasticho.erp.procurement.repository.SupplierRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class SupplierRateContractServiceTest {

    private final SupplierRateContractRepository contractRepository =
            mock(SupplierRateContractRepository.class);
    private final SupplierRateContractLineRepository lineRepository =
            mock(SupplierRateContractLineRepository.class);
    private final ContactRepository contactRepository = mock(ContactRepository.class);
    private final SupplierRepository supplierRepository = mock(SupplierRepository.class);
    private final ItemRepository itemRepository = mock(ItemRepository.class);
    private final OrganisationRepository organisationRepository =
            mock(OrganisationRepository.class);

    private final Clock fixedClock =
            Clock.fixed(LocalDate.of(2026, 7, 1).atStartOfDay(ZoneId.systemDefault()).toInstant(),
                    ZoneId.systemDefault());

    private final SupplierRateContractService service = new SupplierRateContractService(
            contractRepository, lineRepository, contactRepository,
            supplierRepository, itemRepository, organisationRepository, fixedClock);

    private final UUID orgId = UUID.randomUUID();
    private final UUID userId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(userId);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    private Contact vendor(UUID id, String name) {
        Contact c = new Contact();
        c.setId(id);
        c.setOrgId(orgId);
        c.setDisplayName(name);
        c.setContactType(ContactType.VENDOR);
        return c;
    }

    private Item itemStub(UUID id) {
        Item i = new Item();
        i.setId(id);
        i.setOrgId(orgId);
        i.setName("Item-" + id.toString().substring(0, 4));
        return i;
    }

    private SupplierRateContract draft(UUID id, UUID supplierContactId) {
        SupplierRateContract c = SupplierRateContract.builder()
                .contractNumber("SRC-2026-00001")
                .supplierContactId(supplierContactId)
                .status("DRAFT")
                .validFrom(LocalDate.of(2026, 7, 1))
                .currency("INR")
                .build();
        c.setId(id);
        c.setOrgId(orgId);
        return c;
    }

    // ── 1. Create ──
    @Test
    void createDraftsHeaderAndAutoNumbers() {
        UUID supplierContact = UUID.randomUUID();
        UUID itemId = UUID.randomUUID();
        when(contactRepository.findByIdAndOrgIdAndIsDeletedFalse(supplierContact, orgId))
                .thenReturn(Optional.of(vendor(supplierContact, "ACME")));
        when(itemRepository.findByIdAndOrgIdAndIsDeletedFalse(itemId, orgId))
                .thenReturn(Optional.of(itemStub(itemId)));
        when(contractRepository.countByOrgIdAndIsDeletedFalse(orgId)).thenReturn(0L);
        when(contractRepository.save(any(SupplierRateContract.class))).thenAnswer(inv -> {
            SupplierRateContract c = inv.getArgument(0);
            if (c.getId() == null) c.setId(UUID.randomUUID());
            return c;
        });

        SupplierRateContractResponse resp = service.create(new CreateSupplierRateContractRequest(
                supplierContact, LocalDate.of(2026, 7, 1), LocalDate.of(2027, 6, 30), null,
                List.of(new CreateSupplierRateContractRequest.LineRequest(
                        itemId, new BigDecimal("12.50"), null, null))));

        assertThat(resp.status()).isEqualTo("DRAFT");
        assertThat(resp.contractNumber()).startsWith("SRC-");
        assertThat(resp.lines()).hasSize(1);
        assertThat(resp.lines().get(0).unitPrice()).isEqualByComparingTo("12.50");
    }

    // ── 2. Activate happy path ──
    @Test
    void activateMovesDraftToActiveWithNoConflict() {
        UUID id = UUID.randomUUID();
        UUID supplierContact = UUID.randomUUID();
        UUID itemId = UUID.randomUUID();
        when(contractRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId))
                .thenReturn(Optional.of(draft(id, supplierContact)));

        SupplierRateContractLine line = SupplierRateContractLine.builder()
                .supplierRateContractId(id).itemId(itemId).unitPrice(new BigDecimal("10"))
                .minOrderQty(BigDecimal.ZERO).build();
        line.setOrgId(orgId);
        when(lineRepository.findBySupplierRateContractIdAndIsDeletedFalseOrderByCreatedAtAsc(id))
                .thenReturn(List.of(line));
        when(lineRepository.findActiveLine(orgId, supplierContact, itemId))
                .thenReturn(Optional.empty());
        when(contractRepository.save(any(SupplierRateContract.class)))
                .thenAnswer(inv -> inv.getArgument(0));

        SupplierRateContractResponse resp = service.activate(id);
        assertThat(resp.status()).isEqualTo("ACTIVE");
    }

    // ── 3. Activate w/ collision ──
    @Test
    void activateThrowsWhenSameSupplierItemAlreadyActive() {
        UUID id = UUID.randomUUID();
        UUID supplierContact = UUID.randomUUID();
        UUID itemId = UUID.randomUUID();
        when(contractRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId))
                .thenReturn(Optional.of(draft(id, supplierContact)));

        SupplierRateContractLine line = SupplierRateContractLine.builder()
                .supplierRateContractId(id).itemId(itemId).unitPrice(new BigDecimal("10")).build();
        line.setOrgId(orgId);
        when(lineRepository.findBySupplierRateContractIdAndIsDeletedFalseOrderByCreatedAtAsc(id))
                .thenReturn(List.of(line));

        SupplierRateContractLine existing = SupplierRateContractLine.builder()
                .supplierRateContractId(UUID.randomUUID()).itemId(itemId)
                .unitPrice(new BigDecimal("9")).build();
        when(lineRepository.findActiveLine(orgId, supplierContact, itemId))
                .thenReturn(Optional.of(existing));

        assertThatThrownBy(() -> service.activate(id))
                .isInstanceOf(BusinessException.class)
                .extracting(t -> ((BusinessException) t).getErrorCode())
                .isEqualTo("SRC_OVERLAPPING_ACTIVE");

        verify(contractRepository, never()).save(any());
    }

    // ── 4. Expire sweep ──
    @Test
    void sweepFlipsActiveRowsPastValidUntilToExpired() {
        UUID activeId = UUID.randomUUID();
        SupplierRateContract due = SupplierRateContract.builder()
                .contractNumber("SRC-2026-0001")
                .supplierContactId(UUID.randomUUID())
                .status("ACTIVE")
                .validFrom(LocalDate.of(2026, 1, 1))
                .validUntil(LocalDate.of(2026, 6, 30))
                .build();
        due.setId(activeId);
        due.setOrgId(orgId);

        when(contractRepository.findExpiringActive(orgId, LocalDate.of(2026, 7, 1)))
                .thenReturn(List.of(due));
        when(contractRepository.save(any(SupplierRateContract.class)))
                .thenAnswer(inv -> inv.getArgument(0));

        int n = service.sweepExpiredForOrg(orgId, LocalDate.of(2026, 7, 1));
        assertThat(n).isEqualTo(1);
        assertThat(due.getStatus()).isEqualTo("EXPIRED");
    }

    // ── 5. findActiveRate ──
    @Test
    void findActiveRateReturnsLinePriceWhenPresent() {
        UUID supplierContact = UUID.randomUUID();
        UUID itemId = UUID.randomUUID();
        SupplierRateContractLine line = SupplierRateContractLine.builder()
                .supplierRateContractId(UUID.randomUUID()).itemId(itemId)
                .unitPrice(new BigDecimal("47.25")).build();
        when(lineRepository.findActiveLine(orgId, supplierContact, itemId))
                .thenReturn(Optional.of(line));

        Optional<BigDecimal> rate = service.findActiveRate(supplierContact, itemId);
        assertThat(rate).hasValueSatisfying(v -> assertThat(v).isEqualByComparingTo("47.25"));

        when(lineRepository.findActiveLine(orgId, supplierContact, itemId))
                .thenReturn(Optional.empty());
        assertThat(service.findActiveRate(supplierContact, itemId)).isEmpty();
    }

    // ── 6. PO drafting picks up the active rate when caller omits price ──
    @Test
    void purchaseOrderServiceFallsBackToRateContractWhenUnitPriceNull() {
        // This test wires a real PurchaseOrderService instance and mocks the
        // rate-contract lookup. The order line carries unitPrice=null; the
        // PO line ends up priced at the contract rate (₹47.25).
        PurchaseOrderRepository poRepo = mock(PurchaseOrderRepository.class);
        PurchaseOrderLineRepository lineRepo = mock(PurchaseOrderLineRepository.class);
        StockReceiptLineRepository stockLineRepo = mock(StockReceiptLineRepository.class);
        SupplierRateContractService rateMock = mock(SupplierRateContractService.class);

        PurchaseOrderService poService = new PurchaseOrderService(
                poRepo, lineRepo, supplierRepository, itemRepository,
                stockLineRepo, contactRepository, null, null, rateMock);

        UUID supplierId = UUID.randomUUID();
        UUID itemId = UUID.randomUUID();
        when(supplierRepository.findByIdAndOrgIdAndIsDeletedFalse(supplierId, orgId))
                .thenReturn(Optional.of(Supplier.builder().name("ACME").build()));
        when(itemRepository.findByIdAndOrgIdAndIsDeletedFalse(itemId, orgId))
                .thenReturn(Optional.of(itemStub(itemId)));
        when(poRepo.countByOrgIdAndIsDeletedFalse(orgId)).thenReturn(0L);
        when(poRepo.save(any())).thenAnswer(inv -> {
            var po = (com.katasticho.erp.procurement.entity.PurchaseOrder) inv.getArgument(0);
            if (po.getId() == null) po.setId(UUID.randomUUID());
            return po;
        });
        when(rateMock.findActiveRateForSupplier(supplierId, itemId))
                .thenReturn(Optional.of(new BigDecimal("47.25")));

        PurchaseOrderRequest req = new PurchaseOrderRequest(
                supplierId, LocalDate.of(2026, 7, 1), null, null, null,
                List.of(new PurchaseOrderRequest.LineRequest(
                        itemId, "Test", new BigDecimal("10"), null, null)));

        PurchaseOrderResponse resp = poService.create(req);
        assertThat(resp.totalAmount()).isEqualByComparingTo("472.5000");

        ArgumentCaptor<List<com.katasticho.erp.procurement.entity.PurchaseOrderLine>> linesCap =
                ArgumentCaptor.forClass(List.class);
        verify(lineRepo).saveAll(linesCap.capture());
        assertThat(linesCap.getValue().get(0).getUnitPrice()).isEqualByComparingTo("47.25");
    }

    // ── 7. Explicit caller price overrides contract ──
    @Test
    void purchaseOrderServicePrefersExplicitPriceOverContract() {
        PurchaseOrderRepository poRepo = mock(PurchaseOrderRepository.class);
        PurchaseOrderLineRepository lineRepo = mock(PurchaseOrderLineRepository.class);
        StockReceiptLineRepository stockLineRepo = mock(StockReceiptLineRepository.class);
        SupplierRateContractService rateMock = mock(SupplierRateContractService.class);

        PurchaseOrderService poService = new PurchaseOrderService(
                poRepo, lineRepo, supplierRepository, itemRepository,
                stockLineRepo, contactRepository, null, null, rateMock);

        UUID supplierId = UUID.randomUUID();
        UUID itemId = UUID.randomUUID();
        when(supplierRepository.findByIdAndOrgIdAndIsDeletedFalse(supplierId, orgId))
                .thenReturn(Optional.of(Supplier.builder().name("ACME").build()));
        when(itemRepository.findByIdAndOrgIdAndIsDeletedFalse(itemId, orgId))
                .thenReturn(Optional.of(itemStub(itemId)));
        when(poRepo.countByOrgIdAndIsDeletedFalse(orgId)).thenReturn(0L);
        when(poRepo.save(any())).thenAnswer(inv -> {
            var po = (com.katasticho.erp.procurement.entity.PurchaseOrder) inv.getArgument(0);
            if (po.getId() == null) po.setId(UUID.randomUUID());
            return po;
        });
        // Rate mock would say 47.25, but explicit price wins.
        when(rateMock.findActiveRateForSupplier(any(), any()))
                .thenReturn(Optional.of(new BigDecimal("47.25")));

        PurchaseOrderRequest req = new PurchaseOrderRequest(
                supplierId, LocalDate.of(2026, 7, 1), null, null, null,
                List.of(new PurchaseOrderRequest.LineRequest(
                        itemId, "Test", new BigDecimal("10"),
                        new BigDecimal("100.00"), null)));

        poService.create(req);

        ArgumentCaptor<List<com.katasticho.erp.procurement.entity.PurchaseOrderLine>> linesCap =
                ArgumentCaptor.forClass(List.class);
        verify(lineRepo).saveAll(linesCap.capture());
        assertThat(linesCap.getValue().get(0).getUnitPrice()).isEqualByComparingTo("100.00");
        // Rate service never consulted because the caller supplied a price.
        verify(rateMock, never()).findActiveRateForSupplier(any(), any());
    }
}
