package com.katasticho.erp.kenya.service;

import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.kenya.dto.MpesaStkPushRequest;
import com.katasticho.erp.kenya.dto.MpesaTransactionResponse;
import com.katasticho.erp.kenya.entity.MpesaTransaction;
import com.katasticho.erp.kenya.repository.MpesaTransactionRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class MpesaService {

    private final MpesaTransactionRepository repository;
    private final InvoiceRepository invoiceRepository;

    @Transactional(readOnly = true)
    public List<MpesaTransactionResponse> listTransactions(String status) {
        UUID orgId = TenantContext.getCurrentOrgId();
        List<MpesaTransaction> list;
        if (status != null && !status.isBlank() && !"ALL".equalsIgnoreCase(status)) {
            list = repository.findByOrgIdAndStatusAndIsDeletedFalseOrderByTransactionTimeDesc(orgId, status.toUpperCase());
        } else {
            list = repository.findByOrgIdAndIsDeletedFalseOrderByTransactionTimeDesc(orgId);
        }
        return list.stream().map(MpesaTransactionResponse::from).toList();
    }

    @Transactional
    public MpesaTransactionResponse initiateStkPush(MpesaStkPushRequest request) {
        throw integrationUnavailable("STK Push");
    }

    @Transactional
    public MpesaTransactionResponse reconcileWithInvoice(UUID transactionId, UUID invoiceId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        repository.findByOrgIdAndIdAndIsDeletedFalse(orgId, transactionId)
                .orElseThrow(() -> BusinessException.notFound("MpesaTransaction", transactionId));
        invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(invoiceId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Invoice", invoiceId));
        throw integrationUnavailable("M-Pesa reconciliation");
    }

    private BusinessException integrationUnavailable(String operation) {
        return new BusinessException(
                operation + " is unavailable until the Daraja callback and payment-posting integration is configured",
                "MPESA_INTEGRATION_UNAVAILABLE",
                org.springframework.http.HttpStatus.SERVICE_UNAVAILABLE);
    }
}
