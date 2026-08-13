package com.katasticho.erp.procurement.service;

import com.katasticho.erp.audit.AuditService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.entity.ContactType;
import com.katasticho.erp.contact.repository.ContactRepository;
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
    private final ContactRepository contactRepository;
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

        if (request.contactId() != null) {
            Contact contact = requireVendorContact(request.contactId(), orgId);
            supplier.setContactId(contact.getId());
            copyPartyFields(supplier, contact);
        } else {
            Contact contact = findVendorContact(orgId, supplier.getName(), supplier.getGstin()).orElse(null);
            if (contact == null) contact = createVendorContact(supplier, orgId);
            supplier.setContactId(contact.getId());
            copyPartyFields(supplier, contact);
        }

        supplier = supplierRepository.save(supplier);
        auditService.log("SUPPLIER", supplier.getId(), "CREATE", null,
                "{\"name\":\"" + supplier.getName() + "\"}");
        log.info("Supplier {} created", supplier.getName());
        return toResponse(supplier);
    }

    /**
     * Explicitly promotes a unified vendor contact into the procurement
     * supplier projection used by purchase orders, goods receipts and bills.
     * The operation is idempotent and does not create a second party record.
     */
    @Transactional
    public SupplierResponse createFromContact(UUID contactId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Contact contact = contactRepository.findForSupplierRole(contactId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Contact", contactId));
        if (!isVendor(contact)) {
            throw new BusinessException("Contact '" + contact.getDisplayName() + "' is not a vendor",
                    "SUPPLIER_CONTACT_NOT_VENDOR", HttpStatus.BAD_REQUEST);
        }

        Supplier existing = supplierRepository
                .findFirstByOrgIdAndContactIdAndIsDeletedFalse(orgId, contactId)
                .orElse(null);
        if (existing != null) {
            boolean changed = copyPartyFields(existing, contact);
            if (changed) {
                existing = supplierRepository.save(existing);
            }
            return toResponse(existing);
        }

        if (contact.getGstin() != null && !contact.getGstin().isBlank()
                && supplierRepository.existsByOrgIdAndGstinAndIsDeletedFalse(
                        orgId, contact.getGstin().trim())) {
            throw new BusinessException(
                    "A supplier with GSTIN " + contact.getGstin() + " already exists",
                    "SUP_DUPLICATE_GSTIN", HttpStatus.CONFLICT);
        }

        Supplier supplier = Supplier.builder().name(contact.getDisplayName()).build();
        supplier.setOrgId(orgId);
        supplier.setContactId(contactId);
        copyPartyFields(supplier, contact);
        supplier = supplierRepository.save(supplier);
        auditService.log("SUPPLIER", supplier.getId(), "ENABLE_FROM_CONTACT", null,
                "{\"contactId\":\"" + contactId + "\"}");
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

        if (request.contactId() != null) {
            Contact contact = requireVendorContact(request.contactId(), orgId);
            supplier.setContactId(contact.getId());
        } else if (supplier.getContactId() == null) {
            Contact contact = findVendorContact(orgId, supplier.getName(), supplier.getGstin()).orElse(null);
            if (contact == null) contact = createVendorContact(supplier, orgId);
            supplier.setContactId(contact.getId());
        }

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
    public Page<SupplierResponse> listSuppliers(String search, Pageable pageable, boolean selectableOnly) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Page<Supplier> page;
        if (selectableOnly) {
            page = search != null && !search.isBlank()
                    ? supplierRepository.searchSelectable(orgId, search.trim(), pageable)
                    : supplierRepository.findSelectable(orgId, pageable);
        } else if (search != null && !search.isBlank()) {
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
                s.getId(), s.getContactId(), s.getName(), s.getGstin(), s.getPan(), s.getPhone(), s.getEmail(),
                s.getAddressLine1(), s.getAddressLine2(), s.getCity(), s.getState(), s.getStateCode(),
                s.getPostalCode(), s.getCountry(), s.getPaymentTermsDays(), s.getNotes(),
                s.isActive(), s.getCreatedAt());
    }

    private Contact requireVendorContact(UUID contactId, UUID orgId) {
        Contact contact = contactRepository.findByIdAndOrgIdAndIsDeletedFalse(contactId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Contact", contactId));
        if (contact.getContactType() != ContactType.VENDOR
                && contact.getContactType() != ContactType.BOTH) {
            throw new BusinessException("Contact '" + contact.getDisplayName() + "' is not a vendor",
                    "SUPPLIER_CONTACT_NOT_VENDOR", HttpStatus.BAD_REQUEST);
        }
        return contact;
    }

    private Contact createVendorContact(Supplier supplier, UUID orgId) {
        Contact contact = Contact.builder()
                .contactType(ContactType.VENDOR)
                .displayName(supplier.getName())
                .companyName(supplier.getName())
                .gstin(supplier.getGstin())
                .pan(supplier.getPan())
                .email(supplier.getEmail())
                .phone(supplier.getPhone())
                .billingAddressLine1(supplier.getAddressLine1())
                .billingAddressLine2(supplier.getAddressLine2())
                .billingCity(supplier.getCity())
                .billingState(supplier.getState())
                .billingStateCode(supplier.getStateCode())
                .billingPostalCode(supplier.getPostalCode())
                .billingCountry(supplier.getCountry())
                .currency("INR")
                .paymentTermsDays(supplier.getPaymentTermsDays())
                .notes(supplier.getNotes())
                .active(supplier.isActive())
                .build();
        contact.setOrgId(orgId);
        contact = contactRepository.save(contact);
        auditService.log("CONTACT", contact.getId(), "CREATE_FROM_SUPPLIER", null,
                "{\"displayName\":\"" + contact.getDisplayName() + "\"}");
        return contact;
    }

    private java.util.Optional<Contact> findVendorContact(UUID orgId, String name, String gstin) {
        if (gstin != null && !gstin.isBlank()) {
            java.util.Optional<Contact> byGstin = contactRepository
                    .findFirstByOrgIdAndGstinIgnoreCaseAndIsDeletedFalse(orgId, gstin);
            if (byGstin.filter(this::isVendor).isPresent()) {
                return byGstin;
            }
            if (byGstin.isPresent()) {
                Contact contact = byGstin.get();
                contact.setContactType(ContactType.BOTH);
                return java.util.Optional.of(contactRepository.save(contact));
            }
        }
        return contactRepository.findFirstByOrgIdAndDisplayNameIgnoreCaseAndIsDeletedFalse(orgId, name)
                .filter(this::isVendor);
    }

    private boolean isVendor(Contact contact) {
        return contact.getContactType() == ContactType.VENDOR
                || contact.getContactType() == ContactType.BOTH;
    }

    private boolean copyPartyFields(Supplier supplier, Contact contact) {
        boolean changed = false;
        changed |= !java.util.Objects.equals(supplier.getName(), contact.getDisplayName());
        supplier.setName(contact.getDisplayName());
        changed |= !java.util.Objects.equals(supplier.getGstin(), contact.getGstin());
        supplier.setGstin(contact.getGstin());
        changed |= !java.util.Objects.equals(supplier.getPan(), contact.getPan());
        supplier.setPan(contact.getPan());
        changed |= !java.util.Objects.equals(supplier.getPhone(), contact.getPhone());
        supplier.setPhone(contact.getPhone());
        changed |= !java.util.Objects.equals(supplier.getEmail(), contact.getEmail());
        supplier.setEmail(contact.getEmail());
        changed |= !java.util.Objects.equals(supplier.getAddressLine1(), contact.getBillingAddressLine1());
        supplier.setAddressLine1(contact.getBillingAddressLine1());
        changed |= !java.util.Objects.equals(supplier.getAddressLine2(), contact.getBillingAddressLine2());
        supplier.setAddressLine2(contact.getBillingAddressLine2());
        changed |= !java.util.Objects.equals(supplier.getCity(), contact.getBillingCity());
        supplier.setCity(contact.getBillingCity());
        changed |= !java.util.Objects.equals(supplier.getState(), contact.getBillingState());
        supplier.setState(contact.getBillingState());
        changed |= !java.util.Objects.equals(supplier.getStateCode(), contact.getBillingStateCode());
        supplier.setStateCode(contact.getBillingStateCode());
        changed |= !java.util.Objects.equals(supplier.getPostalCode(), contact.getBillingPostalCode());
        supplier.setPostalCode(contact.getBillingPostalCode());
        changed |= !java.util.Objects.equals(supplier.getCountry(), contact.getBillingCountry());
        supplier.setCountry(contact.getBillingCountry());
        changed |= supplier.getPaymentTermsDays() == null
                || !java.util.Objects.equals(supplier.getPaymentTermsDays(), contact.getPaymentTermsDays());
        supplier.setPaymentTermsDays(contact.getPaymentTermsDays());
        changed |= supplier.isActive() != contact.isActive();
        supplier.setActive(contact.isActive());
        return changed;
    }

    private static String blankToNull(String s) {
        return s == null || s.isBlank() ? null : s.trim();
    }
}
