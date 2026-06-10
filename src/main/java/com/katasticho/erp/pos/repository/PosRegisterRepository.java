package com.katasticho.erp.pos.repository;

import com.katasticho.erp.pos.entity.PosRegister;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface PosRegisterRepository extends JpaRepository<PosRegister, UUID> {

    Optional<PosRegister> findByOrgIdAndRegisterDate(UUID orgId, LocalDate date);

    List<PosRegister> findByOrgIdAndRegisterDateBetweenOrderByRegisterDateDesc(
            UUID orgId, LocalDate from, LocalDate to);
}
