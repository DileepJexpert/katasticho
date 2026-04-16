package com.katasticho.erp.ap.repository;

import com.katasticho.erp.ap.entity.VendorCreditApplication;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface VendorCreditApplicationRepository extends JpaRepository<VendorCreditApplication, UUID> {

    List<VendorCreditApplication> findByVendorCreditId(UUID vendorCreditId);

    List<VendorCreditApplication> findByPurchaseBillId(UUID purchaseBillId);
}
