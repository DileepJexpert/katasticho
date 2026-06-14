package com.katasticho.erp.hr.repository;

import com.katasticho.erp.hr.entity.OffboardingTask;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface OffboardingTaskRepository extends JpaRepository<OffboardingTask, UUID> {

    List<OffboardingTask> findByOrgIdAndOffboardingIdAndIsDeletedFalseOrderByCategoryAsc(
            UUID orgId, UUID offboardingId);
}
