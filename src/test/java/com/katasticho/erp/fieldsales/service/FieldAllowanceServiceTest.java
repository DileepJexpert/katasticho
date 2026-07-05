package com.katasticho.erp.fieldsales.service;

import com.katasticho.erp.accounting.entity.Account;
import com.katasticho.erp.accounting.repository.AccountRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.expense.dto.CreateExpenseRequest;
import com.katasticho.erp.expense.dto.ExpenseResponse;
import com.katasticho.erp.expense.service.ExpenseService;
import com.katasticho.erp.fieldsales.entity.FieldAllowanceClaim;
import com.katasticho.erp.fieldsales.entity.FieldLocationPing;
import com.katasticho.erp.fieldsales.repository.FieldAllowanceClaimRepository;
import com.katasticho.erp.fieldsales.repository.FieldLocationPingRepository;
import com.katasticho.erp.organisation.OrgSettingsService;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class FieldAllowanceServiceTest {

    @Mock private FieldLocationPingRepository pingRepo;
    @Mock private FieldAllowanceClaimRepository claimRepo;
    @Mock private OrgSettingsService settings;
    @Mock private ExpenseService expenseService;
    @Mock private AccountRepository accountRepo;

    private FieldAllowanceService service;

    private final UUID orgId = UUID.randomUUID();
    private final UUID userId = UUID.randomUUID();
    private final LocalDate date = LocalDate.of(2026, 6, 12);

    @BeforeEach
    void setUp() {
        service = new FieldAllowanceService(pingRepo, claimRepo, settings, expenseService, accountRepo);
        TenantContext.setCurrentOrgId(orgId);
        TenantContext.setCurrentUserId(userId);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    // ~11.1 km of travel: 0.1 degrees of latitude
    private void stubTrail() {
        when(pingRepo.findByOrgIdAndSalespersonIdAndRecordedAtBetweenOrderByRecordedAtAsc(
                eq(orgId), eq(userId), any(), any()))
                .thenReturn(List.of(
                        ping("28.6000", "77.2000"),
                        ping("28.7000", "77.2000")));
    }

    private void stubRates(String taPerKm, String daPerDay) {
        when(settings.get(orgId, FieldAllowanceService.SETTING_TA_PER_KM, "0")).thenReturn(taPerKm);
        when(settings.get(orgId, FieldAllowanceService.SETTING_DA_PER_DAY, "0")).thenReturn(daPerDay);
    }

    private void stubMode(String mode) {
        when(settings.get(orgId, FieldAllowanceService.SETTING_MODE, "FLEXIBLE")).thenReturn(mode);
    }

    @Test
    void computeAllowance_distanceTimesRatePlusDa() {
        stubTrail();
        stubRates("5", "150");
        stubMode("FLEXIBLE");
        when(claimRepo.findByOrgIdAndSalespersonIdAndClaimDate(orgId, userId, date))
                .thenReturn(Optional.empty());

        Map<String, Object> result = service.computeAllowance(date);

        double km = ((BigDecimal) result.get("distanceKm")).doubleValue();
        assertTrue(km > 11.0 && km < 11.3, "expected ~11.1km, got " + km);
        double ta = ((BigDecimal) result.get("taAmount")).doubleValue();
        assertTrue(ta > 55 && ta < 57, "expected ~55.6, got " + ta);
        assertEquals(0, new BigDecimal("150").compareTo((BigDecimal) result.get("daAmount")));
        assertEquals(Boolean.TRUE, result.get("configured"));
        assertEquals(Boolean.FALSE, result.get("claimed"));
    }

    @Test
    void computeAllowance_noTravel_noDa() {
        when(pingRepo.findByOrgIdAndSalespersonIdAndRecordedAtBetweenOrderByRecordedAtAsc(
                eq(orgId), eq(userId), any(), any())).thenReturn(List.of());
        stubRates("5", "150");
        stubMode("FLEXIBLE");
        when(claimRepo.findByOrgIdAndSalespersonIdAndClaimDate(orgId, userId, date))
                .thenReturn(Optional.empty());

        Map<String, Object> result = service.computeAllowance(date);

        assertEquals(0, ((BigDecimal) result.get("totalAmount")).signum());
        assertEquals(0, ((BigDecimal) result.get("daAmount")).signum());
    }

    @Test
    void claim_createsExpenseAndClaimRow() {
        stubTrail();
        stubRates("5", "150");
        stubMode("FLEXIBLE");
        when(claimRepo.findByOrgIdAndSalespersonIdAndClaimDate(orgId, userId, date))
                .thenReturn(Optional.empty());
        Account travel = mock(Account.class);
        when(travel.getId()).thenReturn(UUID.randomUUID());
        Account cash = mock(Account.class);
        when(cash.getId()).thenReturn(UUID.randomUUID());
        when(accountRepo.findByOrgIdAndCodeAndIsDeletedFalse(orgId, "5240"))
                .thenReturn(Optional.of(travel));
        when(accountRepo.findByOrgIdAndCodeAndIsDeletedFalse(orgId, "1010"))
                .thenReturn(Optional.of(cash));
        UUID expenseId = UUID.randomUUID();
        ExpenseResponse expense = mock(ExpenseResponse.class);
        when(expense.id()).thenReturn(expenseId);
        when(expenseService.createExpense(any())).thenReturn(expense);
        when(claimRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        FieldAllowanceClaim claim = service.claim(date, null);

        ArgumentCaptor<CreateExpenseRequest> captor =
                ArgumentCaptor.forClass(CreateExpenseRequest.class);
        verify(expenseService).createExpense(captor.capture());
        assertEquals(date, captor.getValue().expenseDate());
        assertEquals("CASH", captor.getValue().paymentMode());
        assertEquals(expenseId, claim.getExpenseId());
        assertEquals(0, claim.getTotalAmount()
                .compareTo(claim.getTaAmount().add(claim.getDaAmount())));
        assertEquals(0, claim.getDistanceKm().compareTo(claim.getGpsDistanceKm()));
    }

    @Test
    void claim_alreadyClaimed_throws() {
        when(claimRepo.findByOrgIdAndSalespersonIdAndClaimDate(orgId, userId, date))
                .thenReturn(Optional.of(FieldAllowanceClaim.builder().build()));

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.claim(date, null));
        assertEquals("FS_ALLOWANCE_ALREADY_CLAIMED", ex.getErrorCode());
    }

    @Test
    void claim_notConfigured_throws() {
        stubTrail();
        stubRates("0", "0");
        stubMode("FLEXIBLE");
        when(claimRepo.findByOrgIdAndSalespersonIdAndClaimDate(orgId, userId, date))
                .thenReturn(Optional.empty());

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.claim(date, null));
        assertEquals("FS_ALLOWANCE_NOTHING_TO_CLAIM", ex.getErrorCode());
        verifyNoInteractions(expenseService);
    }

    @Test
    void claim_flexibleMode_usesAdjustedKmAndKeepsGpsReference() {
        stubTrail();
        stubRates("5", "150");
        stubMode("FLEXIBLE");
        when(claimRepo.findByOrgIdAndSalespersonIdAndClaimDate(orgId, userId, date))
                .thenReturn(Optional.empty());
        stubAccountsAndExpense();
        when(claimRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        // GPS says ~11.1 km but the salesperson deducts a personal detour
        FieldAllowanceClaim claim = service.claim(date, new BigDecimal("8"));

        assertEquals(0, new BigDecimal("8.00").compareTo(claim.getDistanceKm()));
        assertTrue(claim.getGpsDistanceKm().doubleValue() > 11.0);
        assertEquals(0, new BigDecimal("40.00").compareTo(claim.getTaAmount()));

        ArgumentCaptor<CreateExpenseRequest> captor =
                ArgumentCaptor.forClass(CreateExpenseRequest.class);
        verify(expenseService).createExpense(captor.capture());
        assertTrue(captor.getValue().description().contains("claimed (GPS"),
                "expense description should expose the GPS reference");
    }

    @Test
    void claim_flexibleMode_capsRequestedKmAtGpsTrail() {
        // FLEXIBLE mode allows adjusting DOWN, never inflating above the GPS trail.
        stubTrail();
        stubRates("5", "0");
        stubMode("FLEXIBLE");
        when(claimRepo.findByOrgIdAndSalespersonIdAndClaimDate(orgId, userId, date))
                .thenReturn(Optional.empty());
        stubAccountsAndExpense();
        when(claimRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        FieldAllowanceClaim claim = service.claim(date, new BigDecimal("100000"));

        // Claimed km is capped at the GPS distance (~11.1), not the inflated 100000.
        assertEquals(0, claim.getDistanceKm().compareTo(claim.getGpsDistanceKm()));
        assertTrue(claim.getDistanceKm().doubleValue() < 12);
    }

    @Test
    void claim_gpsMode_ignoresRequestedKm() {
        stubTrail();
        stubRates("5", "0");
        stubMode("GPS");
        when(claimRepo.findByOrgIdAndSalespersonIdAndClaimDate(orgId, userId, date))
                .thenReturn(Optional.empty());
        stubAccountsAndExpense();
        when(claimRepo.save(any())).thenAnswer(inv -> inv.getArgument(0));

        FieldAllowanceClaim claim = service.claim(date, new BigDecimal("500"));

        assertEquals(0, claim.getDistanceKm().compareTo(claim.getGpsDistanceKm()));
        assertTrue(claim.getDistanceKm().doubleValue() < 12);
    }

    @Test
    void claim_manualMode_requiresKm() {
        when(pingRepo.findByOrgIdAndSalespersonIdAndRecordedAtBetweenOrderByRecordedAtAsc(
                eq(orgId), eq(userId), any(), any())).thenReturn(List.of());
        stubMode("MANUAL");
        when(claimRepo.findByOrgIdAndSalespersonIdAndClaimDate(orgId, userId, date))
                .thenReturn(Optional.empty());

        BusinessException ex = assertThrows(BusinessException.class,
                () -> service.claim(date, null));
        assertEquals("FS_ALLOWANCE_KM_REQUIRED", ex.getErrorCode());
        verifyNoInteractions(expenseService);
    }

    private void stubAccountsAndExpense() {
        Account travel = mock(Account.class);
        when(travel.getId()).thenReturn(UUID.randomUUID());
        Account cash = mock(Account.class);
        when(cash.getId()).thenReturn(UUID.randomUUID());
        when(accountRepo.findByOrgIdAndCodeAndIsDeletedFalse(orgId, "5240"))
                .thenReturn(Optional.of(travel));
        when(accountRepo.findByOrgIdAndCodeAndIsDeletedFalse(orgId, "1010"))
                .thenReturn(Optional.of(cash));
        ExpenseResponse expense = mock(ExpenseResponse.class);
        when(expense.id()).thenReturn(UUID.randomUUID());
        when(expenseService.createExpense(any())).thenReturn(expense);
    }

    private FieldLocationPing ping(String lat, String lng) {
        return FieldLocationPing.builder()
                .orgId(orgId).salespersonId(userId)
                .latitude(new BigDecimal(lat)).longitude(new BigDecimal(lng))
                .recordedAt(Instant.now())
                .build();
    }
}
