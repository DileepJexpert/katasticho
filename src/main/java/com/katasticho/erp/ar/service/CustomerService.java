package com.katasticho.erp.ar.service;

import com.katasticho.erp.ar.dto.CreateCustomerRequest;
import com.katasticho.erp.ar.dto.CustomerResponse;
import com.katasticho.erp.ar.entity.Customer;
import com.katasticho.erp.ar.repository.CustomerRepository;
import com.katasticho.erp.audit.AuditService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

@Service
@RequiredArgsConstructor
public class CustomerService {

    private final CustomerRepository customerRepository;
    private final AuditService auditService;

    @Transactional
    public CustomerResponse createCustomer(CreateCustomerRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();

        String gstin = blankToNull(request.gstin());
        String pan = blankToNull(request.pan());

        if (gstin != null) {
            if (customerRepository.existsByOrgIdAndGstinAndIsDeletedFalse(orgId, gstin)) {
                throw new BusinessException("Customer with GSTIN " + gstin + " already exists",
                        "AR_DUPLICATE_GSTIN", HttpStatus.CONFLICT);
            }
        }

        Customer customer = Customer.builder()
                .name(request.name())
                .email(request.email())
                .phone(request.phone())
                .gstin(gstin)
                .taxId(request.taxId())
                .pan(pan)
                .billingAddressLine1(request.billingAddressLine1())
                .billingAddressLine2(request.billingAddressLine2())
                .billingCity(request.billingCity())
                .billingState(request.billingState())
                .billingStateCode(request.billingStateCode())
                .billingPostalCode(request.billingPostalCode())
                .billingCountry(request.billingCountry() != null ? request.billingCountry() : "IN")
                .shippingAddressLine1(request.shippingAddressLine1())
                .shippingAddressLine2(request.shippingAddressLine2())
                .shippingCity(request.shippingCity())
                .shippingState(request.shippingState())
                .shippingStateCode(request.shippingStateCode())
                .shippingPostalCode(request.shippingPostalCode())
                .shippingCountry(request.shippingCountry() != null ? request.shippingCountry() : "IN")
                .creditLimit(request.creditLimit() != null ? request.creditLimit() : java.math.BigDecimal.ZERO)
                .paymentTermsDays(request.paymentTermsDays() != null ? request.paymentTermsDays() : 30)
                .notes(request.notes())
                .defaultPriceListId(request.defaultPriceListId())
                .build();

        customer = customerRepository.save(customer);

        auditService.log("CUSTOMER", customer.getId(), "CREATE", null,
                "{\"name\":\"" + customer.getName() + "\"}");

        return toResponse(customer);
    }

    public CustomerResponse getCustomer(UUID customerId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Customer customer = customerRepository.findByIdAndOrgIdAndIsDeletedFalse(customerId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Customer", customerId));
        return toResponse(customer);
    }

    public Page<CustomerResponse> listCustomers(Pageable pageable) {
        UUID orgId = TenantContext.getCurrentOrgId();
        return customerRepository.findByOrgIdAndIsDeletedFalse(orgId, pageable).map(this::toResponse);
    }

    @Transactional
    public CustomerResponse updateCustomer(UUID customerId, CreateCustomerRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Customer customer = customerRepository.findByIdAndOrgIdAndIsDeletedFalse(customerId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Customer", customerId));

        String gstin = blankToNull(request.gstin());
        String pan = blankToNull(request.pan());

        if (gstin != null && !gstin.equals(customer.getGstin())) {
            if (customerRepository.existsByOrgIdAndGstinAndIsDeletedFalse(orgId, gstin)) {
                throw new BusinessException("Customer with GSTIN " + gstin + " already exists",
                        "AR_DUPLICATE_GSTIN", HttpStatus.CONFLICT);
            }
        }

        customer.setName(request.name());
        customer.setEmail(request.email());
        customer.setPhone(request.phone());
        customer.setGstin(gstin);
        customer.setTaxId(request.taxId());
        customer.setPan(pan);
        customer.setBillingAddressLine1(request.billingAddressLine1());
        customer.setBillingAddressLine2(request.billingAddressLine2());
        customer.setBillingCity(request.billingCity());
        customer.setBillingState(request.billingState());
        customer.setBillingStateCode(request.billingStateCode());
        customer.setBillingPostalCode(request.billingPostalCode());
        if (request.billingCountry() != null) customer.setBillingCountry(request.billingCountry());
        customer.setShippingAddressLine1(request.shippingAddressLine1());
        customer.setShippingAddressLine2(request.shippingAddressLine2());
        customer.setShippingCity(request.shippingCity());
        customer.setShippingState(request.shippingState());
        customer.setShippingStateCode(request.shippingStateCode());
        customer.setShippingPostalCode(request.shippingPostalCode());
        if (request.shippingCountry() != null) customer.setShippingCountry(request.shippingCountry());
        if (request.creditLimit() != null) customer.setCreditLimit(request.creditLimit());
        if (request.paymentTermsDays() != null) customer.setPaymentTermsDays(request.paymentTermsDays());
        customer.setNotes(request.notes());
        // defaultPriceListId is a simple pass-through — set it unconditionally
        // so clients can unset the pin by sending null.
        customer.setDefaultPriceListId(request.defaultPriceListId());

        customer = customerRepository.save(customer);

        auditService.log("CUSTOMER", customer.getId(), "UPDATE", null, null);
        return toResponse(customer);
    }

    @Transactional
    public void deleteCustomer(UUID customerId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        Customer customer = customerRepository.findByIdAndOrgIdAndIsDeletedFalse(customerId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Customer", customerId));
        customer.setDeleted(true);
        customerRepository.save(customer);
        auditService.log("CUSTOMER", customer.getId(), "DELETE", null, null);
    }

    /**
     * Normalizes blank/empty strings to {@code null} for fields that participate in
     * partial unique indexes ({@code WHERE col IS NOT NULL}). Postgres treats the
     * empty string {@code ""} as a real value, so without this helper a second
     * customer with no GSTIN would collide with the first on
     * {@code idx_customer_org_gstin}.
     */
    private static String blankToNull(String value) {
        if (value == null) return null;
        String trimmed = value.trim();
        return trimmed.isEmpty() ? null : trimmed;
    }

    public CustomerResponse toResponse(Customer c) {
        return new CustomerResponse(
                c.getId(), c.getName(), c.getEmail(), c.getPhone(),
                c.getGstin(), c.getTaxId(), c.getPan(),
                c.getBillingAddressLine1(), c.getBillingAddressLine2(),
                c.getBillingCity(), c.getBillingState(), c.getBillingStateCode(),
                c.getBillingPostalCode(), c.getBillingCountry(),
                c.getShippingAddressLine1(), c.getShippingAddressLine2(),
                c.getShippingCity(), c.getShippingState(), c.getShippingStateCode(),
                c.getShippingPostalCode(), c.getShippingCountry(),
                c.getCreditLimit(), c.getPaymentTermsDays(),
                c.getNotes(), c.getDefaultPriceListId(), c.isActive(), c.getCreatedAt());
    }
}
