package com.katasticho.erp.loyalty.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.loyalty.dto.EarnPointsRequest;
import com.katasticho.erp.loyalty.dto.RedeemPointsRequest;
import com.katasticho.erp.loyalty.dto.WalletResponse;
import com.katasticho.erp.loyalty.dto.WalletTransactionResponse;
import com.katasticho.erp.loyalty.service.WalletService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/wallet")
@RequiredArgsConstructor
@PreAuthorize("hasAnyRole('OWNER','ADMIN','OPERATOR')")
public class WalletController {

    private final WalletService walletService;

    @GetMapping("/contact/{contactId}")
    public ResponseEntity<ApiResponse<WalletResponse>> getWallet(
            @PathVariable UUID contactId) {
        return ResponseEntity.ok(ApiResponse.ok(walletService.getWallet(contactId)));
    }

    @GetMapping("/contact/{contactId}/transactions")
    public ResponseEntity<ApiResponse<List<WalletTransactionResponse>>> getTransactionHistory(
            @PathVariable UUID contactId) {
        return ResponseEntity.ok(ApiResponse.ok(walletService.getTransactionHistory(contactId)));
    }

    @GetMapping("/contact/{contactId}/redeemable")
    public ResponseEntity<ApiResponse<WalletResponse>> checkRedeemable(
            @PathVariable UUID contactId,
            @RequestParam BigDecimal saleTotal) {
        return ResponseEntity.ok(ApiResponse.ok(walletService.checkRedeemable(contactId, saleTotal)));
    }

    @PostMapping("/earn")
    public ResponseEntity<ApiResponse<WalletResponse>> earnPoints(
            @Valid @RequestBody EarnPointsRequest request) {
        return ResponseEntity.ok(ApiResponse.ok(walletService.earnPoints(request)));
    }

    @PostMapping("/redeem")
    public ResponseEntity<ApiResponse<WalletResponse>> redeemPoints(
            @Valid @RequestBody RedeemPointsRequest request) {
        return ResponseEntity.ok(ApiResponse.ok(walletService.redeemPoints(request)));
    }
}
