package com.katasticho.erp.inventory.service;

import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.inventory.dto.DrugMasterResponse;
import com.katasticho.erp.inventory.dto.SaltMasterResponse;
import com.katasticho.erp.inventory.repository.DrugMasterRepository;
import com.katasticho.erp.inventory.repository.SaltMasterRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

@Service
@RequiredArgsConstructor
public class DrugMasterService {

    private final DrugMasterRepository drugRepo;
    private final SaltMasterRepository saltRepo;

    @Transactional(readOnly = true)
    public Page<DrugMasterResponse> searchDrugs(String query, int page, int size) {
        String q = (query == null || query.isBlank()) ? "" : query.trim();
        return drugRepo.search(q, PageRequest.of(page, Math.min(size, 50)))
                .map(DrugMasterResponse::from);
    }

    @Transactional(readOnly = true)
    public DrugMasterResponse getDrug(UUID id) {
        return drugRepo.findById(id)
                .map(DrugMasterResponse::from)
                .orElseThrow(() -> BusinessException.notFound("DrugMaster", id));
    }

    @Transactional(readOnly = true)
    public Page<DrugMasterResponse> getDrugsBySalt(UUID saltId, int page, int size) {
        return drugRepo.findBySaltId(saltId, PageRequest.of(page, Math.min(size, 50)))
                .map(DrugMasterResponse::from);
    }

    @Transactional(readOnly = true)
    public Page<SaltMasterResponse> searchSalts(String query, int page, int size) {
        String q = (query == null || query.isBlank()) ? "" : query.trim();
        return saltRepo.search(q, PageRequest.of(page, Math.min(size, 50)))
                .map(SaltMasterResponse::from);
    }
}
