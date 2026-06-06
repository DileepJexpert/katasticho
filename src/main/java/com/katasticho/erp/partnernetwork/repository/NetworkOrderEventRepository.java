package com.katasticho.erp.partnernetwork.repository;

import com.katasticho.erp.partnernetwork.entity.NetworkOrderEvent;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface NetworkOrderEventRepository extends JpaRepository<NetworkOrderEvent, UUID> {

    List<NetworkOrderEvent> findAllByNetworkOrderIdOrderByCreatedAtAsc(UUID networkOrderId);
}
