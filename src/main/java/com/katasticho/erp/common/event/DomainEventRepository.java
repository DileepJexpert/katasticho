package com.katasticho.erp.common.event;

import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface DomainEventRepository extends JpaRepository<DomainEvent, UUID> {

    List<DomainEvent> findByProcessedFalseOrderByCreatedAtAsc(Pageable pageable);
}
