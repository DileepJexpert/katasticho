package com.katasticho.erp.ai.service;

public record ActiveAiModel(
        String taskType,
        String modelName,
        String modelVersion,
        String provider
) {
}
