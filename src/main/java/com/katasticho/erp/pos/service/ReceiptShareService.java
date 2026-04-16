package com.katasticho.erp.pos.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.pos.entity.SalesReceipt;
import com.katasticho.erp.pos.repository.SalesReceiptRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.Map;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class ReceiptShareService {

    @Value("${app.base-url:https://app.katasticho.com}")
    private String appBaseUrl;

    private final SalesReceiptRepository receiptRepository;

    public Map<String, String> generateShareLink(UUID receiptId) {
        UUID orgId = TenantContext.getCurrentOrgId();

        SalesReceipt receipt = receiptRepository
                .findByIdAndOrgIdAndIsDeletedFalse(receiptId, orgId)
                .orElseThrow(() -> BusinessException.notFound("SalesReceipt", receiptId));

        // Generate a simple encoded token (orgId:receiptId encoded in base64)
        String token = Base64.getUrlEncoder().withoutPadding()
                .encodeToString((orgId + ":" + receiptId).getBytes(StandardCharsets.UTF_8));

        String shareUrl = appBaseUrl + "/r/" + token;

        return Map.of(
                "shareUrl", shareUrl,
                "receiptNumber", receipt.getReceiptNumber(),
                "token", token
        );
    }
}
