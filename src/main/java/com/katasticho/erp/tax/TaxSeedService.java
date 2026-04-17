package com.katasticho.erp.tax;

import com.katasticho.erp.accounting.entity.Account;
import com.katasticho.erp.accounting.repository.AccountRepository;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import com.katasticho.erp.tax.entity.TaxConfiguration;
import com.katasticho.erp.tax.entity.TaxGroup;
import com.katasticho.erp.tax.entity.TaxGroupRate;
import com.katasticho.erp.tax.entity.TaxRate;
import com.katasticho.erp.tax.repository.TaxConfigurationRepository;
import com.katasticho.erp.tax.repository.TaxGroupRateRepository;
import com.katasticho.erp.tax.repository.TaxGroupRepository;
import com.katasticho.erp.tax.repository.TaxRateRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Seeds tax configuration, rates, and groups for an org based on its
 * country code. Runs on application startup for any org that doesn't
 * have tax data yet.
 *
 * To add a new country: add a seedXxx() method and a case in
 * {@link #seedForOrg(Organisation)}.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class TaxSeedService {

    private final TaxConfigurationRepository configRepo;
    private final TaxRateRepository rateRepo;
    private final TaxGroupRepository groupRepo;
    private final TaxGroupRateRepository groupRateRepo;
    private final AccountRepository accountRepo;
    private final OrganisationRepository orgRepo;

    @EventListener(ApplicationReadyEvent.class)
    @Order(3)
    @Transactional
    public void seedAllOrgs() {
        List<Organisation> orgs = orgRepo.findAll();
        int seeded = 0;
        for (Organisation org : orgs) {
            if (!configRepo.existsByOrgId(org.getId())) {
                seedForOrg(org);
                seeded++;
            } else {
                seeded += repairMissingGlAccounts(org);
            }
        }
        if (seeded > 0) {
            log.info("Seeded/repaired tax configuration for {} org(s)", seeded);
        }
    }

    private int repairMissingGlAccounts(Organisation org) {
        List<TaxRate> rates = rateRepo.findByOrgId(org.getId());
        int fixed = 0;
        for (TaxRate rate : rates) {
            // Honour user customisations: if the admin has explicitly mapped
            // this rate from Settings → Tax Account Mapping (even to NULL),
            // never silently re-point it during startup repair.
            if (rate.isGlAccountCustomized()) continue;

            boolean changed = false;
            if (rate.getGlInputAccountId() == null && rate.isRecoverable()) {
                UUID inputId = findAccountId(org.getId(), "1500");
                if (inputId != null) {
                    rate.setGlInputAccountId(inputId);
                    changed = true;
                }
            }
            if (rate.getGlOutputAccountId() == null) {
                String code = switch (rate.getRateCode()) {
                    case "CGST" -> "2020";
                    case "SGST" -> "2021";
                    case "IGST" -> "2022";
                    default -> null;
                };
                if (code != null) {
                    UUID outputId = findAccountId(org.getId(), code);
                    if (outputId != null) {
                        rate.setGlOutputAccountId(outputId);
                        changed = true;
                    }
                }
            }
            if (changed) {
                rateRepo.save(rate);
                fixed++;
            }
        }
        if (fixed > 0) {
            log.info("Repaired {} tax rates with missing GL accounts for org {}", fixed, org.getId());
        }
        return fixed > 0 ? 1 : 0;
    }

    @Transactional
    public void seedForOrg(Organisation org) {
        switch (org.getCountryCode()) {
            case "IN" -> seedIndia(org);
            case "VN" -> seedVietnam(org);
            case "AE" -> seedUAE(org);
            case "GB" -> seedUK(org);
            case "US" -> seedUSA(org);
            case "MY" -> seedMalaysia(org);
            case "ID" -> seedIndonesia(org);
            default   -> seedGenericVAT(org);
        }
        log.info("Tax seeded for org {} (country={})", org.getId(), org.getCountryCode());
    }

    // ── India GST ───────────────────────────────────────────────

    private void seedIndia(Organisation org) {
        UUID orgId = org.getId();

        TaxConfiguration config = configRepo.save(TaxConfiguration.builder()
                .orgId(orgId).countryCode("IN").taxSystem("GST").name("India GST").build());

        // GL accounts (seeded by V1 coa_template)
        UUID glCgstOutput = findAccountId(orgId, "2020");
        UUID glSgstOutput = findAccountId(orgId, "2021");
        UUID glIgstOutput = findAccountId(orgId, "2022");
        UUID glInputCredit = findAccountId(orgId, "1500");

        // Tax rates for each slab
        Map<String, BigDecimal[]> slabs = Map.of(
                "5",  new BigDecimal[]{bd("2.50"), bd("5.00")},
                "12", new BigDecimal[]{bd("6.00"), bd("12.00")},
                "18", new BigDecimal[]{bd("9.00"), bd("18.00")},
                "28", new BigDecimal[]{bd("14.00"), bd("28.00")}
        );

        // Exempt group (no rates)
        groupRepo.save(TaxGroup.builder()
                .orgId(orgId).name("Exempt").description("No tax applicable").build());

        for (var entry : slabs.entrySet()) {
            String slab = entry.getKey();
            BigDecimal halfRate = entry.getValue()[0];
            BigDecimal fullRate = entry.getValue()[1];

            // CGST rate
            TaxRate cgst = rateRepo.save(TaxRate.builder()
                    .orgId(orgId).taxConfigId(config.getId())
                    .name("CGST " + halfRate + "%").rateCode("CGST")
                    .percentage(halfRate).taxType("BOTH")
                    .glOutputAccountId(glCgstOutput).glInputAccountId(glInputCredit)
                    .build());

            // SGST rate
            TaxRate sgst = rateRepo.save(TaxRate.builder()
                    .orgId(orgId).taxConfigId(config.getId())
                    .name("SGST " + halfRate + "%").rateCode("SGST")
                    .percentage(halfRate).taxType("BOTH")
                    .glOutputAccountId(glSgstOutput).glInputAccountId(glInputCredit)
                    .build());

            // IGST rate
            TaxRate igst = rateRepo.save(TaxRate.builder()
                    .orgId(orgId).taxConfigId(config.getId())
                    .name("IGST " + fullRate + "%").rateCode("IGST")
                    .percentage(fullRate).taxType("BOTH")
                    .glOutputAccountId(glIgstOutput).glInputAccountId(glInputCredit)
                    .build());

            // GST group (intra-state: CGST + SGST)
            TaxGroup gstGroup = groupRepo.save(TaxGroup.builder()
                    .orgId(orgId).name("GST " + slab + "%")
                    .description("CGST " + halfRate + "% + SGST " + halfRate + "%")
                    .build());
            groupRateRepo.save(TaxGroupRate.builder()
                    .taxGroupId(gstGroup.getId()).taxRateId(cgst.getId()).build());
            groupRateRepo.save(TaxGroupRate.builder()
                    .taxGroupId(gstGroup.getId()).taxRateId(sgst.getId()).build());

            // IGST group (inter-state: single IGST)
            TaxGroup igstGroup = groupRepo.save(TaxGroup.builder()
                    .orgId(orgId).name("IGST " + slab + "%")
                    .description("IGST " + fullRate + "%")
                    .build());
            groupRateRepo.save(TaxGroupRate.builder()
                    .taxGroupId(igstGroup.getId()).taxRateId(igst.getId()).build());
        }
    }

    // ── Vietnam VAT ─────────────────────────────────────────────

    private void seedVietnam(Organisation org) {
        UUID orgId = org.getId();

        TaxConfiguration config = configRepo.save(TaxConfiguration.builder()
                .orgId(orgId).countryCode("VN").taxSystem("VAT").name("Vietnam VAT").build());

        UUID glOutput = ensureAccount(orgId, "2040", "VAT Output", "LIABILITY", "CURRENT_LIABILITY");
        UUID glInput  = ensureAccount(orgId, "1510", "VAT Input", "ASSET", "CURRENT_ASSET");

        groupRepo.save(TaxGroup.builder().orgId(orgId).name("Exempt").description("No tax").build());

        for (BigDecimal rate : List.of(bd("5.00"), bd("10.00"))) {
            TaxRate vat = rateRepo.save(TaxRate.builder()
                    .orgId(orgId).taxConfigId(config.getId())
                    .name("VAT " + rate + "%").rateCode("VAT").percentage(rate).taxType("BOTH")
                    .glOutputAccountId(glOutput).glInputAccountId(glInput).build());

            TaxGroup group = groupRepo.save(TaxGroup.builder()
                    .orgId(orgId).name("VAT " + rate.stripTrailingZeros().toPlainString() + "%").build());
            groupRateRepo.save(TaxGroupRate.builder()
                    .taxGroupId(group.getId()).taxRateId(vat.getId()).build());
        }
    }

    // ── UAE VAT ─────────────────────────────────────────────────

    private void seedUAE(Organisation org) {
        UUID orgId = org.getId();

        TaxConfiguration config = configRepo.save(TaxConfiguration.builder()
                .orgId(orgId).countryCode("AE").taxSystem("VAT").name("UAE VAT").build());

        UUID glOutput = ensureAccount(orgId, "2041", "VAT Output", "LIABILITY", "CURRENT_LIABILITY");
        UUID glInput  = ensureAccount(orgId, "1511", "VAT Input", "ASSET", "CURRENT_ASSET");

        groupRepo.save(TaxGroup.builder().orgId(orgId).name("Exempt").description("No tax").build());

        TaxRate vat5 = rateRepo.save(TaxRate.builder()
                .orgId(orgId).taxConfigId(config.getId())
                .name("VAT 5%").rateCode("VAT").percentage(bd("5.00")).taxType("BOTH")
                .glOutputAccountId(glOutput).glInputAccountId(glInput).build());

        TaxGroup group = groupRepo.save(TaxGroup.builder()
                .orgId(orgId).name("VAT 5%").description("Standard rate").build());
        groupRateRepo.save(TaxGroupRate.builder()
                .taxGroupId(group.getId()).taxRateId(vat5.getId()).build());
    }

    // ── UK VAT ──────────────────────────────────────────────────

    private void seedUK(Organisation org) {
        UUID orgId = org.getId();

        TaxConfiguration config = configRepo.save(TaxConfiguration.builder()
                .orgId(orgId).countryCode("GB").taxSystem("VAT").name("UK VAT").build());

        UUID glOutput = ensureAccount(orgId, "2042", "VAT Output", "LIABILITY", "CURRENT_LIABILITY");
        UUID glInput  = ensureAccount(orgId, "1512", "VAT Input", "ASSET", "CURRENT_ASSET");

        groupRepo.save(TaxGroup.builder().orgId(orgId).name("Exempt").description("No tax").build());

        for (var entry : Map.of("Zero Rated", bd("0.00"), "Reduced Rate", bd("5.00"), "Standard Rate", bd("20.00")).entrySet()) {
            TaxRate vat = rateRepo.save(TaxRate.builder()
                    .orgId(orgId).taxConfigId(config.getId())
                    .name("VAT " + entry.getValue() + "%").rateCode("VAT")
                    .percentage(entry.getValue()).taxType("BOTH")
                    .glOutputAccountId(glOutput).glInputAccountId(glInput).build());

            TaxGroup group = groupRepo.save(TaxGroup.builder()
                    .orgId(orgId).name(entry.getKey())
                    .description("VAT " + entry.getValue() + "%").build());
            groupRateRepo.save(TaxGroupRate.builder()
                    .taxGroupId(group.getId()).taxRateId(vat.getId()).build());
        }
    }

    // ── USA Sales Tax ───────────────────────────────────────────

    private void seedUSA(Organisation org) {
        UUID orgId = org.getId();

        TaxConfiguration config = configRepo.save(TaxConfiguration.builder()
                .orgId(orgId).countryCode("US").taxSystem("SALES_TAX").name("US Sales Tax").build());

        UUID glOutput = ensureAccount(orgId, "2050", "Sales Tax Payable", "LIABILITY", "CURRENT_LIABILITY");
        // No input account — US sales tax is NOT recoverable on purchases

        groupRepo.save(TaxGroup.builder().orgId(orgId).name("Exempt").description("Tax exempt").build());

        // Default rate — org configures their actual state rate
        TaxRate salesTax = rateRepo.save(TaxRate.builder()
                .orgId(orgId).taxConfigId(config.getId())
                .name("Sales Tax").rateCode("SALES_TAX").percentage(bd("0.00")).taxType("OUTPUT")
                .glOutputAccountId(glOutput).glInputAccountId(null)
                .recoverable(false).build());

        TaxGroup group = groupRepo.save(TaxGroup.builder()
                .orgId(orgId).name("Taxable").description("State sales tax").build());
        groupRateRepo.save(TaxGroupRate.builder()
                .taxGroupId(group.getId()).taxRateId(salesTax.getId()).build());
    }

    // ── Malaysia SST ────────────────────────────────────────────

    private void seedMalaysia(Organisation org) {
        UUID orgId = org.getId();

        TaxConfiguration config = configRepo.save(TaxConfiguration.builder()
                .orgId(orgId).countryCode("MY").taxSystem("SST").name("Malaysia SST").build());

        UUID glOutput = ensureAccount(orgId, "2043", "SST Output", "LIABILITY", "CURRENT_LIABILITY");
        UUID glInput  = ensureAccount(orgId, "1513", "SST Input", "ASSET", "CURRENT_ASSET");

        groupRepo.save(TaxGroup.builder().orgId(orgId).name("Exempt").description("No tax").build());

        for (BigDecimal rate : List.of(bd("6.00"), bd("10.00"))) {
            TaxRate sst = rateRepo.save(TaxRate.builder()
                    .orgId(orgId).taxConfigId(config.getId())
                    .name("SST " + rate + "%").rateCode("SST").percentage(rate).taxType("BOTH")
                    .glOutputAccountId(glOutput).glInputAccountId(glInput).build());

            TaxGroup group = groupRepo.save(TaxGroup.builder()
                    .orgId(orgId).name("SST " + rate.stripTrailingZeros().toPlainString() + "%").build());
            groupRateRepo.save(TaxGroupRate.builder()
                    .taxGroupId(group.getId()).taxRateId(sst.getId()).build());
        }
    }

    // ── Indonesia PPN ───────────────────────────────────────────

    private void seedIndonesia(Organisation org) {
        UUID orgId = org.getId();

        TaxConfiguration config = configRepo.save(TaxConfiguration.builder()
                .orgId(orgId).countryCode("ID").taxSystem("PPN").name("Indonesia PPN").build());

        UUID glOutput = ensureAccount(orgId, "2044", "PPN Output", "LIABILITY", "CURRENT_LIABILITY");
        UUID glInput  = ensureAccount(orgId, "1514", "PPN Input", "ASSET", "CURRENT_ASSET");

        groupRepo.save(TaxGroup.builder().orgId(orgId).name("Exempt").description("No tax").build());

        TaxRate ppn = rateRepo.save(TaxRate.builder()
                .orgId(orgId).taxConfigId(config.getId())
                .name("PPN 11%").rateCode("PPN").percentage(bd("11.00")).taxType("BOTH")
                .glOutputAccountId(glOutput).glInputAccountId(glInput).build());

        TaxGroup group = groupRepo.save(TaxGroup.builder()
                .orgId(orgId).name("PPN 11%").description("Standard rate").build());
        groupRateRepo.save(TaxGroupRate.builder()
                .taxGroupId(group.getId()).taxRateId(ppn.getId()).build());
    }

    // ── Generic fallback ────────────────────────────────────────

    private void seedGenericVAT(Organisation org) {
        UUID orgId = org.getId();

        configRepo.save(TaxConfiguration.builder()
                .orgId(orgId).countryCode(org.getCountryCode()).taxSystem("VAT")
                .name("VAT").build());

        groupRepo.save(TaxGroup.builder().orgId(orgId).name("Exempt").description("No tax").build());

        log.info("Generic VAT config created for org {} — admin must add rates via API",
                orgId);
    }

    // ── Helpers ─────────────────────────────────────────────────

    private UUID findAccountId(UUID orgId, String code) {
        return accountRepo.findByOrgIdAndCodeAndIsDeletedFalse(orgId, code)
                .map(Account::getId).orElse(null);
    }

    private UUID ensureAccount(UUID orgId, String code, String name, String type, String subType) {
        return accountRepo.findByOrgIdAndCodeAndIsDeletedFalse(orgId, code)
                .map(Account::getId)
                .orElseGet(() -> {
                    Account account = Account.builder()
                            .code(code).name(name)
                            .type(type).subType(subType).level(2)
                            .currency("INR").active(true).build();
                    account.setOrgId(orgId);
                    return accountRepo.save(account).getId();
                });
    }

    private static BigDecimal bd(String val) {
        return new BigDecimal(val);
    }
}
