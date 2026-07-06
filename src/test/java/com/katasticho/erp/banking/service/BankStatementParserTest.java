package com.katasticho.erp.banking.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.katasticho.erp.ai.service.VisionModelRouter;
import com.katasticho.erp.banking.service.BankStatementParser.ParsedBankRow;
import org.junit.jupiter.api.Test;

import java.time.LocalDate;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class BankStatementParserTest {

    private final VisionModelRouter claudeApiClient = mock(VisionModelRouter.class);
    private final BankStatementParser parser =
            new BankStatementParser(claudeApiClient, new ObjectMapper());

    @Test
    void parsesHdfcStyleStatementWithPreambleAndSplitColumns() {
        // Real bank exports put account info above the header and split
        // withdrawals/deposits into separate columns.
        String csv = """
                HDFC BANK Ltd.
                Account No,50100123456789
                Statement of account for the period 01/04/2026 to 30/04/2026

                Txn Date,Value Date,Narration,Chq./Ref.No.,Withdrawal Amt.,Deposit Amt.,Closing Balance
                03/04/26,03/04/26,UPI-MEDIMART DISTRIBUTORS-PAY,UPI509812345678,,"15,000.00","1,15,000.00"
                05/04/26,05/04/26,NEFT-ABC PHARMA SUPPLIES-INV-77,NEFT000123,"22,000.00",,93000.00
                Closing Balance,,,,,,"93,000.00"
                """;

        List<ParsedBankRow> rows = parser.parseText(csv);

        assertThat(rows).hasSize(2);
        ParsedBankRow credit = rows.get(0);
        assertThat(credit.date()).isEqualTo(LocalDate.of(2026, 4, 3));
        assertThat(credit.direction()).isEqualTo("CREDIT");
        assertThat(credit.amount()).isEqualByComparingTo("15000.00");
        assertThat(credit.narration()).contains("MEDIMART");
        assertThat(credit.reference()).isEqualTo("UPI509812345678");

        ParsedBankRow debit = rows.get(1);
        assertThat(debit.direction()).isEqualTo("DEBIT");
        assertThat(debit.amount()).isEqualByComparingTo("22000.00");

        verify(claudeApiClient, never()).sendMessage(anyString(), anyString());
    }

    @Test
    void parsesLegacySimpleFormat() {
        String csv = """
                date,amount,narration,direction,utr
                2026-04-03,15000,UPI from MediMart,CREDIT,UTR123
                2026-04-05,-2200,ATM withdrawal,,
                """;

        List<ParsedBankRow> rows = parser.parseText(csv);

        assertThat(rows).hasSize(2);
        assertThat(rows.get(0).direction()).isEqualTo("CREDIT");
        assertThat(rows.get(0).reference()).isEqualTo("UTR123");
        // Negative single-amount with no direction column → DEBIT.
        assertThat(rows.get(1).direction()).isEqualTo("DEBIT");
        assertThat(rows.get(1).amount()).isEqualByComparingTo("2200");
    }

    @Test
    void singleAmountColumnHonoursInlineCrDrSuffix() {
        // Indian PSU/co-op export: one amount column with inline Dr/Cr. The suffix
        // must win over the (positive) sign so a debit isn't misread as a credit.
        String csv = """
                Date,Particulars,Ref,Amount,Balance
                01/01/2024,Vendor payment,REF1,"5,000.00 Dr","95,000.00"
                02/01/2024,Customer receipt,REF2,"1,200.00 Cr","96,200.00"
                """;

        List<ParsedBankRow> rows = parser.parseText(csv);

        assertThat(rows).hasSize(2);
        assertThat(rows.get(0).direction()).isEqualTo("DEBIT");
        assertThat(rows.get(0).amount()).isEqualByComparingTo("5000.00");
        assertThat(rows.get(1).direction()).isEqualTo("CREDIT");
        assertThat(rows.get(1).amount()).isEqualByComparingTo("1200.00");
    }

    @Test
    void parsesMonthNameDates() {
        String csv = """
                Date,Description,Debit,Credit
                01-Apr-26,Opening payment to vendor,5000,
                02 Apr 2026,Customer collection,,7500
                """;

        List<ParsedBankRow> rows = parser.parseText(csv);

        assertThat(rows).hasSize(2);
        assertThat(rows.get(0).date()).isEqualTo(LocalDate.of(2026, 4, 1));
        assertThat(rows.get(1).date()).isEqualTo(LocalDate.of(2026, 4, 2));
    }

    @Test
    void fallsBackToAiWhenNoHeaderFound() {
        when(claudeApiClient.sendMessage(anyString(), anyString())).thenReturn("""
                [{"date":"2026-04-03","amount":15000,"direction":"CREDIT","narration":"UPI from MediMart","reference":"UTR123"}]
                """);

        List<ParsedBankRow> rows = parser.parseText(
                "03 Apr — received 15,000 by UPI from MediMart ref UTR123");

        assertThat(rows).hasSize(1);
        assertThat(rows.get(0).amount()).isEqualByComparingTo("15000");
        assertThat(rows.get(0).direction()).isEqualTo("CREDIT");
        verify(claudeApiClient).sendMessage(anyString(), anyString());
    }

    @Test
    void amountParsingHandlesIndianFormats() {
        assertThat(BankStatementParser.parseAmount("\"1,15,000.00\"")).isNull(); // quoted handled upstream
        assertThat(BankStatementParser.parseAmount("1,15,000.00")).isEqualByComparingTo("115000.00");
        assertThat(BankStatementParser.parseAmount("₹500.50")).isEqualByComparingTo("500.50");
        assertThat(BankStatementParser.parseAmount("2200 Cr")).isEqualByComparingTo("2200");
        assertThat(BankStatementParser.parseAmount("(300)")).isEqualByComparingTo("-300");
        assertThat(BankStatementParser.parseAmount("-")).isNull();
    }
}
