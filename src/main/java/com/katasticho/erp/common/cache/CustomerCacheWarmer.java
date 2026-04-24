package com.katasticho.erp.common.cache;

import com.katasticho.erp.ar.entity.Invoice;
import com.katasticho.erp.ar.repository.InvoiceRepository;
import com.katasticho.erp.common.cache.dto.CachedCustomerOutstanding;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.entity.ContactType;
import com.katasticho.erp.contact.repository.ContactRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.time.Duration;
import java.util.*;

@Component
@RequiredArgsConstructor
@Slf4j
public class CustomerCacheWarmer {

    private final ContactRepository contactRepository;
    private final InvoiceRepository invoiceRepository;
    private final CacheService cacheService;

    private static final Duration CUSTOMER_TTL = Duration.ofHours(12);
    private static final int PAGE_SIZE = 500;

    public int warmCustomerOutstanding(UUID orgId) {
        log.info("[CacheWarmer] Warming customer outstanding for org={}", orgId);

        List<Invoice> outstanding = invoiceRepository.findOutstandingInvoices(orgId);

        Map<UUID, BigDecimal> outstandingByContact = new HashMap<>();
        Map<UUID, Integer> countByContact = new HashMap<>();
        for (Invoice inv : outstanding) {
            if (inv.getContactId() != null) {
                outstandingByContact.merge(inv.getContactId(), inv.getBalanceDue(), BigDecimal::add);
                countByContact.merge(inv.getContactId(), 1, Integer::sum);
            }
        }

        int count = 0;
        int page = 0;
        Page<Contact> contactPage;

        do {
            contactPage = contactRepository.findCustomers(orgId, PageRequest.of(page, PAGE_SIZE));
            for (Contact contact : contactPage.getContent()) {
                BigDecimal ar = outstandingByContact.getOrDefault(contact.getId(), contact.getOutstandingAr());
                int openCount = countByContact.getOrDefault(contact.getId(), 0);

                CachedCustomerOutstanding cached = new CachedCustomerOutstanding(
                        contact.getId(), contact.getDisplayName(),
                        ar, contact.getCreditLimit(), openCount);
                cacheService.put(CacheKeys.customerOutstanding(orgId, contact.getId()), cached, CUSTOMER_TTL);
                count++;
            }
            page++;
        } while (contactPage.hasNext());

        log.info("[CacheWarmer] Warmed {} customer outstanding entries for org={}", count, orgId);
        return count;
    }
}
