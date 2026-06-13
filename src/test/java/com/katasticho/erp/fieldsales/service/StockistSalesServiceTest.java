package com.katasticho.erp.fieldsales.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.fieldsales.entity.StockistSalesLine;
import com.katasticho.erp.fieldsales.entity.StockistSalesStatement;
import com.katasticho.erp.fieldsales.repository.StockistSalesLineRepository;
import com.katasticho.erp.fieldsales.repository.StockistSalesStatementRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class StockistSalesServiceTest {

    @Mock private StockistSalesStatementRepository statementRepo;
    @Mock private StockistSalesLineRepository lineRepo;
    @Mock private ContactRepository contactRepo;

    private StockistSalesService service;

    private final UUID orgId = UUID.randomUUID();
    private final UUID stockistId = UUID.randomUUID();
    private final LocalDate month = LocalDate.of(2026, 5, 1);

    @BeforeEach
    void setUp() {
        service = new StockistSalesService(statementRepo, lineRepo, contactRepo);
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(UUID.randomUUID());
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    private StockistSalesLine line(String product, String open, String purchase,
                                   String sales, String ret, String value) {
        return StockistSalesLine.builder()
                .orgId(orgId).productName(product)
                .openingQty(new BigDecimal(open)).purchaseQty(new BigDecimal(purchase))
                .salesQty(new BigDecimal(sales)).returnQty(new BigDecimal(ret))
                .salesValue(new BigDecimal(value)).build();
    }

    @Test
    @SuppressWarnings("unchecked")
    void saveStatement_derivesClosingFromMovement() {
        when(contactRepo.findByIdAndOrgIdAndIsDeletedFalse(stockistId, orgId))
                .thenReturn(Optional.of(mock(Contact.class)));
        when(statementRepo.findByOrgIdAndStockistContactIdAndPeriodMonthAndIsDeletedFalse(
                orgId, stockistId, month)).thenReturn(Optional.empty());
        when(statementRepo.save(any())).thenAnswer(inv -> {
            StockistSalesStatement s = inv.getArgument(0);
            if (s.getId() == null) s.setId(UUID.randomUUID());
            return s;
        });
        when(lineRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        var lines = List.of(new StockistSalesService.LineInput(
                null, "Dolo 650", new BigDecimal("100"), new BigDecimal("50"),
                new BigDecimal("120"), new BigDecimal("5"), new BigDecimal("3600")));

        Map<String, Object> result = service.saveStatement(stockistId, month, "May SSS", lines);

        verify(lineRepo).deleteByOrgIdAndStatementId(eq(orgId), any());
        List<StockistSalesLine> saved = (List<StockistSalesLine>) result.get("lines");
        assertEquals(1, saved.size());
        // 100 + 50 - 120 - 5 = 25
        assertEquals(0, saved.get(0).getClosingQty().compareTo(new BigDecimal("25")));
    }

    @Test
    void saveStatement_submittedStatement_throws() {
        when(contactRepo.findByIdAndOrgIdAndIsDeletedFalse(stockistId, orgId))
                .thenReturn(Optional.of(mock(Contact.class)));
        StockistSalesStatement existing = StockistSalesStatement.builder()
                .id(UUID.randomUUID()).orgId(orgId).stockistContactId(stockistId)
                .periodMonth(month).status("SUBMITTED").build();
        when(statementRepo.findByOrgIdAndStockistContactIdAndPeriodMonthAndIsDeletedFalse(
                orgId, stockistId, month)).thenReturn(Optional.of(existing));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.saveStatement(stockistId, month, null, List.of()));
        assertEquals("SSS_NOT_DRAFT", ex.getErrorCode());
    }

    @Test
    void secondarySalesReport_aggregatesByProductAcrossStatements() {
        StockistSalesStatement s1 = StockistSalesStatement.builder().id(UUID.randomUUID()).build();
        StockistSalesStatement s2 = StockistSalesStatement.builder().id(UUID.randomUUID()).build();
        when(statementRepo.findByOrgIdAndPeriodMonthBetweenAndIsDeletedFalse(eq(orgId), any(), any()))
                .thenReturn(List.of(s1, s2));
        when(lineRepo.findByOrgIdAndStatementIdInAndIsDeletedFalse(eq(orgId), any()))
                .thenReturn(List.of(
                        line("Dolo 650", "0", "0", "100", "0", "1000"),
                        line("Dolo 650", "0", "0", "50", "0", "500"),
                        line("Azee 500", "0", "0", "30", "0", "900")));

        List<Map<String, Object>> rows = service.secondarySalesReport(month, month);

        assertEquals(2, rows.size());
        // sorted by sales value desc -> Dolo (1500) first
        assertEquals("Dolo 650", rows.get(0).get("productName"));
        assertEquals(0, ((BigDecimal) rows.get(0).get("salesQty")).compareTo(new BigDecimal("150")));
        assertEquals(0, ((BigDecimal) rows.get(0).get("salesValue")).compareTo(new BigDecimal("1500")));
        assertEquals("Azee 500", rows.get(1).get("productName"));
    }

    @Test
    void stockOnHand_sumsClosingByProduct() {
        StockistSalesStatement s1 = StockistSalesStatement.builder().id(UUID.randomUUID()).build();
        when(statementRepo.findByOrgIdAndPeriodMonthBetweenAndIsDeletedFalse(eq(orgId), any(), any()))
                .thenReturn(List.of(s1));
        StockistSalesLine a = line("Dolo 650", "0", "0", "0", "0", "0");
        a.setClosingQty(new BigDecimal("25"));
        StockistSalesLine b = line("Dolo 650", "0", "0", "0", "0", "0");
        b.setClosingQty(new BigDecimal("15"));
        when(lineRepo.findByOrgIdAndStatementIdInAndIsDeletedFalse(eq(orgId), any()))
                .thenReturn(List.of(a, b));

        List<Map<String, Object>> rows = service.stockOnHand(month);

        assertEquals(1, rows.size());
        assertEquals(0, ((BigDecimal) rows.get(0).get("closingQty")).compareTo(new BigDecimal("40")));
    }
}
