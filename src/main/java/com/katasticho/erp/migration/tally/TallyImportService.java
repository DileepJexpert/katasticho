package com.katasticho.erp.migration.tally;

import com.katasticho.erp.accounting.dto.CreateAccountRequest;
import com.katasticho.erp.accounting.repository.AccountRepository;
import com.katasticho.erp.accounting.service.AccountService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.entity.ContactType;
import com.katasticho.erp.contact.entity.GstTreatment;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.inventory.dto.CreateItemRequest;
import com.katasticho.erp.inventory.entity.HsnGstMaster;
import com.katasticho.erp.inventory.entity.ItemType;
import com.katasticho.erp.inventory.repository.HsnGstMasterRepository;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.inventory.service.ItemService;
import com.katasticho.erp.migration.tally.TallyImportDtos.RowError;
import com.katasticho.erp.migration.tally.TallyImportDtos.RowPlan;
import com.katasticho.erp.migration.tally.TallyImportDtos.TallyImportPreview;
import com.katasticho.erp.migration.tally.TallyImportDtos.TallyImportResult;
import com.katasticho.erp.migration.tally.TallyMasters.TallyLedger;
import com.katasticho.erp.migration.tally.TallyMasters.TallyStockItem;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;

/**
 * Tally → Katasticho migration, slice 1: masters + opening balances.
 *
 * <p>Maps Tally's predefined groups: Sundry Debtors → customers, Sundry
 * Creditors → vendors, the remaining balance-sheet/P&L groups → chart of
 * accounts, Stock Items → items (with opening stock movement + journal via
 * {@link ItemService}). Custom subgroups resolve up the GROUP hierarchy.
 * Duties & Taxes ledgers are skipped — Katasticho has its own GST/TDS control
 * accounts and importing Tally's would double-count.
 *
 * <p><b>Sign convention:</b> Tally XML writes debit balances negative
 * (₹15,000 Dr = {@code -15000.00}); openings are normalized to each entity's
 * natural side.
 *
 * <p>Two-phase: {@link #preview} writes nothing; {@link #importMasters}
 * commits row by row (each create runs in the called service's own
 * transaction), so one bad row never rolls back the rest. Re-running is safe —
 * existing contacts (GSTIN/name), items (name) and accounts (name) are skipped.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class TallyImportService {

    private final TallyXmlParser parser;
    private final ContactRepository contactRepository;
    private final AccountRepository accountRepository;
    private final AccountService accountService;
    private final ItemRepository itemRepository;
    private final ItemService itemService;
    private final HsnGstMasterRepository hsnGstMasterRepository;

    // ── Public API ───────────────────────────────────────────────────────

    public TallyImportPreview preview(byte[] xml) {
        UUID orgId = requireOrgId();
        List<Plan> plans = plan(orgId, parser.parse(xml));

        int customers = 0, vendors = 0, accounts = 0, items = 0, skipped = 0;
        List<RowPlan> rows = new ArrayList<>(plans.size());
        for (Plan p : plans) {
            rows.add(p.row);
            if (!"CREATE".equals(p.row.action())) { skipped++; continue; }
            switch (p.kind) {
                case CUSTOMER -> customers++;
                case VENDOR -> vendors++;
                case ITEM -> items++;
                default -> accounts++;
            }
        }
        return new TallyImportPreview(customers, vendors, accounts, items, skipped, rows);
    }

    public TallyImportResult importMasters(byte[] xml) {
        UUID orgId = requireOrgId();
        List<Plan> plans = plan(orgId, parser.parse(xml));

        int customers = 0, vendors = 0, accounts = 0, items = 0, skipped = 0;
        List<RowError> errors = new ArrayList<>();
        int accountSeq = 1;

        for (Plan p : plans) {
            if (!"CREATE".equals(p.row.action())) { skipped++; continue; }
            try {
                switch (p.kind) {
                    case CUSTOMER, VENDOR -> {
                        contactRepository.save(buildContact(p.ledger, p.kind));
                        if (p.kind == Kind.CUSTOMER) customers++; else vendors++;
                    }
                    case ITEM -> {
                        itemService.createItem(buildItemRequest(p.stockItem));
                        items++;
                    }
                    default -> {
                        accountSeq = createAccount(orgId, p, accountSeq);
                        accounts++;
                    }
                }
            } catch (Exception e) {
                String name = p.ledger != null ? p.ledger.name() : p.stockItem.name();
                errors.add(new RowError(name, e.getMessage()));
                log.warn("Tally import row failed ({}): {}", name, e.getMessage());
            }
        }

        log.info("Tally import: {} customers, {} vendors, {} accounts, {} items, {} skipped, {} errors",
                customers, vendors, accounts, items, skipped, errors.size());
        return new TallyImportResult(customers, vendors, accounts, items, skipped, errors);
    }

    // ── Planning ─────────────────────────────────────────────────────────

    enum Kind { CUSTOMER, VENDOR, ASSET, LIABILITY, EQUITY, REVENUE, EXPENSE, ITEM, SKIP }

    private record Plan(Kind kind, RowPlan row, TallyLedger ledger, TallyStockItem stockItem) {}

    private List<Plan> plan(UUID orgId, TallyMasters masters) {
        List<Plan> plans = new ArrayList<>();
        for (TallyLedger ledger : masters.ledgers()) {
            plans.add(planLedger(orgId, ledger, masters.groupParents()));
        }
        for (TallyStockItem item : masters.stockItems()) {
            plans.add(planStockItem(orgId, item));
        }
        return plans;
    }

    private Plan planLedger(UUID orgId, TallyLedger ledger, Map<String, String> groupParents) {
        Kind kind = classify(ledger, groupParents);
        String becomes = switch (kind) {
            case CUSTOMER -> "CUSTOMER";
            case VENDOR -> "VENDOR";
            case ITEM -> "ITEM"; // unreachable for ledgers
            case SKIP -> "SKIPPED";
            default -> "ACCOUNT_" + kind;
        };

        if (kind == Kind.SKIP) {
            return new Plan(kind, new RowPlan(ledger.name(), ledger.parentGroup(), becomes,
                    "SKIP", "System/tax ledger — Katasticho manages this itself"), ledger, null);
        }

        if (kind == Kind.CUSTOMER || kind == Kind.VENDOR) {
            String gstin = ledger.gstin();
            boolean exists = (gstin != null && !gstin.isBlank()
                    && contactRepository.findFirstByOrgIdAndGstinIgnoreCaseAndIsDeletedFalse(orgId, gstin).isPresent())
                    || contactRepository.findFirstByOrgIdAndDisplayNameIgnoreCaseAndIsDeletedFalse(
                            orgId, ledger.name()).isPresent();
            if (exists) {
                return new Plan(kind, new RowPlan(ledger.name(), ledger.parentGroup(), becomes,
                        "SKIP_EXISTS", "A contact with this GSTIN/name already exists"), ledger, null);
            }
            BigDecimal opening = normalizedContactOpening(ledger, kind);
            String detail = opening.signum() != 0
                    ? "Opening " + opening.toPlainString() : "No opening balance";
            return new Plan(kind, new RowPlan(ledger.name(), ledger.parentGroup(), becomes,
                    "CREATE", detail), ledger, null);
        }

        if (accountRepository.findFirstByOrgIdAndNameIgnoreCaseAndIsDeletedFalse(orgId, ledger.name()).isPresent()) {
            return new Plan(kind, new RowPlan(ledger.name(), ledger.parentGroup(), becomes,
                    "SKIP_EXISTS", "An account with this name already exists"), ledger, null);
        }
        return new Plan(kind, new RowPlan(ledger.name(), ledger.parentGroup(), becomes,
                "CREATE", "Chart of accounts entry"), ledger, null);
    }

    private Plan planStockItem(UUID orgId, TallyStockItem item) {
        if (itemRepository.findFirstByOrgIdAndNameIgnoreCaseAndIsDeletedFalse(orgId, item.name()).isPresent()) {
            return new Plan(Kind.ITEM, new RowPlan(item.name(), item.parentGroup(), "ITEM",
                    "SKIP_EXISTS", "An item with this name already exists"), null, item);
        }
        String detail = item.openingQty() != null && item.openingQty().signum() > 0
                ? "Opening stock " + item.openingQty().toPlainString() + " " + nvl(item.baseUnit(), "PCS")
                : "No opening stock";
        return new Plan(Kind.ITEM, new RowPlan(item.name(), item.parentGroup(), "ITEM",
                "CREATE", detail), null, item);
    }

    // ── Group classification ─────────────────────────────────────────────

    /** Resolve the ledger's group up the GROUP hierarchy to a predefined primary group. */
    Kind classify(TallyLedger ledger, Map<String, String> groupParents) {
        if ("Profit & Loss A/c".equalsIgnoreCase(nvl(ledger.name(), ""))) return Kind.SKIP;

        String group = ledger.parentGroup();
        for (int hops = 0; group != null && hops < 10; hops++) {
            Kind kind = primaryGroupKind(group);
            if (kind != null) return kind;
            group = groupParents.get(group);
        }
        // Unknown custom group with no recognizable ancestor — don't guess a type.
        return Kind.SKIP;
    }

    private Kind primaryGroupKind(String group) {
        return switch (group.trim().toLowerCase(Locale.ROOT)) {
            case "sundry debtors" -> Kind.CUSTOMER;
            case "sundry creditors" -> Kind.VENDOR;
            case "duties & taxes", "duties and taxes" -> Kind.SKIP;
            case "bank accounts", "cash-in-hand", "cash-in hand", "fixed assets",
                 "current assets", "investments", "deposits (asset)",
                 "loans & advances (asset)", "stock-in-hand", "misc. expenses (asset)"
                    -> Kind.ASSET;
            case "bank od a/c", "bank occ a/c", "secured loans", "unsecured loans",
                 "current liabilities", "provisions", "loans (liability)", "suspense a/c"
                    -> Kind.LIABILITY;
            case "capital account", "reserves & surplus" -> Kind.EQUITY;
            case "sales accounts", "direct incomes", "indirect incomes",
                 "income (direct)", "income (indirect)" -> Kind.REVENUE;
            case "purchase accounts", "direct expenses", "indirect expenses",
                 "expenses (direct)", "expenses (indirect)" -> Kind.EXPENSE;
            default -> null;
        };
    }

    // ── Entity builders ──────────────────────────────────────────────────

    private Contact buildContact(TallyLedger ledger, Kind kind) {
        String gstin = trimToNull(ledger.gstin());
        return Contact.builder()
                .contactType(kind == Kind.CUSTOMER ? ContactType.CUSTOMER : ContactType.VENDOR)
                .displayName(ledger.name().trim())
                .gstin(gstin)
                .gstTreatment(gstin != null && gstin.length() == 15
                        ? GstTreatment.REGISTERED : GstTreatment.UNREGISTERED)
                .billingStateCode(stateCodeOf(gstin))
                .billingState(trimToNull(ledger.stateName()))
                .billingAddressLine1(truncate(ledger.address(), 255))
                .email(trimToNull(ledger.email()))
                .phone(truncate(ledger.phone(), 30))
                .mobile(truncate(ledger.mobile(), 30))
                .pan(truncate(ledger.pan(), 10))
                .openingBalance(normalizedContactOpening(ledger, kind))
                .notes("Imported from Tally (group: " + nvl(ledger.parentGroup(), "?") + ")")
                .build();
    }

    /**
     * Tally: negative = debit. A customer's receivable is a debit (negative in
     * the file); a vendor's payable is a credit (positive). Both normalize to
     * positive "outstanding" here; opposite-side balances (advances) stay negative.
     */
    BigDecimal normalizedContactOpening(TallyLedger ledger, Kind kind) {
        BigDecimal raw = ledger.openingBalance() == null ? BigDecimal.ZERO : ledger.openingBalance();
        return kind == Kind.CUSTOMER ? raw.negate() : raw;
    }

    private int createAccount(UUID orgId, Plan plan, int seq) {
        String code = nextFreeCode(orgId, seq);
        BigDecimal opening = normalizedAccountOpening(plan.ledger.openingBalance(), plan.kind);
        accountService.createAccount(new CreateAccountRequest(
                code,
                plan.ledger.name().trim(),
                plan.kind.name(),
                null,
                null,
                "Imported from Tally (group: " + nvl(plan.ledger.parentGroup(), "?") + ")",
                opening));
        // Continue numbering after the code we just used.
        return Integer.parseInt(code.substring(1)) + 1;
    }

    /** Tally ledgers have no codes — mint T-prefixed sequential ones. */
    private String nextFreeCode(UUID orgId, int seq) {
        for (int i = seq; i < seq + 10000; i++) {
            String code = String.format("T%04d", i);
            if (!accountRepository.existsByOrgIdAndCodeAndIsDeletedFalse(orgId, code)) {
                return code;
            }
        }
        throw new BusinessException("Could not allocate an account code", "TALLY_CODE_EXHAUSTED");
    }

    /** Debit-normal types flip Tally's negative-debit convention; credit-normal keep it. */
    BigDecimal normalizedAccountOpening(BigDecimal raw, Kind kind) {
        if (raw == null) return BigDecimal.ZERO;
        return switch (kind) {
            case ASSET, EXPENSE -> raw.negate();
            default -> raw;
        };
    }

    private CreateItemRequest buildItemRequest(TallyStockItem item) {
        BigDecimal gstRate = item.gstRate();
        if ((gstRate == null || gstRate.signum() == 0) && item.hsnCode() != null) {
            gstRate = hsnGstMasterRepository.findByHsnCodeAndActiveTrue(item.hsnCode().trim())
                    .map(HsnGstMaster::getGstRate).orElse(BigDecimal.ZERO);
        }
        BigDecimal openingQty = item.openingQty() != null && item.openingQty().signum() > 0
                ? item.openingQty() : null;
        BigDecimal rate = item.openingRate() == null ? BigDecimal.ZERO : item.openingRate().abs();

        return new CreateItemRequest(
                skuFromName(item.name()),                 // sku
                truncate(item.name(), 255),               // name
                null,                                     // description
                ItemType.GOODS,                           // itemType
                trimToNull(item.parentGroup()),           // category (Tally stock group)
                null,                                     // brand
                truncate(item.hsnCode(), 10),             // hsnCode
                truncate(nvl(item.baseUnit(), "PCS"), 20),// unitOfMeasure
                rate,                                     // purchasePrice (opening rate)
                BigDecimal.ZERO,                          // salePrice
                null,                                     // mrp
                gstRate == null ? BigDecimal.ZERO : gstRate, // gstRate
                true,                                     // trackInventory
                false,                                    // trackBatches
                null, null,                               // reorderLevel, reorderQuantity
                null, null,                               // barcode, manufacturer
                null, null,                               // preferredVendorId, rackLocationId
                null, null, null, null, null, null,       // weight/dimensions
                null, null, null, null, null, null, null, // pharma fields
                null, null, null,                         // account codes
                openingQty,                               // openingStock
                null,                                     // openingWarehouseId (default)
                null, null, null,                         // opening batch fields
                null, null, null,                         // purchase UoM fields
                null,                                     // secondaryUnits
                null,                                     // groupId
                null                                      // variantAttributes
        );
    }

    /** SKU from the Tally item name: alphanumeric, upper-cased, ≤50 chars. */
    static String skuFromName(String name) {
        String cleaned = name.toUpperCase(Locale.ROOT).replaceAll("[^A-Z0-9]+", "-")
                .replaceAll("(^-+|-+$)", "");
        if (cleaned.isEmpty()) cleaned = "TALLY-ITEM";
        return cleaned.length() <= 50 ? cleaned : cleaned.substring(0, 50);
    }

    /** First two GSTIN digits are the GST state code. */
    private static String stateCodeOf(String gstin) {
        return gstin != null && gstin.length() >= 2 ? gstin.substring(0, 2) : null;
    }

    private static String truncate(String s, int max) {
        String t = trimToNull(s);
        return t == null || t.length() <= max ? t : t.substring(0, max);
    }

    private static String trimToNull(String s) {
        if (s == null) return null;
        String t = s.trim();
        return t.isEmpty() ? null : t;
    }

    private static String nvl(String s, String fallback) {
        return s == null || s.isBlank() ? fallback : s;
    }

    private UUID requireOrgId() {
        UUID orgId = TenantContext.getCurrentOrgId();
        if (orgId == null) {
            throw new BusinessException("Organisation context is required", "ORG_CONTEXT_REQUIRED");
        }
        return orgId;
    }
}
