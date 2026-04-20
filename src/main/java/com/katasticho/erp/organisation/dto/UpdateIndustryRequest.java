package com.katasticho.erp.organisation.dto;

import java.util.List;

public record UpdateIndustryRequest(
        String businessType,
        String industryCode,
        List<String> subCategories,
        String gstin,
        String state,
        String stateCode,
        String phone
) {}
