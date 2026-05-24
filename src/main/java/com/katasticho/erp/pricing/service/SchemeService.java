package com.katasticho.erp.pricing.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.repository.ItemRepository;
import com.katasticho.erp.pricing.dto.SchemeRequest;
import com.katasticho.erp.pricing.dto.SchemeResponse;
import com.katasticho.erp.pricing.entity.Scheme;
import com.katasticho.erp.pricing.repository.SchemeRepository;
import com.katasticho.erp.procurement.entity.Supplier;
import com.katasticho.erp.procurement.repository.SupplierRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.Comparator;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class SchemeService {

    private final SchemeRepository schemeRepository;
    private final ItemRepository itemRepository;
    private final SupplierRepository supplierRepository;

    @Transactional
    public SchemeResponse create(SchemeRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Scheme scheme = Scheme.builder()
                .orgId(orgId)
                .name(request.name())
                .schemeType(request.schemeType())
                .itemId(request.itemId())
                .buyQuantity(request.buyQuantity())
                .freeQuantity(request.freeQuantity())
                .discountPercent(request.discountPercent())
                .minOrderQuantity(request.minOrderQuantity() != null
                        ? request.minOrderQuantity() : BigDecimal.ZERO)
                .validFrom(request.validFrom())
                .validTo(request.validTo())
                .supplierId(request.supplierId())
                .active(request.active())
                .build();
        return toResponse(schemeRepository.save(scheme));
    }

    @Transactional
    public SchemeResponse update(UUID id, SchemeRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Scheme scheme = schemeRepository.findByIdAndOrgIdAndDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("Scheme", id));
        scheme.setName(request.name());
        scheme.setSchemeType(request.schemeType());
        scheme.setItemId(request.itemId());
        scheme.setBuyQuantity(request.buyQuantity());
        scheme.setFreeQuantity(request.freeQuantity());
        scheme.setDiscountPercent(request.discountPercent());
        scheme.setMinOrderQuantity(request.minOrderQuantity() != null
                ? request.minOrderQuantity() : BigDecimal.ZERO);
        scheme.setValidFrom(request.validFrom());
        scheme.setValidTo(request.validTo());
        scheme.setSupplierId(request.supplierId());
        scheme.setActive(request.active());
        return toResponse(schemeRepository.save(scheme));
    }

    @Transactional
    public void delete(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Scheme scheme = schemeRepository.findByIdAndOrgIdAndDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("Scheme", id));
        scheme.setDeleted(true);
        schemeRepository.save(scheme);
    }

    @Transactional(readOnly = true)
    public List<SchemeResponse> list() {
        UUID orgId = TenantContext.getCurrentOrgId();
        return schemeRepository.findByOrgIdAndDeletedFalseOrderByCreatedAtDesc(orgId)
                .stream().map(this::toResponse).toList();
    }

    @Transactional(readOnly = true)
    public List<SchemeResponse> getApplicable(UUID itemId, BigDecimal quantity) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return schemeRepository.findApplicable(orgId, itemId, LocalDate.now())
                .stream()
                .filter(s -> s.getMinOrderQuantity() == null
                        || quantity == null
                        || quantity.compareTo(s.getMinOrderQuantity()) >= 0)
                .sorted(Comparator
                        .comparing((Scheme s) -> s.getMinOrderQuantity() == null
                                ? BigDecimal.ZERO : s.getMinOrderQuantity())
                        .reversed()
                        .thenComparing(Scheme::getCreatedAt, Comparator.reverseOrder()))
                .map(this::toResponse)
                .toList();
    }

    private SchemeResponse toResponse(Scheme s) {
        String itemName = s.getItemId() != null
                ? itemRepository.findById(s.getItemId()).map(Item::getName).orElse(null)
                : null;
        String supplierName = s.getSupplierId() != null
                ? supplierRepository.findById(s.getSupplierId()).map(Supplier::getName).orElse(null)
                : null;
        return new SchemeResponse(
                s.getId(), s.getName(), s.getSchemeType(),
                s.getItemId(), itemName,
                s.getBuyQuantity(), s.getFreeQuantity(), s.getDiscountPercent(),
                s.getMinOrderQuantity(), s.getValidFrom(), s.getValidTo(),
                s.getSupplierId(), supplierName, s.isActive(), s.getCreatedAt());
    }
}
