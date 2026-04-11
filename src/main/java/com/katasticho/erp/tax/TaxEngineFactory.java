package com.katasticho.erp.tax;

import com.katasticho.erp.common.exception.BusinessException;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

import java.util.List;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;

/**
 * Factory that returns the correct TaxEngine for a given tax regime.
 * In v1: always returns IndiaGSTEngine.
 * In v3: routes to KenyaVATEngine, NigeriaVATEngine, etc.
 */
@Component
public class TaxEngineFactory {

    private final Map<String, TaxEngine> enginesByRegime;

    public TaxEngineFactory(List<TaxEngine> engines) {
        this.enginesByRegime = engines.stream()
                .collect(Collectors.toMap(TaxEngine::getTaxRegimeCode, Function.identity()));
    }

    public TaxEngine getEngine(String taxRegime) {
        TaxEngine engine = enginesByRegime.get(taxRegime);
        if (engine == null) {
            throw new BusinessException(
                    "No TaxEngine found for regime: " + taxRegime,
                    "TAX_ENGINE_NOT_FOUND", HttpStatus.INTERNAL_SERVER_ERROR);
        }
        return engine;
    }
}
