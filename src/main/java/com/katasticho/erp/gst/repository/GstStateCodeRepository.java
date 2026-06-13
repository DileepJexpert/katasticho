package com.katasticho.erp.gst.repository;

import com.katasticho.erp.gst.entity.GstStateCode;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface GstStateCodeRepository extends JpaRepository<GstStateCode, UUID> {

    List<GstStateCode> findByActiveTrueOrderByCodeAsc();

    Optional<GstStateCode> findByCodeAndActiveTrue(String code);
}
