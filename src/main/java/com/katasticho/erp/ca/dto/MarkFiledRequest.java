package com.katasticho.erp.ca.dto;

import java.time.Instant;

public record MarkFiledRequest(
        String filingReference,
        Instant filedAt
) {
}
