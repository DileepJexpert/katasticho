package com.katasticho.erp.franchise.service;

import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.franchise.dto.FranchiseRoyaltySettlementRequest;
import com.katasticho.erp.franchise.dto.FranchiseRoyaltySettlementResponse;
import com.katasticho.erp.franchise.entity.FranchiseNode;
import com.katasticho.erp.franchise.entity.FranchiseRoyaltySettlement;
import com.katasticho.erp.franchise.repository.FranchiseNodeRepository;
import com.katasticho.erp.franchise.repository.FranchiseRoyaltySettlementRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.ZoneOffset;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class FranchiseRoyaltyService {

    private final FranchiseRoyaltySettlementRepository settlementRepo;
    private final FranchiseNodeRepository nodeRepo;

    @Transactional(readOnly = true)
    public List<FranchiseRoyaltySettlementResponse> listSettlements(UUID orgId, UUID nodeId) {
        List<FranchiseRoyaltySettlement> list = (nodeId != null)
                ? settlementRepo.findByNodeId(orgId, nodeId)
                : settlementRepo.findAllByOrgId(orgId);

        return list.stream().map(this::toSettlementResponse).collect(Collectors.toList());
    }

    @Transactional
    public FranchiseRoyaltySettlementResponse calculateSettlement(UUID orgId, FranchiseRoyaltySettlementRequest req) {
        requireRecordedBranchSales();
        FranchiseNode node = nodeRepo.findByOrgIdAndId(orgId, req.getFranchiseNodeId())
                .orElseThrow(() -> BusinessException.notFound("FranchiseNode", req.getFranchiseNodeId()));

        if (req.getPeriodStart().isAfter(req.getPeriodEnd())) {
            throw new BusinessException("Period start cannot be after period end", "INVALID_DATE_RANGE", HttpStatus.BAD_REQUEST);
        }

        // Aggregate node gross sales
        BigDecimal grossSales = new BigDecimal("450000.00");
        BigDecimal royaltyPercent = node.getRoyaltyRatePercent();
        BigDecimal royaltyAmount = grossSales.multiply(royaltyPercent)
                .divide(new BigDecimal("100"), 2, RoundingMode.HALF_UP);
        BigDecimal fixedFee = node.getFixedMonthlyFee();
        BigDecimal totalSettlement = royaltyAmount.add(fixedFee);

        FranchiseRoyaltySettlement settlement = FranchiseRoyaltySettlement.builder()
                .franchiseNodeId(node.getId())
                .periodStart(req.getPeriodStart())
                .periodEnd(req.getPeriodEnd())
                .grossSalesAmount(grossSales)
                .royaltyPercent(royaltyPercent)
                .royaltyAmount(royaltyAmount)
                .fixedFeeAmount(fixedFee)
                .totalSettlementAmount(totalSettlement)
                .status("CALCULATED")
                .build();
        settlement.setOrgId(orgId);

        FranchiseRoyaltySettlement saved = settlementRepo.save(settlement);
        log.info("Calculated royalty settlement [{}] for node [{}] total [INR {}]",
                saved.getId(), node.getNodeCode(), totalSettlement);

        return toSettlementResponse(saved);
    }

    @Transactional
    public FranchiseRoyaltySettlementResponse generateRoyaltyInvoice(UUID orgId, UUID settlementId) {
        requireRecordedBranchSales();
        FranchiseRoyaltySettlement settlement = settlementRepo.findByOrgIdAndId(orgId, settlementId)
                .orElseThrow(() -> BusinessException.notFound("FranchiseRoyaltySettlement", settlementId));

        if ("INVOICED".equalsIgnoreCase(settlement.getStatus()) || "SETTLED".equalsIgnoreCase(settlement.getStatus())) {
            throw new BusinessException("Settlement is already invoiced or settled", "ALREADY_INVOICED", HttpStatus.BAD_REQUEST);
        }

        settlement.setGeneratedInvoiceId(UUID.randomUUID());
        settlement.setStatus("INVOICED");

        FranchiseRoyaltySettlement updated = settlementRepo.save(settlement);
        log.info("Generated royalty invoice for settlement [{}]", settlementId);
        return toSettlementResponse(updated);
    }

    private FranchiseRoyaltySettlementResponse toSettlementResponse(FranchiseRoyaltySettlement s) {
        FranchiseNode node = s.getOrgId() != null 
                ? nodeRepo.findByOrgIdAndId(s.getOrgId(), s.getFranchiseNodeId()).orElse(null)
                : nodeRepo.findById(s.getFranchiseNodeId()).orElse(null);
        String code = node != null ? node.getNodeCode() : "--";
        String name = node != null ? node.getNodeName() : "Franchise Store";

        return FranchiseRoyaltySettlementResponse.builder()
                .id(s.getId())
                .franchiseNodeId(s.getFranchiseNodeId())
                .nodeCode(code)
                .nodeName(name)
                .periodStart(s.getPeriodStart())
                .periodEnd(s.getPeriodEnd())
                .grossSalesAmount(s.getGrossSalesAmount())
                .royaltyPercent(s.getRoyaltyPercent())
                .royaltyAmount(s.getRoyaltyAmount())
                .fixedFeeAmount(s.getFixedFeeAmount())
                .totalSettlementAmount(s.getTotalSettlementAmount())
                .status(s.getStatus())
                .generatedInvoiceId(s.getGeneratedInvoiceId())
                .createdAt(s.getCreatedAt() != null ? s.getCreatedAt().atOffset(ZoneOffset.UTC) : null)
                .build();
    }

    private void requireRecordedBranchSales() {
        throw new BusinessException(
                "Franchise royalty settlement requires recorded branch sales and a real invoice integration and is not available yet",
                "FRANCHISE_ROYALTY_UNAVAILABLE",
                HttpStatus.SERVICE_UNAVAILABLE);
    }
}
