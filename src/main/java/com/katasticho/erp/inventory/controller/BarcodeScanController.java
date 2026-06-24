package com.katasticho.erp.inventory.controller;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.inventory.barcode.BarcodeScanResponse;
import com.katasticho.erp.inventory.barcode.GsOneCode;
import com.katasticho.erp.inventory.barcode.GsOneDataMatrixParser;
import com.katasticho.erp.inventory.entity.DrugMaster;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.repository.DrugMasterRepository;
import com.katasticho.erp.inventory.repository.ItemRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.Optional;
import java.util.UUID;

/**
 * GS1 DataMatrix scanner endpoint — top-300 pharma packs (CDSCO G.S.R. 823(E)).
 *
 * <p>Receives the raw scanner output, runs the parser, and (if it carries a
 * GTIN we know) returns the linked drug master row and the matching org
 * item — so the cashier / receiver can route to either POS sell-add or a
 * GRN line in one tap.
 */
@RestController
@RequestMapping("/api/v1/inventory/barcode")
@RequiredArgsConstructor
public class BarcodeScanController {

    private final DrugMasterRepository drugMasterRepository;
    private final ItemRepository itemRepository;

    @GetMapping("/scan")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN','OPERATOR')")
    public ResponseEntity<ApiResponse<BarcodeScanResponse>> scan(@RequestParam String code) {
        // G.S.R. 823(E) mandates GS1 DataMatrix for the top-300 brands, but
        // every other pack on the shelf still carries an EAN-13 / proprietary
        // QR / hand-typed code. A failed GS1 parse is not a server error —
        // the client falls back to manual batch entry. We return 200 with
        // parsed=null + parseError so the frontend can switch UX paths.
        GsOneCode parsed;
        try {
            parsed = GsOneDataMatrixParser.parse(code);
        } catch (BusinessException e) {
            return ResponseEntity.ok(ApiResponse.ok(
                    BarcodeScanResponse.unrecognised(code, e.getMessage())));
        }

        BarcodeScanResponse.DrugMasterRef dmRef = null;
        BarcodeScanResponse.ItemRef itemRef = null;

        Optional<DrugMaster> drug = drugMasterRepository.findByGtinIgnoreCase(parsed.gtin());
        if (drug.isPresent()) {
            DrugMaster d = drug.get();
            dmRef = new BarcodeScanResponse.DrugMasterRef(
                    d.getId(), d.getBrandName(), d.getGenericName(),
                    d.getHsnCode(), d.getGstRate(), d.getManufacturer(),
                    d.getDrugSchedule());

            UUID orgId = TenantContext.getCurrentOrgId();
            if (orgId != null) {
                Optional<Item> item = itemRepository
                        .findFirstByOrgIdAndNameIgnoreCaseAndIsDeletedFalse(
                                orgId, d.getBrandName().trim());
                if (item.isPresent()) {
                    Item i = item.get();
                    itemRef = new BarcodeScanResponse.ItemRef(
                            i.getId(), i.getName(), i.getSku(), i.isTrackBatches());
                }
            }
        }
        return ResponseEntity.ok(ApiResponse.ok(
                BarcodeScanResponse.gs1(parsed, dmRef, itemRef)));
    }
}
