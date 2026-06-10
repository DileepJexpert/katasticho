package com.katasticho.erp.pos.service;

import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.pos.dto.CashRegisterSummary;
import com.katasticho.erp.pos.entity.PaymentMode;
import com.katasticho.erp.pos.entity.PosRegister;
import com.katasticho.erp.pos.entity.PosRegisterExpense;
import com.katasticho.erp.pos.repository.PosRegisterExpenseRepository;
import com.katasticho.erp.pos.repository.PosRegisterRepository;
import com.katasticho.erp.pos.repository.SalesReceiptRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class CashRegisterService {

    private final PosRegisterRepository registerRepo;
    private final PosRegisterExpenseRepository expenseRepo;
    private final SalesReceiptRepository receiptRepo;

    // ── Open ──────────────────────────────────────────────────────────────

    @Transactional
    public CashRegisterSummary openToday(UUID orgId, UUID userId,
                                         BigDecimal openingBalance, String notes) {
        LocalDate today = LocalDate.now();
        if (registerRepo.findByOrgIdAndRegisterDate(orgId, today).isPresent()) {
            throw new BusinessException("Cash register already opened for today",
                    "REGISTER_ALREADY_OPEN", HttpStatus.CONFLICT);
        }
        PosRegister register = PosRegister.builder()
                .orgId(orgId)
                .registerDate(today)
                .openingBalance(openingBalance != null ? openingBalance : BigDecimal.ZERO)
                .status("OPEN")
                .notes(notes)
                .openedBy(userId)
                .build();
        registerRepo.save(register);
        log.info("[CashRegister] Opened for org {} date {} opening={}", orgId, today, openingBalance);
        return buildSummary(register);
    }

    // ── Read ──────────────────────────────────────────────────────────────

    @Transactional(readOnly = true)
    public CashRegisterSummary getTodaySummary(UUID orgId) {
        PosRegister register = getOrAutoCreate(orgId, LocalDate.now());
        return buildSummary(register);
    }

    @Transactional(readOnly = true)
    public CashRegisterSummary getSummary(UUID orgId, LocalDate date) {
        PosRegister register = registerRepo.findByOrgIdAndRegisterDate(orgId, date)
                .orElseThrow(() -> BusinessException.notFound("CashRegister", date.toString()));
        return buildSummary(register);
    }

    @Transactional(readOnly = true)
    public List<CashRegisterSummary> getHistory(UUID orgId, LocalDate from, LocalDate to) {
        return registerRepo
                .findByOrgIdAndRegisterDateBetweenOrderByRegisterDateDesc(orgId, from, to)
                .stream()
                .map(this::buildSummary)
                .toList();
    }

    // ── Expense ───────────────────────────────────────────────────────────

    @Transactional
    public CashRegisterSummary addExpense(UUID orgId, UUID userId,
                                          BigDecimal amount, String description) {
        PosRegister register = getOrAutoCreate(orgId, LocalDate.now());
        if ("CLOSED".equals(register.getStatus())) {
            throw new BusinessException("Cannot add expense to a closed register",
                    "REGISTER_CLOSED", HttpStatus.CONFLICT);
        }
        PosRegisterExpense expense = PosRegisterExpense.builder()
                .orgId(orgId)
                .registerId(register.getId())
                .amount(amount)
                .description(description)
                .recordedBy(userId)
                .build();
        expenseRepo.save(expense);
        log.info("[CashRegister] Expense {} '{}' added for org {}", amount, description, orgId);
        return buildSummary(register);
    }

    @Transactional
    public void deleteExpense(UUID orgId, UUID expenseId) {
        PosRegisterExpense expense = expenseRepo.findById(expenseId)
                .filter(e -> orgId.equals(e.getOrgId()))
                .orElseThrow(() -> BusinessException.notFound("CashExpense", expenseId));
        PosRegister register = registerRepo.findById(expense.getRegisterId())
                .orElseThrow(() -> BusinessException.notFound("CashRegister", expense.getRegisterId()));
        if ("CLOSED".equals(register.getStatus())) {
            throw new BusinessException("Cannot delete expense from a closed register",
                    "REGISTER_CLOSED", HttpStatus.CONFLICT);
        }
        expenseRepo.delete(expense);
    }

    // ── Close ─────────────────────────────────────────────────────────────

    @Transactional
    public CashRegisterSummary closeRegister(UUID orgId, UUID userId,
                                              BigDecimal actualClosing, String notes) {
        PosRegister register = getOrAutoCreate(orgId, LocalDate.now());
        if ("CLOSED".equals(register.getStatus())) {
            throw new BusinessException("Register is already closed",
                    "REGISTER_ALREADY_CLOSED", HttpStatus.CONFLICT);
        }
        register.setActualClosing(actualClosing);
        register.setStatus("CLOSED");
        register.setClosedBy(userId);
        register.setClosedAt(Instant.now());
        if (notes != null) register.setNotes(notes);
        registerRepo.save(register);
        log.info("[CashRegister] Closed for org {} actual={}", orgId, actualClosing);
        return buildSummary(register);
    }

    // ── Internal ──────────────────────────────────────────────────────────

    private PosRegister getOrAutoCreate(UUID orgId, LocalDate date) {
        return registerRepo.findByOrgIdAndRegisterDate(orgId, date)
                .orElseGet(() -> {
                    PosRegister r = PosRegister.builder()
                            .orgId(orgId)
                            .registerDate(date)
                            .openingBalance(BigDecimal.ZERO)
                            .status("OPEN")
                            .build();
                    return registerRepo.save(r);
                });
    }

    private CashRegisterSummary buildSummary(PosRegister register) {
        LocalDate date = register.getRegisterDate();
        UUID orgId = register.getOrgId();

        BigDecimal cashSales = receiptRepo.sumByOrgDateAndMode(orgId, date, PaymentMode.CASH);
        BigDecimal upiSales  = receiptRepo.sumByOrgDateAndMode(orgId, date, PaymentMode.UPI);
        BigDecimal cardSales = receiptRepo.sumByOrgDateAndMode(orgId, date, PaymentMode.CARD);
        BigDecimal mixedSales = receiptRepo.sumByOrgDateAndMode(orgId, date, PaymentMode.MIXED);
        BigDecimal totalSales = cashSales.add(upiSales).add(cardSales).add(mixedSales);
        long txCount = receiptRepo.countByOrgAndDate(orgId, date);

        List<PosRegisterExpense> expenseEntities = expenseRepo.findByRegisterIdOrderByExpenseTimeAsc(register.getId());
        BigDecimal totalExpenses = expenseEntities.stream()
                .map(PosRegisterExpense::getAmount)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        // Expected closing = opening + cash sales only (UPI/Card don't affect physical drawer)
        BigDecimal expectedClosing = register.getOpeningBalance().add(cashSales).subtract(totalExpenses);

        BigDecimal variance = register.getActualClosing() != null
                ? register.getActualClosing().subtract(expectedClosing)
                : null;

        List<CashRegisterSummary.ExpenseLine> expenses = expenseEntities.stream()
                .map(e -> new CashRegisterSummary.ExpenseLine(
                        e.getId(), e.getAmount(), e.getDescription(),
                        e.getExpenseTime().toString()))
                .toList();

        return new CashRegisterSummary(
                register.getId(), date, register.getStatus(),
                register.getOpeningBalance(),
                cashSales, upiSales, cardSales, totalSales,
                totalExpenses, expectedClosing,
                register.getActualClosing(), variance,
                txCount, expenses
        );
    }
}
