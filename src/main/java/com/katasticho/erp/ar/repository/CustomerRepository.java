package com.katasticho.erp.ar.repository;

import com.katasticho.erp.ar.entity.Customer;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface CustomerRepository extends JpaRepository<Customer, UUID> {

    Page<Customer> findByOrgIdAndIsDeletedFalse(UUID orgId, Pageable pageable);

    List<Customer> findByOrgIdAndIsDeletedFalseOrderByName(UUID orgId);

    Optional<Customer> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    boolean existsByOrgIdAndGstinAndIsDeletedFalse(UUID orgId, String gstin);
}
