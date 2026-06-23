package com.katasticho.erp.payroll.gulf;

import com.katasticho.erp.common.country.RequiresCountry;
import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.module.ModuleCode;
import com.katasticho.erp.common.module.RequiresModule;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.util.UUID;

/**
 * Gulf-only payroll endpoints — gratuity calculation + WPS SIF export.
 *
 * <p>Class-level {@code @RequiresCountry({"AE","OM"})} keeps an Indian org
 * from accidentally hitting these — they would otherwise see Gulf gratuity
 * formulas applied to INR payslips, which is nonsense. WPS is UAE-only;
 * Oman's parallel scheme produces a different file and lives in a separate
 * endpoint when needed.
 */
@RestController
@RequestMapping("/api/v1/payroll/gulf")
@RequiredArgsConstructor
@RequiresModule(ModuleCode.PAYROLL)
@RequiresCountry({"AE", "OM"})
public class GulfPayrollController {

    private final GulfPayrollService gulfPayrollService;
    private final WpsFileService wpsFileService;

    /**
     * Preview end-of-service gratuity for an employee. Pass {@code asOf} to
     * snapshot at a future termination date; omit it for today.
     */
    @GetMapping("/gratuity/{employeeId}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<GratuityResult>> gratuity(
            @PathVariable UUID employeeId,
            @RequestParam(required = false)
            @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate asOf) {
        return ResponseEntity.ok(ApiResponse.ok(gulfPayrollService.computeFor(employeeId, asOf)));
    }

    /**
     * Generate the SIF v2 WPS file for a payroll run. UAE only — Oman orgs
     * hit this endpoint will get an OM-result back, but Oman's WPS uses a
     * different format and the agent bank will reject it. The file is
     * returned with a {@code .sif} extension and {@code Content-Disposition:
     * attachment} so the browser saves it directly.
     */
    @PostMapping("/wps/{payrollRunId}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    @RequiresCountry("AE")
    public ResponseEntity<byte[]> wps(@PathVariable UUID payrollRunId) {
        WpsFileService.WpsFile file = wpsFileService.generate(payrollRunId);
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(new MediaType("text", "plain", StandardCharsets.UTF_8));
        headers.setContentDisposition(
                org.springframework.http.ContentDisposition.attachment()
                        .filename(file.filename())
                        .build());
        headers.add("X-WPS-Employee-Count", String.valueOf(file.employeeCount()));
        headers.add("X-WPS-Total-Salary", file.totalSalary().toPlainString());
        return ResponseEntity.ok().headers(headers)
                .body(file.content().getBytes(StandardCharsets.UTF_8));
    }
}
