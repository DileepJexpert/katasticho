package com.katasticho.erp.gst.controller;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.gst.service.GstService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/v1/gst")
@RequiredArgsConstructor
public class GstController {

    private final GstService gstService;
    private final ObjectMapper objectMapper;

    @GetMapping("/gstr1")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getGstr1(
            @RequestParam int year,
            @RequestParam int month) {
        Map<String, Object> data = gstService.generateGstr1(year, month);
        return ResponseEntity.ok(ApiResponse.ok(data));
    }

    @GetMapping("/gstr3b")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT','VIEWER')")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getGstr3b(
            @RequestParam int year,
            @RequestParam int month) {
        Map<String, Object> data = gstService.generateGstr3b(year, month);
        return ResponseEntity.ok(ApiResponse.ok(data));
    }

    @GetMapping("/gstr1/export")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<byte[]> exportGstr1(
            @RequestParam int year,
            @RequestParam int month) throws Exception {
        Map<String, Object> data = gstService.generateGstr1(year, month);
        byte[] json = objectMapper.writerWithDefaultPrettyPrinter().writeValueAsBytes(data);
        String filename = String.format("GSTR1_%d_%02d.json", year, month);
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"" + filename + "\"")
                .contentType(MediaType.APPLICATION_JSON)
                .body(json);
    }

    @GetMapping("/gstr3b/export")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<byte[]> exportGstr3b(
            @RequestParam int year,
            @RequestParam int month) throws Exception {
        Map<String, Object> data = gstService.generateGstr3b(year, month);
        byte[] json = objectMapper.writerWithDefaultPrettyPrinter().writeValueAsBytes(data);
        String filename = String.format("GSTR3B_%d_%02d.json", year, month);
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"" + filename + "\"")
                .contentType(MediaType.APPLICATION_JSON)
                .body(json);
    }
}
