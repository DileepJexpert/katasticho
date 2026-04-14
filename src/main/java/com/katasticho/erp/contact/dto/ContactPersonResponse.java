package com.katasticho.erp.contact.dto;

import java.util.UUID;

public record ContactPersonResponse(
        UUID id,
        String salutation,
        String firstName,
        String lastName,
        String designation,
        String department,
        String email,
        String phone,
        String mobile,
        boolean primary
) {}
