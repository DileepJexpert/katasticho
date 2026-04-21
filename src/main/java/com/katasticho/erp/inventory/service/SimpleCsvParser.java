package com.katasticho.erp.inventory.service;

import java.io.IOException;
import java.io.Reader;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Tiny RFC 4180 CSV parser. Just enough for the bulk item import — no
 * external dependency, no streaming optimisations, no charset detection.
 *
 * Supports:
 *   - Comma-separated fields
 *   - Quoted fields containing commas, newlines, and "" escaped quotes
 *   - Header row (first row) used as the map key for each subsequent row
 *   - Trims whitespace around unquoted fields
 *
 * Returns a list of {@code Map<header, value>} — small files only (a few
 * thousand items at most, which is the realistic ceiling for one upload).
 */
public final class SimpleCsvParser {

    private SimpleCsvParser() {}

    public static List<Map<String, String>> parse(Reader reader) throws IOException {
        List<List<String>> rows = readAllRows(reader);
        if (rows.isEmpty()) {
            return Collections.emptyList();
        }

        List<String> headers = new ArrayList<>(rows.get(0).size());
        for (String h : rows.get(0)) {
            headers.add(h == null ? "" : h.trim().toLowerCase());
        }

        List<Map<String, String>> result = new ArrayList<>(rows.size() - 1);
        for (int i = 1; i < rows.size(); i++) {
            List<String> row = rows.get(i);
            if (row.isEmpty() || (row.size() == 1 && (row.get(0) == null || row.get(0).isBlank()))) {
                continue; // skip blank lines
            }
            Map<String, String> map = new HashMap<>();
            for (int c = 0; c < headers.size(); c++) {
                String value = c < row.size() ? row.get(c) : null;
                map.put(headers.get(c), value);
            }
            result.add(map);
        }
        return result;
    }

    private static List<List<String>> readAllRows(Reader reader) throws IOException {
        List<List<String>> rows = new ArrayList<>();
        List<String> currentRow = new ArrayList<>();
        StringBuilder field = new StringBuilder();
        boolean inQuotes = false;
        int prev = -1;
        int c;
        while ((c = reader.read()) != -1) {
            char ch = (char) c;
            if (inQuotes) {
                if (ch == '"') {
                    int next = reader.read();
                    if (next == '"') {
                        field.append('"');     // escaped quote
                    } else {
                        inQuotes = false;
                        if (next == -1) {
                            currentRow.add(field.toString());
                            field.setLength(0);
                            rows.add(currentRow);
                            return rows;
                        }
                        ch = (char) next;
                        // fall through to handle this char outside quotes
                        if (ch == ',') {
                            currentRow.add(field.toString());
                            field.setLength(0);
                        } else if (ch == '\n' || ch == '\r') {
                            currentRow.add(field.toString());
                            field.setLength(0);
                            rows.add(currentRow);
                            currentRow = new ArrayList<>();
                            if (ch == '\r') {
                                int peek = reader.read();
                                if (peek != -1 && peek != '\n') {
                                    // Not a CRLF — push back by handling it now
                                    char pc = (char) peek;
                                    if (pc == '"') {
                                        inQuotes = true;
                                    } else if (pc == ',') {
                                        currentRow.add("");
                                    } else {
                                        field.append(pc);
                                    }
                                }
                            }
                        } else {
                            field.append(ch);
                        }
                    }
                } else {
                    field.append(ch);
                }
            } else {
                if (ch == '"' && field.length() == 0) {
                    inQuotes = true;
                } else if (ch == ',') {
                    currentRow.add(trimUnquoted(field.toString()));
                    field.setLength(0);
                } else if (ch == '\r') {
                    currentRow.add(trimUnquoted(field.toString()));
                    field.setLength(0);
                    rows.add(currentRow);
                    currentRow = new ArrayList<>();
                    int next = reader.read();
                    if (next != -1 && next != '\n') {
                        // Bare CR row separator — process the next char
                        char nc = (char) next;
                        if (nc == '"') {
                            inQuotes = true;
                        } else if (nc == ',') {
                            currentRow.add("");
                        } else {
                            field.append(nc);
                        }
                    }
                } else if (ch == '\n') {
                    currentRow.add(trimUnquoted(field.toString()));
                    field.setLength(0);
                    rows.add(currentRow);
                    currentRow = new ArrayList<>();
                } else {
                    field.append(ch);
                }
            }
            prev = c;
        }

        // Flush the last field / row if the file did not end with a newline.
        if (field.length() > 0 || !currentRow.isEmpty()) {
            currentRow.add(inQuotes ? field.toString() : trimUnquoted(field.toString()));
            rows.add(currentRow);
        }
        return rows;
    }

    private static String trimUnquoted(String s) {
        return s == null ? null : s.trim();
    }
}
