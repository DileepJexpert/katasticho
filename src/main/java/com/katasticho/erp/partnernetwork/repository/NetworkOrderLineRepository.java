package com.katasticho.erp.partnernetwork.repository;

import com.katasticho.erp.partnernetwork.entity.NetworkOrderLine;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface NetworkOrderLineRepository extends JpaRepository<NetworkOrderLine, UUID> {

    List<NetworkOrderLine> findAllByNetworkOrderId(UUID networkOrderId);
}
