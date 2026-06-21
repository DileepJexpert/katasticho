package com.katasticho.erp.gst.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.inventory.entity.HsnGstMaster;
import com.katasticho.erp.inventory.entity.Item;
import com.katasticho.erp.inventory.repository.HsnGstMasterRepository;
import com.katasticho.erp.inventory.repository.ItemRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class Gst20RateRemapperTest {

    @Mock private ItemRepository itemRepository;
    @Mock private HsnGstMasterRepository hsnRepository;

    private Gst20RateRemapper remapper;
    private final UUID orgId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        remapper = new Gst20RateRemapper(itemRepository, hsnRepository);
        TenantContext.setCurrentOrgId(orgId);
    }

    @AfterEach
    void clear() { TenantContext.clear(); }

    @Test
    void candidates_groups_drift_into_buckets_sorted_by_size() {
        // Three items HSN 3402 detergent currently 12%, master says 18% (3 rows in 12→18)
        // Two items HSN 3004 medicine currently 12%, master says 5% (2 rows in 12→5)
        Item det1 = item("DET-1", "Tide", "3402", "12");
        Item det2 = item("DET-2", "Ariel", "3402", "12");
        Item det3 = item("DET-3", "Surf Excel", "3402", "12");
        Item med1 = item("MED-1", "Crocin", "3004", "12");
        Item med2 = item("MED-2", "Dolo", "3004", "12");
        Item ok = item("OK", "AlreadyOk", "3401", "5");

        when(itemRepository.findByOrgIdAndIsDeletedFalseOrderByNameAsc(orgId))
                .thenReturn(List.of(det1, det2, det3, med1, med2, ok));
        when(hsnRepository.findByHsnCodeAndActiveTrue("3402"))
                .thenReturn(Optional.of(hsn("3402", "18")));
        when(hsnRepository.findByHsnCodeAndActiveTrue("3004"))
                .thenReturn(Optional.of(hsn("3004", "5")));
        when(hsnRepository.findByHsnCodeAndActiveTrue("3401"))
                .thenReturn(Optional.of(hsn("3401", "5")));

        Map<String, Object> out = remapper.candidates();
        assertEquals(5, out.get("totalDriftItems"));
        assertEquals(2, out.get("bucketCount"));

        @SuppressWarnings("unchecked")
        var buckets = (List<Gst20RateRemapper.DriftBucket>) out.get("buckets");
        // Biggest bucket first
        assertEquals(3, buckets.get(0).itemCount(),
                "12→18 (3 items) should come before 12→5 (2 items)");
        assertEquals(0, new BigDecimal("12").compareTo(buckets.get(0).fromRate()));
        assertEquals(0, new BigDecimal("18").compareTo(buckets.get(0).toRate()));
    }

    @Test
    void skips_items_without_hsn() {
        Item noHsn = item("NOHSN", "Mystery", null, "12");
        when(itemRepository.findByOrgIdAndIsDeletedFalseOrderByNameAsc(orgId))
                .thenReturn(List.of(noHsn));

        Map<String, Object> out = remapper.candidates();
        assertEquals(0, out.get("totalDriftItems"));
    }

    @Test
    void skips_items_whose_hsn_has_no_master_entry() {
        Item mystery = item("MYST", "Mystery", "9999", "12");
        when(itemRepository.findByOrgIdAndIsDeletedFalseOrderByNameAsc(orgId))
                .thenReturn(List.of(mystery));
        when(hsnRepository.findByHsnCodeAndActiveTrue("9999")).thenReturn(Optional.empty());

        Map<String, Object> out = remapper.candidates();
        assertEquals(0, out.get("totalDriftItems"));
    }

    @Test
    void candidates_caches_hsn_lookup_per_call() {
        Item a = item("A", "A", "3402", "12");
        Item b = item("B", "B", "3402", "12");
        Item c = item("C", "C", "3402", "12");
        when(itemRepository.findByOrgIdAndIsDeletedFalseOrderByNameAsc(orgId))
                .thenReturn(List.of(a, b, c));
        when(hsnRepository.findByHsnCodeAndActiveTrue("3402"))
                .thenReturn(Optional.of(hsn("3402", "18")));

        remapper.candidates();
        org.mockito.Mockito.verify(hsnRepository, org.mockito.Mockito.times(1))
                .findByHsnCodeAndActiveTrue("3402");
    }

    @Test
    void applyBulk_updates_drifting_items_and_skips_already_current() {
        Item drift = item("D", "Drifting", "3402", "12");
        Item current = item("C", "AlreadyCurrent", "3402", "18");
        when(itemRepository.findById(drift.getId())).thenReturn(Optional.of(drift));
        when(itemRepository.findById(current.getId())).thenReturn(Optional.of(current));
        when(hsnRepository.findByHsnCodeAndActiveTrue("3402"))
                .thenReturn(Optional.of(hsn("3402", "18")));
        when(itemRepository.save(any())).thenAnswer(i -> i.getArgument(0));

        Map<String, Object> out = remapper.applyBulk(
                List.of(drift.getId(), current.getId()), false);
        assertEquals(1, out.get("updated"));
        assertEquals(1, out.get("skippedAlreadyCurrent"));
        assertEquals(0, new BigDecimal("18").compareTo(drift.getGstRate()));
    }

    @Test
    void dry_run_does_not_save() {
        Item drift = item("D", "Drifting", "3402", "12");
        when(itemRepository.findById(drift.getId())).thenReturn(Optional.of(drift));
        when(hsnRepository.findByHsnCodeAndActiveTrue("3402"))
                .thenReturn(Optional.of(hsn("3402", "18")));

        Map<String, Object> out = remapper.applyBulk(List.of(drift.getId()), true);
        assertEquals(0, out.get("updated"));
        assertEquals(1, out.get("skippedAlreadyCurrent"));
        // Original rate untouched
        assertEquals(0, new BigDecimal("12").compareTo(drift.getGstRate()));
        org.mockito.Mockito.verify(itemRepository, org.mockito.Mockito.never()).save(any());
    }

    @Test
    void empty_apply_throws() {
        var ex = assertThrows(BusinessException.class,
                () -> remapper.applyBulk(List.of(), false));
        assertEquals("GST_REMAP_NO_ITEMS", ex.getErrorCode());
    }

    @Test
    void apply_skips_items_from_other_orgs() {
        Item foreign = item("F", "Foreign", "3402", "12");
        foreign.setOrgId(UUID.randomUUID()); // different org
        lenient().when(itemRepository.findById(foreign.getId())).thenReturn(Optional.of(foreign));

        Map<String, Object> out = remapper.applyBulk(List.of(foreign.getId()), false);
        assertEquals(0, out.get("updated"));
    }

    @Test
    void apply_skips_items_without_hsn_or_master() {
        Item noHsn = item("NH", "NoHsn", null, "12");
        Item noMaster = item("NM", "NoMaster", "9999", "12");
        when(itemRepository.findById(noHsn.getId())).thenReturn(Optional.of(noHsn));
        when(itemRepository.findById(noMaster.getId())).thenReturn(Optional.of(noMaster));
        when(hsnRepository.findByHsnCodeAndActiveTrue("9999")).thenReturn(Optional.empty());

        Map<String, Object> out = remapper.applyBulk(
                List.of(noHsn.getId(), noMaster.getId()), false);
        assertEquals(0, out.get("updated"));
        assertEquals(1, out.get("skippedNoHsn"));
        assertEquals(1, out.get("skippedNoMaster"));
    }

    @Test
    void applyBucket_routes_to_correct_set_of_items() {
        Item det1 = item("DET-1", "Tide", "3402", "12");
        Item det2 = item("DET-2", "Ariel", "3402", "12");
        Item med = item("MED", "Crocin", "3004", "12");
        when(itemRepository.findByOrgIdAndIsDeletedFalseOrderByNameAsc(orgId))
                .thenReturn(List.of(det1, det2, med));
        when(hsnRepository.findByHsnCodeAndActiveTrue("3402"))
                .thenReturn(Optional.of(hsn("3402", "18")));
        when(hsnRepository.findByHsnCodeAndActiveTrue("3004"))
                .thenReturn(Optional.of(hsn("3004", "5")));
        when(itemRepository.findById(det1.getId())).thenReturn(Optional.of(det1));
        when(itemRepository.findById(det2.getId())).thenReturn(Optional.of(det2));
        when(itemRepository.save(any())).thenAnswer(i -> i.getArgument(0));

        Map<String, Object> out = remapper.applyBucket("12→18");
        assertEquals(2, out.get("updated"));
        // Medicine bucket (12→5) untouched
        assertEquals(0, new BigDecimal("12").compareTo(med.getGstRate()));
    }

    @Test
    void applyBucket_unknown_throws() {
        when(itemRepository.findByOrgIdAndIsDeletedFalseOrderByNameAsc(orgId))
                .thenReturn(List.of());
        var ex = assertThrows(BusinessException.class,
                () -> remapper.applyBucket("28→18"));
        assertEquals("GST_REMAP_BUCKET_NOT_FOUND", ex.getErrorCode());
    }

    @Test
    void movement_label_signs_correctly() {
        assertEquals("+6%", Gst20RateRemapper.movementLabel(
                new BigDecimal("12"), new BigDecimal("18")));
        assertEquals("-7%", Gst20RateRemapper.movementLabel(
                new BigDecimal("12"), new BigDecimal("5")));
        assertEquals("+0%", Gst20RateRemapper.movementLabel(
                new BigDecimal("5"), new BigDecimal("5")));
    }

    // ── helpers ───────────────────────────────────────────────────

    private Item item(String sku, String name, String hsn, String rate) {
        Item i = new Item();
        i.setId(UUID.randomUUID());
        i.setOrgId(orgId);
        i.setSku(sku);
        i.setName(name);
        i.setHsnCode(hsn);
        i.setGstRate(new BigDecimal(rate));
        return i;
    }

    private HsnGstMaster hsn(String code, String rate) {
        HsnGstMaster h = new HsnGstMaster();
        h.setHsnCode(code);
        h.setGstRate(new BigDecimal(rate));
        return h;
    }
}
