package com.katasticho.erp.gst.einvoice;

import com.katasticho.erp.common.country.RequiresCountry;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.UUID;

/**
 * UAE / Oman PINT-AE e-invoice generation. Country-gated to the Gulf — the
 * mirror of the India {@code EInvoiceController} (IRN), which is gated to "IN".
 * Returns the UBL XML for a posted invoice; ASP submission is Phase 2.
 */
@RestController
@RequestMapping("/api/v1/gst/einvoices/pint-ae")
@RequiresCountry({"AE", "OM"})
@RequiredArgsConstructor
public class PintAeEInvoiceController {

    private final PintAeEInvoiceService service;

    @GetMapping(value = "/{invoiceId}", produces = MediaType.APPLICATION_XML_VALUE)
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','ACCOUNTANT')")
    public ResponseEntity<String> generate(@PathVariable UUID invoiceId) {
        return ResponseEntity.ok(service.generateXml(invoiceId));
    }
}
