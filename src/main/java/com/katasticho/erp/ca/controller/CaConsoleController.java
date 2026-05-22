package com.katasticho.erp.ca.controller;

import com.katasticho.erp.ca.dto.*;
import com.katasticho.erp.ca.service.*;
import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.module.ModuleCode;
import com.katasticho.erp.common.module.RequiresModule;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/ca")
@RequiredArgsConstructor
public class CaConsoleController {

    private final CaFirmService caFirmService;
    private final CaDashboardService dashboardService;
    private final CaClientLinkService clientLinkService;
    private final CaComplianceService complianceService;
    private final CaAlertService alertService;
    private final CaReportDispatchService reportDispatchService;

    @PostMapping("/firm")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','CA_PARTNER')")
    public ApiResponse<CaFirmResponse> createFirm(@RequestBody CreateCaFirmRequest request) {
        return ApiResponse.ok(caFirmService.createOrGet(request));
    }

    @GetMapping("/firm")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','CA_PARTNER','CA_STAFF')")
    public ApiResponse<CaFirmResponse> currentFirm() {
        return ApiResponse.ok(caFirmService.current());
    }

    @GetMapping("/dashboard")
    @RequiresModule(ModuleCode.CA_CONSOLE)
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','CA_PARTNER','CA_STAFF')")
    public ApiResponse<CaDashboardResponse> dashboard() {
        return ApiResponse.ok(dashboardService.dashboard());
    }

    @GetMapping("/clients")
    @RequiresModule(ModuleCode.CA_CONSOLE)
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','CA_PARTNER','CA_STAFF')")
    public ApiResponse<List<CaClientSummaryResponse>> clients(
            @RequestParam(required = false) String healthStatus,
            @RequestParam(required = false) UUID assignedUserId,
            @RequestParam(required = false) String engagementType
    ) {
        return ApiResponse.ok(dashboardService.clients(healthStatus, assignedUserId, engagementType));
    }

    @PostMapping("/clients/invite")
    @RequiresModule(ModuleCode.CA_CONSOLE)
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','CA_PARTNER')")
    public ApiResponse<CaClientSummaryResponse> invite(@RequestBody InviteClientRequest request) {
        return ApiResponse.created(clientLinkService.inviteOrLink(request, dashboardService));
    }

    @PostMapping("/clients/{linkId}/assign")
    @RequiresModule(ModuleCode.CA_CONSOLE)
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','CA_PARTNER')")
    public ApiResponse<Void> assign(@PathVariable UUID linkId, @RequestBody AssignClientRequest request) {
        clientLinkService.assign(linkId, request);
        return ApiResponse.ok(null, "Client assigned");
    }

    @DeleteMapping("/clients/{linkId}")
    @RequiresModule(ModuleCode.CA_CONSOLE)
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','CA_PARTNER')")
    public ApiResponse<Void> end(@PathVariable UUID linkId) {
        clientLinkService.end(linkId);
        return ApiResponse.ok(null, "Client engagement ended");
    }

    @PostMapping("/clients/{linkId}/access-token")
    @RequiresModule(ModuleCode.CA_CONSOLE)
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','CA_PARTNER','CA_STAFF')")
    public ApiResponse<DelegatedAccessResponse> accessToken(@PathVariable UUID linkId) {
        return ApiResponse.ok(clientLinkService.accessToken(linkId));
    }

    @GetMapping("/compliance/deadlines")
    @RequiresModule(ModuleCode.CA_CONSOLE)
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','CA_PARTNER','CA_STAFF')")
    public ApiResponse<List<CaComplianceDeadlineResponse>> deadlines(
            @RequestParam(required = false) String deadlineType,
            @RequestParam(required = false) String status,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate fromDate,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate toDate,
            @RequestParam(required = false) UUID clientOrgId
    ) {
        return ApiResponse.ok(complianceService.list(deadlineType, status, fromDate, toDate, clientOrgId));
    }

    @PostMapping("/compliance/deadlines/{deadlineId}/mark-filed")
    @RequiresModule(ModuleCode.CA_CONSOLE)
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','CA_PARTNER','CA_STAFF')")
    public ApiResponse<CaComplianceDeadlineResponse> markFiled(
            @PathVariable UUID deadlineId,
            @RequestBody MarkFiledRequest request
    ) {
        return ApiResponse.ok(complianceService.markFiled(deadlineId, request));
    }

    @PostMapping("/compliance/deadlines/generate")
    @RequiresModule(ModuleCode.CA_CONSOLE)
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','CA_PARTNER')")
    public ApiResponse<Integer> generateDeadlines() {
        return ApiResponse.ok(complianceService.generate(), "Compliance deadlines generated");
    }

    @GetMapping("/alerts")
    @RequiresModule(ModuleCode.CA_CONSOLE)
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','CA_PARTNER','CA_STAFF')")
    public ApiResponse<List<CaAlertResponse>> alerts(
            @RequestParam(required = false) String severity,
            @RequestParam(required = false) UUID clientOrgId,
            @RequestParam(required = false) String suggestionType,
            @RequestParam(required = false) String status
    ) {
        return ApiResponse.ok(alertService.list(severity, clientOrgId, suggestionType, status));
    }

    @PostMapping("/alerts/{suggestionId}/dismiss")
    @RequiresModule(ModuleCode.CA_CONSOLE)
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','CA_PARTNER','CA_STAFF')")
    public ApiResponse<Void> dismissAlert(@PathVariable UUID suggestionId) {
        alertService.dismiss(suggestionId);
        return ApiResponse.ok(null, "Alert dismissed");
    }

    @PostMapping("/alerts/{suggestionId}/assign")
    @RequiresModule(ModuleCode.CA_CONSOLE)
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','CA_PARTNER')")
    public ApiResponse<Void> assignAlert(@PathVariable UUID suggestionId, @RequestBody AssignAlertRequest request) {
        alertService.assign(suggestionId, request);
        return ApiResponse.ok(null, "Alert assigned");
    }

    @PostMapping("/reports/dispatch")
    @RequiresModule(ModuleCode.CA_CONSOLE)
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','CA_PARTNER','CA_STAFF')")
    public ApiResponse<List<ReportDispatchResponse>> dispatchReports(@RequestBody ReportDispatchRequest request) {
        return ApiResponse.ok(reportDispatchService.dispatch(request), "Report dispatch queued");
    }

    @GetMapping("/reports/dispatch/{jobId}/status")
    @RequiresModule(ModuleCode.CA_CONSOLE)
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','CA_PARTNER','CA_STAFF')")
    public ApiResponse<ReportDispatchResponse> dispatchStatus(@PathVariable UUID jobId) {
        return ApiResponse.ok(reportDispatchService.status(jobId));
    }

    @GetMapping("/reports/dispatch/history")
    @RequiresModule(ModuleCode.CA_CONSOLE)
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','CA_PARTNER','CA_STAFF')")
    public ApiResponse<List<ReportDispatchResponse>> dispatchHistory() {
        return ApiResponse.ok(reportDispatchService.history());
    }

    @GetMapping("/staff")
    @RequiresModule(ModuleCode.CA_CONSOLE)
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','CA_PARTNER','CA_STAFF')")
    public ApiResponse<List<CaStaffResponse>> staff() {
        return ApiResponse.ok(clientLinkService.staff());
    }
}
