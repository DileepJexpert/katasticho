package com.katasticho.erp.procurement.service;

import com.katasticho.erp.audit.AuditService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.procurement.dto.SupplierRequest;
import com.katasticho.erp.procurement.dto.SupplierResponse;
import com.katasticho.erp.procurement.entity.Supplier;
import com.katasticho.erp.procurement.repository.SupplierRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class SupplierService {

    private final SupplierRepository supplierRepository;
    private final AuditService auditService;

    @Transactional
    public SupplierResponse createSupplier(SupplierRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();

        if (request.gstin() != null && !request.gstin().isBlank()
                && supplierRepository.existsByOrgIdAndGstinAndIsDeletedFalse(orgId, request.gstin().trim())) {
            throw new BusinessException(
                    "Supplier with GSTIN " + request.gstin() + " already exists",
                    "SUP_DUPLICATE_GSTIN", HttpStatus.CONFLICT);
        }

        Supplier supplier = Supplier.builder()
                .name(request.name().trim())
                .gstin(blankToNull(request.gstin()))
                .pan(blankToNull(request.pan()))
                .phone(blankToNull(request.phone()))
                .email(blankToNull(request.email()))
                .addressLine1(request.addressLine1())
                .addressLine2(request.addressLine2())
                .city(request.city())
                .state(request.state())
                .stateCode(request.stateCode())
                .postalCode(request.postalCode())
                .country(request.country() != null ? request.country() : "IN")
                .paymentTermsDays(request.paymentTermsDays() != null ? request.paymentTermsDays() : 30)
                .notes(request.notes())
                .active(request.active() == null || request.active())
                .build();

        supplier = supplierRepository.save(supplier);
        auditService.log("SUPPLIER", supplier.getId(), "CREATE", null,
                "{\"name\":\"" + supplier.getName() + "\"}");
        log.info("Supplier {} created", supplier.getName());
        return toResponse(supplier);
    }

    @Transactional
    public SupplierResponse updateSupplier(UUID id, SupplierRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Supplier supplier = supplierRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("Supplier", id));

        supplier.setName(request.name().trim());
        supplier.setGstin(blankToNull(request.gstin()));
        supplier.setPan(blankToNull(request.pan()));
        supplier.setPhone(blankToNull(request.phone()));
        supplier.setEmail(blankToNull(request.email()));
        supplier.setAddressLine1(request.addressLine1());
        supplier.setAddressLine2(request.addressLine2());
        supplier.setCity(request.city());
        supplier.setState(request.state());
        supplier.setStateCode(request.stateCode());
        supplier.setPostalCode(request.postalCode());
        if (request.country() != null) supplier.setCountry(request.country());
        if (request.paymentTermsDays() != null) supplier.setPaymentTermsDays(request.paymentTermsDays());
        supplier.setNotes(request.notes());
        if (request.active() != null) supplier.setActive(request.active());

        supplier = supplierRepository.save(supplier);
        auditService.log("SUPPLIER", supplier.getId(), "UPDATE", null, null);
        return toResponse(supplier);
    }

    @Transactional
    public void deleteSupplier(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Supplier supplier = supplierRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("Supplier", id));
        supplier.setDeleted(true);
        supplier.setActive(false);
        supplierRepository.save(supplier);
        auditService.log("SUPPLIER", id, "DELETE", null, null);
    }

    @Transactional(readOnly = true)
    public SupplierResponse getSupplier(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return supplierRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .map(this::toResponse)
                .orElseThrow(() -> BusinessException.notFound("Supplier", id));
    }

    @Transactional(readOnly = true)
    public Page<SupplierResponse> listSuppliers(String search, Pageable pageable) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Page<Supplier> page;
        if (search != null && !search.isBlank()) {
            page = supplierRepository.search(orgId, search.trim(), pageable);
        } else {
            page = supplierRepository.findByOrgIdAndIsDeletedFalseOrderByNameAsc(orgId, pageable);
        }
        return page.map(this::toResponse);
    }

    public Supplier requireSupplier(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return supplierRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("Supplier", id));
    }

    public SupplierResponse toResponse(Supplier s) {
        return new SupplierResponse(
                s.getId(), s.getName(), s.getGstin(), s.getPan(), s.getPhone(), s.getEmail(),
                s.getAddressLine1(), s.getAddressLine2(), s.getCity(), s.getState(), s.getStateCode(),
                s.getPostalCode(), s.getCountry(), s.getPaymentTermsDays(), s.getNotes(),
                s.isActive(), s.getCreatedAt());
    }

    private static String blankToNull(String s) {
        return s == null || s.isBlank() ? null : s.trim();
    }
}
