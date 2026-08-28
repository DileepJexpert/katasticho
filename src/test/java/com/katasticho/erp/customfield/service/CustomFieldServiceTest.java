package com.katasticho.erp.customfield.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.customfield.dto.*;
import com.katasticho.erp.customfield.entity.CustomFieldDefinition;
import com.katasticho.erp.customfield.entity.CustomFieldValue;
import com.katasticho.erp.customfield.entity.FieldType;
import com.katasticho.erp.customfield.repository.CustomFieldDefinitionRepository;
import com.katasticho.erp.customfield.repository.CustomFieldValueRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.*;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class CustomFieldServiceTest {

    @Mock private CustomFieldDefinitionRepository definitionRepository;
    @Mock private CustomFieldValueRepository valueRepository;

    private CustomFieldService service;
    private final ObjectMapper objectMapper = new ObjectMapper();
    private final UUID orgId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(UUID.randomUUID());
        service = new CustomFieldService(definitionRepository, valueRepository, objectMapper);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    void createDefinition_success() {
        CustomFieldDefinitionRequest req = new CustomFieldDefinitionRequest(
                "CONTACT",
                "drug_license_no",
                "Drug License Number",
                FieldType.TEXT,
                true,
                null,
                null,
                "^[0-9]{2}[A-Z]{2}[0-9]{4}$",
                1,
                true,
                true,
                true
        );

        when(definitionRepository.existsByOrgIdAndEntityTypeAndFieldNameAndIsDeletedFalse(orgId, "CONTACT", "drug_license_no"))
                .thenReturn(false);

        when(definitionRepository.save(any(CustomFieldDefinition.class))).thenAnswer(inv -> {
            CustomFieldDefinition def = inv.getArgument(0);
            def.setId(UUID.randomUUID());
            return def;
        });

        CustomFieldDefinitionResponse res = service.createDefinition(req);

        assertThat(res).isNotNull();
        assertThat(res.fieldName()).isEqualTo("drug_license_no");
        assertThat(res.fieldLabel()).isEqualTo("Drug License Number");
        assertThat(res.isRequired()).isTrue();
        assertThat(res.validationRegex()).isEqualTo("^[0-9]{2}[A-Z]{2}[0-9]{4}$");
    }

    @Test
    void createDefinition_duplicateName_throwsConflict() {
        CustomFieldDefinitionRequest req = new CustomFieldDefinitionRequest(
                "CONTACT", "pan_no", "PAN", FieldType.TEXT, false, null, null, null, 1, true, false, false
        );

        when(definitionRepository.existsByOrgIdAndEntityTypeAndFieldNameAndIsDeletedFalse(orgId, "CONTACT", "pan_no"))
                .thenReturn(true);

        assertThatThrownBy(() -> service.createDefinition(req))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("already exists");
    }

    @Test
    void createDefinition_dropdownWithoutOptions_throwsBadRequest() {
        CustomFieldDefinitionRequest req = new CustomFieldDefinitionRequest(
                "ITEM", "category_tier", "Category Tier", FieldType.DROPDOWN, false, null, null, null, 1, true, false, false
        );

        when(definitionRepository.existsByOrgIdAndEntityTypeAndFieldNameAndIsDeletedFalse(orgId, "ITEM", "category_tier"))
                .thenReturn(false);

        assertThatThrownBy(() -> service.createDefinition(req))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("at least one option");
    }

    @Test
    void saveValues_success_withTypedValues() {
        UUID entityId = UUID.randomUUID();
        UUID defId1 = UUID.randomUUID();
        UUID defId2 = UUID.randomUUID();

        CustomFieldDefinition defText = CustomFieldDefinition.builder()
                .entityType("CONTACT")
                .fieldName("license_no")
                .fieldLabel("License Number")
                .fieldType(FieldType.TEXT)
                .isRequired(false)
                .build();
        defText.setId(defId1);
        defText.setOrgId(orgId);

        CustomFieldDefinition defNum = CustomFieldDefinition.builder()
                .entityType("CONTACT")
                .fieldName("credit_score")
                .fieldLabel("Credit Score")
                .fieldType(FieldType.NUMBER)
                .isRequired(false)
                .build();
        defNum.setId(defId2);
        defNum.setOrgId(orgId);

        when(definitionRepository.findByOrgIdAndEntityTypeAndIsActiveTrueAndIsDeletedFalseOrderBySortOrderAsc(orgId, "CONTACT"))
                .thenReturn(List.of(defText, defNum));

        when(valueRepository.findByOrgIdAndEntityTypeAndEntityIdAndIsDeletedFalse(orgId, "CONTACT", entityId))
                .thenReturn(Collections.emptyList());

        when(valueRepository.save(any(CustomFieldValue.class))).thenAnswer(inv -> inv.getArgument(0));

        List<CustomFieldValueInput> inputs = List.of(
                new CustomFieldValueInput(defId1, "license_no", "DL-9988"),
                new CustomFieldValueInput(defId2, "credit_score", "780")
        );

        List<CustomFieldValueDTO> results = service.saveValues("CONTACT", entityId, inputs);

        assertThat(results).hasSize(2);
        verify(valueRepository, times(2)).save(any(CustomFieldValue.class));
    }

    @Test
    void saveValues_missingRequired_throwsException() {
        UUID entityId = UUID.randomUUID();
        UUID defId = UUID.randomUUID();

        CustomFieldDefinition defReq = CustomFieldDefinition.builder()
                .entityType("ITEM")
                .fieldName("storage_temp")
                .fieldLabel("Storage Temperature")
                .fieldType(FieldType.TEXT)
                .isRequired(true)
                .build();
        defReq.setId(defId);
        defReq.setOrgId(orgId);

        when(definitionRepository.findByOrgIdAndEntityTypeAndIsActiveTrueAndIsDeletedFalseOrderBySortOrderAsc(orgId, "ITEM"))
                .thenReturn(List.of(defReq));

        List<CustomFieldValueInput> inputs = List.of(
                new CustomFieldValueInput(defId, "storage_temp", "")
        );

        assertThatThrownBy(() -> service.saveValues("ITEM", entityId, inputs))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("Mandatory custom field");
    }

    @Test
    void saveValues_invalidDropdownOption_throwsException() {
        UUID entityId = UUID.randomUUID();
        UUID defId = UUID.randomUUID();

        CustomFieldDefinition defDropdown = CustomFieldDefinition.builder()
                .entityType("INVOICE")
                .fieldName("dispatch_priority")
                .fieldLabel("Dispatch Priority")
                .fieldType(FieldType.DROPDOWN)
                .optionsJson("[\"LOW\",\"MEDIUM\",\"HIGH\"]")
                .isRequired(false)
                .build();
        defDropdown.setId(defId);
        defDropdown.setOrgId(orgId);

        when(definitionRepository.findByOrgIdAndEntityTypeAndIsActiveTrueAndIsDeletedFalseOrderBySortOrderAsc(orgId, "INVOICE"))
                .thenReturn(List.of(defDropdown));

        List<CustomFieldValueInput> inputs = List.of(
                new CustomFieldValueInput(defId, "dispatch_priority", "SUPER_URGENT")
        );

        assertThatThrownBy(() -> service.saveValues("INVOICE", entityId, inputs))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("not a valid option");
    }
}
