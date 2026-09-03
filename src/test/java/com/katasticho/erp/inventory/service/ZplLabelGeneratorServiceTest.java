package com.katasticho.erp.inventory.service;

import com.katasticho.erp.inventory.dto.BarcodeLabelRequest;
import com.katasticho.erp.inventory.dto.BarcodeLabelResponse;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;

import static org.assertj.core.api.Assertions.assertThat;

class ZplLabelGeneratorServiceTest {

    private ZplLabelGeneratorService service;

    @BeforeEach
    void setUp() {
        service = new ZplLabelGeneratorService();
    }

    @Test
    void generateLabel_standardCode128_success() {
        BarcodeLabelRequest request = BarcodeLabelRequest.builder()
                .itemName("Amoxicillin 500mg Caps")
                .sku("MED-AMOX-500")
                .barcodeValue("8901234567890")
                .barcodeType("CODE128")
                .batchNumber("B2026-X8")
                .expiryDate("12/2028")
                .mrp(new BigDecimal("120.00"))
                .sellingPrice(new BigDecimal("95.00"))
                .fssaiLicNo("10020011000123")
                .labelWidthMm(50)
                .labelHeightMm(25)
                .dpi(203)
                .copies(2)
                .build();

        BarcodeLabelResponse response = service.generateLabel(request);

        assertThat(response).isNotNull();
        assertThat(response.copies()).isEqualTo(2);
        assertThat(response.labelWidthDots()).isEqualTo(400); // 50 * 8 = 400
        assertThat(response.labelHeightDots()).isEqualTo(200); // 25 * 8 = 200

        String zpl = response.zplCode();
        assertThat(zpl).startsWith("^XA");
        assertThat(zpl).endsWith("^XZ\n");
        assertThat(zpl).contains("^PW400");
        assertThat(zpl).contains("^LL200");
        assertThat(zpl).contains("Amoxicillin 500mg Caps");
        assertThat(zpl).contains("8901234567890");
        assertThat(zpl).contains("B.No: B2026-X8");
        assertThat(zpl).contains("Exp: 12/2028");
        assertThat(zpl).contains("MRP: Rs. 120.00");
        assertThat(zpl).contains("^PQ2");

        String epl = response.eplCode();
        assertThat(epl).startsWith("N\n");
        assertThat(epl).contains("q400");
        assertThat(epl).contains("P2\n");
    }

    @Test
    void generateLabel_qrCode_success() {
        BarcodeLabelRequest request = BarcodeLabelRequest.builder()
                .itemName("Surgical Gloves Box")
                .barcodeValue("https://erp.katasticho.com/qr/GLV-99")
                .barcodeType("QR")
                .labelWidthMm(100)
                .labelHeightMm(50)
                .dpi(203)
                .build();

        BarcodeLabelResponse response = service.generateLabel(request);

        assertThat(response).isNotNull();
        assertThat(response.labelWidthDots()).isEqualTo(800);
        assertThat(response.zplCode()).contains("^BQN,2,4^FDQA,https://erp.katasticho.com/qr/GLV-99");
    }
}