package com.katasticho.erp.ai.service;

import com.katasticho.erp.ai.repository.AiModelRegistryRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class AiModelRegistryService {

    private final AiModelRegistryRepository modelRegistryRepository;

    @Transactional(readOnly = true)
    public ActiveAiModel getActiveModel(String taskType) {
        return modelRegistryRepository.findFirstByTaskTypeAndStatusOrderByCreatedAtDesc(taskType, "ACTIVE")
                .map(model -> new ActiveAiModel(
                        taskType,
                        model.getModelName(),
                        model.getModelVersion(),
                        providerFor(model.getModelType())
                ))
                .orElseGet(() -> new ActiveAiModel(taskType, "deterministic_rules", "1", "internal"));
    }

    private String providerFor(String modelType) {
        return "RULE_ENGINE".equals(modelType) ? "internal" : "external";
    }
}
