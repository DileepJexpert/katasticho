package com.katasticho.erp.pos.repository;

import com.katasticho.erp.pos.entity.PosRegisterExpense;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface PosRegisterExpenseRepository extends JpaRepository<PosRegisterExpense, UUID> {

    List<PosRegisterExpense> findByRegisterIdOrderByExpenseTimeAsc(UUID registerId);

    void deleteByIdAndOrgId(UUID id, UUID orgId);
}
