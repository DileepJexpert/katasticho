package com.katasticho.erp.organisation.dto;

import com.katasticho.erp.organisation.Organisation;

import java.util.UUID;

public record OrgDetailsResponse(
        UUID id,
        String name,
        String gstin,
        String phone,
        String email,
        String addressLine1,
        String addressLine2,
        String city,
        String state,
        String stateCode,
        String postalCode,
        String industryCode,
        String businessType,
        String planTier
) {
    public static OrgDetailsResponse from(Organisation o) {
        return new OrgDetailsResponse(
                o.getId(),
                o.getName(),
                o.getGstin(),
                o.getPhone(),
                o.getEmail(),
                o.getAddressLine1(),
                o.getAddressLine2(),
                o.getCity(),
                o.getState(),
                o.getStateCode(),
                o.getPostalCode(),
                o.getIndustryCode(),
                o.getBusinessType(),
                o.getPlanTier()
        );
    }
}
