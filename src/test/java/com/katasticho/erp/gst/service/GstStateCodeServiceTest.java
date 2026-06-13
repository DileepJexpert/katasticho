package com.katasticho.erp.gst.service;

import com.katasticho.erp.gst.entity.GstStateCode;
import com.katasticho.erp.gst.repository.GstStateCodeRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class GstStateCodeServiceTest {

    @Mock private GstStateCodeRepository repository;
    @InjectMocks private GstStateCodeService service;

    private GstStateCode state(String code, String name) {
        GstStateCode s = new GstStateCode();
        s.setCode(code);
        s.setStateName(name);
        return s;
    }

    @Test
    void listAll_returnsActiveOrderedByCode() {
        when(repository.findByActiveTrueOrderByCodeAsc())
                .thenReturn(List.of(state("27", "Maharashtra"), state("29", "Karnataka")));

        List<GstStateCode> result = service.listAll();

        assertEquals(2, result.size());
        assertEquals("27", result.get(0).getCode());
    }

    @Test
    void resolveFromGstin_validPrefix_resolvesState() {
        when(repository.findByCodeAndActiveTrue("27"))
                .thenReturn(Optional.of(state("27", "Maharashtra")));

        Optional<GstStateCode> result = service.resolveFromGstin("27AABCU9603R1ZM");

        assertTrue(result.isPresent());
        assertEquals("Maharashtra", result.get().getStateName());
    }

    @Test
    void resolveFromGstin_nonDigitPrefix_returnsEmpty() {
        assertTrue(service.resolveFromGstin("ABCDE1234F1Z5").isEmpty());
        verify(repository, never()).findByCodeAndActiveTrue(anyString());
    }

    @Test
    void resolveFromGstin_tooShortOrNull_returnsEmpty() {
        assertTrue(service.resolveFromGstin("2").isEmpty());
        assertTrue(service.resolveFromGstin(null).isEmpty());
        verify(repository, never()).findByCodeAndActiveTrue(anyString());
    }

    @Test
    void findByCode_blankOrNull_returnsEmptyWithoutQuery() {
        assertTrue(service.findByCode("  ").isEmpty());
        assertTrue(service.findByCode(null).isEmpty());
        verify(repository, never()).findByCodeAndActiveTrue(anyString());
    }
}
