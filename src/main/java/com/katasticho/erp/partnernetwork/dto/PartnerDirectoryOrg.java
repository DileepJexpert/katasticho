package com.katasticho.erp.partnernetwork.dto;

import java.util.UUID;

public record PartnerDirectoryOrg(
    UUID id,
    String name,
    String industry,
    String stateCode,
    String countryCode,
    String gstin
) {}
