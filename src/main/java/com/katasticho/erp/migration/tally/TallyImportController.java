package com.katasticho.erp.migration.tally;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.migration.tally.TallyImportDtos.TallyImportPreview;
import com.katasticho.erp.migration.tally.TallyImportDtos.TallyImportResult;
import com.katasticho.erp.migration.tally.TallyImportDtos.VoucherImportPreview;
import com.katasticho.erp.migration.tally.TallyImportDtos.VoucherImportResult;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;

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
