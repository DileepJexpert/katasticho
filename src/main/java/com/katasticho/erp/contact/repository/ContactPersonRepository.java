package com.katasticho.erp.contact.repository;

import com.katasticho.erp.contact.entity.ContactPerson;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface ContactPersonRepository extends JpaRepository<ContactPerson, UUID> {

    List<ContactPerson> findByContactIdAndDeletedFalse(UUID contactId);
}
