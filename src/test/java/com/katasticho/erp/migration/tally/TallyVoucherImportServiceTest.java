package com.katasticho.erp.migration.tally;

import com.katasticho.erp.accounting.dto.JournalPostRequest;
import com.katasticho.erp.accounting.entity.Account;
import com.katasticho.erp.accounting.entity.JournalEntry;
import com.katasticho.erp.accounting.repository.AccountRepository;
import com.katasticho.erp.accounting.service.JournalService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.entity.ContactType;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.migration.tally.TallyImportDtos.VoucherImportPreview;
import com.katasticho.erp.migration.tally.TallyImportDtos.VoucherImportResult;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

class TallyVoucherImportServiceTest {

    private final ContactRepository contactRepository = mock(ContactRepository.class);
    private final AccountRepository accountRepository = mock(AccountRepository.class);
    private final JournalService journalService = mock(JournalService.class);

    private final TallyVoucherImportService service = new TallyVoucherImportService(
            new TallyXmlParser(), contactRepository, accountRepository, journalService);

    private final UUID orgId = UUID.randomUUID();

    /**
     * Realistic TallyPrime Day Book export using Tally's <b>real</b> sign
     * convention (debit = negative AMOUNT + ISDEEMEDPOSITIVE=Yes; credit =
     * positive + No) and structures:
     * <ul>
     *   <li>Sales (invoice mode): party + GST in LEDGERENTRIES.LIST, the
     *       revenue ledger nested in ALLINVENTORYENTRIES.LIST →
     *       ACCOUNTINGALLOCATIONS.LIST. BILLALLOCATIONS/BATCHALLOCATIONS
     *       amounts must NOT be double counted.</li>
     *   <li>Receipt (voucher mode): ALLLEDGERENTRIES.LIST.</li>
     *   <li>Journal (voucher mode): ALLLEDGERENTRIES.LIST.</li>
     *   <li>Purchase (invoice mode): vendor + input GST in LEDGERENTRIES.LIST,
     *       purchase ledger in ACCOUNTINGALLOCATIONS.LIST.</li>
     * </ul>
     */
    private static final String DAY_BOOK_XML = """
            <ENVELOPE>
             <HEADER><TALLYREQUEST>Export Data</TALLYREQUEST></HEADER>
             <BODY><IMPORTDATA><REQUESTDATA>
              <TALLYMESSAGE>
               <VOUCHER VCHTYPE="Sales">
                <DATE>20250401</DATE>
                <VOUCHERTYPENAME>Sales</VOUCHERTYPENAME>
                <VOUCHERNUMBER>S-001</VOUCHERNUMBER>
                <PARTYLEDGERNAME>MediMart Distributors</PARTYLEDGERNAME>
                <NARRATION>Goods sold</NARRATION>
                <LEDGERENTRIES.LIST>
                 <LEDGERNAME>MediMart Distributors</LEDGERNAME>
                 <ISDEEMEDPOSITIVE>Yes</ISDEEMEDPOSITIVE>
                 <ISPARTYLEDGER>Yes</ISPARTYLEDGER>
                 <AMOUNT>-11200.00</AMOUNT>
                 <BILLALLOCATIONS.LIST>
                  <NAME>S-001</NAME><BILLTYPE>New Ref</BILLTYPE><AMOUNT>-11200.00</AMOUNT>
                 </BILLALLOCATIONS.LIST>
                </LEDGERENTRIES.LIST>
                <LEDGERENTRIES.LIST>
                 <LEDGERNAME>CGST</LEDGERNAME>
                 <ISDEEMEDPOSITIVE>No</ISDEEMEDPOSITIVE>
                 <AMOUNT>600.00</AMOUNT>
                </LEDGERENTRIES.LIST>
                <LEDGERENTRIES.LIST>
                 <LEDGERNAME>SGST</LEDGERNAME>
                 <ISDEEMEDPOSITIVE>No</ISDEEMEDPOSITIVE>
                 <AMOUNT>600.00</AMOUNT>
                </LEDGERENTRIES.LIST>
                <ALLINVENTORYENTRIES.LIST>
                 <STOCKITEMNAME>Crocin 500mg</STOCKITEMNAME>
                 <ISDEEMEDPOSITIVE>No</ISDEEMEDPOSITIVE>
                 <RATE>100.00/Nos</RATE>
                 <AMOUNT>10000.00</AMOUNT>
                 <ACTUALQTY>100 Nos</ACTUALQTY>
                 <BATCHALLOCATIONS.LIST>
                  <GODOWNNAME>Main Location</GODOWNNAME><BATCHNAME>Primary</BATCHNAME><AMOUNT>10000.00</AMOUNT>
                 </BATCHALLOCATIONS.LIST>
                 <ACCOUNTINGALLOCATIONS.LIST>
                  <LEDGERNAME>Sales A/c</LEDGERNAME>
                  <ISDEEMEDPOSITIVE>No</ISDEEMEDPOSITIVE>
                  <AMOUNT>10000.00</AMOUNT>
                 </ACCOUNTINGALLOCATIONS.LIST>
                </ALLINVENTORYENTRIES.LIST>
               </VOUCHER>
              </TALLYMESSAGE>
              <TALLYMESSAGE>
               <VOUCHER VCHTYPE="Receipt">
                <DATE>20250405</DATE>
                <VOUCHERTYPENAME>Receipt</VOUCHERTYPENAME>
                <VOUCHERNUMBER>R-001</VOUCHERNUMBER>
                <PARTYLEDGERNAME>MediMart Distributors</PARTYLEDGERNAME>
                <NARRATION>Payment received</NARRATION>
                <ALLLEDGERENTRIES.LIST>
                 <LEDGERNAME>Cash</LEDGERNAME>
                 <ISDEEMEDPOSITIVE>Yes</ISDEEMEDPOSITIVE>
                 <AMOUNT>-11200.00</AMOUNT>
                </ALLLEDGERENTRIES.LIST>
                <ALLLEDGERENTRIES.LIST>
                 <LEDGERNAME>MediMart Distributors</LEDGERNAME>
                 <ISDEEMEDPOSITIVE>No</ISDEEMEDPOSITIVE>
                 <AMOUNT>11200.00</AMOUNT>
                 <BILLALLOCATIONS.LIST>
                  <NAME>S-001</NAME><BILLTYPE>Agst Ref</BILLTYPE><AMOUNT>11200.00</AMOUNT>
                 </BILLALLOCATIONS.LIST>
                </ALLLEDGERENTRIES.LIST>
               </VOUCHER>
              </TALLYMESSAGE>
              <TALLYMESSAGE>
               <VOUCHER VCHTYPE="Journal">
                <DATE>20250410</DATE>
                <VOUCHERTYPENAME>Journal</VOUCHERTYPENAME>
                <VOUCHERNUMBER>J-001</VOUCHERNUMBER>
                <NARRATION>Shop rent for April</NARRATION>
                <ALLLEDGERENTRIES.LIST>
                 <LEDGERNAME>Shop Rent</LEDGERNAME>
                 <ISDEEMEDPOSITIVE>Yes</ISDEEMEDPOSITIVE>
                 <AMOUNT>-15000.00</AMOUNT>
                </ALLLEDGERENTRIES.LIST>
                <ALLLEDGERENTRIES.LIST>
                 <LEDGERNAME>HDFC Bank</LEDGERNAME>
                 <ISDEEMEDPOSITIVE>No</ISDEEMEDPOSITIVE>
                 <AMOUNT>15000.00</AMOUNT>
                </ALLLEDGERENTRIES.LIST>
               </VOUCHER>
              </TALLYMESSAGE>
              <TALLYMESSAGE>
               <VOUCHER VCHTYPE="Purchase">
                <DATE>20250415</DATE>
                <VOUCHERTYPENAME>Purchase</VOUCHERTYPENAME>
                <VOUCHERNUMBER>P-001</VOUCHERNUMBER>
                <PARTYLEDGERNAME>ABC Pharma Supplies</PARTYLEDGERNAME>
                <NARRATION>Stock purchase</NARRATION>
                <LEDGERENTRIES.LIST>
                 <LEDGERNAME>ABC Pharma Supplies</LEDGERNAME>
                 <ISDEEMEDPOSITIVE>No</ISDEEMEDPOSITIVE>
                 <ISPARTYLEDGER>Yes</ISPARTYLEDGER>
                 <AMOUNT>22400.00</AMOUNT>
                </LEDGERENTRIES.LIST>
                <LEDGERENTRIES.LIST>
                 <LEDGERNAME>Input CGST</LEDGERNAME>
                 <ISDEEMEDPOSITIVE>Yes</ISDEEMEDPOSITIVE>
                 <AMOUNT>-1200.00</AMOUNT>
                </LEDGERENTRIES.LIST>
                <LEDGERENTRIES.LIST>
                 <LEDGERNAME>Input SGST</LEDGERNAME>
                 <ISDEEMEDPOSITIVE>Yes</ISDEEMEDPOSITIVE>
                 <AMOUNT>-1200.00</AMOUNT>
                </LEDGERENTRIES.LIST>
                <ALLINVENTORYENTRIES.LIST>
                 <STOCKITEMNAME>Crocin 500mg</STOCKITEMNAME>
                 <ISDEEMEDPOSITIVE>Yes</ISDEEMEDPOSITIVE>
                 <AMOUNT>-20000.00</AMOUNT>
                 <ACCOUNTINGALLOCATIONS.LIST>
                  <LEDGERNAME>Purchase A/c</LEDGERNAME>
                  <ISDEEMEDPOSITIVE>Yes</ISDEEMEDPOSITIVE>
                  <AMOUNT>-20000.00</AMOUNT>
                 </ACCOUNTINGALLOCATIONS.LIST>
                </ALLINVENTORYENTRIES.LIST>
               </VOUCHER>
              </TALLYMESSAGE>
             </REQUESTDATA></IMPORTDATA></BODY>
            </ENVELOPE>
            """;

    @BeforeEach
    void setUp() {
        TenantContext.setCurrentOrgId(orgId);

        // MediMart is a customer
        Contact customer = Contact.builder()
                .contactType(ContactType.CUSTOMER)
                .displayName("MediMart Distributors").build();
        when(contactRepository.findFirstByOrgIdAndDisplayNameIgnoreCaseAndIsDeletedFalse(
                eq(orgId), eq("MediMart Distributors")))
                .thenReturn(Optional.of(customer));

        // ABC Pharma is a vendor
        Contact vendor = Contact.builder()
                .contactType(ContactType.VENDOR)
                .displayName("ABC Pharma Supplies").build();
        when(contactRepository.findFirstByOrgIdAndDisplayNameIgnoreCaseAndIsDeletedFalse(
                eq(orgId), eq("ABC Pharma Supplies")))
                .thenReturn(Optional.of(vendor));

        // Shop Rent is an account from Slice 1 import
        Account shopRent = new Account();
        shopRent.setCode("T0001");
        shopRent.setName("Shop Rent");
        when(accountRepository.findFirstByOrgIdAndNameIgnoreCaseAndIsDeletedFalse(
                eq(orgId), eq("Shop Rent")))
                .thenReturn(Optional.of(shopRent));

        // Default: unknown names return empty
        when(contactRepository.findFirstByOrgIdAndDisplayNameIgnoreCaseAndIsDeletedFalse(
                eq(orgId), argThat(n -> !n.equals("MediMart Distributors")
                        && !n.equals("ABC Pharma Supplies"))))
                .thenReturn(Optional.empty());
        when(accountRepository.findFirstByOrgIdAndNameIgnoreCaseAndIsDeletedFalse(
                eq(orgId), argThat(n -> !n.equals("Shop Rent"))))
                .thenReturn(Optional.empty());

        // Journal service returns a stub
        when(journalService.postJournal(any())).thenReturn(new JournalEntry());
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    void previewCountsVouchersByType() {
        VoucherImportPreview preview = service.preview(DAY_BOOK_XML.getBytes(StandardCharsets.UTF_8));

        assertThat(preview.total()).isEqualTo(4);
        assertThat(preview.importable()).isEqualTo(4);
        assertThat(preview.skipped()).isZero();
        assertThat(preview.byType()).containsEntry("Sales", 1);
        assertThat(preview.byType()).containsEntry("Receipt", 1);
        assertThat(preview.byType()).containsEntry("Journal", 1);
        assertThat(preview.byType()).containsEntry("Purchase", 1);
    }

    @Test
    void importCreatesFourJournalEntries() {
        VoucherImportResult result = service.importVouchers(DAY_BOOK_XML.getBytes(StandardCharsets.UTF_8));

        assertThat(result.journalsCreated()).isEqualTo(4);
        assertThat(result.skipped()).isZero();
        assertThat(result.errors()).isEmpty();
        verify(journalService, times(4)).postJournal(any());
    }

    @Test
    void salesVoucherResolvesAllLedgersCorrectly() {
        service.importVouchers(DAY_BOOK_XML.getBytes(StandardCharsets.UTF_8));

        ArgumentCaptor<JournalPostRequest> captor = ArgumentCaptor.forClass(JournalPostRequest.class);
        verify(journalService, times(4)).postJournal(captor.capture());

        // First journal = Sales voucher. Entry order: party + GST from
        // LEDGERENTRIES.LIST, then revenue from ACCOUNTINGALLOCATIONS.LIST.
        JournalPostRequest salesJournal = captor.getAllValues().get(0);
        assertThat(salesJournal.effectiveDate().toString()).isEqualTo("2025-04-01");
        assertThat(salesJournal.sourceModule()).isEqualTo("TALLY_IMPORT");
        assertThat(salesJournal.description()).contains("Sales").contains("S-001").contains("MediMart");
        assertThat(salesJournal.lines()).hasSize(4);

        // Customer (debit, Tally -11200) → AR (1100), debit 11200
        assertThat(salesJournal.lines().get(0).accountCode()).isEqualTo("1100");
        assertThat(salesJournal.lines().get(0).debit()).isEqualByComparingTo("11200");

        // CGST (credit, Tally +600) → 2020, credit 600
        assertThat(salesJournal.lines().get(1).accountCode()).isEqualTo("2020");
        assertThat(salesJournal.lines().get(1).credit()).isEqualByComparingTo("600");

        // SGST (credit, Tally +600) → 2021, credit 600
        assertThat(salesJournal.lines().get(2).accountCode()).isEqualTo("2021");
        assertThat(salesJournal.lines().get(2).credit()).isEqualByComparingTo("600");

        // Sales A/c from ACCOUNTINGALLOCATIONS (credit, Tally +10000) → 4010, credit 10000.
        // BILLALLOCATIONS (-11200) and BATCHALLOCATIONS (10000) must NOT be counted.
        assertThat(salesJournal.lines().get(3).accountCode()).isEqualTo("4010");
        assertThat(salesJournal.lines().get(3).credit()).isEqualByComparingTo("10000");

        // Sanity: balanced (total Dr = total Cr = 11200)
        assertThat(salesJournal.lines().stream()
                .map(l -> l.debit().subtract(l.credit()))
                .reduce(java.math.BigDecimal.ZERO, java.math.BigDecimal::add))
                .isEqualByComparingTo("0");
    }

    @Test
    void purchaseVoucherUsesInputGstAndVendorAccount() {
        service.importVouchers(DAY_BOOK_XML.getBytes(StandardCharsets.UTF_8));

        ArgumentCaptor<JournalPostRequest> captor = ArgumentCaptor.forClass(JournalPostRequest.class);
        verify(journalService, times(4)).postJournal(captor.capture());

        // Fourth journal = Purchase voucher. Entry order: vendor + input GST
        // from LEDGERENTRIES.LIST, then purchase ledger from ACCOUNTINGALLOCATIONS.LIST.
        JournalPostRequest purchaseJournal = captor.getAllValues().get(3);
        assertThat(purchaseJournal.effectiveDate().toString()).isEqualTo("2025-04-15");

        // Vendor (credit, Tally +22400) → AP (2010), credit 22400
        assertThat(purchaseJournal.lines().get(0).accountCode()).isEqualTo("2010");
        assertThat(purchaseJournal.lines().get(0).credit()).isEqualByComparingTo("22400");

        // Input CGST + Input SGST (debit, Tally -1200) → 1500
        assertThat(purchaseJournal.lines().get(1).accountCode()).isEqualTo("1500");
        assertThat(purchaseJournal.lines().get(1).debit()).isEqualByComparingTo("1200");
        assertThat(purchaseJournal.lines().get(2).accountCode()).isEqualTo("1500");
        assertThat(purchaseJournal.lines().get(2).debit()).isEqualByComparingTo("1200");

        // Purchase A/c from ACCOUNTINGALLOCATIONS (debit, Tally -20000) → 5020, debit 20000
        assertThat(purchaseJournal.lines().get(3).accountCode()).isEqualTo("5020");
        assertThat(purchaseJournal.lines().get(3).debit()).isEqualByComparingTo("20000");
    }

    @Test
    void journalVoucherResolvesBankByPatternMatch() {
        service.importVouchers(DAY_BOOK_XML.getBytes(StandardCharsets.UTF_8));

        ArgumentCaptor<JournalPostRequest> captor = ArgumentCaptor.forClass(JournalPostRequest.class);
        verify(journalService, times(4)).postJournal(captor.capture());

        // Third journal = Journal voucher (Shop Rent DR, HDFC Bank CR)
        JournalPostRequest journalEntry = captor.getAllValues().get(2);

        // Shop Rent → T0001 (from account lookup)
        assertThat(journalEntry.lines().get(0).accountCode()).isEqualTo("T0001");
        assertThat(journalEntry.lines().get(0).debit()).isEqualByComparingTo("15000");

        // HDFC Bank → 1020 (pattern match: contains "bank")
        assertThat(journalEntry.lines().get(1).accountCode()).isEqualTo("1020");
        assertThat(journalEntry.lines().get(1).credit()).isEqualByComparingTo("15000");
    }

    @Test
    void unresolvedLedgerSkipsVoucher() {
        // Remove Shop Rent account — makes it unresolvable
        when(accountRepository.findFirstByOrgIdAndNameIgnoreCaseAndIsDeletedFalse(any(), any()))
                .thenReturn(Optional.empty());

        VoucherImportPreview preview = service.preview(DAY_BOOK_XML.getBytes(StandardCharsets.UTF_8));

        // Journal voucher has "Shop Rent" which is no longer resolvable
        assertThat(preview.skipped()).isEqualTo(1);
        assertThat(preview.importable()).isEqualTo(3);

        var skippedVoucher = preview.vouchers().stream()
                .filter(v -> "SKIP_UNRESOLVED".equals(v.action())).findFirst().orElseThrow();
        assertThat(skippedVoucher.warnings()).anyMatch(w -> w.contains("Shop Rent"));
    }

    @Test
    void rejectsNonDayBookXml() {
        assertThatThrownBy(() ->
                service.preview("<html>not tally</html>".getBytes(StandardCharsets.UTF_8)))
                .hasMessageContaining("No vouchers found");
    }

    @Test
    void resolveLedgerWellKnownNames() {
        assertThat(service.resolveLedger(orgId, "Cash")).isEqualTo("1010");
        assertThat(service.resolveLedger(orgId, "Cash-in-Hand")).isEqualTo("1010");
        assertThat(service.resolveLedger(orgId, "Sales A/c")).isEqualTo("4010");
        assertThat(service.resolveLedger(orgId, "Purchase Account")).isEqualTo("5020");
        assertThat(service.resolveLedger(orgId, "Round Off")).isEqualTo("5600");
        assertThat(service.resolveLedger(orgId, "Bank Charges")).isEqualTo("5280");
        assertThat(service.resolveLedger(orgId, "Axis Bank A/c")).isEqualTo("1020");
    }
}
