package com.katasticho.erp.manufacturing.repository;

import com.katasticho.erp.manufacturing.entity.RoutingOperation;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface RoutingOperationRepository extends JpaRepository<RoutingOperation, UUID> {

    List<RoutingOperation> findByRoutingIdAndIsDeletedFalseOrderBySequenceNumberAsc(UUID routingId);
}
