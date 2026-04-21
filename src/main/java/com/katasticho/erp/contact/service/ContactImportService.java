package com.katasticho.erp.contact.service;

import com.katasticho.erp.audit.AuditService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.contact.dto.ContactImportPreview;
import com.katasticho.erp.contact.dto.ContactImportResult;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.entity.ContactType;
import com.katasticho.erp.contact.entity.GstTreatment;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.inventory.service.ExcelParser;
import com.katasticho.erp.inventory.service.SimpleCsvParser;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.io.InputStreamReader;
import java.io.Reader;
import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.util.*;

/**
 * Bulk contact import from CSV / XLSX. Mirrors the two-phase flow of
 * ItemImportService: preview (dry-run) then commit.
 *
 * Expected columns (case-insensitive):
 *   display_name      (required)
 *   type              (required — CUSTOMER | VENDOR | BOTH)
 *   phone             (optional)
 *   email             (optional)
 *   gstin             (optional — validated for duplicates)
 *   billing_address   (optional — maps to billingAddressLine1)
 *   city              (optional — billingCity)
 *   state             (optional — billingState)
 *   payment_terms_days (optional)
 *   opening_balance   (optional)
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class ContactImportService {

    public static final String TEMPLATE_HEADER =
            "display_name,type,phone,email,gstin,"
            + "billing_address,city,state,payment_terms_days,opening_balance";

    private static final String STATUS_OK = "OK";
    private static final String STATUS_ERROR = "ERROR";

    private static final Set<String> XLSX_CONTENT_TYPES = Set.of(
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            "application/vnd.ms-excel"
    );

    private final ContactRepository contactRepository;
    private final AuditService auditService;

    public ContactImportPreview previewImport(MultipartFile file) {
        UUID orgId = TenantContext.getCurrentOrgId();
        List<ParsedRow> parsed = parseAndValidate(file, orgId);

        List<ContactImportPreview.RowPreview> previews = new ArrayList<>(parsed.size());
        int valid = 0;
        for (ParsedRow p : parsed) {
            previews.add(p.preview);
            if (STATUS_OK.equals(p.preview.status())) valid++;
        }
        return new ContactImportPreview(parsed.size(), valid, parsed.size() - valid, previews);
    }

    @Transactional
    public ContactImportResult importContacts(MultipartFile file) {
        UUID orgId = TenantContext.getCurrentOrgId();
        List<ParsedRow> parsed = parseAndValidate(file, orgId);

        List<ContactImportResult.RowError> errors = new ArrayList<>();
        int created = 0;

        for (ParsedRow p : parsed) {
            if (!STATUS_OK.equals(p.preview.status())) {
                errors.add(new ContactImportResult.RowError(
                        p.preview.rowNumber(), p.preview.displayName(), p.preview.error()));
                continue;
            }
            contactRepository.save(p.contact);
            created++;
        }

        int total = parsed.size();
        auditService.log("CONTACT_IMPORT", null, "BULK_IMPORT", null,
                "{\"total\":" + total + ",\"created\":" + created + ",\"skipped\":" + (total - created) + "}");
        log.info("Contact bulk import done: {} total, {} created, {} skipped",
                total, created, total - created);

        return new ContactImportResult(total, created, total - created, errors);
    }

    private List<ParsedRow> parseAndValidate(MultipartFile file, UUID orgId) {
        if (file == null || file.isEmpty()) {
            throw new BusinessException("Upload file is required",
                    "IMPORT_EMPTY_FILE", HttpStatus.BAD_REQUEST);
        }

        List<Map<String, String>> rows = parseFile(file);
        List<ParsedRow> out = new ArrayList<>(rows.size());
        Set<String> seenGstinsInFile = new HashSet<>();

        for (int i = 0; i < rows.size(); i++) {
            Map<String, String> row = rows.get(i);
            int rowNumber = i + 2;

            String displayName = get(row, "display_name");
            String typeRaw = get(row, "type");
            String phone = get(row, "phone");
            String email = get(row, "email");
            String gstin = get(row, "gstin");

            if (displayName == null || displayName.isBlank()) {
                out.add(ParsedRow.error(rowNumber, null, typeRaw, phone, email,
                        "display_name is required"));
                continue;
            }

            if (typeRaw == null || typeRaw.isBlank()) {
                out.add(ParsedRow.error(rowNumber, displayName, null, phone, email,
                        "type is required (CUSTOMER, VENDOR, or BOTH)"));
                continue;
            }

            ContactType contactType;
            try {
                contactType = ContactType.valueOf(typeRaw.trim().toUpperCase());
            } catch (IllegalArgumentException e) {
                out.add(ParsedRow.error(rowNumber, displayName, typeRaw, phone, email,
                        "type must be CUSTOMER, VENDOR, or BOTH"));
                continue;
            }

            // GSTIN uniqueness
            if (gstin != null && !gstin.isBlank()) {
                if (!seenGstinsInFile.add(gstin)) {
                    out.add(ParsedRow.error(rowNumber, displayName, typeRaw, phone, email,
                            "Duplicate GSTIN within file: " + gstin));
                    continue;
                }
                if (contactRepository.existsByOrgIdAndGstinAndIsDeletedFalse(orgId, gstin)) {
                    out.add(ParsedRow.error(rowNumber, displayName, typeRaw, phone, email,
                            "GSTIN already registered: " + gstin));
                    continue;
                }
            }

            // Numeric fields
            BigDecimal openingBalance;
            Integer paymentTermsDays;
            try {
                openingBalance = parseDecimal(row, "opening_balance", null);
                String ptRaw = get(row, "payment_terms_days");
                paymentTermsDays = ptRaw != null ? Integer.parseInt(ptRaw) : null;
            } catch (NumberFormatException e) {
                out.add(ParsedRow.error(rowNumber, displayName, typeRaw, phone, email,
                        "Invalid number: " + e.getMessage()));
                continue;
            }

            GstTreatment gstTreatment = (gstin != null && !gstin.isBlank())
                    ? GstTreatment.REGISTERED
                    : GstTreatment.UNREGISTERED;

            Contact contact = Contact.builder()
                    .contactType(contactType)
                    .displayName(displayName.trim())
                    .phone(phone)
                    .email(email)
                    .gstin(gstin)
                    .gstTreatment(gstTreatment)
                    .billingAddressLine1(get(row, "billing_address"))
                    .billingCity(get(row, "city"))
                    .billingState(get(row, "state"))
                    .paymentTermsDays(paymentTermsDays != null ? paymentTermsDays : 30)
                    .openingBalance(openingBalance != null ? openingBalance : BigDecimal.ZERO)
                    .active(true)
                    .build();

            out.add(new ParsedRow(
                    new ContactImportPreview.RowPreview(
                            rowNumber, displayName, contactType.name(),
                            phone, email, STATUS_OK, null),
                    contact));
        }

        return out;
    }

    private List<Map<String, String>> parseFile(MultipartFile file) {
        String filename = file.getOriginalFilename();
        String contentType = file.getContentType();

        boolean isExcel = (filename != null && filename.toLowerCase().endsWith(".xlsx"))
                || (contentType != null && XLSX_CONTENT_TYPES.contains(contentType));

        if (isExcel) {
            try {
                return ExcelParser.parse(file.getInputStream());
            } catch (IOException e) {
                throw new BusinessException("Failed to parse Excel file: " + e.getMessage(),
                        "IMPORT_PARSE_FAILED", HttpStatus.BAD_REQUEST);
            }
        }

        try (Reader reader = new InputStreamReader(file.getInputStream(), StandardCharsets.UTF_8)) {
            return SimpleCsvParser.parse(reader);
        } catch (IOException e) {
            throw new BusinessException("Failed to parse CSV: " + e.getMessage(),
                    "IMPORT_PARSE_FAILED", HttpStatus.BAD_REQUEST);
        }
    }

    private record ParsedRow(ContactImportPreview.RowPreview preview, Contact contact) {
        static ParsedRow error(int rowNumber, String displayName, String type,
                               String phone, String email, String message) {
            return new ParsedRow(
                    new ContactImportPreview.RowPreview(
                            rowNumber, displayName, type, phone, email, STATUS_ERROR, message),
                    null);
        }
    }

    private static String get(Map<String, String> row, String key) {
        String v = row.get(key);
        return v == null || v.isBlank() ? null : v.trim();
    }

    private static BigDecimal parseDecimal(Map<String, String> row, String key, BigDecimal def) {
        String raw = get(row, key);
        if (raw == null) return def;
        return new BigDecimal(raw);
    }
}
