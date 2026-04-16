package com.katasticho.erp.ap.repository;

import com.katasticho.erp.ap.entity.VendorPaymentAllocation;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface VendorPaymentAllocationRepository extends JpaRepository<VendorPaymentAllocation, UUID> {

    List<VendorPaymentAllocation> findByPurchaseBillId(UUID purchaseBillId);

    List<VendorPaymentAllocation> findByVendorPaymentId(UUID vendorPaymentId);

    boolean existsByPurchaseBillId(UUID purchaseBillId);
}
