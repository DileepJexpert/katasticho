package com.katasticho.erp.migration.tally;

import com.katasticho.erp.accounting.dto.report.TrialBalanceResponse;
import com.katasticho.erp.accounting.dto.report.TrialBalanceResponse.TrialBalanceLine;
import com.katasticho.erp.accounting.entity.Account;
import com.katasticho.erp.accounting.entity.JournalEntry;
import com.katasticho.erp.accounting.entity.JournalLine;
import com.katasticho.erp.accounting.repository.AccountRepository;
import com.katasticho.erp.accounting.repository.JournalEntryRepository;
import com.katasticho.erp.accounting.service.FinancialReportService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.migration.tally.TallyImportDtos.TbVerificationResult;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

class TallyCaBridgeServiceTest {

    private final FinancialReportService financialReportService = mock(FinancialReportService.class);
    private final JournalEntryRepository journalEntryRepository = mock(JournalEntryRepository.class);
    private final AccountRepository accountRepository = mock(AccountRepository.class);
    private final ContactRepository contactRepository = mock(ContactRepository.class);
    private final ItemRepository itemRepository = mock(ItemRepository.class);

    private final TallyCaBridgeService service = new TallyCaBridgeService(
            new TallyXmlParser(), financialReportService, journalEntryRepository, accountRepository,
            contactRepository, itemRepository);

    private final UUID orgId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        TenantContext.setCurrentOrgId(orgId);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    // ── Trial Balance verification ──────────────────────────────────────

    /**
     * Tally TB report XML: Cash (15000 Dr) matches; Sales (10000 Cr in Tally,
     * 9000 Cr in our books) mismatches; Rent (5000 Dr) only in Tally.
     */
    private static final String TB_XML = """
            <ENVELOPE>
             <BODY><DATA>
              <TALLYMESSAGE>
               <DSPACCNAME><DSPDISPNAME>Cash</DSPDISPNAME></DSPACCNAME>
               <DSPACCINFO>
                <DSPCLDRAMT><DSPCLDRAMTA>15000.00</DSPCLDRAMTA></DSPCLDRAMT>
                <DSPCLCRAMT><DSPCLCRAMTA/></DSPCLCRAMT>
               </DSPACCINFO>
              </TALLYMESSAGE>
              <TALLYMESSAGE>
               <DSPACCNAME><DSPDISPNAME>Sales A/c</DSPDISPNAME></DSPACCNAME>
               <DSPACCINFO>
                <DSPCLDRAMT><DSPCLDRAMTA/></DSPCLDRAMT>
                <DSPCLCRAMT><DSPCLCRAMTA>10000.00</DSPCLCRAMTA></DSPCLCRAMT>
               </DSPACCINFO>
              </TALLYMESSAGE>
              <TALLYMESSAGE>
               <DSPACCNAME><DSPDISPNAME>Shop Rent</DSPDISPNAME></DSPACCNAME>
               <DSPACCINFO>
                <DSPCLDRAMT><DSPCLDRAMTA>5000.00</DSPCLDRAMTA></DSPCLDRAMT>
                <DSPCLCRAMT><DSPCLCRAMTA/></DSPCLCRAMT>
               </DSPACCINFO>
              </TALLYMESSAGE>
             </DATA></BODY>
            </ENVELOPE>
            """;

    @Test
    void verifyClassifiesMatchMismatchAndMissing() {
        // Our books: Cash 15000 Dr (match), Sales 9000 Cr (mismatch vs 10000),
        // Bank 2000 Dr (only in our books).
        TrialBalanceResponse ours = new TrialBalanceResponse(
                LocalDate.of(2025, 3, 31), "INR",
                new BigDecimal("17000"), new BigDecimal("9000"), false,
                List.of(
                        line("Cash", new BigDecimal("15000"), BigDecimal.ZERO),
                        line("Sales A/c", BigDecimal.ZERO, new BigDecimal("9000")),
                        line("Bank Account", new BigDecimal("2000"), BigDecimal.ZERO)
                ));
        when(financialReportService.generateTrialBalance(any())).thenReturn(ours);

        TbVerificationResult result = service.verifyTrialBalance(
                TB_XML.getBytes(StandardCharsets.UTF_8), LocalDate.of(2025, 3, 31));

        assertThat(result.matched()).isEqualTo(1);          // Cash
        assertThat(result.mismatched()).isEqualTo(1);       // Sales A/c
        assertThat(result.missingInBooks()).isEqualTo(1);   // Shop Rent (Tally only)
        assertThat(result.missingInTally()).isEqualTo(1);   // Bank Account (books only)

        var cash = result.lines().stream().filter(l -> l.name().equals("Cash")).findFirst().orElseThrow();
        assertThat(cash.status()).isEqualTo("MATCHED");
        assertThat(cash.difference()).isEqualByComparingTo("0");

        var sales = result.lines().stream().filter(l -> l.name().equals("Sales A/c")).findFirst().orElseThrow();
        assertThat(sales.status()).isEqualTo("MISMATCH");
        // ours −9000, tally −10000 → diff = −9000 − (−10000) = +1000
        assertThat(sales.difference()).isEqualByComparingTo("1000");

        var rent = result.lines().stream().filter(l -> l.name().equals("Shop Rent")).findFirst().orElseThrow();
        assertThat(rent.status()).isEqualTo("MISSING_IN_BOOKS");
    }

    @Test
    void verifyOrdersProblemsFirst() {
        TrialBalanceResponse ours = new TrialBalanceResponse(
                LocalDate.of(2025, 3, 31), "INR", BigDecimal.ZERO, BigDecimal.ZERO, true,
                List.of(line("Cash", new BigDecimal("15000"), BigDecimal.ZERO)));
        when(financialReportService.generateTrialBalance(any())).thenReturn(ours);

        TbVerificationResult result = service.verifyTrialBalance(
                TB_XML.getBytes(StandardCharsets.UTF_8), LocalDate.of(2025, 3, 31));

        // First line is a problem, not the MATCHED Cash row.
        assertThat(result.lines().get(0).status()).isNotEqualTo("MATCHED");
    }

    @Test
    void verifyRejectsNonTbXml() {
        TrialBalanceResponse ours = new TrialBalanceResponse(
                LocalDate.now(), "INR", BigDecimal.ZERO, BigDecimal.ZERO, true, List.of());
        when(financialReportService.generateTrialBalance(any())).thenReturn(ours);

        assertThatThrownBy(() -> service.verifyTrialBalance(
                "<html>nope</html>".getBytes(StandardCharsets.UTF_8), LocalDate.now()))
                .hasMessageContaining("No Trial Balance rows");
    }

    // ── Tally XML voucher export ────────────────────────────────────────

    @Test
    void exportProducesTallyImportableXmlWithCorrectSigns() {
        UUID arId = UUID.randomUUID();
        UUID salesId = UUID.randomUUID();

        Account ar = new Account();
        ar.setId(arId);
        ar.setName("Accounts Receivable");
        Account sales = new Account();
        sales.setId(salesId);
        sales.setName("Sales Revenue");
        when(accountRepository.findByOrgIdAndIsDeletedFalseOrderByCode(orgId))
                .thenReturn(List.of(ar, sales));

        JournalEntry entry = JournalEntry.builder()
                .orgId(orgId)
                .entryNumber("JV-0001")
                .effectiveDate(LocalDate.of(2025, 4, 1))
                .description("Sale to customer")
                .sourceModule("SALES")
                .status("POSTED")
                .build();
        entry.getLines().add(JournalLine.builder()
                .accountId(arId).baseDebit(new BigDecimal("11200")).baseCredit(BigDecimal.ZERO).build());
        entry.getLines().add(JournalLine.builder()
                .accountId(salesId).baseDebit(BigDecimal.ZERO).baseCredit(new BigDecimal("11200")).build());

        when(journalEntryRepository.findPostedWithLinesInRange(any(), any(), any()))
                .thenReturn(List.of(entry));

        String xml = service.exportVouchersXml(LocalDate.of(2025, 4, 1), LocalDate.of(2025, 4, 30));

        assertThat(xml).contains("<TALLYREQUEST>Import Data</TALLYREQUEST>");
        assertThat(xml).contains("VCHTYPE=\"Sales\"");
        assertThat(xml).contains("<DATE>20250401</DATE>");
        assertThat(xml).contains("<VOUCHERNUMBER>JV-0001</VOUCHERNUMBER>");
        assertThat(xml).contains("<NARRATION>Sale to customer</NARRATION>");
        // Debit line: AR, negative amount, ISDEEMEDPOSITIVE Yes
        assertThat(xml).contains("<LEDGERNAME>Accounts Receivable</LEDGERNAME>");
        assertThat(xml).contains("<ISDEEMEDPOSITIVE>Yes</ISDEEMEDPOSITIVE>");
        assertThat(xml).contains("<AMOUNT>-11200</AMOUNT>");
        // Credit line: Sales, positive amount, ISDEEMEDPOSITIVE No
        assertThat(xml).contains("<LEDGERNAME>Sales Revenue</LEDGERNAME>");
        assertThat(xml).contains("<ISDEEMEDPOSITIVE>No</ISDEEMEDPOSITIVE>");
        assertThat(xml).contains("<AMOUNT>11200</AMOUNT>");
    }

    @Test
    void exportEscapesXmlSpecialCharsInLedgerNames() {
        UUID id = UUID.randomUUID();
        Account a = new Account();
        a.setId(id);
        a.setName("Tom & Jerry <Traders>");
        when(accountRepository.findByOrgIdAndIsDeletedFalseOrderByCode(orgId)).thenReturn(List.of(a));

        JournalEntry entry = JournalEntry.builder()
                .orgId(orgId).entryNumber("JV-1").effectiveDate(LocalDate.of(2025, 4, 1))
                .sourceModule("JOURNAL").status("POSTED").build();
        entry.getLines().add(JournalLine.builder()
                .accountId(id).baseDebit(new BigDecimal("100")).baseCredit(BigDecimal.ZERO).build());
        when(journalEntryRepository.findPostedWithLinesInRange(any(), any(), any()))
                .thenReturn(List.of(entry));

        String xml = service.exportVouchersXml(LocalDate.of(2025, 4, 1), LocalDate.of(2025, 4, 30));

        assertThat(xml).contains("Tom &amp; Jerry &lt;Traders&gt;");
        assertThat(xml).doesNotContain("Tom & Jerry <Traders>");
    }

    @Test
    void exportRejectsInvalidRange() {
        assertThatThrownBy(() -> service.exportVouchersXml(
                LocalDate.of(2025, 4, 30), LocalDate.of(2025, 4, 1)))
                .hasMessageContaining("must not be after");
    }

    @Test
    void voucherTypeMapping() {
        assertThat(TallyCaBridgeService.voucherTypeFor("SALES")).isEqualTo("Sales");
        assertThat(TallyCaBridgeService.voucherTypeFor("AR_INVOICE")).isEqualTo("Sales");
        assertThat(TallyCaBridgeService.voucherTypeFor("PURCHASE_BILL")).isEqualTo("Purchase");
        assertThat(TallyCaBridgeService.voucherTypeFor("AR_RECEIPT")).isEqualTo("Receipt");
        assertThat(TallyCaBridgeService.voucherTypeFor("AP_PAYMENT")).isEqualTo("Payment");
        assertThat(TallyCaBridgeService.voucherTypeFor("POS")).isEqualTo("Receipt");
        assertThat(TallyCaBridgeService.voucherTypeFor("PAYROLL")).isEqualTo("Journal");
        assertThat(TallyCaBridgeService.voucherTypeFor(null)).isEqualTo("Journal");
    }

    private static TrialBalanceLine line(String name, BigDecimal debit, BigDecimal credit) {
        return new TrialBalanceLine(UUID.randomUUID(), null, name, "ASSET",
                debit, credit, debit.subtract(credit));
    }
}
