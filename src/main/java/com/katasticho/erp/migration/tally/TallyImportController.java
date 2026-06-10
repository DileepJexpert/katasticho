package com.katasticho.erp.migration.tally;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.migration.tally.TallyImportDtos.TallyImportPreview;
import com.katasticho.erp.migration.tally.TallyImportDtos.TallyImportResult;
import com.katasticho.erp.migration.tally.TallyImportDtos.TbVerificationResult;
import com.katasticho.erp.migration.tally.TallyImportDtos.VoucherImportPreview;
import com.katasticho.erp.migration.tally.TallyImportDtos.VoucherImportResult;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.time.LocalDate;

/**
 * Tally → Katasticho migration.
 * <ul>
 *   <li>Slice 1 (masters + openings): export Masters from TallyPrime → upload.</li>
 *   <li>Slice 2 (vouchers / history): export Day Book from TallyPrime → upload.
 *       Every voucher becomes a journal entry; accounting history transfers.</li>
 * </ul>
 */
@RestController
@RequestMapping("/api/v1/migration/tally")
@RequiredArgsConstructor
public class TallyImportController {

    private final TallyImportService tallyImportService;
    private final TallyVoucherImportService tallyVoucherImportService;
    private final TallyCaBridgeService tallyCaBridgeService;

    @PostMapping(value = "/preview", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<TallyImportPreview>> preview(
            @RequestParam("file") MultipartFile file) {
        return ResponseEntity.ok(ApiResponse.ok(tallyImportService.preview(bytes(file))));
    }

    @PostMapping(value = "/import", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<TallyImportResult>> importMasters(
            @RequestParam("file") MultipartFile file) {
        TallyImportResult result = tallyImportService.importMasters(bytes(file));
        return ResponseEntity.ok(ApiResponse.ok(result, "Tally masters imported"));
    }

    // ── Slice 2: Vouchers / Day Book ──────────────────────────────────

    @PostMapping(value = "/vouchers/preview", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<VoucherImportPreview>> previewVouchers(
            @RequestParam("file") MultipartFile file) {
        return ResponseEntity.ok(ApiResponse.ok(tallyVoucherImportService.preview(bytes(file))));
    }

    @PostMapping(value = "/vouchers/import", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<VoucherImportResult>> importVouchers(
            @RequestParam("file") MultipartFile file) {
        VoucherImportResult result = tallyVoucherImportService.importVouchers(bytes(file));
        return ResponseEntity.ok(ApiResponse.ok(result, "Tally vouchers imported as journal entries"));
    }

    // ── Slice 3: CA Bridge ────────────────────────────────────────────

    /**
     * Verify the migration: upload the closing Trial Balance exported from
     * Tally (Display → Trial Balance → Alt+E → XML) and diff it against our
     * books as of the same date.
     */
    @PostMapping(value = "/verify-trial-balance", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<TbVerificationResult>> verifyTrialBalance(
            @RequestParam("file") MultipartFile file,
            @RequestParam(value = "asOfDate", required = false)
            @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate asOfDate) {
        return ResponseEntity.ok(ApiResponse.ok(
                tallyCaBridgeService.verifyTrialBalance(bytes(file), asOfDate)));
    }

    /**
     * Export our posted vouchers for a period as Tally-importable XML so the
     * CA continues filing from Tally. Returns the XML file directly.
     */
    @GetMapping("/export-vouchers")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<byte[]> exportVouchers(
            @RequestParam("fromDate") @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate fromDate,
            @RequestParam("toDate") @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate toDate) {
        String xml = tallyCaBridgeService.exportVouchersXml(fromDate, toDate);
        byte[] body = xml.getBytes(StandardCharsets.UTF_8);
        String filename = "katasticho-vouchers-" + fromDate + "-to-" + toDate + ".xml";
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"" + filename + "\"")
                .contentType(MediaType.APPLICATION_XML)
                .body(body);
    }

    // ── Shared ──────────────────────────────────────────────────────────

    private byte[] bytes(MultipartFile file) {
        try {
            if (file == null || file.isEmpty()) {
                throw new BusinessException("Upload the Masters XML exported from Tally",
                        "TALLY_FILE_REQUIRED", HttpStatus.BAD_REQUEST);
            }
            return file.getBytes();
        } catch (IOException e) {
            throw new BusinessException("Could not read the uploaded file",
                    "TALLY_FILE_UNREADABLE", HttpStatus.BAD_REQUEST);
        }
    }
}
