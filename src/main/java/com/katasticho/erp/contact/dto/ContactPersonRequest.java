package com.katasticho.erp.contact.dto;

import jakarta.validation.constraints.NotBlank;

public record ContactPersonRequest(
        String salutation,
        @NotBlank String firstName,
        String lastName,
        String designation,
        String department,
        String email,
        String phone,
        String mobile,
        boolean primary
) {}
