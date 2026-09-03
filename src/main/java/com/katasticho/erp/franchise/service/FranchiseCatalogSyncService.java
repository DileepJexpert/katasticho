package com.katasticho.erp.franchise.service;

import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.franchise.dto.*;
import com.katasticho.erp.franchise.entity.BranchItemOverride;
import com.katasticho.erp.franchise.entity.FranchiseCatalogPolicy;
import com.katasticho.erp.franchise.entity.FranchiseNode;
import com.katasticho.erp.franchise.repository.BranchItemOverrideRepository;
import com.katasticho.erp.franchise.repository.FranchiseCatalogPolicyRepository;
import com.katasticho.erp.franchise.repository.FranchiseNodeRepository;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.repository.ItemRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class FranchiseCatalogSyncService {

    private final FranchiseNodeRepository nodeRepo;
    private final FranchiseCatalogPolicyRepository policyRepo;
    private final BranchItemOverrideRepository overrideRepo;
    private final ItemRepository itemRepo;

    // --- Franchise Nodes ---

    @Transactional(readOnly = true)
    public List<FranchiseNodeResponse> listNodes(UUID orgId) {
        return nodeRepo.findAllByOrgId(orgId).stream()
                .map(this::toNodeResponse)
                .collect(Collectors.toList());
    }

    @Transactional
    public FranchiseNodeResponse createNode(UUID orgId, FranchiseNodeRequest req) {
        if (nodeRepo.findByOrgIdAndNodeCode(orgId, req.getNodeCode()).isPresent()) {
            throw new BusinessException("Franchise node code already exists: " + req.getNodeCode(),
                    "DUPLICATE_NODE_CODE", HttpStatus.CONFLICT);
        }

        FranchiseNode node = FranchiseNode.builder()
                .nodeCode(req.getNodeCode().trim().toUpperCase())
                .nodeName(req.getNodeName().trim())
                .nodeType(req.getNodeType() != null ? req.getNodeType() : "FOFO")
                .branchId(req.getBranchId())
                .contactEmail(req.getContactEmail())
                .phone(req.getPhone())
                .city(req.getCity())
                .stateCode(req.getStateCode())
                .royaltyRatePercent(req.getRoyaltyRatePercent() != null ? req.getRoyaltyRatePercent() : new BigDecimal("5.00"))
                .fixedMonthlyFee(req.getFixedMonthlyFee() != null ? req.getFixedMonthlyFee() : BigDecimal.ZERO)
                .active(req.getActive() == null || req.getActive())
                .build();
        node.setOrgId(orgId);

        FranchiseNode saved = nodeRepo.save(node);
        log.info("Created franchise node [{}] for org [{}]", saved.getNodeCode(), orgId);
        return toNodeResponse(saved);
    }

    @Transactional
    public FranchiseNodeResponse updateNode(UUID orgId, UUID nodeId, FranchiseNodeRequest req) {
        FranchiseNode node = nodeRepo.findByOrgIdAndId(orgId, nodeId)
                .orElseThrow(() -> BusinessException.notFound("FranchiseNode", nodeId));

        if (req.getNodeName() != null) node.setNodeName(req.getNodeName().trim());
        if (req.getNodeType() != null) node.setNodeType(req.getNodeType());
        if (req.getBranchId() != null) node.setBranchId(req.getBranchId());
        if (req.getContactEmail() != null) node.setContactEmail(req.getContactEmail());
        if (req.getPhone() != null) node.setPhone(req.getPhone());
        if (req.getCity() != null) node.setCity(req.getCity());
        if (req.getStateCode() != null) node.setStateCode(req.getStateCode());
        if (req.getRoyaltyRatePercent() != null) node.setRoyaltyRatePercent(req.getRoyaltyRatePercent());
        if (req.getFixedMonthlyFee() != null) node.setFixedMonthlyFee(req.getFixedMonthlyFee());
        if (req.getActive() != null) node.setActive(req.getActive());

        FranchiseNode updated = nodeRepo.save(node);
        return toNodeResponse(updated);
    }

    @Transactional
    public void deleteNode(UUID orgId, UUID nodeId) {
        FranchiseNode node = nodeRepo.findByOrgIdAndId(orgId, nodeId)
                .orElseThrow(() -> BusinessException.notFound("FranchiseNode", nodeId));
        node.setDeleted(true);
        nodeRepo.save(node);
        log.info("Soft-deleted franchise node [{}]", nodeId);
    }

    // --- Policy ---

    @Transactional(readOnly = true)
    public FranchiseCatalogPolicyResponse getPolicy(UUID orgId) {
        FranchiseCatalogPolicy policy = policyRepo.findByOrgId(orgId)
                .orElseGet(() -> FranchiseCatalogPolicy.builder()
                        .autoSyncNewItems(true)
                        .allowBranchPriceOverride(true)
                        .maxDiscountFromMrpPercent(new BigDecimal("15.00"))
                        .minMarginPercent(new BigDecimal("8.00"))
                        .syncMode("ALL_ITEMS")
                        .build());
        return toPolicyResponse(policy);
    }

    @Transactional
    public FranchiseCatalogPolicyResponse savePolicy(UUID orgId, FranchiseCatalogPolicyRequest req) {
        FranchiseCatalogPolicy policy = policyRepo.findByOrgId(orgId)
                .orElseGet(() -> {
                    FranchiseCatalogPolicy p = new FranchiseCatalogPolicy();
                    p.setOrgId(orgId);
                    return p;
                });

        if (req.getAutoSyncNewItems() != null) policy.setAutoSyncNewItems(req.getAutoSyncNewItems());
        if (req.getAllowBranchPriceOverride() != null) policy.setAllowBranchPriceOverride(req.getAllowBranchPriceOverride());
        if (req.getMaxDiscountFromMrpPercent() != null) policy.setMaxDiscountFromMrpPercent(req.getMaxDiscountFromMrpPercent());
        if (req.getMinMarginPercent() != null) policy.setMinMarginPercent(req.getMinMarginPercent());
        if (req.getSyncMode() != null) policy.setSyncMode(req.getSyncMode());

        FranchiseCatalogPolicy saved = policyRepo.save(policy);
        log.info("Saved franchise catalog policy for org [{}]", orgId);
        return toPolicyResponse(saved);
    }

    // --- Catalog Sync Push ---

    @Transactional
    public CatalogSyncResultResponse pushCatalogToBranches(UUID orgId, CatalogSyncPushRequest req) {
        requireBranchIntegration();
        List<FranchiseNode> targetNodes = (req.getTargetNodeIds() != null && !req.getTargetNodeIds().isEmpty())
                ? req.getTargetNodeIds().stream()
                .map(id -> nodeRepo.findByOrgIdAndId(orgId, id).orElse(null))
                .filter(n -> n != null && n.isActive())
                .collect(Collectors.toList())
                : nodeRepo.findActiveByOrgId(orgId);

        if (targetNodes.isEmpty()) {
            throw new BusinessException("No active franchise nodes found to sync catalog", "NO_TARGET_NODES", HttpStatus.BAD_REQUEST);
        }

        List<Item> itemsToSync = (req.getItemIds() != null && !req.getItemIds().isEmpty())
                ? itemRepo.findAllById(req.getItemIds())
                : itemRepo.findByOrgIdAndIsDeletedFalse(orgId, Pageable.unpaged()).getContent();

        OffsetDateTime now = OffsetDateTime.now();
        List<String> nodeNames = new ArrayList<>();
        int itemsSynced = 0;

        for (FranchiseNode node : targetNodes) {
            node.setLastSyncAt(now);
            nodeRepo.save(node);
            nodeNames.add(node.getNodeName() + " (" + node.getNodeCode() + ")");
            itemsSynced += itemsToSync.size();
        }

        log.info("Pushed catalog sync of [{}] items to [{}] franchise nodes for org [{}]",
                itemsToSync.size(), targetNodes.size(), orgId);

        return CatalogSyncResultResponse.builder()
                .nodesTargeted(targetNodes.size())
                .itemsSynced(itemsSynced)
                .itemsCreated(itemsToSync.size())
                .itemsUpdated(0)
                .nodeNames(nodeNames)
                .syncedAt(now)
                .build();
    }

    // --- Branch Price Overrides ---

    @Transactional(readOnly = true)
    public List<BranchPriceOverrideResponse> getBranchOverrides(UUID orgId, UUID branchId) {
        requireBranchIntegration();
        return overrideRepo.findByBranchId(orgId, branchId).stream()
                .map(o -> {
                    Item item = itemRepo.findById(o.getItemId()).orElse(null);
                    String sku = item != null ? item.getSku() : "--";
                    String name = item != null ? item.getName() : "Item";
                    BigDecimal masterSelling = item != null && item.getSalePrice() != null ? item.getSalePrice() : BigDecimal.ZERO;
                    BigDecimal masterMrp = item != null && item.getMrp() != null ? item.getMrp() : BigDecimal.ZERO;

                    BigDecimal margin = BigDecimal.ZERO;
                    if (masterSelling.compareTo(BigDecimal.ZERO) > 0) {
                        margin = o.getCustomSellingPrice().subtract(masterSelling)
                                .divide(masterSelling, 4, RoundingMode.HALF_UP)
                                .multiply(new BigDecimal("100"));
                    }

                    return BranchPriceOverrideResponse.builder()
                            .id(o.getId())
                            .branchId(o.getBranchId())
                            .itemId(o.getItemId())
                            .itemSku(sku)
                            .itemName(name)
                            .masterSellingPrice(masterSelling)
                            .masterMrp(masterMrp)
                            .customSellingPrice(o.getCustomSellingPrice())
                            .customMrp(o.getCustomMrp())
                            .effectiveMarginPercent(margin)
                            .overrideActive(o.isOverrideActive())
                            .build();
                })
                .collect(Collectors.toList());
    }

    @Transactional
    public BranchPriceOverrideResponse savePriceOverride(UUID orgId, BranchPriceOverrideRequest req) {
        requireBranchIntegration();
        FranchiseCatalogPolicy policy = policyRepo.findByOrgId(orgId).orElse(null);
        if (policy != null && !policy.isAllowBranchPriceOverride()) {
            throw new BusinessException("Branch price overrides are prohibited by HQ catalog policy",
                    "BRANCH_OVERRIDES_FORBIDDEN", HttpStatus.FORBIDDEN);
        }

        Item item = itemRepo.findById(req.getItemId())
                .orElseThrow(() -> BusinessException.notFound("Item", req.getItemId()));

        BigDecimal customPrice = req.getCustomSellingPrice();
        if (customPrice == null || customPrice.compareTo(BigDecimal.ZERO) <= 0) {
            throw new BusinessException("Custom selling price must be greater than zero",
                    "INVALID_PRICE", HttpStatus.BAD_REQUEST);
        }

        // Validate margin bounds if policy exists
        if (policy != null && item.getMrp() != null && item.getMrp().compareTo(BigDecimal.ZERO) > 0) {
            BigDecimal maxDiscountRate = policy.getMaxDiscountFromMrpPercent().divide(new BigDecimal("100"), 4, RoundingMode.HALF_UP);
            BigDecimal minAllowedPrice = item.getMrp().multiply(BigDecimal.ONE.subtract(maxDiscountRate));
            if (customPrice.compareTo(minAllowedPrice) < 0) {
                throw new BusinessException("Selling price INR " + customPrice + " is below maximum allowed discount limit (Min: INR " + minAllowedPrice.setScale(2, RoundingMode.HALF_UP) + ")",
                        "PRICE_BELOW_HQ_FLOOR", HttpStatus.BAD_REQUEST);
            }
        }

        BranchItemOverride override = overrideRepo.findByBranchAndItem(orgId, req.getBranchId(), req.getItemId())
                .orElseGet(() -> {
                    BranchItemOverride bio = new BranchItemOverride();
                    bio.setOrgId(orgId);
                    bio.setBranchId(req.getBranchId());
                    bio.setItemId(req.getItemId());
                    return bio;
                });

        override.setCustomSellingPrice(customPrice);
        override.setCustomMrp(req.getCustomMrp() != null ? req.getCustomMrp() : item.getMrp());
        override.setMinRetailPrice(req.getMinRetailPrice());
        override.setOverrideActive(req.getOverrideActive() == null || req.getOverrideActive());

        BranchItemOverride saved = overrideRepo.save(override);
        log.info("Saved branch price override for item [{}] on branch [{}]", req.getItemId(), req.getBranchId());

        BigDecimal masterSelling = item.getSalePrice() != null ? item.getSalePrice() : BigDecimal.ZERO;
        BigDecimal margin = BigDecimal.ZERO;
        if (masterSelling.compareTo(BigDecimal.ZERO) > 0) {
            margin = customPrice.subtract(masterSelling)
                    .divide(masterSelling, 4, RoundingMode.HALF_UP)
                    .multiply(new BigDecimal("100"));
        }

        return BranchPriceOverrideResponse.builder()
                .id(saved.getId())
                .branchId(saved.getBranchId())
                .itemId(saved.getItemId())
                .itemSku(item.getSku())
                .itemName(item.getName())
                .masterSellingPrice(masterSelling)
                .masterMrp(item.getMrp())
                .customSellingPrice(saved.getCustomSellingPrice())
                .customMrp(saved.getCustomMrp())
                .effectiveMarginPercent(margin)
                .overrideActive(saved.isOverrideActive())
                .build();
    }

    @Transactional
    public void deletePriceOverride(UUID orgId, UUID overrideId) {
        requireBranchIntegration();
        BranchItemOverride bio = overrideRepo.findById(overrideId)
                .orElseThrow(() -> BusinessException.notFound("BranchItemOverride", overrideId));
        bio.setDeleted(true);
        overrideRepo.save(bio);
    }

    private FranchiseNodeResponse toNodeResponse(FranchiseNode n) {
        return FranchiseNodeResponse.builder()
                .id(n.getId())
                .nodeCode(n.getNodeCode())
                .nodeName(n.getNodeName())
                .nodeType(n.getNodeType())
                .branchId(n.getBranchId())
                .contactEmail(n.getContactEmail())
                .phone(n.getPhone())
                .city(n.getCity())
                .stateCode(n.getStateCode())
                .royaltyRatePercent(n.getRoyaltyRatePercent())
                .fixedMonthlyFee(n.getFixedMonthlyFee())
                .active(n.isActive())
                .lastSyncAt(n.getLastSyncAt())
                .createdAt(n.getCreatedAt() != null ? n.getCreatedAt().atOffset(ZoneOffset.UTC) : null)
                .build();
    }

    private FranchiseCatalogPolicyResponse toPolicyResponse(FranchiseCatalogPolicy p) {
        return FranchiseCatalogPolicyResponse.builder()
                .id(p.getId())
                .autoSyncNewItems(p.isAutoSyncNewItems())
                .allowBranchPriceOverride(p.isAllowBranchPriceOverride())
                .maxDiscountFromMrpPercent(p.getMaxDiscountFromMrpPercent())
                .minMarginPercent(p.getMinMarginPercent())
                .syncMode(p.getSyncMode())
                .build();
    }

    private void requireBranchIntegration() {
        throw new BusinessException(
                "Franchise catalog sync and branch price overrides require an organisation-to-branch integration and are not available yet",
                "FRANCHISE_INTEGRATION_UNAVAILABLE",
                HttpStatus.SERVICE_UNAVAILABLE);
    }
}
