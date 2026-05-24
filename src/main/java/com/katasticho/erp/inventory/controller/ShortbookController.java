package com.katasticho.erp.inventory.controller;

import com.katasticho.erp.inventory.dto.ShortbookItemResponse;
import com.katasticho.erp.inventory.service.ShortbookService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/stock/shortbook")
@RequiredArgsConstructor
public class ShortbookController {

    private final ShortbookService shortbookService;

    @GetMapping
    public ResponseEntity<List<ShortbookItemResponse>> getShortbook() {
        return ResponseEntity.ok(shortbookService.getShortbook());
    }
}
