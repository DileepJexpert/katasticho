package com.katasticho.erp.contact.service;

import com.katasticho.erp.audit.AuditService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.common.service.CommentService;
import com.katasticho.erp.contact.dto.*;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.entity.ContactPerson;
import com.katasticho.erp.contact.entity.ContactType;
import com.katasticho.erp.contact.entity.GstTreatment;
import com.katasticho.erp.contact.repository.ContactPersonRepository;
import com.katasticho.erp.contact.repository.ContactRepository;
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
public class ContactService {

    private final ContactRepository contactRepository;
    private final ContactPersonRepository contactPersonRepository;
    private final AuditService auditService;
    private final CommentService commentService;

    @Transactional
    public ContactResponse create(CreateContactRequest req) {
        UUID orgId = TenantContext.getCurrentOrgId();

        if (req.gstin() != null && !req.gstin().isBlank()) {
            if (contactRepository.existsByOrgIdAndGstinAndIsDeletedFalse(orgId, req.gstin())) {
                throw new BusinessException(
                        "A contact with GSTIN " + req.gstin() + " already exists",
                        "CONTACT_DUPLICATE_GSTIN", HttpStatus.CONFLICT);
            }
        }

        Contact contact = Contact.builder()
                .contactType(req.contactType())
                .displayName(req.displayName().trim())
                .companyName(req.companyName())
                .firstName(req.firstName())
                .lastName(req.lastName())
                .salutation(req.salutation())
                .gstin(req.gstin())
                .pan(req.pan())
                .taxId(req.taxId())
                .gstTreatment(inferGstTreatment(req))
                .placeOfSupply(req.placeOfSupply())
                .email(req.email())
                .phone(req.phone())
                .mobile(req.mobile())
                .website(req.website())
                .billingAddressLine1(req.billingAddressLine1())
                .billingAddressLine2(req.billingAddressLine2())
                .billingCity(req.billingCity())
                .billingState(req.billingState())
                .billingStateCode(req.billingStateCode())
                .billingPostalCode(req.billingPostalCode())
                .billingCountry(req.billingCountry() != null ? req.billingCountry() : "IN")
                .shippingAddressLine1(req.shippingAddressLine1())
                .shippingAddressLine2(req.shippingAddressLine2())
                .shippingCity(req.shippingCity())
                .shippingState(req.shippingState())
                .shippingStateCode(req.shippingStateCode())
                .shippingPostalCode(req.shippingPostalCode())
                .shippingCountry(req.shippingCountry() != null ? req.shippingCountry() : "IN")
                .currency(req.currency() != null ? req.currency() : "INR")
                .paymentTermsDays(req.paymentTermsDays() != null ? req.paymentTermsDays() : 30)
                .creditLimit(req.creditLimit() != null ? req.creditLimit() : java.math.BigDecimal.ZERO)
                .openingBalance(req.openingBalance() != null ? req.openingBalance() : java.math.BigDecimal.ZERO)
                .defaultPriceListId(req.defaultPriceListId())
                .tdsApplicable(Boolean.TRUE.equals(req.tdsApplicable()))
                .tdsSection(req.tdsSection())
                .tdsRate(req.tdsRate())
                .bankName(req.bankName())
                .bankAccountNo(req.bankAccountNo())
                .bankIfsc(req.bankIfsc())
                .upiId(req.upiId())
                .notes(req.notes())
                .build();

        contact = contactRepository.save(contact);
        auditService.log("CONTACT", contact.getId(), "CREATE", null,
                "{\"displayName\":\"" + contact.getDisplayName() + "\",\"type\":\"" + contact.getContactType() + "\"}");
        commentService.addSystemComment("CONTACT", contact.getId(), "Contact created");
        log.info("Contact {} created: {} ({})", contact.getId(), contact.getDisplayName(), contact.getContactType());
        return toResponse(contact);
    }

    @Transactional
    public ContactResponse update(UUID id, CreateContactRequest req) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Contact contact = load(id, orgId);

        if (req.gstin() != null && !req.gstin().isBlank()) {
            if (contactRepository.existsByOrgIdAndGstinAndIdNotAndIsDeletedFalse(orgId, req.gstin(), id)) {
                throw new BusinessException(
                        "A contact with GSTIN " + req.gstin() + " already exists",
                        "CONTACT_DUPLICATE_GSTIN", HttpStatus.CONFLICT);
            }
        }

        contact.setContactType(req.contactType());
        contact.setDisplayName(req.displayName().trim());
        contact.setCompanyName(req.companyName());
        contact.setFirstName(req.firstName());
        contact.setLastName(req.lastName());
        contact.setSalutation(req.salutation());
        contact.setGstin(req.gstin());
        contact.setPan(req.pan());
        contact.setTaxId(req.taxId());
        contact.setGstTreatment(inferGstTreatment(req));
        contact.setPlaceOfSupply(req.placeOfSupply());
        contact.setEmail(req.email());
        contact.setPhone(req.phone());
        contact.setMobile(req.mobile());
        contact.setWebsite(req.website());
        contact.setBillingAddressLine1(req.billingAddressLine1());
        contact.setBillingAddressLine2(req.billingAddressLine2());
        contact.setBillingCity(req.billingCity());
        contact.setBillingState(req.billingState());
        contact.setBillingStateCode(req.billingStateCode());
        contact.setBillingPostalCode(req.billingPostalCode());
        if (req.billingCountry() != null) contact.setBillingCountry(req.billingCountry());
        contact.setShippingAddressLine1(req.shippingAddressLine1());
        contact.setShippingAddressLine2(req.shippingAddressLine2());
        contact.setShippingCity(req.shippingCity());
        contact.setShippingState(req.shippingState());
        contact.setShippingStateCode(req.shippingStateCode());
        contact.setShippingPostalCode(req.shippingPostalCode());
        if (req.shippingCountry() != null) contact.setShippingCountry(req.shippingCountry());
        if (req.currency() != null) contact.setCurrency(req.currency());
        if (req.paymentTermsDays() != null) contact.setPaymentTermsDays(req.paymentTermsDays());
        if (req.creditLimit() != null) contact.setCreditLimit(req.creditLimit());
        if (req.openingBalance() != null) contact.setOpeningBalance(req.openingBalance());
        contact.setDefaultPriceListId(req.defaultPriceListId());
        contact.setTdsApplicable(Boolean.TRUE.equals(req.tdsApplicable()));
        contact.setTdsSection(req.tdsSection());
        contact.setTdsRate(req.tdsRate());
        contact.setBankName(req.bankName());
        contact.setBankAccountNo(req.bankAccountNo());
        contact.setBankIfsc(req.bankIfsc());
        contact.setUpiId(req.upiId());
        contact.setNotes(req.notes());

        contact = contactRepository.save(contact);
        auditService.log("CONTACT", contact.getId(), "UPDATE", null, null);
        commentService.addSystemComment("CONTACT", contact.getId(), "Contact details updated");
        return toResponse(contact);
    }

    @Transactional
    public void delete(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Contact contact = load(id, orgId);
        contact.setDeleted(true);
        contact.setActive(false);
        contactRepository.save(contact);
        auditService.log("CONTACT", id, "DELETE", null, null);
        commentService.addSystemComment("CONTACT", id, "Contact deleted");
    }

    @Transactional(readOnly = true)
    public ContactResponse get(UUID id) {
        return toResponse(load(id, TenantContext.getCurrentOrgId()));
    }

    @Transactional(readOnly = true)
    public Page<ContactResponse> list(String type, String search, Pageable pageable) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Page<Contact> page;

        if (search != null && !search.isBlank()) {
            page = contactRepository.search(orgId, search.trim(), pageable);
        } else if ("CUSTOMER".equalsIgnoreCase(type)) {
            page = contactRepository.findCustomers(orgId, pageable);
        } else if ("VENDOR".equalsIgnoreCase(type)) {
            page = contactRepository.findVendors(orgId, pageable);
        } else {
            page = contactRepository.findByOrgIdAndIsDeletedFalse(orgId, pageable);
        }

        return page.map(this::toResponse);
    }

    @Transactional
    public ContactPersonResponse addPerson(UUID contactId, ContactPersonRequest req) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Contact contact = load(contactId, orgId);

        if (req.primary()) {
            // Demote existing primary
            contact.getPersons().stream()
                    .filter(p -> p.isPrimary() && !p.isDeleted())
                    .forEach(p -> p.setPrimary(false));
        }

        ContactPerson person = ContactPerson.builder()
                .contact(contact)
                .salutation(req.salutation())
                .firstName(req.firstName())
                .lastName(req.lastName())
                .designation(req.designation())
                .department(req.department())
                .email(req.email())
                .phone(req.phone())
                .mobile(req.mobile())
                .primary(req.primary())
                .build();

        contact.getPersons().add(person);
        contactRepository.save(contact);
        return toPersonResponse(person);
    }

    @Transactional
    public void deletePerson(UUID contactId, UUID personId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        load(contactId, orgId); // authorization check
        ContactPerson person = contactPersonRepository.findById(personId)
                .orElseThrow(() -> BusinessException.notFound("ContactPerson", personId));
        person.setDeleted(true);
        contactPersonRepository.save(person);
    }

    // ── helpers ──────────────────────────────────────────────

    public Contact load(UUID id, UUID orgId) {
        return contactRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("Contact", id));
    }

    private GstTreatment inferGstTreatment(CreateContactRequest req) {
        if (req.gstTreatment() != null) return req.gstTreatment();
        if (req.gstin() != null && req.gstin().length() == 15) return GstTreatment.REGISTERED;
        return GstTreatment.UNREGISTERED;
    }

    public ContactResponse toResponse(Contact c) {
        return new ContactResponse(
                c.getId(), c.getContactType(),
                c.getDisplayName(), c.getCompanyName(),
                c.getFirstName(), c.getLastName(),
                c.getGstin(), c.getPan(), c.getGstTreatment(), c.getPlaceOfSupply(),
                c.getEmail(), c.getPhone(), c.getMobile(), c.getWebsite(),
                c.getBillingAddressLine1(), c.getBillingAddressLine2(),
                c.getBillingCity(), c.getBillingState(), c.getBillingStateCode(),
                c.getBillingPostalCode(), c.getBillingCountry(),
                c.getShippingAddressLine1(), c.getShippingAddressLine2(),
                c.getShippingCity(), c.getShippingState(), c.getShippingStateCode(),
                c.getShippingPostalCode(), c.getShippingCountry(),
                c.getCurrency(), c.getPaymentTermsDays(),
                c.getCreditLimit(), c.getOpeningBalance(),
                c.getOutstandingAr(), c.getOutstandingAp(),
                c.getDefaultPriceListId(),
                c.isTdsApplicable(), c.getTdsSection(), c.getTdsRate(),
                c.getBankName(), c.getBankAccountNo(), c.getBankIfsc(), c.getUpiId(),
                c.isActive(), c.getNotes(), c.getCreatedAt(),
                c.getPersons().stream()
                        .filter(p -> !p.isDeleted())
                        .map(this::toPersonResponse)
                        .toList()
        );
    }

    private ContactPersonResponse toPersonResponse(ContactPerson p) {
        return new ContactPersonResponse(
                p.getId(), p.getSalutation(), p.getFirstName(), p.getLastName(),
                p.getDesignation(), p.getDepartment(),
                p.getEmail(), p.getPhone(), p.getMobile(), p.isPrimary()
        );
    }
}
