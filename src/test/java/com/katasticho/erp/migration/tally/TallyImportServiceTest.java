package com.katasticho.erp.migration.tally;

import com.katasticho.erp.accounting.dto.CreateAccountRequest;
import com.katasticho.erp.accounting.repository.AccountRepository;
import com.katasticho.erp.accounting.service.AccountService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.entity.ContactType;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.inventory.dto.CreateItemRequest;
import com.katasticho.erp.inventory.repository.HsnGstMasterRepository;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.inventory.service.ItemService;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class TallyImportServiceTest {

    private final ContactRepository contactRepository = mock(ContactRepository.class);
    private final AccountRepository accountRepository = mock(AccountRepository.class);
    private final AccountService accountService = mock(AccountService.class);
    private final ItemRepository itemRepository = mock(ItemRepository.class);
    private final ItemService itemService = mock(ItemService.class);
    private final HsnGstMasterRepository hsnGstMasterRepository = mock(HsnGstMasterRepository.class);

    private final TallyImportService service = new TallyImportService(
            new TallyXmlParser(), contactRepository, accountRepository, accountService,
            itemRepository, itemService, hsnGstMasterRepository);

    private final UUID orgId = UUID.randomUUID();

    /**
     * Realistic TallyPrime Masters export slice: a custom debtor subgroup, a
     * customer (debit opening = negative in Tally), a vendor, a GST duty
     * ledger (must skip), an indirect expense ledger, and a stock item with
     * opening qty/rate ("10 Nos", "95.00/Nos") + HSN + GST rate.
     */
    private static final String SAMPLE_XML = """
            <ENVELOPE>
             <HEADER><TALLYREQUEST>Export Data</TALLYREQUEST></HEADER>
             <BODY><IMPORTDATA><REQUESTDATA>
              <TALLYMESSAGE>
               <GROUP NAME="Local Debtors">
                <PARENT>Sundry Debtors</PARENT>
               </GROUP>
              </TALLYMESSAGE>
              <TALLYMESSAGE>
               <LEDGER NAME="MediMart Distributors">
                <PARENT>Local Debtors</PARENT>
                <OPENINGBALANCE>-15000.00</OPENINGBALANCE>
                <PARTYGSTIN>27AABCT1234A1Z5</PARTYGSTIN>
                <LEDSTATENAME>Maharashtra</LEDSTATENAME>
                <EMAIL>medimart@example.com</EMAIL>
                <LEDGERMOBILE>9876543210</LEDGERMOBILE>
                <INCOMETAXNUMBER>AAAPB1234C</INCOMETAXNUMBER>
                <ADDRESS.LIST><ADDRESS>12 MG Road</ADDRESS><ADDRESS>Pune</ADDRESS></ADDRESS.LIST>
               </LEDGER>
              </TALLYMESSAGE>
              <TALLYMESSAGE>
               <LEDGER NAME="ABC Pharma Supplies">
                <PARENT>Sundry Creditors</PARENT>
                <OPENINGBALANCE>22000.00</OPENINGBALANCE>
               </LEDGER>
              </TALLYMESSAGE>
              <TALLYMESSAGE>
               <LEDGER NAME="CGST Payable">
                <PARENT>Duties &amp; Taxes</PARENT>
                <OPENINGBALANCE>5000.00</OPENINGBALANCE>
               </LEDGER>
              </TALLYMESSAGE>
              <TALLYMESSAGE>
               <LEDGER NAME="Shop Rent">
                <PARENT>Indirect Expenses</PARENT>
               </LEDGER>
              </TALLYMESSAGE>
              <TALLYMESSAGE>
               <STOCKITEM NAME="Crocin 500mg">
                <PARENT>Medicines</PARENT>
                <BASEUNITS>Nos</BASEUNITS>
                <OPENINGBALANCE>10 Nos</OPENINGBALANCE>
                <OPENINGRATE>95.00/Nos</OPENINGRATE>
                <OPENINGVALUE>-950.00</OPENINGVALUE>
                <HSNDETAILS.LIST><HSNCODE>3004</HSNCODE></HSNDETAILS.LIST>
                <GSTDETAILS.LIST><GSTRATE>12</GSTRATE></GSTDETAILS.LIST>
               </STOCKITEM>
              </TALLYMESSAGE>
             </REQUESTDATA></IMPORTDATA></BODY>
            </ENVELOPE>
            """;

    @BeforeEach
    void setUp() {
        TenantContext.setCurrentOrgId(orgId);
        when(contactRepository.findFirstByOrgIdAndGstinIgnoreCaseAndIsDeletedFalse(any(), any()))
                .thenReturn(Optional.empty());
        when(contactRepository.findFirstByOrgIdAndDisplayNameIgnoreCaseAndIsDeletedFalse(any(), any()))
                .thenReturn(Optional.empty());
        when(accountRepository.findFirstByOrgIdAndNameIgnoreCaseAndIsDeletedFalse(any(), any()))
                .thenReturn(Optional.empty());
        when(accountRepository.existsByOrgIdAndCodeAndIsDeletedFalse(any(), anyString()))
                .thenReturn(false);
        when(itemRepository.findFirstByOrgIdAndNameIgnoreCaseAndIsDeletedFalse(any(), any()))
                .thenReturn(Optional.empty());
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    void previewClassifiesEveryMaster() {
        var preview = service.preview(SAMPLE_XML.getBytes(StandardCharsets.UTF_8));

        assertThat(preview.customers()).isEqualTo(1);
        assertThat(preview.vendors()).isEqualTo(1);
        assertThat(preview.accounts()).isEqualTo(1); // Shop Rent
        assertThat(preview.items()).isEqualTo(1);
        assertThat(preview.skipped()).isEqualTo(1);  // CGST Payable (Duties & Taxes)
        assertThat(preview.rows()).hasSize(5);

        // Custom subgroup resolved up to Sundry Debtors via the GROUP message.
        var customerRow = preview.rows().stream()
                .filter(r -> "MediMart Distributors".equals(r.tallyName())).findFirst().orElseThrow();
        assertThat(customerRow.becomes()).isEqualTo("CUSTOMER");
        assertThat(customerRow.detail()).contains("15000"); // debit normalized positive
    }

    @Test
    void importCreatesContactsWithNormalizedOpenings() {
        service.importMasters(SAMPLE_XML.getBytes(StandardCharsets.UTF_8));

        ArgumentCaptor<Contact> captor = ArgumentCaptor.forClass(Contact.class);
        verify(contactRepository, org.mockito.Mockito.times(2)).save(captor.capture());
        List<Contact> saved = captor.getAllValues();

        Contact customer = saved.stream()
                .filter(c -> c.getContactType() == ContactType.CUSTOMER).findFirst().orElseThrow();
        // Tally -15000 (Dr) → receivable +15000.
        assertThat(customer.getOpeningBalance()).isEqualByComparingTo("15000.00");
        assertThat(customer.getGstin()).isEqualTo("27AABCT1234A1Z5");
        assertThat(customer.getBillingStateCode()).isEqualTo("27");
        assertThat(customer.getMobile()).isEqualTo("9876543210");
        assertThat(customer.getBillingAddressLine1()).contains("12 MG Road");

        Contact vendor = saved.stream()
                .filter(c -> c.getContactType() == ContactType.VENDOR).findFirst().orElseThrow();
        // Tally +22000 (Cr) → payable +22000.
        assertThat(vendor.getOpeningBalance()).isEqualByComparingTo("22000.00");
    }

    @Test
    void importCreatesExpenseAccountAndSkipsDutyLedger() {
        var result = service.importMasters(SAMPLE_XML.getBytes(StandardCharsets.UTF_8));

        ArgumentCaptor<CreateAccountRequest> captor =
                ArgumentCaptor.forClass(CreateAccountRequest.class);
        verify(accountService).createAccount(captor.capture());
        CreateAccountRequest account = captor.getValue();
        assertThat(account.name()).isEqualTo("Shop Rent");
        assertThat(account.type()).isEqualTo("EXPENSE");
        assertThat(account.code()).startsWith("T");

        assertThat(result.accountsCreated()).isEqualTo(1);
        assertThat(result.skipped()).isEqualTo(1); // CGST Payable
        assertThat(result.errors()).isEmpty();
    }

    @Test
    void importCreatesItemWithOpeningStockAndGst() {
        service.importMasters(SAMPLE_XML.getBytes(StandardCharsets.UTF_8));

        ArgumentCaptor<CreateItemRequest> captor = ArgumentCaptor.forClass(CreateItemRequest.class);
        verify(itemService).createItem(captor.capture());
        CreateItemRequest item = captor.getValue();
        assertThat(item.name()).isEqualTo("Crocin 500mg");
        assertThat(item.sku()).isEqualTo("CROCIN-500MG");
        assertThat(item.hsnCode()).isEqualTo("3004");
        assertThat(item.gstRate()).isEqualByComparingTo("12");
        assertThat(item.unitOfMeasure()).isEqualTo("Nos");
        assertThat(item.openingStock()).isEqualByComparingTo("10");
        assertThat(item.purchasePrice()).isEqualByComparingTo("95.00");
        assertThat(item.category()).isEqualTo("Medicines");
    }

    @Test
    void rerunningSkipsExistingMasters() {
        when(contactRepository.findFirstByOrgIdAndGstinIgnoreCaseAndIsDeletedFalse(
                eq(orgId), eq("27AABCT1234A1Z5")))
                .thenReturn(Optional.of(Contact.builder()
                        .contactType(ContactType.CUSTOMER).displayName("MediMart Distributors").build()));
        when(itemRepository.findFirstByOrgIdAndNameIgnoreCaseAndIsDeletedFalse(eq(orgId), eq("Crocin 500mg")))
                .thenReturn(Optional.of(new com.katasticho.erp.inventory.entity.Item()));

        var preview = service.preview(SAMPLE_XML.getBytes(StandardCharsets.UTF_8));

        assertThat(preview.customers()).isZero();
        assertThat(preview.items()).isZero();
        assertThat(preview.rows()).extracting(TallyImportDtos.RowPlan::action)
                .contains("SKIP_EXISTS");
    }

    @Test
    void rejectsNonTallyXml() {
        org.assertj.core.api.Assertions.assertThatThrownBy(() ->
                        service.preview("<html>not tally</html>".getBytes(StandardCharsets.UTF_8)))
                .hasMessageContaining("No ledgers or stock items");
    }

    @Test
    void skuFromNameIsCleanAndBounded() {
        assertThat(TallyImportService.skuFromName("Crocin 500mg (Strip of 15)"))
                .isEqualTo("CROCIN-500MG-STRIP-OF-15");
        assertThat(TallyImportService.skuFromName("a".repeat(100))).hasSize(50);
    }
}
