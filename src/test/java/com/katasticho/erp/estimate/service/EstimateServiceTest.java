package com.katasticho.erp.estimate.service;

import com.katasticho.erp.accounting.defaults.service.DefaultAccountService;
import com.katasticho.erp.ar.dto.CreateInvoiceRequest;
import com.katasticho.erp.ar.dto.InvoiceResponse;
import com.katasticho.erp.ar.repository.InvoiceNumberSequenceRepository;
import com.katasticho.erp.ar.service.InvoiceService;
import com.katasticho.erp.audit.AuditService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.common.service.CommentService;
import com.katasticho.erp.common.service.DocumentEmailService;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.entity.ContactType;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.estimate.entity.Estimate;
import com.katasticho.erp.estimate.entity.EstimateLine;
import com.katasticho.erp.estimate.entity.EstimateStatus;
import com.katasticho.erp.estimate.repository.EstimateRepository;
import com.katasticho.erp.organisation.OrganisationRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class EstimateServiceTest {

    @Mock private EstimateRepository estimateRepository;
    @Mock private ContactRepository contactRepository;
    @Mock private InvoiceNumberSequenceRepository sequenceRepository;
    @Mock private OrganisationRepository organisationRepository;
    @Mock private InvoiceService invoiceService;
    @Mock private AuditService auditService;
    @Mock private CommentService commentService;
    @Mock private DefaultAccountService defaultAccountService;
    @Mock private DocumentEmailService documentEmailService;

    @InjectMocks
    private EstimateService estimateService;

    private UUID orgId;
    private UUID userId;
    private UUID contactId;
    private UUID estimateId;

    @BeforeEach
    void setUp() {
        orgId = UUID.randomUUID();
        userId = UUID.randomUUID();
        contactId = UUID.randomUUID();
        estimateId = UUID.randomUUID();

        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(userId);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    void convertToInvoice_successful_whenContactIsCustomer() {
        Estimate estimate = Estimate.builder()
                .id(estimateId)
                .orgId(orgId)
                .contactId(contactId)
                .estimateNumber("EST-001")
                .status(EstimateStatus.ACCEPTED.name())
                .lines(List.of(EstimateLine.builder()
                        .id(UUID.randomUUID())
                        .description("Test line")
                        .quantity(BigDecimal.ONE)
                        .rate(new BigDecimal("100"))
                        .taxRate(new BigDecimal("18"))
                        .build()))
                .build();

        Contact contact = new Contact();
        contact.setId(contactId);
        contact.setOrgId(orgId);
        contact.setContactType(ContactType.CUSTOMER);
        contact.setDisplayName("Test Customer");

        InvoiceResponse mockInvoice = new InvoiceResponse(
                UUID.randomUUID(),
                contactId,
                "Test Customer",
                "INV-001",
                LocalDate.now(),
                LocalDate.now().plusDays(30),
                "DRAFT",
                new BigDecimal("100"),
                new BigDecimal("18"),
                BigDecimal.ZERO,
                new BigDecimal("118"),
                BigDecimal.ZERO,
                new BigDecimal("118"),
                "INR",
                "27",
                false,
                null,
                null,
                null,
                List.of(),
                List.of(),
                Instant.now()
        );

        when(estimateRepository.findByIdAndOrgIdAndIsDeletedFalse(estimateId, orgId))
                .thenReturn(Optional.of(estimate));
        when(contactRepository.findById(contactId)).thenReturn(Optional.of(contact));
        when(defaultAccountService.getCode(any(), any())).thenReturn("4001");
        when(invoiceService.createInvoice(any(CreateInvoiceRequest.class))).thenReturn(mockInvoice);
        when(estimateRepository.save(any(Estimate.class))).thenAnswer(inv -> inv.getArgument(0));

        InvoiceResponse result = estimateService.convertToInvoice(estimateId);

        assertNotNull(result);
        assertEquals("INV-001", result.invoiceNumber());
        assertEquals(EstimateStatus.INVOICED.name(), estimate.getStatus());
        assertEquals(mockInvoice.id(), estimate.getConvertedToInvoiceId());
        assertNotNull(estimate.getConvertedAt());
    }

    @Test
    void convertToInvoice_fails_whenContactIsVendorOnly() {
        Estimate estimate = Estimate.builder()
                .id(estimateId)
                .orgId(orgId)
                .contactId(contactId)
                .estimateNumber("EST-001")
                .status(EstimateStatus.ACCEPTED.name())
                .lines(List.of(EstimateLine.builder()
                        .id(UUID.randomUUID())
                        .description("Test line")
                        .quantity(BigDecimal.ONE)
                        .rate(new BigDecimal("100"))
                        .build()))
                .build();

        Contact contact = new Contact();
        contact.setId(contactId);
        contact.setOrgId(orgId);
        contact.setContactType(ContactType.VENDOR);
        contact.setDisplayName("Test Vendor");

        when(estimateRepository.findByIdAndOrgIdAndIsDeletedFalse(estimateId, orgId))
                .thenReturn(Optional.of(estimate));
        when(contactRepository.findById(contactId)).thenReturn(Optional.of(contact));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> estimateService.convertToInvoice(estimateId));

        assertEquals("EST_CONTACT_NOT_CUSTOMER", ex.getErrorCode());
    }
}
