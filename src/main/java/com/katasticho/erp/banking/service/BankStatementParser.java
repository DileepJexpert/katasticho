package com.katasticho.erp.banking.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.katasticho.erp.ai.service.ClaudeApiClient;
import com.katasticho.erp.common.exception.BusinessException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.apache.poi.ss.usermodel.*;
import org.springframework.stereotype.Component;

import java.io.ByteArrayInputStream;
import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeFormatterBuilder;
import java.util.*;
import java.util.regex.Pattern;

/**
 * Turns real Indian bank statements (HDFC/ICICI/SBI/Axis/Kotak CSV or XLSX
 * exports, or pasted text) into normalized transaction rows.
 *
 * <p>Strategy: deterministic first — find the header row anywhere in the first
 * 25 lines (banks put account preambles above it), map columns by fuzzy names
 * (Txn Date / Value Date, Narration / Description / Particulars, Withdrawal /
 * Deposit or a single Amount, Chq./Ref.No / UTR), and parse the data rows.
 * If no header can be found, fall back to Claude (text) to extract the rows —
 * token usage lands in {@code ai_usage_log} via the client.
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class BankStatementParser {

    public record ParsedBankRow(
            LocalDate date,
            BigDecimal amount,        // always positive
            String direction,         // CREDIT / DEBIT
            String narration,
            String reference,         // UTR / cheque / ref no
            String payerName,
            String payerVpa
    ) {}

    private static final int HEADER_SCAN_ROWS = 25;
    private static final int AI_TEXT_CAP = 12000;

    private static final List<DateTimeFormatter> DATE_FORMATS = List.of(
            DateTimeFormatter.ofPattern("yyyy-MM-dd"),
            DateTimeFormatter.ofPattern("dd/MM/yyyy"),
            DateTimeFormatter.ofPattern("dd-MM-yyyy"),
            DateTimeFormatter.ofPattern("dd/MM/yy"),
            DateTimeFormatter.ofPattern("dd-MM-yy"),
            DateTimeFormatter.ofPattern("MM/dd/yyyy"),
            caseInsensitive("dd MMM yyyy"),
            caseInsensitive("dd-MMM-yyyy"),
            caseInsensitive("dd-MMM-yy")
    );

    private static DateTimeFormatter caseInsensitive(String pattern) {
        return new DateTimeFormatterBuilder().parseCaseInsensitive()
                .appendPattern(pattern).toFormatter(Locale.ENGLISH);
    }

    private static final Pattern CSV_SPLIT =
            Pattern.compile(",(?=(?:[^\"]*\"[^\"]*\")*[^\"]*$)");

    private final ClaudeApiClient claudeApiClient;
    private final ObjectMapper objectMapper;

    // ── Entry points ─────────────────────────────────────────────────────

    /** Parse an uploaded statement file (.csv/.txt or .xlsx/.xls). */
    public List<ParsedBankRow> parseFile(String filename, byte[] bytes) {
        String lower = filename == null ? "" : filename.toLowerCase(Locale.ROOT);
        if (lower.endsWith(".xlsx") || lower.endsWith(".xls")) {
            List<ParsedBankRow> rows = fromGrid(readExcelGrid(bytes));
            if (!rows.isEmpty()) return rows;
            throw new BusinessException(
                    "Could not find transaction rows in the Excel statement — "
                            + "export it as CSV from your bank and try again",
                    "BANK_STATEMENT_UNREADABLE");
        }
        return parseText(new String(bytes, StandardCharsets.UTF_8));
    }

    /** Parse pasted/decoded statement text — deterministic, then AI fallback. */
    public List<ParsedBankRow> parseText(String text) {
        List<ParsedBankRow> rows = fromGrid(textGrid(text));
        if (!rows.isEmpty()) return rows;
        return aiParse(text);
    }

    // ── Deterministic path ───────────────────────────────────────────────

    List<ParsedBankRow> fromGrid(List<List<String>> grid) {
        int headerIdx = findHeaderRow(grid);
        if (headerIdx < 0) return List.of();
        ColumnMap cols = mapColumns(grid.get(headerIdx));
        if (!cols.usable()) return List.of();

        List<ParsedBankRow> rows = new ArrayList<>();
        for (int i = headerIdx + 1; i < grid.size(); i++) {
            List<String> row = grid.get(i);
            LocalDate date = parseDate(cell(row, cols.date));
            if (date == null) continue; // footer / balance / blank rows

            BigDecimal debit = parseAmount(cell(row, cols.debit));
            BigDecimal credit = parseAmount(cell(row, cols.credit));
            BigDecimal amount;
            String direction;
            if (credit != null && credit.signum() != 0) {
                amount = credit.abs();
                direction = "CREDIT";
            } else if (debit != null && debit.signum() != 0) {
                amount = debit.abs();
                direction = "DEBIT";
            } else {
                BigDecimal single = parseAmount(cell(row, cols.amount));
                if (single == null || single.signum() == 0) continue;
                String explicit = upper(cell(row, cols.direction));
                direction = explicit != null && (explicit.startsWith("D") || explicit.startsWith("W"))
                        ? "DEBIT"
                        : explicit != null ? "CREDIT"
                        : (single.signum() >= 0 ? "CREDIT" : "DEBIT");
                amount = single.abs();
            }

            rows.add(new ParsedBankRow(
                    date, amount, direction,
                    cell(row, cols.narration),
                    cell(row, cols.reference),
                    cell(row, cols.payerName),
                    cell(row, cols.payerVpa)));
        }
        return rows;
    }

    private int findHeaderRow(List<List<String>> grid) {
        int limit = Math.min(grid.size(), HEADER_SCAN_ROWS);
        for (int i = 0; i < limit; i++) {
            boolean hasDate = false, hasMoney = false, hasNarration = false;
            for (String raw : grid.get(i)) {
                String h = normalizeHeader(raw);
                if (h.contains("date")) hasDate = true;
                if (h.contains("amount") || h.contains("withdrawal") || h.contains("deposit")
                        || h.equals("debit") || h.equals("credit")
                        || h.contains("debitamt") || h.contains("creditamt")
                        || h.contains("dramount") || h.contains("cramount")) hasMoney = true;
                if (h.contains("narration") || h.contains("description") || h.contains("particulars")
                        || h.contains("remarks") || h.contains("details")) hasNarration = true;
            }
            if (hasDate && (hasMoney || hasNarration)) return i;
        }
        return -1;
    }

    private record ColumnMap(int date, int narration, int debit, int credit,
                             int amount, int direction, int reference,
                             int payerName, int payerVpa) {
        boolean usable() {
            return date >= 0 && (amount >= 0 || debit >= 0 || credit >= 0);
        }
    }

    private ColumnMap mapColumns(List<String> header) {
        int date = -1, narration = -1, debit = -1, credit = -1,
                amount = -1, direction = -1, reference = -1, payerName = -1, payerVpa = -1;
        for (int i = 0; i < header.size(); i++) {
            String h = normalizeHeader(header.get(i));
            if (h.isEmpty()) continue;
            // Prefer the transaction date over the value date when both exist.
            if (date < 0 && (h.equals("date") || h.contains("txndate") || h.contains("transactiondate")
                    || h.contains("trandate") || h.contains("postdate"))) date = i;
            else if (date < 0 && h.contains("valuedate")) date = i;
            else if (narration < 0 && (h.contains("narration") || h.contains("description")
                    || h.contains("particulars") || h.contains("remarks") || h.contains("details"))) narration = i;
            else if (debit < 0 && (h.contains("withdrawal") || h.equals("debit")
                    || h.contains("debitamt") || h.contains("dramount") || h.equals("dr"))) debit = i;
            else if (credit < 0 && (h.contains("deposit") || h.equals("credit")
                    || h.contains("creditamt") || h.contains("cramount") || h.equals("cr"))) credit = i;
            else if (amount < 0 && h.contains("amount") && !h.contains("balance")) amount = i;
            else if (direction < 0 && (h.equals("direction") || h.equals("type") || h.equals("drcr"))) direction = i;
            else if (reference < 0 && (h.contains("utr") || h.contains("chq") || h.contains("cheque")
                    || h.contains("refno") || h.contains("reference"))) reference = i;
            else if (payerName < 0 && h.contains("payername")) payerName = i;
            else if (payerVpa < 0 && (h.contains("payervpa") || h.contains("vpa"))) payerVpa = i;
        }
        return new ColumnMap(date, narration, debit, credit, amount, direction,
                reference, payerName, payerVpa);
    }

    // ── AI fallback ──────────────────────────────────────────────────────

    private static final String AI_SYSTEM_PROMPT = """
            You extract bank statement transactions from raw text (any Indian bank format).
            Reply with ONLY a JSON array, no markdown, no commentary. Each element:
            {"date":"YYYY-MM-DD","amount":123.45,"direction":"CREDIT|DEBIT","narration":"...","reference":"UTR/cheque or null"}
            direction: CREDIT = money received into the account (deposit), DEBIT = money paid out (withdrawal).
            amount is always positive. Skip opening/closing balance lines and non-transaction rows.
            If you find no transactions, reply with [].
            """;

    List<ParsedBankRow> aiParse(String text) {
        String capped = text == null ? "" : text.strip();
        if (capped.isEmpty()) {
            throw new BusinessException("The statement is empty", "BANK_STATEMENT_EMPTY");
        }
        if (capped.length() > AI_TEXT_CAP) capped = capped.substring(0, AI_TEXT_CAP);

        String response;
        try {
            response = claudeApiClient.sendMessage(AI_SYSTEM_PROMPT, capped);
        } catch (Exception e) {
            throw new BusinessException(
                    "Could not read this statement format automatically and the AI parser is unavailable ("
                            + e.getMessage() + "). Export CSV from your bank with date/amount/narration columns.",
                    "BANK_STATEMENT_UNREADABLE");
        }

        try {
            String cleaned = response.strip();
            if (cleaned.startsWith("```")) {
                cleaned = cleaned.replaceAll("^```(?:json)?\\s*", "").replaceAll("```\\s*$", "");
            }
            JsonNode root = objectMapper.readTree(cleaned);
            if (!root.isArray()) throw new IllegalArgumentException("not a JSON array");
            List<ParsedBankRow> rows = new ArrayList<>();
            for (JsonNode n : root) {
                LocalDate date = parseDate(n.path("date").asText(null));
                BigDecimal amount = parseAmount(n.path("amount").asText(null));
                if (date == null || amount == null || amount.signum() == 0) continue;
                String direction = "DEBIT".equalsIgnoreCase(n.path("direction").asText(""))
                        ? "DEBIT" : "CREDIT";
                rows.add(new ParsedBankRow(date, amount.abs(), direction,
                        n.path("narration").asText(null),
                        n.path("reference").asText(null), null, null));
            }
            if (rows.isEmpty()) {
                throw new BusinessException(
                        "No transactions could be extracted from this statement",
                        "BANK_STATEMENT_EMPTY");
            }
            log.info("Bank statement AI parse extracted {} rows", rows.size());
            return rows;
        } catch (BusinessException e) {
            throw e;
        } catch (Exception e) {
            throw new BusinessException(
                    "AI could not extract transactions from this statement (" + e.getMessage() + ")",
                    "BANK_STATEMENT_UNREADABLE");
        }
    }

    // ── Grids ────────────────────────────────────────────────────────────

    private List<List<String>> textGrid(String text) {
        if (text == null || text.isBlank()) return List.of();
        List<List<String>> grid = new ArrayList<>();
        for (String line : text.lines().toList()) {
            if (line.isBlank()) continue;
            // Banks export comma CSVs; pasted netbanking tables are often tab-separated.
            String[] cells = line.contains("\t")
                    ? line.split("\t", -1)
                    : CSV_SPLIT.split(line, -1);
            List<String> row = new ArrayList<>(cells.length);
            for (String cell : cells) row.add(unquote(cell));
            grid.add(row);
        }
        return grid;
    }

    private List<List<String>> readExcelGrid(byte[] bytes) {
        try (Workbook workbook = WorkbookFactory.create(new ByteArrayInputStream(bytes))) {
            DataFormatter formatter = new DataFormatter();
            Sheet sheet = workbook.getSheetAt(0);
            List<List<String>> grid = new ArrayList<>();
            for (Row row : sheet) {
                List<String> cells = new ArrayList<>();
                short last = row.getLastCellNum();
                for (int c = 0; c < last; c++) {
                    Cell cell = row.getCell(c, Row.MissingCellPolicy.RETURN_BLANK_AS_NULL);
                    if (cell != null && cell.getCellType() == CellType.NUMERIC
                            && DateUtil.isCellDateFormatted(cell)) {
                        cells.add(cell.getLocalDateTimeCellValue().toLocalDate().toString());
                    } else {
                        cells.add(cell == null ? "" : formatter.formatCellValue(cell).trim());
                    }
                }
                grid.add(cells);
            }
            return grid;
        } catch (Exception e) {
            throw new BusinessException(
                    "Could not read the Excel file (" + e.getMessage() + ")",
                    "BANK_STATEMENT_UNREADABLE");
        }
    }

    // ── Cell parsing ─────────────────────────────────────────────────────

    static LocalDate parseDate(String raw) {
        if (raw == null || raw.isBlank()) return null;
        String v = raw.trim();
        for (DateTimeFormatter f : DATE_FORMATS) {
            try {
                return LocalDate.parse(v, f);
            } catch (Exception ignored) { }
        }
        return null;
    }

    static BigDecimal parseAmount(String raw) {
        if (raw == null || raw.isBlank()) return null;
        String v = raw.trim()
                .replace("₹", "").replace("INR", "").replace(",", "")
                .replaceAll("(?i)\\s*(cr|dr)\\.?$", "")
                .trim();
        boolean negative = v.startsWith("(") && v.endsWith(")");
        if (negative) v = v.substring(1, v.length() - 1);
        if (v.isBlank() || v.equals("-")) return null;
        try {
            BigDecimal d = new BigDecimal(v);
            return negative ? d.negate() : d;
        } catch (NumberFormatException e) {
            return null;
        }
    }

    private static String cell(List<String> row, int idx) {
        if (idx < 0 || idx >= row.size()) return null;
        String v = row.get(idx);
        return v == null || v.isBlank() ? null : v.trim();
    }

    private static String upper(String s) {
        return s == null ? null : s.trim().toUpperCase(Locale.ROOT);
    }

    private static String normalizeHeader(String value) {
        return value == null ? "" : value.replaceAll("[^A-Za-z]", "").toLowerCase(Locale.ROOT);
    }

    private static String unquote(String value) {
        String trimmed = value == null ? "" : value.trim();
        if (trimmed.startsWith("\"") && trimmed.endsWith("\"") && trimmed.length() >= 2) {
            return trimmed.substring(1, trimmed.length() - 1).replace("\"\"", "\"");
        }
        return trimmed;
    }
}
