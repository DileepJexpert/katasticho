package com.katasticho.erp.ar.dto;

import java.util.UUID;

public record ReminderTextResponse(
        UUID contactId,
        String contactName,
        String phone,
        String message,
        String whatsappUrl
) {}
