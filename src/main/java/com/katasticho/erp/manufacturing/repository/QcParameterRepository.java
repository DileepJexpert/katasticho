package com.katasticho.erp.manufacturing.repository;

import com.katasticho.erp.manufacturing.entity.QcParameter;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface QcParameterRepository extends JpaRepository<QcParameter, UUID> {

    List<QcParameter> findByTemplateIdAndIsDeletedFalseOrderBySequenceNumberAsc(UUID templateId);
}
