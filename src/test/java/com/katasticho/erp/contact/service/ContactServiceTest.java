package com.katasticho.erp.contact.service;

import com.katasticho.erp.audit.AuditService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.common.service.CommentService;
import com.katasticho.erp.contact.dto.ContactResponse;
import com.katasticho.erp.contact.dto.CreateContactRequest;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.entity.ContactType;
import com.katasticho.erp.contact.entity.GstTreatment;
import com.katasticho.erp.contact.repository.ContactPersonRepository;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.procurement.repository.SupplierRepository;
import com.katasticho.erp.procurement.service.SupplierService;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class ContactServiceTest {

    @Mock
    private ContactRepository contactRepository;

    @Mock
    private ContactPersonRepository contactPersonRepository;

    @Mock
    private AuditService auditService;

    @Mock
    private CommentService commentService;

    @Mock
    private SupplierRepository supplierRepository;

    @Mock
    private SupplierService supplierService;

    @InjectMocks
    private ContactService contactService;

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

    @Test
    void create_customer_success() {
        CreateContactRequest req = new CreateContactRequest(
                ContactType.CUSTOMER,
                "Acme Pharma Pvt Ltd",
                "Acme Pharma",
                "John",
                "Doe",
                "Mr.",
                "29AABCU9603R1ZM",
                "AABCU9603R",
                null,
                GstTreatment.REGISTERED,
                "29",
                "john@acme.com",
                "08012345678",
                "9876543210",
                "https://acme.com",
                "123 MG Road",
                "Suite 400",
                "Bengaluru",
                "Karnataka",
                "29",
                "560001",
                "IN",
                "123 MG Road",
                null,
                "Bengaluru",
                "Karnataka",
                "29",
                "560001",
                "IN",
                "INR",
                30,
                BigDecimal.valueOf(500000),
                BigDecimal.valueOf(25000),
                null,
                false,
                null,
                null,
                false,
                null,
                null,
                "HDFC Bank",
                "50100234567890",
                "HDFC0000123",
                "acme@hdfcbank",
                "Valued distributor",
                null,
                null,
                null,
                null,
                false,
                null,
                false
        );

        when(contactRepository.existsByOrgIdAndGstinAndIsDeletedFalse(orgId, "29AABCU9603R1ZM")).thenReturn(false);
        when(contactRepository.save(any(Contact.class))).thenAnswer(inv -> {
            Contact c = inv.getArgument(0);
            c.setId(UUID.randomUUID());
            return c;
        });

        ContactResponse resp = contactService.create(req);

        assertThat(resp).isNotNull();
        assertThat(resp.displayName()).isEqualTo("Acme Pharma Pvt Ltd");
        assertThat(resp.contactType()).isEqualTo(ContactType.CUSTOMER);
        assertThat(resp.gstin()).isEqualTo("29AABCU9603R1ZM");
        assertThat(resp.pan()).isEqualTo("AABCU9603R");
        assertThat(resp.bankName()).isEqualTo("HDFC Bank");
        assertThat(resp.bankAccountNo()).isEqualTo("50100234567890");
        assertThat(resp.supplierEnabled()).isFalse();

        verify(auditService).log(eq("CONTACT"), any(), eq("CREATE"), isNull(), any());
        verify(supplierService, never()).createFromContact(any());
    }

    @Test
    void create_vendor_with_msme_and_tds_and_supplier_role() {
        CreateContactRequest req = new CreateContactRequest(
                ContactType.VENDOR,
                "Apex Raw Materials LLP",
                "Apex Raw Materials",
                null,
                null,
                null,
                "27AAACA1234P1Z5",
                "AAACA1234P",
                null,
                GstTreatment.REGISTERED,
                "27",
                "sales@apexraw.com",
                null,
                "9811122233",
                null,
                "Plot 45, MIDC",
                null,
                "Pune",
                "Maharashtra",
                "27",
                "411018",
                "IN",
                null,
                null,
                null,
                null,
                null,
                null,
                "IN",
                "INR",
                45,
                BigDecimal.ZERO,
                BigDecimal.valueOf(-15000),
                null,
                false,
                null,
                null,
                true,
                "194C",
                BigDecimal.valueOf(1.0),
                "ICICI Bank",
                "000105001234",
                "ICIC0000001",
                "apex@icici",
                "Primary API vendor",
                null,
                null,
                null,
                null,
                true,
                "UDYAM-MH-01-0012345",
                true
        );

        when(contactRepository.existsByOrgIdAndGstinAndIsDeletedFalse(orgId, "27AAACA1234P1Z5")).thenReturn(false);
        when(contactRepository.save(any(Contact.class))).thenAnswer(inv -> {
            Contact c = inv.getArgument(0);
            c.setId(UUID.randomUUID());
            return c;
        });

        ContactResponse resp = contactService.create(req);

        assertThat(resp).isNotNull();
        assertThat(resp.contactType()).isEqualTo(ContactType.VENDOR);
        assertThat(resp.msmeRegistered()).isTrue();
        assertThat(resp.msmeRegistrationNo()).isEqualTo("UDYAM-MH-01-0012345");
        assertThat(resp.tdsApplicable()).isTrue();
        assertThat(resp.tdsSection()).isEqualTo("194C");
        assertThat(resp.tdsRate()).isEqualByComparingTo(BigDecimal.valueOf(1.0));
        assertThat(resp.supplierEnabled()).isTrue();

        verify(supplierService).createFromContact(any(UUID.class));
    }

    @Test
    void create_duplicate_gstin_throws_conflict() {
        CreateContactRequest req = new CreateContactRequest(
                ContactType.CUSTOMER,
                "Duplicate Test Ltd",
                null, null, null, null,
                "29AABCU9603R1ZM",
                "AABCU9603R",
                null, GstTreatment.REGISTERED, "29",
                null, null, null, null,
                null, null, null, null, null, null, "IN",
                null, null, null, null, null, null, "IN",
                "INR", 30, BigDecimal.ZERO, BigDecimal.ZERO, null,
                false, null, null, false, null, null,
                null, null, null, null, null,
                null, null, null, null, false, null, false
        );

        when(contactRepository.existsByOrgIdAndGstinAndIsDeletedFalse(orgId, "29AABCU9603R1ZM")).thenReturn(true);

        assertThatThrownBy(() -> contactService.create(req))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("already exists");
    }

    @Test
    void create_customer_with_supplier_role_throws_error() {
        CreateContactRequest req = new CreateContactRequest(
                ContactType.CUSTOMER,
                "Customer With Supplier Role",
                null, null, null, null,
                null, null, null, GstTreatment.UNREGISTERED, null,
                null, null, null, null,
                null, null, null, null, null, null, "IN",
                null, null, null, null, null, null, "IN",
                "INR", 30, BigDecimal.ZERO, BigDecimal.ZERO, null,
                false, null, null, false, null, null,
                null, null, null, null, null,
                null, null, null, null, false, null, true
        );

        assertThatThrownBy(() -> contactService.create(req))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("Only Vendor or Both contacts can be enabled as suppliers");
    }

    @Test
    void update_contact_updates_msme_and_bank_details() {
        UUID contactId = UUID.randomUUID();
        Contact existing = Contact.builder()
                .contactType(ContactType.VENDOR)
                .displayName("Old Name")
                .billingCountry("IN")
                .shippingCountry("IN")
                .currency("INR")
                .paymentTermsDays(30)
                .build();
        existing.setId(contactId);
        existing.setOrgId(orgId);

        when(contactRepository.findByIdAndOrgIdAndIsDeletedFalse(contactId, orgId)).thenReturn(Optional.of(existing));
        when(supplierRepository.existsByOrgIdAndContactIdAndActiveTrueAndIsDeletedFalse(orgId, contactId)).thenReturn(false);
        when(contactRepository.save(any(Contact.class))).thenAnswer(inv -> inv.getArgument(0));

        CreateContactRequest updateReq = new CreateContactRequest(
                ContactType.VENDOR,
                "Updated Vendor Name",
                "Updated Vendor Org",
                null, null, null,
                "27AAACA1234P1Z5",
                "AAACA1234P",
                null, GstTreatment.REGISTERED, "27",
                "vendor@updated.com", null, null, null,
                "New Address Line 1", null, "Mumbai", "Maharashtra", "27", "400001", "IN",
                null, null, null, null, null, null, "IN",
                "INR", 45, BigDecimal.ZERO, BigDecimal.ZERO, null,
                false, null, null, true, "194J", BigDecimal.valueOf(10.0),
                "Axis Bank", "919020012345678", "UTIB0000123", "vendor@axis",
                "Updated notes", null, null, null, null,
                true, "UDYAM-MH-02-9988776", false
        );

        when(contactRepository.existsByOrgIdAndGstinAndIdNotAndIsDeletedFalse(orgId, "27AAACA1234P1Z5", contactId)).thenReturn(false);

        ContactResponse resp = contactService.update(contactId, updateReq);

        assertThat(resp.displayName()).isEqualTo("Updated Vendor Name");
        assertThat(resp.msmeRegistered()).isTrue();
        assertThat(resp.msmeRegistrationNo()).isEqualTo("UDYAM-MH-02-9988776");
        assertThat(resp.bankName()).isEqualTo("Axis Bank");
        assertThat(resp.bankAccountNo()).isEqualTo("919020012345678");
        assertThat(resp.bankIfsc()).isEqualTo("UTIB0000123");
        assertThat(resp.tdsSection()).isEqualTo("194J");
        assertThat(resp.tdsRate()).isEqualByComparingTo(BigDecimal.valueOf(10.0));
    }
}
