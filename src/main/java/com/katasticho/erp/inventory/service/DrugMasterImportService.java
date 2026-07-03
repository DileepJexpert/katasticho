package com.katasticho.erp.inventory.service;

import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.inventory.dto.DrugMasterImportResult;
import com.katasticho.erp.inventory.entity.DrugMaster;
import com.katasticho.erp.inventory.entity.ManufacturerMaster;
import com.katasticho.erp.inventory.entity.SaltMaster;
import com.katasticho.erp.inventory.repository.DrugMasterRepository;
import com.katasticho.erp.inventory.repository.ManufacturerMasterRepository;
import com.katasticho.erp.inventory.repository.SaltMasterRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

/**
 * Bulk CSV import into the platform drug_master catalogue — the "collect from
 * everywhere" path for external medicine lists (Marg exports, 1mg-style A-Z
 * dumps, Apollo / DavaIndia ranges, distributor price lists).
 *
 * Expected columns (header-driven, order- and case-insensitive; aliases in
 * parentheses): brand_name (brand, product_name) — required; generic_name
 * (generic); salt_composition (composition, salt); manufacturer (company,
 * mfg); hsn_code (hsn); gst_rate (gst); drug_schedule (schedule); dosage_form
 * (form); pack_size (pack, packing); mrp (price); prescription_required (rx,
 * prescription). This matches the repo-root drugs_reference.csv sample.
 *
 * Semantics mirror the HSN-master precedent for shared platform tables:
 * OWNER/ADMIN may ADD rows, never mutate existing ones — duplicates (by
 * case-insensitive brand name, against the DB and within the file) are
 * skipped, so re-importing the same list is a no-op. Salts are linked when a
 * salt_master row matches the generic name (never auto-created — salt_master
 * feeds the interaction checker and must stay curated); manufacturers are
 * auto-registered in manufacturer_master so autocomplete picks them up.
 *
 * Quoted fields with embedded commas / doubled quotes are handled; embedded
 * newlines inside quotes are not (none of the source catalogues use them).
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class DrugMasterImportService {

    static final int MAX_ROWS = 100_000;
    private static final int BATCH_SIZE = 500;
    private static final int MAX_ERRORS_REPORTED = 50;

    private final DrugMasterRepository drugMasterRepository;
    private final SaltMasterRepository saltMasterRepository;
    private final ManufacturerMasterRepository manufacturerMasterRepository;

    @Transactional
    public DrugMasterImportResult importCsv(MultipartFile file, boolean dryRun) {
        if (file == null || file.isEmpty()) {
            throw new BusinessException("Upload a CSV file with at least a header row",
                    "DRUG_IMPORT_EMPTY", HttpStatus.BAD_REQUEST);
        }
        List<List<String>> lines = readCsv(file);
        if (lines.isEmpty()) {
            throw new BusinessException("Upload a CSV file with at least a header row",
                    "DRUG_IMPORT_EMPTY", HttpStatus.BAD_REQUEST);
        }
        Map<String, Integer> header = mapHeader(lines.get(0));
        if (!header.containsKey("brand_name")) {
            throw new BusinessException(
                    "CSV must have a brand_name column (aliases: brand, product_name)",
                    "DRUG_IMPORT_NO_BRAND_COLUMN", HttpStatus.BAD_REQUEST);
        }
        List<List<String>> rows = lines.subList(1, lines.size());
        if (rows.size() > MAX_ROWS) {
            throw new BusinessException(
                    "File has " + rows.size() + " rows; the per-upload limit is " + MAX_ROWS
                            + " — split the list and import in parts",
                    "DRUG_IMPORT_TOO_LARGE", HttpStatus.BAD_REQUEST);
        }

        Set<String> knownBrands = new HashSet<>(drugMasterRepository.findAllBrandNamesLower());
        Map<String, UUID> saltIdsByName = resolveSalts(rows, header);
        Set<String> knownManufacturers = new HashSet<>();
        List<String> errors = new ArrayList<>();
        List<DrugMaster> batch = new ArrayList<>();
        int imported = 0, skipped = 0, errorCount = 0, saltLinked = 0, manufacturersCreated = 0;

        for (int i = 0; i < rows.size(); i++) {
            int lineNo = i + 2; // 1-based, after the header line
            List<String> row = rows.get(i);
            try {
                String brand = truncate(get(row, header, "brand_name"), 255);
                if (brand == null) {
                    throw new IllegalArgumentException("brand_name is blank");
                }
                if (knownBrands.contains(brand.toLowerCase(Locale.ROOT))) {
                    skipped++;
                    continue;
                }
                DrugMaster drug = new DrugMaster();
                drug.setBrandName(brand);
                drug.setGenericName(truncate(get(row, header, "generic_name"), 255));
                drug.setSaltComposition(get(row, header, "salt_composition"));
                drug.setManufacturer(truncate(get(row, header, "manufacturer"), 255));
                String hsn = truncate(get(row, header, "hsn_code"), 10);
                drug.setHsnCode(hsn != null ? hsn : "3004");
                drug.setGstRate(parseDecimal(get(row, header, "gst_rate"), new BigDecimal("5"), "gst_rate"));
                String schedule = normalizeSchedule(get(row, header, "drug_schedule"));
                drug.setDrugSchedule(schedule);
                drug.setDosageForm(truncate(get(row, header, "dosage_form"), 50));
                drug.setPackSize(truncate(get(row, header, "pack_size"), 50));
                drug.setMrp(parseDecimal(get(row, header, "mrp"), null, "mrp"));
                Boolean rx = parseBoolean(get(row, header, "prescription_required"));
                drug.setPrescriptionRequired(rx != null ? rx : !"GENERAL".equals(schedule));
                drug.setActive(true);

                String generic = drug.getGenericName();
                if (generic != null) {
                    UUID saltId = saltIdsByName.get(generic.toLowerCase(Locale.ROOT));
                    if (saltId != null) {
                        drug.setSaltId(saltId);
                        saltLinked++;
                    }
                }
                if (registerManufacturer(drug.getManufacturer(), knownManufacturers, dryRun)) {
                    manufacturersCreated++;
                }

                knownBrands.add(brand.toLowerCase(Locale.ROOT));
                imported++;
                if (!dryRun) {
                    batch.add(drug);
                    if (batch.size() >= BATCH_SIZE) {
                        drugMasterRepository.saveAll(batch);
                        batch.clear();
                    }
                }
            } catch (IllegalArgumentException e) {
                errorCount++;
                if (errors.size() < MAX_ERRORS_REPORTED) {
                    errors.add("row " + lineNo + ": " + e.getMessage());
                }
            }
        }
        if (!dryRun && !batch.isEmpty()) {
            drugMasterRepository.saveAll(batch);
        }
        log.info("Drug master import{}: {} rows -> {} imported, {} duplicate, {} errors, "
                        + "{} salt-linked, {} manufacturers created",
                dryRun ? " (dry run)" : "", rows.size(), imported, skipped, errorCount,
                saltLinked, manufacturersCreated);
        return new DrugMasterImportResult(rows.size(), imported, skipped, errorCount,
                errors, saltLinked, manufacturersCreated, dryRun);
    }

    /** One bulk query: every distinct generic name in the file -> salt_master id. */
    private Map<String, UUID> resolveSalts(List<List<String>> rows, Map<String, Integer> header) {
        Set<String> names = new HashSet<>();
        for (List<String> row : rows) {
            String generic = get(row, header, "generic_name");
            if (generic != null) {
                names.add(generic);
            }
        }
        Map<String, UUID> byLowerName = new HashMap<>();
        if (!names.isEmpty()) {
            for (SaltMaster salt : saltMasterRepository.findByNameIgnoreCaseIn(names)) {
                byLowerName.put(salt.getName().toLowerCase(Locale.ROOT), salt.getId());
            }
        }
        return byLowerName;
    }

    /** Add-only manufacturer_master registration; returns true when a row was created. */
    private boolean registerManufacturer(String name, Set<String> knownInRun, boolean dryRun) {
        if (name == null) {
            return false;
        }
        String key = name.toLowerCase(Locale.ROOT);
        if (!knownInRun.add(key)) {
            return false;
        }
        if (manufacturerMasterRepository.findByNameIgnoreCaseAndActiveTrue(name).isPresent()) {
            return false;
        }
        if (!dryRun) {
            ManufacturerMaster manufacturer = new ManufacturerMaster();
            manufacturer.setName(name);
            manufacturer.setActive(true);
            manufacturerMasterRepository.save(manufacturer);
        }
        return true;
    }

    private List<List<String>> readCsv(MultipartFile file) {
        List<List<String>> lines = new ArrayList<>();
        try (BufferedReader reader = new BufferedReader(
                new InputStreamReader(file.getInputStream(), StandardCharsets.UTF_8))) {
            String line;
            boolean first = true;
            while ((line = reader.readLine()) != null) {
                if (first) {
                    line = stripBom(line);
                    first = false;
                }
                if (!line.isBlank()) {
                    lines.add(splitCsvLine(line));
                }
            }
        } catch (IOException e) {
            throw new BusinessException("Could not read the uploaded file: " + e.getMessage(),
                    "DRUG_IMPORT_UNREADABLE", HttpStatus.BAD_REQUEST);
        }
        return lines;
    }

    private Map<String, Integer> mapHeader(List<String> headerRow) {
        Map<String, Integer> byName = new HashMap<>();
        for (int i = 0; i < headerRow.size(); i++) {
            String raw = headerRow.get(i);
            if (raw == null) {
                continue;
            }
            String key = canonicalHeader(raw.trim().toLowerCase(Locale.ROOT).replace(' ', '_'));
            if (key != null) {
                byName.putIfAbsent(key, i);
            }
        }
        return byName;
    }

    private String canonicalHeader(String name) {
        return switch (name) {
            case "brand_name", "brand", "product_name" -> "brand_name";
            case "generic_name", "generic" -> "generic_name";
            case "salt_composition", "composition", "salt" -> "salt_composition";
            case "manufacturer", "company", "mfg" -> "manufacturer";
            case "hsn_code", "hsn" -> "hsn_code";
            case "gst_rate", "gst" -> "gst_rate";
            case "drug_schedule", "schedule" -> "drug_schedule";
            case "dosage_form", "form" -> "dosage_form";
            case "pack_size", "pack", "packing" -> "pack_size";
            case "mrp", "price" -> "mrp";
            case "prescription_required", "rx", "prescription" -> "prescription_required";
            default -> null;
        };
    }

    private String get(List<String> row, Map<String, Integer> header, String column) {
        Integer idx = header.get(column);
        if (idx == null || idx >= row.size()) {
            return null;
        }
        String value = row.get(idx);
        if (value == null) {
            return null;
        }
        value = value.trim();
        return value.isEmpty() ? null : value;
    }

    private String truncate(String value, int max) {
        if (value == null) {
            return null;
        }
        return value.length() <= max ? value : value.substring(0, max);
    }

    private BigDecimal parseDecimal(String raw, BigDecimal fallback, String column) {
        if (raw == null) {
            return fallback;
        }
        String cleaned = raw.replace("₹", "").replace(",", "").replace("%", "").trim();
        if (cleaned.isEmpty()) {
            return fallback;
        }
        try {
            BigDecimal value = new BigDecimal(cleaned);
            if (value.signum() < 0) {
                throw new IllegalArgumentException(column + " cannot be negative: " + raw);
            }
            return value;
        } catch (NumberFormatException e) {
            throw new IllegalArgumentException("invalid " + column + ": " + raw);
        }
    }

    private Boolean parseBoolean(String raw) {
        if (raw == null) {
            return null;
        }
        return switch (raw.trim().toLowerCase(Locale.ROOT)) {
            case "true", "yes", "y", "1" -> true;
            case "false", "no", "n", "0" -> false;
            default -> null;
        };
    }

    /**
     * Tolerates the schedule spellings seen across Marg / Tally / paper lists
     * ("Sch H1", "Schedule-X", "h") — same spirit as
     * StatutoryRegisterService.classify(). Unknown values fall back to GENERAL.
     */
    static String normalizeSchedule(String raw) {
        if (raw == null || raw.isBlank()) {
            return "GENERAL";
        }
        String s = raw.trim().toUpperCase(Locale.ROOT)
                .replace("SCHEDULE", "").replace("SCH", "")
                .replace("-", "").replace(".", "").trim();
        if (s.startsWith("H1")) {
            return "H1";
        }
        if (s.equals("H")) {
            return "H";
        }
        if (s.equals("X")) {
            return "X";
        }
        if (s.startsWith("NARC") || s.equals("NDPS")) {
            return "NARCOTICS";
        }
        return "GENERAL";
    }

    private String stripBom(String line) {
        return line.startsWith("﻿") ? line.substring(1) : line;
    }

    /** Minimal RFC-4180 field splitter: quoted commas + doubled quotes. */
    static List<String> splitCsvLine(String line) {
        List<String> out = new ArrayList<>();
        StringBuilder current = new StringBuilder();
        boolean inQuotes = false;
        for (int i = 0; i < line.length(); i++) {
            char c = line.charAt(i);
            if (inQuotes) {
                if (c == '"') {
                    if (i + 1 < line.length() && line.charAt(i + 1) == '"') {
                        current.append('"');
                        i++;
                    } else {
                        inQuotes = false;
                    }
                } else {
                    current.append(c);
                }
            } else if (c == '"') {
                inQuotes = true;
            } else if (c == ',') {
                out.add(current.toString());
                current.setLength(0);
            } else {
                current.append(c);
            }
        }
        out.add(current.toString());
        return out;
    }
}
