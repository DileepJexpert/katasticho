package com.katasticho.erp.partnernetwork.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import com.katasticho.erp.partnernetwork.dto.*;
import com.katasticho.erp.partnernetwork.entity.*;
import com.katasticho.erp.partnernetwork.repository.*;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.*;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class PartnerNetworkServiceTest {

    @Mock private TradingPartnerRepository tradingPartnerRepo;
    @Mock private PublishedCatalogItemRepository catalogRepo;
    @Mock private NetworkOrderRepository orderRepo;
    @Mock private NetworkOrderLineRepository orderLineRepo;
    @Mock private NetworkOrderEventRepository eventRepo;
    @Mock private OrganisationRepository orgRepo;

    private PartnerNetworkService service;

    private final UUID orgA = UUID.randomUUID();
    private final UUID orgB = UUID.randomUUID();
    private final UUID userId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        service = new PartnerNetworkService(
                tradingPartnerRepo, catalogRepo, orderRepo, orderLineRepo, eventRepo, orgRepo);
        TenantContext.setCurrentOrgId(orgA);
        TenantContext.setCurrentUserId(userId);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    void requestPartnership_asBuyer_setsCorrectSellerBuyer() {
        when(orgRepo.findById(orgB)).thenReturn(Optional.of(new Organisation()));
        when(tradingPartnerRepo.findBySellerOrgIdAndBuyerOrgIdAndIsDeletedFalse(orgB, orgA)).thenReturn(Optional.empty());
        when(tradingPartnerRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        TradingPartnerRequest request = new TradingPartnerRequest(orgB, "BUYER", null, null, null, null);
        TradingPartner result = service.requestPartnership(request);

        assertEquals(orgB, result.getSellerOrgId());
        assertEquals(orgA, result.getBuyerOrgId());
        assertEquals("PENDING", result.getStatus());
        assertEquals(orgA, result.getRequestedByOrgId());
    }

    @Test
    void requestPartnership_asSeller_setsCorrectSellerBuyer() {
        when(orgRepo.findById(orgB)).thenReturn(Optional.of(new Organisation()));
        when(tradingPartnerRepo.findBySellerOrgIdAndBuyerOrgIdAndIsDeletedFalse(orgA, orgB)).thenReturn(Optional.empty());
        when(tradingPartnerRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        TradingPartnerRequest request = new TradingPartnerRequest(orgB, "SELLER", null, null, null, null);
        TradingPartner result = service.requestPartnership(request);

        assertEquals(orgA, result.getSellerOrgId());
        assertEquals(orgB, result.getBuyerOrgId());
    }

    @Test
    void requestPartnership_selfPartner_throws() {
        TradingPartnerRequest request = new TradingPartnerRequest(orgA, "BUYER", null, null, null, null);
        BusinessException ex = assertThrows(BusinessException.class, () -> service.requestPartnership(request));
        assertEquals("PN_SELF_PARTNER", ex.getErrorCode());
    }

    @Test
    void requestPartnership_duplicate_throws() {
        when(orgRepo.findById(orgB)).thenReturn(Optional.of(new Organisation()));
        TradingPartner existing = TradingPartner.builder().status("APPROVED").build();
        when(tradingPartnerRepo.findBySellerOrgIdAndBuyerOrgIdAndIsDeletedFalse(orgB, orgA))
                .thenReturn(Optional.of(existing));

        TradingPartnerRequest request = new TradingPartnerRequest(orgB, "BUYER", null, null, null, null);
        BusinessException ex = assertThrows(BusinessException.class, () -> service.requestPartnership(request));
        assertEquals("PN_DUPLICATE_PARTNER", ex.getErrorCode());
    }

    @Test
    void approvePartnership_byCounterparty_succeeds() {
        TenantContext.setCurrentOrgId(orgB);
        TradingPartner tp = TradingPartner.builder()
                .id(UUID.randomUUID()).sellerOrgId(orgA).buyerOrgId(orgB)
                .status("PENDING").requestedByOrgId(orgA).build();
        when(tradingPartnerRepo.findByIdAndIsDeletedFalse(tp.getId())).thenReturn(Optional.of(tp));
        when(tradingPartnerRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        TradingPartner result = service.approvePartnership(tp.getId());
        assertEquals("APPROVED", result.getStatus());
        assertNotNull(result.getApprovedAt());
    }

    @Test
    void approvePartnership_bySameOrg_throws() {
        TradingPartner tp = TradingPartner.builder()
                .id(UUID.randomUUID()).sellerOrgId(orgB).buyerOrgId(orgA)
                .status("PENDING").requestedByOrgId(orgA).build();
        when(tradingPartnerRepo.findByIdAndIsDeletedFalse(tp.getId())).thenReturn(Optional.of(tp));

        BusinessException ex = assertThrows(BusinessException.class, () -> service.approvePartnership(tp.getId()));
        assertEquals("PN_SELF_APPROVE", ex.getErrorCode());
    }

    @Test
    void placeOrder_withApprovedPartner_createsOrder() {
        UUID tpId = UUID.randomUUID();
        TradingPartner tp = TradingPartner.builder()
                .id(tpId).sellerOrgId(orgB).buyerOrgId(orgA).status("APPROVED").build();
        when(tradingPartnerRepo.findByIdAndIsDeletedFalse(tpId)).thenReturn(Optional.of(tp));
        when(orderRepo.findMaxOrderNumber(orgA)).thenReturn(0);
        when(orderRepo.save(any())).thenAnswer(inv -> {
            NetworkOrder o = inv.getArgument(0);
            o.setId(UUID.randomUUID());
            return o;
        });
        when(eventRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        PlaceNetworkOrderRequest request = new PlaceNetworkOrderRequest(
                tpId, null, "Test order",
                List.of(new PlaceNetworkOrderRequest.LineRequest(null, UUID.randomUUID(), BigDecimal.TEN, BigDecimal.valueOf(100)))
        );

        NetworkOrder result = service.placeOrder(request);
        assertEquals("PLACED", result.getStatus());
        assertEquals("NO-00001", result.getOrderNumber());
        assertEquals(orgA, result.getBuyerOrgId());
        assertEquals(orgB, result.getSellerOrgId());
        assertEquals(1, result.getLines().size());
        assertEquals(BigDecimal.valueOf(1000), result.getTotalAmount());
    }

    @Test
    void placeOrder_notBuyer_throws() {
        TenantContext.setCurrentOrgId(orgB);
        UUID tpId = UUID.randomUUID();
        TradingPartner tp = TradingPartner.builder()
                .id(tpId).sellerOrgId(orgB).buyerOrgId(orgA).status("APPROVED").build();
        when(tradingPartnerRepo.findByIdAndIsDeletedFalse(tpId)).thenReturn(Optional.of(tp));

        PlaceNetworkOrderRequest request = new PlaceNetworkOrderRequest(
                tpId, null, null,
                List.of(new PlaceNetworkOrderRequest.LineRequest(null, UUID.randomUUID(), BigDecimal.ONE, BigDecimal.TEN))
        );

        BusinessException ex = assertThrows(BusinessException.class, () -> service.placeOrder(request));
        assertEquals("PN_NOT_BUYER", ex.getErrorCode());
    }

    @Test
    void confirmOrder_bySeller_setsConfirmed() {
        TenantContext.setCurrentOrgId(orgB);
        UUID orderId = UUID.randomUUID();
        UUID lineId = UUID.randomUUID();

        NetworkOrderLine line = NetworkOrderLine.builder()
                .id(lineId).orderedQty(BigDecimal.TEN).status("PENDING").build();
        NetworkOrder order = NetworkOrder.builder()
                .id(orderId).buyerOrgId(orgA).sellerOrgId(orgB)
                .tradingPartnerId(UUID.randomUUID()).status("PLACED")
                .lines(new ArrayList<>(List.of(line))).build();
        line.setNetworkOrder(order);

        when(orderRepo.findByIdAndIsDeletedFalse(orderId)).thenReturn(Optional.of(order));
        when(orderRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));
        when(eventRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        ConfirmNetworkOrderRequest request = new ConfirmNetworkOrderRequest(
                "Will ship tomorrow",
                List.of(new ConfirmNetworkOrderRequest.LineConfirmation(lineId, BigDecimal.TEN, null, null))
        );

        NetworkOrder result = service.confirmOrder(orderId, request);
        assertEquals("CONFIRMED", result.getStatus());
        assertNotNull(result.getConfirmedAt());
        assertEquals("CONFIRMED", result.getLines().get(0).getStatus());
    }

    @Test
    void rejectOrder_bySeller_rejectsAllLines() {
        TenantContext.setCurrentOrgId(orgB);
        UUID orderId = UUID.randomUUID();

        NetworkOrderLine line = NetworkOrderLine.builder()
                .id(UUID.randomUUID()).orderedQty(BigDecimal.TEN).status("PENDING").build();
        NetworkOrder order = NetworkOrder.builder()
                .id(orderId).buyerOrgId(orgA).sellerOrgId(orgB)
                .tradingPartnerId(UUID.randomUUID()).status("PLACED")
                .lines(new ArrayList<>(List.of(line))).build();
        line.setNetworkOrder(order);

        when(orderRepo.findByIdAndIsDeletedFalse(orderId)).thenReturn(Optional.of(order));
        when(orderRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));
        when(eventRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        NetworkOrder result = service.rejectOrder(orderId, "Out of stock");
        assertEquals("REJECTED", result.getStatus());
        assertEquals("REJECTED", result.getLines().get(0).getStatus());
    }

    @Test
    void cancelOrder_byBuyer_succeeds() {
        UUID orderId = UUID.randomUUID();
        NetworkOrderLine line = NetworkOrderLine.builder()
                .id(UUID.randomUUID()).orderedQty(BigDecimal.ONE).status("PENDING").build();
        NetworkOrder order = NetworkOrder.builder()
                .id(orderId).buyerOrgId(orgA).sellerOrgId(orgB)
                .tradingPartnerId(UUID.randomUUID()).status("PLACED")
                .lines(new ArrayList<>(List.of(line))).build();
        line.setNetworkOrder(order);

        when(orderRepo.findByIdAndIsDeletedFalse(orderId)).thenReturn(Optional.of(order));
        when(orderRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));
        when(eventRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        NetworkOrder result = service.cancelOrder(orderId);
        assertEquals("CANCELLED", result.getStatus());
        assertNotNull(result.getCancelledAt());
    }

    @Test
    void markDispatched_bySeller_updatesStatus() {
        TenantContext.setCurrentOrgId(orgB);
        UUID orderId = UUID.randomUUID();

        NetworkOrderLine line = NetworkOrderLine.builder()
                .id(UUID.randomUUID()).orderedQty(BigDecimal.TEN)
                .confirmedQty(BigDecimal.TEN).status("CONFIRMED").build();
        NetworkOrder order = NetworkOrder.builder()
                .id(orderId).buyerOrgId(orgA).sellerOrgId(orgB)
                .tradingPartnerId(UUID.randomUUID()).status("CONFIRMED")
                .lines(new ArrayList<>(List.of(line))).build();
        line.setNetworkOrder(order);

        when(orderRepo.findByIdAndIsDeletedFalse(orderId)).thenReturn(Optional.of(order));
        when(orderRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));
        when(eventRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        NetworkOrder result = service.markDispatched(orderId);
        assertEquals("DISPATCHED", result.getStatus());
        assertNotNull(result.getDispatchedAt());
        assertEquals("DISPATCHED", result.getLines().get(0).getStatus());
    }
}
