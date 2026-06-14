package com.katasticho.erp.hr.repository;

import com.katasticho.erp.hr.entity.HrTicketComment;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface HrTicketCommentRepository extends JpaRepository<HrTicketComment, UUID> {

    List<HrTicketComment> findByOrgIdAndTicketIdAndIsDeletedFalseOrderByCreatedAtAsc(
            UUID orgId, UUID ticketId);
}
