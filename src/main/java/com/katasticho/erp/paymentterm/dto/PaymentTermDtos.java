package com.katasticho.erp.paymentterm.dto;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

/** DTOs for payment terms + the derived instalment schedule. */
public final class PaymentTermDtos {

    private PaymentTermDtos() {}

    public record LineRequest(
            Integer seq,
            String valueType,   // PERCENT | BALANCE
            BigDecimal value,   // percent of total when PERCENT
            Integer daysOffset) {}

    public record PaymentTermRequest(
            String name,
            String description,
            Boolean isDefault,
            Boolean active,
            List<LineRequest> lines) {}

    public record LineResponse(
            UUID id, int seq, String valueType, BigDecimal value, int daysOffset) {}

    public record PaymentTermResponse(
            UUID id, String name, String description, boolean isDefault, boolean active,
            List<LineResponse> lines) {}

    /** One row of the derived (never stored) per-instalment status. */
    public record InstalmentView(
            UUID id, int seq, BigDecimal amount, LocalDate dueDate,
            BigDecimal paidAmount, BigDecimal balance, String status, boolean overdue) {}

    public record InstalmentScheduleResponse(
            UUID invoiceId, UUID paymentTermId, BigDecimal totalAmount, BigDecimal amountPaid,
            boolean allPaid, LocalDate effectiveDueDate, List<InstalmentView> instalments) {}
}
