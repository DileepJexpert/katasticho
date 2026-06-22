package com.katasticho.erp.gst.einvoice;

import com.katasticho.erp.ar.entity.Invoice;
import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * Maps a posted invoice to {@link EInvoiceData} and renders it as PINT-AE UBL XML
 * via {@link PintAeProvider}. The Gulf counterpart to the India IRN flow.
 *
 * <p>Foundation/demo stub: it generates a compliant-shaped document on demand
 * (the design-partner proof). It does NOT yet submit to an Accredited Service
 * Provider — that's Phase 2 (reuse the GspClient transport).
 */
@Service
@RequiredArgsConstructor
public class PintAeEInvoiceService {

    private final InvoiceRepository invoiceRepository;
    private final OrganisationRepository organisationRepository;
    private final ContactRepository contactRepository;
    private final PintAeProvider pintAeProvider;

    /** Generate the PINT-AE UBL XML for one posted invoice (current org). */
    public String generateXml(UUID invoiceId) {
        return pintAeProvider.buildPayload(toData(invoiceId));
    }

    EInvoiceData toData(UUID invoiceId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Invoice inv = invoiceRepository.findByIdAndOrgIdAndIsDeletedFalse(invoiceId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Invoice", invoiceId));

        Organisation org = organisationRepository.findById(orgId)
                .orElseThrow(() -> BusinessException.notFound("Organisation", orgId));
        EInvoiceData.Party supplier = new EInvoiceData.Party(
                org.getName(), taxId(org.getTaxId(), org.getGstin()), org.getCountryCode());

        EInvoiceData.Party customer = contactRepository
                .findByIdAndOrgIdAndIsDeletedFalse(inv.getContactId(), orgId)
                .map(c -> new EInvoiceData.Party(
                        partyName(c), taxId(c.getTaxId(), c.getGstin()), null))
                .orElse(new EInvoiceData.Party("Customer", null, null));

        List<EInvoiceData.Line> lines = new ArrayList<>();
        BigDecimal vatRate = BigDecimal.ZERO;
        if (inv.getLines() != null) {
            for (var l : inv.getLines()) {
                BigDecimal rate = nz(l.getGstRate());
                if (rate.signum() > 0) vatRate = rate;
                lines.add(new EInvoiceData.Line(
                        l.getDescription(), nz(l.getQuantity()), nz(l.getUnitPrice()),
                        nz(l.getLineTotal()), rate));
            }
        }

        return new EInvoiceData(
                inv.getInvoiceNumber(),
                inv.getInvoiceDate(),
                inv.getCurrency() == null ? "AED" : inv.getCurrency(),
                supplier,
                customer,
                lines,
                nz(inv.getSubtotal()),
                nz(inv.getTaxAmount()),
                nz(inv.getTotalAmount()),
                vatRate);
    }

    private static String taxId(String primary, String fallback) {
        if (primary != null && !primary.isBlank()) return primary;
        return fallback;
    }

    private static String partyName(Contact c) {
        if (c.getCompanyName() != null && !c.getCompanyName().isBlank()) return c.getCompanyName();
        return c.getDisplayName();
    }

    private static BigDecimal nz(BigDecimal v) {
        return v == null ? BigDecimal.ZERO : v;
    }
}
