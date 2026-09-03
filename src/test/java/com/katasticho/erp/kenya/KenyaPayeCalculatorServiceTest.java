package com.katasticho.erp.kenya;

import com.katasticho.erp.kenya.dto.KenyaPayeCalculationRequest;
import com.katasticho.erp.kenya.dto.KenyaPayeCalculationResponse;
import com.katasticho.erp.kenya.service.KenyaPayeCalculatorService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;

import static org.assertj.core.api.Assertions.assertThat;

class KenyaPayeCalculatorServiceTest {

    private KenyaPayeCalculatorService service;

    @BeforeEach
    void setUp() {
        service = new KenyaPayeCalculatorService();
    }

    @Test
    void shouldCalculateLowIncomeWithFullPersonalRelief() {
        // Gross KSh 20,000 -> Taxable Pay = 20,000 - 480 (NSSF T1) = 19,520
        // Gross PAYE @ 10% = 1,952.00
        // Personal Relief = 2,400.00 -> Net PAYE = 0.00
        // SHIF @ 2.75% = 550.00
        // Housing Levy @ 1.5% = 300.00
        KenyaPayeCalculationRequest req = KenyaPayeCalculationRequest.builder()
                .grossSalary(new BigDecimal("20000.00"))
                .build();

        KenyaPayeCalculationResponse res = service.calculate(req);

        assertThat(res.grossSalary()).isEqualByComparingTo("20000.00");
        assertThat(res.nssfTier1()).isEqualByComparingTo("480.00");
        assertThat(res.nssfTier2()).isEqualByComparingTo("720.00");
        assertThat(res.totalNssf()).isEqualByComparingTo("1200.00");
        assertThat(res.netPaye()).isEqualByComparingTo("0.00");
        assertThat(res.shifAmount()).isEqualByComparingTo("550.00");
        assertThat(res.housingLevyAmount()).isEqualByComparingTo("300.00");
        assertThat(res.netPay()).isEqualByComparingTo("17950.00");
    }

    @Test
    void shouldCalculateMiddleIncomeCorrectly() {
        // Gross KSh 100,000
        // NSSF Tier 1 = 480, Tier 2 = 1,680 -> Total NSSF = 2,160
        // Taxable = 97,840.00
        // Band 1: 24,000 * 10% = 2,400
        // Band 2: 8,333.33 * 25% = 2,083.33
        // Band 3: (97,840 - 32,333.33) * 30% = 65,506.67 * 30% = 19,652.00
        // Gross PAYE = 2,400 + 2,083.33 + 19,652.00 = 24,135.33
        // Net PAYE = 24,135.33 - 2,400 = 21,735.33
        // SHIF = 100,000 * 2.75% = 2,750.00
        // Housing Levy = 100,000 * 1.5% = 1,500.00
        KenyaPayeCalculationRequest req = KenyaPayeCalculationRequest.builder()
                .grossSalary(new BigDecimal("100000.00"))
                .build();

        KenyaPayeCalculationResponse res = service.calculate(req);

        assertThat(res.totalNssf()).isEqualByComparingTo("2160.00");
        assertThat(res.taxablePay()).isEqualByComparingTo("97840.00");
        assertThat(res.netPaye()).isGreaterThan(new BigDecimal("20000.00"));
        assertThat(res.shifAmount()).isEqualByComparingTo("2750.00");
        assertThat(res.housingLevyAmount()).isEqualByComparingTo("1500.00");
        assertThat(res.netPay()).isGreaterThan(BigDecimal.ZERO);
    }
}