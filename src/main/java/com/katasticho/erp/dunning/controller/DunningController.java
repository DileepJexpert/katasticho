package com.katasticho.erp.dunning.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.dunning.dto.DunningDtos.*;
import com.katasticho.erp.dunning.service.DunningService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

/** Dunning-level configuration + manual sweep + preview + send log. */
@RestController
@RequestMapping("/api/v1/dunning")
@RequiredArgsConstructor
public class DunningController {

    private final DunningService service;

    @PostMapping("/levels")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<LevelResponse>> createLevel(@RequestBody LevelRequest req) {
        return ResponseEntity.ok(ApiResponse.ok(service.createLevel(req), "Dunning level created"));
    }

    @PutMapping("/levels/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<LevelResponse>> updateLevel(
            @PathVariable UUID id, @RequestBody LevelRequest req) {
        return ResponseEntity.ok(ApiResponse.ok(service.updateLevel(id, req), "Dunning level updated"));
    }

    @DeleteMapping("/levels/{id}")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<Void>> deleteLevel(@PathVariable UUID id) {
        service.deleteLevel(id);
        return ResponseEntity.ok(ApiResponse.ok(null, "Dunning level deleted"));
    }

    @GetMapping("/levels")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<List<LevelResponse>>> listLevels() {
        return ResponseEntity.ok(ApiResponse.ok(service.listLevels()));
    }

    @PostMapping("/run")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<DunningRunResult>> run() {
        return ResponseEntity.ok(ApiResponse.ok(service.run(), "Dunning sweep complete"));
    }

    @GetMapping("/preview")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<List<DunningPreviewRow>>> preview() {
        return ResponseEntity.ok(ApiResponse.ok(service.preview()));
    }

    @GetMapping("/log")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<ApiResponse<Page<DunningLogResponse>>> log(
            @RequestParam(required = false) UUID invoiceId,
            @RequestParam(defaultValue = "0") int page, @RequestParam(defaultValue = "20") int size) {
        return ResponseEntity.ok(ApiResponse.ok(service.log(invoiceId, PageRequest.of(page, size))));
    }
}
