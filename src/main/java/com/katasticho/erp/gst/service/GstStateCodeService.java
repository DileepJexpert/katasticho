package com.katasticho.erp.gst.service;

import com.katasticho.erp.gst.entity.GstStateCode;
import com.katasticho.erp.gst.repository.GstStateCodeRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;

/**
 * Read-only access to the platform GST state-code master. Powers state
 * dropdowns and GSTIN-prefix resolution (place of supply) across the app.
 */
@Service
@RequiredArgsConstructor
public class GstStateCodeService {

    private final GstStateCodeRepository repository;

    @Transactional(readOnly = true)
    public List<GstStateCode> listAll() {
        return repository.findByActiveTrueOrderByCodeAsc();
    }

    @Transactional(readOnly = true)
    public Optional<GstStateCode> findByCode(String code) {
        if (code == null || code.isBlank()) return Optional.empty();
        return repository.findByCodeAndActiveTrue(code.trim());
    }

    /**
     * Resolve the state from a GSTIN by its leading two digits.
     * Returns empty for anything that isn't a well-formed 15-char GSTIN whose
     * first two characters are digits matching a known state code.
     */
    @Transactional(readOnly = true)
    public Optional<GstStateCode> resolveFromGstin(String gstin) {
        if (gstin == null) return Optional.empty();
        String trimmed = gstin.trim();
        if (trimmed.length() < 2) return Optional.empty();
        String prefix = trimmed.substring(0, 2);
        if (!prefix.chars().allMatch(Character::isDigit)) return Optional.empty();
        return findByCode(prefix);
    }
}
