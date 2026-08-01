package com.katasticho.erp.inventory.service;

import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.common.module.ModuleAccessService;
import com.katasticho.erp.common.module.ModuleCode;
import com.katasticho.erp.inventory.dto.DrugMasterResponse;
import com.katasticho.erp.inventory.dto.SaltMasterResponse;
import com.katasticho.erp.inventory.entity.DrugMaster;
import com.katasticho.erp.inventory.entity.SaltMaster;
import com.katasticho.erp.inventory.repository.DrugMasterRepository;
import com.katasticho.erp.inventory.repository.SaltMasterRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class DrugMasterService {

    private final ModuleAccessService moduleAccessService;
    private final DrugMasterRepository drugMasterRepository;
    private final SaltMasterRepository saltMasterRepository;

    public List<DrugMasterResponse> searchDrugs(String query, int limit) {
        moduleAccessService.requireEnabled(ModuleCode.PHARMA);
        PageRequest page = PageRequest.of(0, limit);
        return drugMasterRepository.search(query == null ? "" : query.trim(), page)
                .stream()
                .map(this::toResponse)
                .toList();
    }

    public DrugMasterResponse getById(UUID id) {
        moduleAccessService.requireEnabled(ModuleCode.PHARMA);
        DrugMaster drug = drugMasterRepository.findById(id)
                .orElseThrow(() -> BusinessException.notFound("DrugMaster", id));
        return toResponse(drug);
    }

    public List<SaltMasterResponse> searchSalts(String query, int limit) {
        moduleAccessService.requireEnabled(ModuleCode.PHARMA);
        PageRequest page = PageRequest.of(0, limit);
        return saltMasterRepository
                .findByNameContainingIgnoreCaseOrderByNameAsc(query == null ? "" : query.trim(), page)
                .stream()
                .map(this::toSaltResponse)
                .toList();
    }

    private DrugMasterResponse toResponse(DrugMaster d) {
        return new DrugMasterResponse(
                d.getId(),
                d.getBrandName(),
                d.getGenericName(),
                d.getSaltComposition(),
                d.getManufacturer(),
                d.getHsnCode(),
                d.getGstRate(),
                d.getDrugSchedule(),
                d.getDosageForm(),
                d.getPackSize(),
                d.getMrp(),
                d.isPrescriptionRequired()
        );
    }

    private SaltMasterResponse toSaltResponse(SaltMaster s) {
        return new SaltMasterResponse(s.getId(), s.getName(), s.getCategory());
    }
}

