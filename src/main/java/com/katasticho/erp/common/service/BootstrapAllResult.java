package com.katasticho.erp.common.service;

import java.util.List;

public record BootstrapAllResult(
        int totalOrgs,
        int succeeded,
        int repaired,
        int failed,
        List<BootstrapResult> results) {
}
