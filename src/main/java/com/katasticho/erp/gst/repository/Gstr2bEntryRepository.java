package com.katasticho.erp.gst.repository;

import com.katasticho.erp.gst.entity.Gstr2bEntry;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface Gstr2bEntryRepository extends JpaRepository<Gstr2bEntry, UUID> {

    List<Gstr2bEntry> findByOrgIdAndReturnPeriodOrderBySupplierGstinAscInvoiceNumberAsc(
            UUID orgId, String returnPeriod);

    void deleteByOrgIdAndReturnPeriod(UUID orgId, String returnPeriod);

    long countByOrgIdAndReturnPeriod(UUID orgId, String returnPeriod);
}
