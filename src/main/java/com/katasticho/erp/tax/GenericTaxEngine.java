package com.katasticho.erp.tax;

import com.katasticho.erp.accounting.entity.Account;
import com.katasticho.erp.accounting.repository.AccountRepository;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.tax.entity.TaxGroup;
import com.katasticho.erp.tax.entity.TaxGroupRate;
import com.katasticho.erp.tax.entity.TaxRate;
import com.katasticho.erp.tax.repository.TaxGroupRateRepository;
import com.katasticho.erp.tax.repository.TaxGroupRepository;
import com.katasticho.erp.tax.repository.TaxRateRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * Database-driven tax engine. Replaces IndiaGSTEngine + TaxEngineFactory.
 *
 * Loads tax_group → tax_group_rate → tax_rate from DB to compute tax.
 * GL accounts come from tax_rate.gl_output_account_id (sales) or
 * tax_rate.gl_input_account_id (purchases) — never hardcoded.
 *
 * Works for any country with zero code changes:
 *   India: CGST+SGST or IGST groups, accounts 2020/2021/2022 output, 1500 input
 *   Vietnam: VAT 10% group, accounts 2040 output, 1510 input
 *   UAE: VAT 5% group
 *   UK: VAT 20%/5%/0% groups
 *   US: Sales Tax (not recoverable on purchases)
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class GenericTaxEngine implements TaxEngine {

    private final TaxGroupRepository groupRepository;
    private final TaxGroupRateRepository groupRateRepository;
    private final TaxRateRepository rateRepository;
    private final AccountRepository accountRepository;

    @Override
    public TaxCalculationResult calculate(UUID orgId, UUID taxGroupId,
                                          BigDecimal taxableAmount, TransactionType type) {
        if (taxGroupId == null) {
            return new TaxCalculationResult(List.of(), BigDecimal.ZERO);
        }

        List<TaxGroupRate> groupRates = groupRateRepository.findByTaxGroupId(taxGroupId);
        if (groupRates.isEmpty()) {
            // Exempt group or group with no rates = zero tax
            return new TaxCalculationResult(List.of(), BigDecimal.ZERO);
        }

        List<TaxComponent> components = new ArrayList<>();
        BigDecimal totalTax = BigDecimal.ZERO;

        for (TaxGroupRate gr : groupRates) {
            TaxRate rate = rateRepository.findById(gr.getTaxRateId())
                    .orElseThrow(() -> BusinessException.notFound("TaxRate", gr.getTaxRateId()));

            BigDecimal amount = taxableAmount.multiply(rate.getPercentage())
                    .divide(BigDecimal.valueOf(100), 2, RoundingMode.HALF_UP);

            // Pick the correct GL account based on transaction direction
            UUID glAccountId;
            if (type == TransactionType.SALE) {
                glAccountId = rate.getGlOutputAccountId();
            } else {
                // PURCHASE: use input account if recoverable, null otherwise
                glAccountId = rate.isRecoverable() ? rate.getGlInputAccountId() : null;
            }

            String glAccountCode = null;
            if (glAccountId != null) {
                glAccountCode = accountRepository.findById(glAccountId)
                        .map(Account::getCode).orElse(null);
            }

            components.add(new TaxComponent(
                    rate.getId(),
                    rate.getRateCode(),
                    rate.getName(),
                    rate.getPercentage(),
                    amount,
                    glAccountId,
                    glAccountCode,
                    rate.isRecoverable()));

            totalTax = totalTax.add(amount);
        }

        return new TaxCalculationResult(components, totalTax);
    }

    @Override
    public Optional<UUID> resolveGroupId(UUID orgId, BigDecimal rate,
                                         String sellerState, String buyerState) {
        if (rate == null || rate.compareTo(BigDecimal.ZERO) == 0) {
            return groupRepository.findByOrgIdAndNameAndActiveTrue(orgId, "Exempt")
                    .map(TaxGroup::getId);
        }

        String rateStr = rate.stripTrailingZeros().toPlainString();
        boolean isInterState = sellerState != null && buyerState != null
                && !sellerState.equalsIgnoreCase(buyerState);

        // Try India-specific groups first (GST / IGST)
        if (isInterState) {
            Optional<UUID> igst = findGroup(orgId, "IGST " + rateStr + "%");
            if (igst.isPresent()) return igst;
        } else {
            Optional<UUID> gst = findGroup(orgId, "GST " + rateStr + "%");
            if (gst.isPresent()) return gst;
        }

        // Fallback: try generic names (VAT, SST, Sales Tax)
        for (String prefix : List.of("VAT ", "SST ", "PPN ", "Sales Tax ")) {
            Optional<UUID> found = findGroup(orgId, prefix + rateStr + "%");
            if (found.isPresent()) return found;
        }

        // Last resort: try "Taxable" group (US style)
        return findGroup(orgId, "Taxable");
    }

    private Optional<UUID> findGroup(UUID orgId, String name) {
        return groupRepository.findByOrgIdAndNameAndActiveTrue(orgId, name)
                .map(TaxGroup::getId);
    }
}
