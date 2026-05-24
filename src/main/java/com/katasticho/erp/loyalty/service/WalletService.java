package com.katasticho.erp.loyalty.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.loyalty.dto.EarnPointsRequest;
import com.katasticho.erp.loyalty.dto.RedeemPointsRequest;
import com.katasticho.erp.loyalty.dto.WalletResponse;
import com.katasticho.erp.loyalty.dto.WalletTransactionResponse;
import com.katasticho.erp.loyalty.entity.CustomerWallet;
import com.katasticho.erp.loyalty.entity.WalletTransaction;
import com.katasticho.erp.loyalty.repository.CustomerWalletRepository;
import com.katasticho.erp.loyalty.repository.WalletTransactionRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Transactional
public class WalletService {

    private static final BigDecimal EARN_RATE = new BigDecimal("100"); // ₹1 per ₹100 spent
    private static final BigDecimal MIN_REDEMPTION = new BigDecimal("10");
    private static final BigDecimal MAX_REDEMPTION_RATIO = new BigDecimal("0.5");

    private final CustomerWalletRepository walletRepository;
    private final WalletTransactionRepository transactionRepository;

    // -------------------------------------------------------------------------
    // Private helpers
    // -------------------------------------------------------------------------

    private CustomerWallet getOrCreateWallet(UUID orgId, UUID contactId) {
        return walletRepository.findByOrgIdAndContactIdAndIsDeletedFalse(orgId, contactId)
                .orElseGet(() -> {
                    CustomerWallet wallet = CustomerWallet.builder()
                            .contactId(contactId)
                            .build();
                    wallet.setOrgId(orgId);
                    return walletRepository.save(wallet);
                });
    }

    private WalletResponse toWalletResponse(CustomerWallet wallet) {
        return new WalletResponse(
                wallet.getId(),
                wallet.getContactId(),
                wallet.getBalance(),
                wallet.getTotalEarned(),
                wallet.getTotalRedeemed(),
                wallet.getBalance()  // maxRedeemable = full balance; 50% cap applied per-sale in checkRedeemable
        );
    }

    private WalletTransactionResponse toTransactionResponse(WalletTransaction txn) {
        return new WalletTransactionResponse(
                txn.getId(),
                txn.getTxnType(),
                txn.getAmount(),
                txn.getBalanceAfter(),
                txn.getReferenceType(),
                txn.getNotes(),
                txn.getCreatedAt()
        );
    }

    // -------------------------------------------------------------------------
    // Public API
    // -------------------------------------------------------------------------

    @Transactional(readOnly = true)
    public WalletResponse getWallet(UUID contactId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return walletRepository.findByOrgIdAndContactIdAndIsDeletedFalse(orgId, contactId)
                .map(this::toWalletResponse)
                .orElseGet(() -> new WalletResponse(null, contactId, BigDecimal.ZERO,
                        BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO));
    }

    public WalletResponse earnPoints(EarnPointsRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();

        // ₹1 per ₹100 spent — floor division
        BigDecimal earned = request.saleTotal()
                .divide(EARN_RATE, 0, RoundingMode.FLOOR);

        if (earned.compareTo(BigDecimal.ZERO) <= 0) {
            // Sale total too small to earn any points — return current wallet state
            CustomerWallet wallet = getOrCreateWallet(orgId, request.contactId());
            return toWalletResponse(wallet);
        }

        CustomerWallet wallet = getOrCreateWallet(orgId, request.contactId());
        wallet.setBalance(wallet.getBalance().add(earned));
        wallet.setTotalEarned(wallet.getTotalEarned().add(earned));
        wallet = walletRepository.save(wallet);

        WalletTransaction txn = WalletTransaction.builder()
                .orgId(orgId)
                .walletId(wallet.getId())
                .contactId(request.contactId())
                .txnType("EARN")
                .amount(earned)
                .balanceAfter(wallet.getBalance())
                .referenceId(request.receiptId())
                .referenceType("SALE")
                .notes("Earned " + earned + " points on sale of ₹" + request.saleTotal())
                .build();
        transactionRepository.save(txn);

        return toWalletResponse(wallet);
    }

    public WalletResponse redeemPoints(RedeemPointsRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();
        BigDecimal redeemAmount = request.redeemAmount();

        if (redeemAmount.compareTo(MIN_REDEMPTION) < 0) {
            throw new BusinessException(
                    "Minimum redemption amount is ₹" + MIN_REDEMPTION,
                    "ERR_WALLET_MIN_REDEMPTION"
            );
        }

        CustomerWallet wallet = walletRepository
                .findByOrgIdAndContactIdAndIsDeletedFalse(orgId, request.contactId())
                .orElseThrow(() -> new BusinessException(
                        "No wallet found for this customer",
                        "ERR_WALLET_NOT_FOUND"
                ));

        if (redeemAmount.compareTo(wallet.getBalance()) > 0) {
            throw new BusinessException(
                    "Insufficient wallet balance. Available: ₹" + wallet.getBalance(),
                    "ERR_WALLET_INSUFFICIENT_BALANCE"
            );
        }

        wallet.setBalance(wallet.getBalance().subtract(redeemAmount));
        wallet.setTotalRedeemed(wallet.getTotalRedeemed().add(redeemAmount));
        wallet = walletRepository.save(wallet);

        WalletTransaction txn = WalletTransaction.builder()
                .orgId(orgId)
                .walletId(wallet.getId())
                .contactId(request.contactId())
                .txnType("REDEEM")
                .amount(redeemAmount.negate())
                .balanceAfter(wallet.getBalance())
                .referenceId(request.receiptId())
                .referenceType("SALE")
                .notes("Redeemed ₹" + redeemAmount + " against sale")
                .build();
        transactionRepository.save(txn);

        return toWalletResponse(wallet);
    }

    @Transactional(readOnly = true)
    public List<WalletTransactionResponse> getTransactionHistory(UUID contactId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return transactionRepository
                .findByOrgIdAndContactIdOrderByCreatedAtDesc(orgId, contactId)
                .stream()
                .map(this::toTransactionResponse)
                .toList();
    }

    @Transactional(readOnly = true)
    public WalletResponse checkRedeemable(UUID contactId, BigDecimal saleTotal) {
        UUID orgId = TenantContext.getCurrentOrgId();

        CustomerWallet wallet = walletRepository
                .findByOrgIdAndContactIdAndIsDeletedFalse(orgId, contactId)
                .orElseGet(() -> {
                    // Return a transient zero-balance wallet for response purposes
                    CustomerWallet empty = new CustomerWallet();
                    empty.setContactId(contactId);
                    empty.setBalance(BigDecimal.ZERO);
                    empty.setTotalEarned(BigDecimal.ZERO);
                    empty.setTotalRedeemed(BigDecimal.ZERO);
                    return empty;
                });

        // max redeemable = min(balance, 50% of sale total)
        BigDecimal maxBySaleTotal = saleTotal.multiply(MAX_REDEMPTION_RATIO)
                .setScale(2, RoundingMode.FLOOR);
        BigDecimal maxRedeemable = wallet.getBalance().min(maxBySaleTotal);

        return new WalletResponse(
                wallet.getId(),
                wallet.getContactId(),
                wallet.getBalance(),
                wallet.getTotalEarned(),
                wallet.getTotalRedeemed(),
                maxRedeemable
        );
    }
}
