package com.katasticho.erp.customfield.service;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.customfield.dto.*;
import com.katasticho.erp.customfield.entity.CustomFieldDefinition;
import com.katasticho.erp.customfield.entity.CustomFieldValue;
import com.katasticho.erp.customfield.entity.FieldType;
import com.katasticho.erp.customfield.repository.CustomFieldDefinitionRepository;
import com.katasticho.erp.customfield.repository.CustomFieldValueRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.format.DateTimeParseException;
import java.util.*;
import java.util.regex.Pattern;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class CustomFieldService {

    private final CustomFieldDefinitionRepository definitionRepository;
    private final CustomFieldValueRepository valueRepository;
    private final ObjectMapper objectMapper;

    @Transactional
    public CustomFieldDefinitionResponse createDefinition(CustomFieldDefinitionRequest req) {
        UUID orgId = TenantContext.getCurrentOrgId();
        String entityType = req.entityType().trim().toUpperCase();
        String fieldName = req.fieldName().trim().toLowerCase();

        if (definitionRepository.existsByOrgIdAndEntityTypeAndFieldNameAndIsDeletedFalse(orgId, entityType, fieldName)) {
            throw new BusinessException(
                    "Custom field '" + fieldName + "' already exists for " + entityType,
                    "UDF_DUPLICATE_FIELD_NAME",
                    HttpStatus.CONFLICT
            );
        }

        if (req.fieldType() == FieldType.DROPDOWN && (req.options() == null || req.options().isEmpty())) {
            throw new BusinessException(
                    "Dropdown custom field must have at least one option",
                    "UDF_OPTIONS_REQUIRED",
                    HttpStatus.BAD_REQUEST
            );
        }

        String optionsJson = serializeOptions(req.options());

        int sortOrder = req.sortOrder() != null ? req.sortOrder() :
                definitionRepository.findByOrgIdAndEntityTypeAndIsDeletedFalseOrderBySortOrderAsc(orgId, entityType).size() + 1;

        CustomFieldDefinition def = CustomFieldDefinition.builder()
                .entityType(entityType)
                .fieldName(fieldName)
                .fieldLabel(req.fieldLabel().trim())
                .fieldType(req.fieldType())
                .isRequired(Boolean.TRUE.equals(req.isRequired()))
                .defaultValue(req.defaultValue())
                .optionsJson(optionsJson)
                .validationRegex(req.validationRegex())
                .sortOrder(sortOrder)
                .isActive(req.isActive() != null ? req.isActive() : true)
                .showInGrid(Boolean.TRUE.equals(req.showInGrid()))
                .showInPdf(Boolean.TRUE.equals(req.showInPdf()))
                .build();
        def.setOrgId(orgId);

        def = definitionRepository.save(def);
        return toDefinitionResponse(def);
    }

    @Transactional
    public CustomFieldDefinitionResponse updateDefinition(UUID id, CustomFieldDefinitionRequest req) {
        UUID orgId = TenantContext.getCurrentOrgId();
        CustomFieldDefinition def = definitionRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("CustomFieldDefinition", id));

        if (req.fieldLabel() != null && !req.fieldLabel().isBlank()) {
            def.setFieldLabel(req.fieldLabel().trim());
        }
        if (req.isRequired() != null) {
            def.setRequired(req.isRequired());
        }
        if (req.defaultValue() != null) {
            def.setDefaultValue(req.defaultValue());
        }
        if (req.options() != null) {
            def.setOptionsJson(serializeOptions(req.options()));
        }
        if (req.validationRegex() != null) {
            def.setValidationRegex(req.validationRegex());
        }
        if (req.sortOrder() != null) {
            def.setSortOrder(req.sortOrder());
        }
        if (req.isActive() != null) {
            def.setActive(req.isActive());
        }
        if (req.showInGrid() != null) {
            def.setShowInGrid(req.showInGrid());
        }
        if (req.showInPdf() != null) {
            def.setShowInPdf(req.showInPdf());
        }

        def = definitionRepository.save(def);
        return toDefinitionResponse(def);
    }

    @Transactional
    public void deleteDefinition(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        CustomFieldDefinition def = definitionRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("CustomFieldDefinition", id));
        def.setDeleted(true);
        definitionRepository.save(def);
    }

    @Transactional(readOnly = true)
    public List<CustomFieldDefinitionResponse> getDefinitions(String entityType, boolean activeOnly) {
        UUID orgId = TenantContext.getCurrentOrgId();
        String normalizedType = entityType.trim().toUpperCase();

        List<CustomFieldDefinition> list = activeOnly
                ? definitionRepository.findByOrgIdAndEntityTypeAndIsActiveTrueAndIsDeletedFalseOrderBySortOrderAsc(orgId, normalizedType)
                : definitionRepository.findByOrgIdAndEntityTypeAndIsDeletedFalseOrderBySortOrderAsc(orgId, normalizedType);

        return list.stream().map(this::toDefinitionResponse).toList();
    }

    @Transactional(readOnly = true)
    public List<CustomFieldDefinitionResponse> getAllDefinitions() {
        UUID orgId = TenantContext.getCurrentOrgId();
        return definitionRepository.findByOrgIdAndIsDeletedFalseOrderByEntityTypeAscSortOrderAsc(orgId)
                .stream()
                .map(this::toDefinitionResponse)
                .toList();
    }

    @Transactional(readOnly = true)
    public List<CustomFieldValueDTO> getValues(String entityType, UUID entityId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        String normalizedType = entityType.trim().toUpperCase();

        List<CustomFieldDefinition> definitions = definitionRepository
                .findByOrgIdAndEntityTypeAndIsActiveTrueAndIsDeletedFalseOrderBySortOrderAsc(orgId, normalizedType);

        List<CustomFieldValue> savedValues = valueRepository
                .findByOrgIdAndEntityTypeAndEntityIdAndIsDeletedFalse(orgId, normalizedType, entityId);

        Map<UUID, CustomFieldValue> valueMap = savedValues.stream()
                .collect(Collectors.toMap(CustomFieldValue::getFieldDefinitionId, v -> v, (a, b) -> a));

        List<CustomFieldValueDTO> result = new ArrayList<>();
        for (CustomFieldDefinition def : definitions) {
            CustomFieldValue val = valueMap.get(def.getId());
            List<String> options = deserializeOptions(def.getOptionsJson());

            String text = val != null ? val.getValueText() : def.getDefaultValue();
            BigDecimal num = val != null ? val.getValueNumber() : null;
            LocalDate date = val != null ? val.getValueDate() : null;
            Boolean bool = val != null ? val.getValueBoolean() : null;

            result.add(new CustomFieldValueDTO(
                    def.getId(),
                    def.getFieldName(),
                    def.getFieldLabel(),
                    def.getFieldType(),
                    def.isRequired(),
                    options,
                    def.isShowInGrid(),
                    def.isShowInPdf(),
                    def.getSortOrder(),
                    text,
                    num,
                    date,
                    bool
            ));
        }

        return result;
    }

    @Transactional(readOnly = true)
    public Map<UUID, List<CustomFieldValueDTO>> getValuesBatch(String entityType, Collection<UUID> entityIds) {
        if (entityIds == null || entityIds.isEmpty()) {
            return Collections.emptyMap();
        }
        UUID orgId = TenantContext.getCurrentOrgId();
        String normalizedType = entityType.trim().toUpperCase();

        List<CustomFieldDefinition> definitions = definitionRepository
                .findByOrgIdAndEntityTypeAndIsActiveTrueAndIsDeletedFalseOrderBySortOrderAsc(orgId, normalizedType);

        List<CustomFieldValue> allValues = valueRepository
                .findByOrgIdAndEntityTypeAndEntityIdInAndIsDeletedFalse(orgId, normalizedType, entityIds);

        Map<UUID, Map<UUID, CustomFieldValue>> entityValueMap = new HashMap<>();
        for (CustomFieldValue cv : allValues) {
            entityValueMap.computeIfAbsent(cv.getEntityId(), k -> new HashMap<>())
                    .put(cv.getFieldDefinitionId(), cv);
        }

        Map<UUID, List<CustomFieldValueDTO>> result = new HashMap<>();
        for (UUID entityId : entityIds) {
            Map<UUID, CustomFieldValue> valueMap = entityValueMap.getOrDefault(entityId, Collections.emptyMap());
            List<CustomFieldValueDTO> list = new ArrayList<>();
            for (CustomFieldDefinition def : definitions) {
                CustomFieldValue val = valueMap.get(def.getId());
                List<String> options = deserializeOptions(def.getOptionsJson());

                list.add(new CustomFieldValueDTO(
                        def.getId(),
                        def.getFieldName(),
                        def.getFieldLabel(),
                        def.getFieldType(),
                        def.isRequired(),
                        options,
                        def.isShowInGrid(),
                        def.isShowInPdf(),
                        def.getSortOrder(),
                        val != null ? val.getValueText() : def.getDefaultValue(),
                        val != null ? val.getValueNumber() : null,
                        val != null ? val.getValueDate() : null,
                        val != null ? val.getValueBoolean() : null
                ));
            }
            result.put(entityId, list);
        }

        return result;
    }

    @Transactional
    public List<CustomFieldValueDTO> saveValues(String entityType, UUID entityId, List<CustomFieldValueInput> inputs) {
        UUID orgId = TenantContext.getCurrentOrgId();
        String normalizedType = entityType.trim().toUpperCase();

        List<CustomFieldDefinition> definitions = definitionRepository
                .findByOrgIdAndEntityTypeAndIsActiveTrueAndIsDeletedFalseOrderBySortOrderAsc(orgId, normalizedType);

        Map<UUID, CustomFieldDefinition> defMapById = definitions.stream()
                .collect(Collectors.toMap(CustomFieldDefinition::getId, d -> d));
        Map<String, CustomFieldDefinition> defMapByName = definitions.stream()
                .collect(Collectors.toMap(CustomFieldDefinition::getFieldName, d -> d));

        // Validate required fields
        Map<UUID, String> providedValues = new HashMap<>();
        if (inputs != null) {
            for (CustomFieldValueInput in : inputs) {
                UUID defId = in.fieldDefinitionId();
                if (defId == null && in.fieldName() != null && defMapByName.containsKey(in.fieldName())) {
                    defId = defMapByName.get(in.fieldName()).getId();
                }
                if (defId != null) {
                    providedValues.put(defId, in.value());
                }
            }
        }

        for (CustomFieldDefinition def : definitions) {
            if (def.isRequired()) {
                String val = providedValues.get(def.getId());
                if (val == null || val.trim().isBlank()) {
                    throw new BusinessException(
                            "Mandatory custom field '" + def.getFieldLabel() + "' (" + def.getFieldName() + ") is required",
                            "UDF_REQUIRED_FIELD_MISSING",
                            HttpStatus.BAD_REQUEST
                    );
                }
            }
        }

        if (inputs != null) {
            for (CustomFieldValueInput in : inputs) {
                CustomFieldDefinition def = in.fieldDefinitionId() != null
                        ? defMapById.get(in.fieldDefinitionId())
                        : (in.fieldName() != null ? defMapByName.get(in.fieldName()) : null);

                if (def == null) continue;

                String rawValue = in.value() != null ? in.value().trim() : null;

                // Validate Regex
                if (rawValue != null && !rawValue.isEmpty() && def.getValidationRegex() != null && !def.getValidationRegex().isBlank()) {
                    try {
                        if (!Pattern.matches(def.getValidationRegex(), rawValue)) {
                            throw new BusinessException(
                                    "Value for '" + def.getFieldLabel() + "' does not match required format",
                                    "UDF_REGEX_VALIDATION_FAILED",
                                    HttpStatus.BAD_REQUEST
                            );
                        }
                    } catch (Exception e) {
                        if (e instanceof BusinessException be) throw be;
                        log.warn("Invalid regex pattern on field {}: {}", def.getFieldName(), def.getValidationRegex());
                    }
                }

                // Validate dropdown option
                if (rawValue != null && !rawValue.isEmpty() && def.getFieldType() == FieldType.DROPDOWN) {
                    List<String> options = deserializeOptions(def.getOptionsJson());
                    if (!options.isEmpty() && !options.contains(rawValue)) {
                        throw new BusinessException(
                                "Value '" + rawValue + "' is not a valid option for " + def.getFieldLabel(),
                                "UDF_INVALID_OPTION",
                                HttpStatus.BAD_REQUEST
                        );
                    }
                }

                BigDecimal numVal = null;
                LocalDate dateVal = null;
                Boolean boolVal = null;

                if (rawValue != null && !rawValue.isEmpty()) {
                    switch (def.getFieldType()) {
                        case NUMBER -> {
                            try {
                                numVal = new BigDecimal(rawValue);
                            } catch (NumberFormatException nfe) {
                                throw new BusinessException("Value for '" + def.getFieldLabel() + "' must be a number",
                                        "UDF_INVALID_NUMBER", HttpStatus.BAD_REQUEST);
                            }
                        }
                        case DATE -> {
                            try {
                                dateVal = LocalDate.parse(rawValue);
                            } catch (DateTimeParseException dtpe) {
                                throw new BusinessException("Value for '" + def.getFieldLabel() + "' must be a valid date (YYYY-MM-DD)",
                                        "UDF_INVALID_DATE", HttpStatus.BAD_REQUEST);
                            }
                        }
                        case BOOLEAN -> {
                            boolVal = Boolean.parseBoolean(rawValue) || "1".equals(rawValue) || "yes".equalsIgnoreCase(rawValue);
                        }
                        default -> {}
                    }
                }

                CustomFieldValue existing = valueRepository
                        .findByOrgIdAndFieldDefinitionIdAndEntityIdAndIsDeletedFalse(orgId, def.getId(), entityId)
                        .orElse(null);

                if (existing != null) {
                    existing.setValueText(rawValue);
                    existing.setValueNumber(numVal);
                    existing.setValueDate(dateVal);
                    existing.setValueBoolean(boolVal);
                    valueRepository.save(existing);
                } else {
                    CustomFieldValue cfv = CustomFieldValue.builder()
                            .fieldDefinitionId(def.getId())
                            .entityType(normalizedType)
                            .entityId(entityId)
                            .valueText(rawValue)
                            .valueNumber(numVal)
                            .valueDate(dateVal)
                            .valueBoolean(boolVal)
                            .build();
                    cfv.setOrgId(orgId);
                    valueRepository.save(cfv);
                }
            }
        }

        return getValues(normalizedType, entityId);
    }

    private String serializeOptions(List<String> options) {
        if (options == null || options.isEmpty()) return null;
        try {
            return objectMapper.writeValueAsString(options);
        } catch (Exception e) {
            log.error("Failed to serialize options: {}", e.getMessage());
            return null;
        }
    }

    private List<String> deserializeOptions(String optionsJson) {
        if (optionsJson == null || optionsJson.isBlank()) return Collections.emptyList();
        try {
            return objectMapper.readValue(optionsJson, new TypeReference<List<String>>() {});
        } catch (Exception e) {
            log.error("Failed to deserialize options: {}", e.getMessage());
            return Collections.emptyList();
        }
    }

    private CustomFieldDefinitionResponse toDefinitionResponse(CustomFieldDefinition def) {
        return new CustomFieldDefinitionResponse(
                def.getId(),
                def.getEntityType(),
                def.getFieldName(),
                def.getFieldLabel(),
                def.getFieldType(),
                def.isRequired(),
                def.getDefaultValue(),
                deserializeOptions(def.getOptionsJson()),
                def.getValidationRegex(),
                def.getSortOrder(),
                def.isActive(),
                def.isShowInGrid(),
                def.isShowInPdf(),
                def.getCreatedAt(),
                def.getUpdatedAt()
        );
    }
}
