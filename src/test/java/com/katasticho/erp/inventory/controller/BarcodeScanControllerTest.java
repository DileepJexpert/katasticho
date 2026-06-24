package com.katasticho.erp.inventory.controller;

import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.inventory.barcode.BarcodeScanResponse;
import com.katasticho.erp.inventory.repository.DrugMasterRepository;
import com.katasticho.erp.inventory.repository.ItemRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.ResponseEntity;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.verifyNoInteractions;

@ExtendWith(MockitoExtension.class)
class BarcodeScanControllerTest {

    @Mock private DrugMasterRepository drugMasterRepository;
    @Mock private ItemRepository itemRepository;
    @InjectMocks private BarcodeScanController controller;

    /** Proprietary QR / EAN-13 / hand-typed code: parser throws; the endpoint
     *  must degrade to 200 with parsed=null + parseError set, so the frontend
     *  can fall back to manual batch entry. */
    @Test
    void proprietaryQr_returns_unrecognised_not_error() {
        ResponseEntity<ApiResponse<BarcodeScanResponse>> resp =
                controller.scan("8901234567890");   // EAN-13, no GS1 AIs

        assertEquals(200, resp.getStatusCode().value());
        BarcodeScanResponse body = resp.getBody().data();
        assertNull(body.parsed(),       "parsed should be null on proprietary code");
        assertNull(body.drugMaster(),   "drugMaster should be null when parser failed");
        assertNull(body.item(),         "item should be null when parser failed");
        assertEquals("8901234567890", body.rawCode());
        assertNotNull(body.parseError(), "parseError must explain why it didn't parse");

        // Never touched the master tables — saves a lookup when the code's
        // not a GS1 DataMatrix at all.
        verifyNoInteractions(drugMasterRepository);
        verifyNoInteractions(itemRepository);
    }
}
