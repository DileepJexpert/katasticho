package com.katasticho.erp.kenya;

import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.kenya.dto.MpesaStkPushRequest;
import com.katasticho.erp.kenya.dto.MpesaTransactionResponse;
import com.katasticho.erp.kenya.entity.MpesaTransaction;
import com.katasticho.erp.kenya.repository.MpesaTransactionRepository;
import com.katasticho.erp.kenya.service.MpesaService;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThatThrownBy;

@ExtendWith(MockitoExtension.class)
class MpesaServiceTest {

    @Mock
    private MpesaTransactionRepository repository;

    @Mock
    private InvoiceRepository invoiceRepository;

    @InjectMocks
    private MpesaService service;

    private final UUID orgId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        TenantContext.setCurrentOrgId(orgId);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    void shouldRejectStkPushUntilDarajaCallbackIntegrationIsConfigured() {
        MpesaStkPushRequest req = MpesaStkPushRequest.builder()
                .phoneNumber("254712345678")
                .amount(new BigDecimal("4500.00"))
                .customerName("John Kamau")
                .accountReference("INV-2026-001")
                .build();

        assertThatThrownBy(() -> service.initiateStkPush(req))
                .hasMessageContaining("Daraja callback")
                .hasFieldOrPropertyWithValue("errorCode", "MPESA_INTEGRATION_UNAVAILABLE");
    }
}
