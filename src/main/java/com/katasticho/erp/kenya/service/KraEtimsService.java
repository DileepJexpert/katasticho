package com.katasticho.erp.kenya.service;

import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.kenya.dto.KraEtimsInvoiceResponse;
import com.katasticho.erp.kenya.dto.KraEtimsSubmitRequest;
import com.katasticho.erp.kenya.entity.KraEtimsInvoice;
import com.katasticho.erp.kenya.repository.KraEtimsInvoiceRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class KraEtimsService {

    private final KraEtimsInvoiceRepository repository;
    private final InvoiceRepository invoiceRepository;

    @Transactional(readOnly = true)
    public List<KraEtimsInvoiceResponse> listSubmissions() {
        UUID orgId = TenantContext.getCurrentOrgId();
        return repository.findByOrgIdAndIsDeletedFalseOrderBySubmittedAtDesc(orgId)
                .stream().map(KraEtimsInvoiceResponse::from).toList();
    }

    @Transactional
    public KraEtimsInvoiceResponse submitToEtims(KraEtimsSubmitRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();
        invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(request.getInvoiceId(), orgId)
                .orElseThrow(() -> BusinessException.notFound("Invoice", request.getInvoiceId()));
        throw new BusinessException(
                "KRA eTIMS submission is unavailable until a certified device or provider integration is configured",
                "ETIMS_INTEGRATION_UNAVAILABLE",
                org.springframework.http.HttpStatus.SERVICE_UNAVAILABLE);
    }
}
