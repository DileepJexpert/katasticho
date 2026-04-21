package com.katasticho.erp.auth.dto;

import jakarta.validation.constraints.NotNull;
import java.util.UUID;

public record SwitchOrgRequest(@NotNull UUID targetOrgId) {}
