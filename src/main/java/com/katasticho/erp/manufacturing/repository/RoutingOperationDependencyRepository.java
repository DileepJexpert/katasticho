package com.katasticho.erp.manufacturing.repository;

import com.katasticho.erp.manufacturing.entity.RoutingOperationDependency;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface RoutingOperationDependencyRepository
        extends JpaRepository<RoutingOperationDependency, UUID> {

    Optional<RoutingOperationDependency> findByIdAndOrgIdAndIsDeletedFalse(UUID id, UUID orgId);

    /** Predecessors of a given routing op — "what must finish first". */
    List<RoutingOperationDependency> findByOrgIdAndRoutingOperationIdAndIsDeletedFalse(
            UUID orgId, UUID routingOperationId);

    /** Successors of a given routing op — "what depends on me finishing". */
    List<RoutingOperationDependency>
            findByOrgIdAndPredecessorRoutingOperationIdAndIsDeletedFalse(
                    UUID orgId, UUID predecessorRoutingOperationId);

    /** Dedupe guard on insert. */
    boolean existsByOrgIdAndRoutingOperationIdAndPredecessorRoutingOperationIdAndIsDeletedFalse(
            UUID orgId, UUID routingOperationId, UUID predecessorRoutingOperationId);
}
