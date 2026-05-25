package com.katasticho.erp.indent.controller;

import com.katasticho.erp.indent.dto.IndentRequest;
import com.katasticho.erp.indent.dto.IndentResponse;
import com.katasticho.erp.indent.dto.IndentSummary;
import com.katasticho.erp.indent.service.CustomerIndentService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/api/v1/indents")
@RequiredArgsConstructor
public class CustomerIndentController {

    private final CustomerIndentService indentService;

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public IndentResponse create(@RequestBody IndentRequest request) {
        return indentService.create(request);
    }

    @GetMapping
    public Page<IndentResponse> list(
            @RequestParam(required = false) String status,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return indentService.list(status, page, size);
    }

    @GetMapping("/{id}")
    public IndentResponse getById(@PathVariable UUID id) {
        return indentService.getById(id);
    }

    @GetMapping("/summary")
    public IndentSummary summary() {
        return indentService.summary();
    }

    @PutMapping("/{id}/mark-ordered")
    public IndentResponse markOrdered(@PathVariable UUID id, @RequestParam UUID purchaseOrderId) {
        return indentService.markOrdered(id, purchaseOrderId);
    }

    @PutMapping("/{id}/mark-arrived")
    public IndentResponse markArrived(@PathVariable UUID id) {
        return indentService.markArrived(id);
    }

    @PutMapping("/{id}/mark-fulfilled")
    public IndentResponse markFulfilled(@PathVariable UUID id, @RequestParam UUID receiptId) {
        return indentService.markFulfilled(id, receiptId);
    }

    @PutMapping("/{id}/cancel")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void cancel(@PathVariable UUID id) {
        indentService.cancel(id);
    }
}
