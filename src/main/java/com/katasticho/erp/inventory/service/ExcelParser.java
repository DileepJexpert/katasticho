package com.katasticho.erp.inventory.service;

import org.apache.poi.ss.usermodel.*;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;

import java.io.IOException;
import java.io.InputStream;
import java.util.*;

/**
 * Parses XLSX files into the same {@code List<Map<String, String>>} shape
 * as {@link SimpleCsvParser} so the import pipeline is format-agnostic.
 */
final class ExcelParser {

    private ExcelParser() {}

    static List<Map<String, String>> parse(InputStream is) throws IOException {
        try (Workbook wb = new XSSFWorkbook(is)) {
            Sheet sheet = wb.getSheetAt(0);
            if (sheet == null || sheet.getPhysicalNumberOfRows() == 0) {
                return Collections.emptyList();
            }

            Row headerRow = sheet.getRow(0);
            if (headerRow == null) return Collections.emptyList();

            List<String> headers = new ArrayList<>();
            for (int c = 0; c < headerRow.getLastCellNum(); c++) {
                Cell cell = headerRow.getCell(c, Row.MissingCellPolicy.CREATE_NULL_AS_BLANK);
                String h = cellToString(cell);
                headers.add(h == null ? "" : h.trim().toLowerCase());
            }

            List<Map<String, String>> result = new ArrayList<>();
            for (int r = 1; r <= sheet.getLastRowNum(); r++) {
                Row row = sheet.getRow(r);
                if (row == null) continue;

                boolean allBlank = true;
                Map<String, String> map = new HashMap<>();
                for (int c = 0; c < headers.size(); c++) {
                    Cell cell = row.getCell(c, Row.MissingCellPolicy.CREATE_NULL_AS_BLANK);
                    String value = cellToString(cell);
                    if (value != null && !value.isBlank()) allBlank = false;
                    map.put(headers.get(c), value);
                }
                if (!allBlank) result.add(map);
            }
            return result;
        }
    }

    private static String cellToString(Cell cell) {
        if (cell == null) return null;
        return switch (cell.getCellType()) {
            case STRING -> cell.getStringCellValue();
            case NUMERIC -> {
                if (DateUtil.isCellDateFormatted(cell)) {
                    var ld = cell.getLocalDateTimeCellValue().toLocalDate();
                    yield ld.toString();
                }
                double d = cell.getNumericCellValue();
                if (d == Math.floor(d) && !Double.isInfinite(d)) {
                    yield String.valueOf((long) d);
                }
                yield String.valueOf(d);
            }
            case BOOLEAN -> String.valueOf(cell.getBooleanCellValue());
            case FORMULA -> {
                try {
                    yield String.valueOf(cell.getNumericCellValue());
                } catch (Exception e) {
                    yield cell.getStringCellValue();
                }
            }
            default -> null;
        };
    }
}
