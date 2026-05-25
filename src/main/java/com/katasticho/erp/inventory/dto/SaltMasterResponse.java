package com.katasticho.erp.inventory.dto;

import com.katasticho.erp.inventory.entity.SaltMaster;

import java.util.UUID;

public record SaltMasterResponse(
        UUID id,
        String name,
        String category
) {
    public static SaltMasterResponse from(SaltMaster s) {
        return new SaltMasterResponse(s.getId(), s.getName(), s.getCategory());
    }
}
