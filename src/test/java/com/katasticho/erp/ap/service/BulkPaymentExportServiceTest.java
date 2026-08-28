package com.katasticho.erp.ap.service;

import com.katasticho.erp.accounting.entity.Account;
import com.katasticho.erp.accounting.repository.AccountRepository;
import com.katasticho.erp.ap.dto.BulkPaymentExportRequest;
import com.katasticho.erp.ap.dto.ChequePrintResponse;
import com.katasticho.erp.ap.entity.VendorPayment;
import com.katasticho.erp.ap.repository.VendorPaymentRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class BulkPaymentExportServiceTest {

    @Mock
    private VendorPaymentRepository paymentRepository;

    @Mock
    private ContactRepository contactRepository;

    @Mock
    private AccountRepository accountRepository;

    @Mock
    private OrganisationRepository organisationRepository;

    @InjectMocks
    private BulkPaymentExportService exportService;

    private UUID orgId;
    private UUID paymentId;
    private UUID contactId;
    private UUID accountId;
    private VendorPayment payment;
    private Contact contact;
    private Account account;
    private Organisation organisation;

    @BeforeEach
    void setUp() {
        orgId = UUID.randomUUID();
        paymentId = UUID.randomUUID();
        contactId = UUID.randomUUID();
        accountId = UUID.randomUUID();

        TenantContext.setCurrentOrgId(orgId);

        organisation = Organisation.builder()
                .name("Medix Pharma Distributors")
                .build();
        organisation.setId(orgId);

        contact = Contact.builder()
                .displayName("Sun Pharma Ltd")
                .companyName("Sun Pharmaceutical Industries Ltd")
                .bankName("HDFC Bank")
                .bankAccountNo("50200012345678")
                .bankIfsc("HDFC0001234")
                .email("accounts@sunpharma.com")
                .phone("9876543210")
                .build();
        contact.setId(contactId);
        contact.setOrgId(orgId);

        account = Account.builder()
                .code("1020")
                .name("HDFC Bank Main")
                .build();
        account.setId(accountId);
        account.setOrgId(orgId);

        payment = VendorPayment.builder()
                .id(paymentId)
                .orgId(orgId)
                .contactId(contactId)
                .paidThroughId(accountId)
                .paymentNumber("VP-2026-0001")
                .paymentDate(LocalDate.of(2026, 8, 29))
                .amount(new BigDecimal("125450.00"))
                .referenceNumber("CHQ-889901")
                .build();
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    void testGetChequePrintData() {
        when(paymentRepository.findByIdAndOrgIdAndIsDeletedFalse(paymentId, orgId))
                .thenReturn(Optional.of(payment));
        when(contactRepository.findByIdAndOrgIdAndIsDeletedFalse(contactId, orgId))
                .thenReturn(Optional.of(contact));
        when(organisationRepository.findById(orgId))
                .thenReturn(Optional.of(organisation));

        ChequePrintResponse cheque = exportService.getChequePrintData(paymentId, null);

        assertThat(cheque).isNotNull();
        assertThat(cheque.payeeName()).isEqualTo("** Sun Pharmaceutical Industries Ltd **");
        assertThat(cheque.amount()).isEqualByComparingTo("125450.00");
        assertThat(cheque.amountInWords()).contains("ONE LAKH TWENTY FIVE THOUSAND FOUR HUNDRED AND FIFTY RUPEES ONLY");
        assertThat(cheque.dateFormatted()).isEqualTo("29-08-2026");
        assertThat(cheque.dateSpaced()).isEqualTo("2 9 0 8 2 0 2 6");
        assertThat(cheque.chequeNumber()).isEqualTo("CHQ-889901");
        assertThat(cheque.accountPayeeOnly()).isTrue();
        assertThat(cheque.bankAccountNo()).isEqualTo("50200012345678");
        assertThat(cheque.ifscCode()).isEqualTo("HDFC0001234");
    }

    @Test
    void testExportBulkPaymentCsvGenericFormat() {
        when(paymentRepository.findAllById(anyCollection())).thenReturn(List.of(payment));
        when(contactRepository.findAllById(anyCollection())).thenReturn(List.of(contact));
        when(accountRepository.findAllById(anyCollection())).thenReturn(List.of(account));
        when(organisationRepository.findById(orgId)).thenReturn(Optional.of(organisation));

        BulkPaymentExportRequest request = new BulkPaymentExportRequest(List.of(paymentId), "GENERIC_NEFT_RTGS");
        byte[] bytes = exportService.exportBulkPaymentCsv(request);
        String csv = new String(bytes, StandardCharsets.UTF_8);

        assertThat(csv).contains("Payment Reference,Payment Date,Beneficiary Name,Beneficiary Account Number,IFSC Code,Bank Name,Amount,Payment Mode,Narration,Vendor Email,Vendor Mobile");
        assertThat(csv).contains("VP-2026-0001");
        assertThat(csv).contains("Sun Pharmaceutical Industries Ltd");
        assertThat(csv).contains("50200012345678");
        assertThat(csv).contains("HDFC0001234");
        assertThat(csv).contains("125450.00");
        assertThat(csv).contains("NEFT");
    }

    @Test
    void testExportBulkPaymentCsvHdfcFormat() {
        when(paymentRepository.findAllById(anyCollection())).thenReturn(List.of(payment));
        when(contactRepository.findAllById(anyCollection())).thenReturn(List.of(contact));
        when(accountRepository.findAllById(anyCollection())).thenReturn(List.of(account));
        when(organisationRepository.findById(orgId)).thenReturn(Optional.of(organisation));

        BulkPaymentExportRequest request = new BulkPaymentExportRequest(List.of(paymentId), "HDFC_CMS");
        byte[] bytes = exportService.exportBulkPaymentCsv(request);
        String csv = new String(bytes, StandardCharsets.UTF_8);

        assertThat(csv).contains("Transaction Type,Beneficiary Code,Beneficiary Account No,Instrument Amount,Beneficiary Name");
        assertThat(csv).contains("50200012345678");
        assertThat(csv).contains("125450.00");
        assertThat(csv).contains("Sun Pharmaceutical Industries Ltd");
        assertThat(csv).contains("VP-2026-0001");
    }

    @Test
    void testExportBulkPaymentCsvIciciFormat() {
        when(paymentRepository.findAllById(anyCollection())).thenReturn(List.of(payment));
        when(contactRepository.findAllById(anyCollection())).thenReturn(List.of(contact));
        when(accountRepository.findAllById(anyCollection())).thenReturn(List.of(account));
        when(organisationRepository.findById(orgId)).thenReturn(Optional.of(organisation));

        BulkPaymentExportRequest request = new BulkPaymentExportRequest(List.of(paymentId), "ICICI_CIB");
        byte[] bytes = exportService.exportBulkPaymentCsv(request);
        String csv = new String(bytes, StandardCharsets.UTF_8);

        assertThat(csv).contains("PYMT_MODE,PYMT_PROD_TYPE_CODE,PYMT_REF_NO,VALUE_DATE,DR_AC_NO,AMOUNT,BENE_NAME,BENE_ACC_NO,BENE_IFSC");
        assertThat(csv).contains("VP-2026-0001");
        assertThat(csv).contains("1020");
        assertThat(csv).contains("125450.00");
    }

    @Test
    void testExportBulkPaymentCsvSbiFormat() {
        when(paymentRepository.findAllById(anyCollection())).thenReturn(List.of(payment));
        when(contactRepository.findAllById(anyCollection())).thenReturn(List.of(contact));
        when(accountRepository.findAllById(anyCollection())).thenReturn(List.of(account));
        when(organisationRepository.findById(orgId)).thenReturn(Optional.of(organisation));

        BulkPaymentExportRequest request = new BulkPaymentExportRequest(List.of(paymentId), "SBI_CMP");
        byte[] bytes = exportService.exportBulkPaymentCsv(request);
        String csv = new String(bytes, StandardCharsets.UTF_8);

        assertThat(csv).contains("Payment Mode,Debit Account No,Txn Date,Txn Amount,Beneficiary Name,Beneficiary Account No,Beneficiary IFSC");
        assertThat(csv).contains("1020");
        assertThat(csv).contains("125450.00");
        assertThat(csv).contains("Sun Pharmaceutical Industries Ltd");
    }
}
