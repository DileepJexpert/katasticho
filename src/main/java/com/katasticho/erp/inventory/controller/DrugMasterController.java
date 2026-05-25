package com.katasticho.erp.inventory.controller;

import com.katasticho.erp.inventory.dto.DrugMasterResponse;
import com.katasticho.erp.inventory.dto.SaltMasterResponse;
import com.katasticho.erp.inventory.service.DrugMasterService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/api/v1/drug-master")
@RequiredArgsConstructor
public class DrugMasterController {

    private final DrugMasterService drugMasterService;

    /** Search drugs by brand name, generic name, or salt composition */
    @GetMapping
    public ResponseEntity<Page<DrugMasterResponse>> search(
            @RequestParam(defaultValue = "") String q,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return ResponseEntity.ok(drugMasterService.searchDrugs(q, page, size));
    }

    @GetMapping("/{id}")
    public ResponseEntity<DrugMasterResponse> getById(@PathVariable UUID id) {
        return ResponseEntity.ok(drugMasterService.getDrug(id));
    }

    @GetMapping("/by-salt/{saltId}")
    public ResponseEntity<Page<DrugMasterResponse>> getBySalt(
            @PathVariable UUID saltId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return ResponseEntity.ok(drugMasterService.getDrugsBySalt(saltId, page, size));
    }

    /** Search salt/composition master */
    @GetMapping("/salts")
    public ResponseEntity<Page<SaltMasterResponse>> searchSalts(
            @RequestParam(defaultValue = "") String q,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return ResponseEntity.ok(drugMasterService.searchSalts(q, page, size));
    }
}
