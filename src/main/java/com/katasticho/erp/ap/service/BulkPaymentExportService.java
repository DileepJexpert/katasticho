package com.katasticho.erp.ap.service;

import com.katasticho.erp.accounting.entity.Account;
import com.katasticho.erp.accounting.repository.AccountRepository;
import com.katasticho.erp.ap.dto.BulkPaymentExportRequest;
import com.katasticho.erp.ap.dto.ChequePrintResponse;
import com.katasticho.erp.ap.entity.VendorPayment;
import com.katasticho.erp.ap.repository.VendorPaymentRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.common.util.AmountToWordsConverter;
import com.katasticho.erp.contact.entity.Contact;
import com.katasticho.erp.contact.repository.ContactRepository;
import com.katasticho.erp.organisation.Organisation;
import com.katasticho.erp.organisation.OrganisationRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.text.DecimalFormat;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.*;
import java.util.function.Function;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class BulkPaymentExportService {

    private final VendorPaymentRepository paymentRepository;
    private final ContactRepository contactRepository;
    private final AccountRepository accountRepository;
    private final OrganisationRepository organisationRepository;

    private static final DateTimeFormatter DDMMYYYY = DateTimeFormatter.ofPattern("dd/MM/yyyy");
    private static final DateTimeFormatter YYYYMMDD = DateTimeFormatter.ofPattern("yyyyMMdd");
    private static final DecimalFormat INDIAN_CURRENCY_FORMAT = new DecimalFormat("#,##,##0.00");

    @Transactional(readOnly = true)
    public ChequePrintResponse getChequePrintData(UUID paymentId, String chequeNumber) {
        UUID orgId = TenantContext.getCurrentOrgId();

        VendorPayment payment = paymentRepository.findByIdAndOrgIdAndIsDeletedFalse(paymentId, orgId)
                .orElseThrow(() -> BusinessException.notFound("VendorPayment", paymentId));

        Contact contact = contactRepository.findByIdAndOrgIdAndIsDeletedFalse(payment.getContactId(), orgId)
                .orElseThrow(() -> BusinessException.notFound("Contact", payment.getContactId()));

        Organisation org = organisationRepository.findById(orgId)
                .orElseThrow(() -> BusinessException.notFound("Organisation", orgId));

        String payeeName = contact.getCompanyName() != null && !contact.getCompanyName().isBlank()
                ? contact.getCompanyName()
                : contact.getDisplayName();

        BigDecimal amount = payment.getAmount().setScale(2, RoundingMode.HALF_UP);
        String amountInWords = AmountToWordsConverter.convert(amount).toUpperCase();
        String formattedAmount = "= ₹ " + INDIAN_CURRENCY_FORMAT.format(amount) + " /-";

        LocalDate date = payment.getPaymentDate() != null ? payment.getPaymentDate() : LocalDate.now();
        String dateFormatted = date.format(DateTimeFormatter.ofPattern("dd-MM-yyyy"));

        // Format for Indian cheque boxes: D D M M Y Y Y Y spaced
        String ddmmyyyy = date.format(DateTimeFormatter.ofPattern("ddMMyyyy"));
        String dateSpaced = String.join(" ", ddmmyyyy.split(""));

        String chqNo = chequeNumber != null && !chequeNumber.isBlank()
                ? chequeNumber
                : (payment.getReferenceNumber() != null ? payment.getReferenceNumber() : "");

        return new ChequePrintResponse(
                payment.getId(),
                payment.getPaymentNumber(),
                "** " + payeeName + " **",
                amount,
                formattedAmount,
                amountInWords,
                date,
                dateFormatted,
                dateSpaced,
                chqNo,
                true,
                contact.getBankName() != null ? contact.getBankName() : "",
                contact.getBankAccountNo() != null ? contact.getBankAccountNo() : "",
                contact.getBankIfsc() != null ? contact.getBankIfsc() : "",
                org.getName()
        );
    }

    @Transactional(readOnly = true)
    public byte[] exportBulkPaymentCsv(BulkPaymentExportRequest request) {
        UUID orgId = TenantContext.getCurrentOrgId();

        List<VendorPayment> payments = paymentRepository.findAllById(request.paymentIds()).stream()
                .filter(p -> p.getOrgId().equals(orgId) && !p.isDeleted())
                .sorted(Comparator.comparing(VendorPayment::getPaymentDate))
                .toList();

        if (payments.isEmpty()) {
            throw new BusinessException("No valid vendor payments found for the given IDs", "NO_PAYMENTS_FOUND");
        }

        Set<UUID> contactIds = payments.stream().map(VendorPayment::getContactId).collect(Collectors.toSet());
        Map<UUID, Contact> contactMap = contactRepository.findAllById(contactIds).stream()
                .collect(Collectors.toMap(Contact::getId, Function.identity()));

        Set<UUID> accountIds = payments.stream().map(VendorPayment::getPaidThroughId).collect(Collectors.toSet());
        Map<UUID, Account> accountMap = accountRepository.findAllById(accountIds).stream()
                .collect(Collectors.toMap(Account::getId, Function.identity()));

        Organisation org = organisationRepository.findById(orgId).orElse(null);
        String orgName = org != null ? org.getName() : "Organisation";

        String format = request.format() != null ? request.format().toUpperCase() : "GENERIC_NEFT_RTGS";

        StringBuilder csv = new StringBuilder();

        switch (format) {
            case "HDFC_CMS" -> generateHdfcCms(csv, payments, contactMap, orgName);
            case "ICICI_CIB" -> generateIciciCib(csv, payments, contactMap, accountMap);
            case "SBI_CMP" -> generateSbiCmp(csv, payments, contactMap, accountMap);
            default -> generateGenericNeftRtgs(csv, payments, contactMap, accountMap);
        }

        return csv.toString().getBytes(java.nio.charset.StandardCharsets.UTF_8);
    }

    private void generateGenericNeftRtgs(
            StringBuilder csv,
            List<VendorPayment> payments,
            Map<UUID, Contact> contactMap,
            Map<UUID, Account> accountMap
    ) {
        csv.append("Payment Reference,Payment Date,Beneficiary Name,Beneficiary Account Number,IFSC Code,Bank Name,Amount,Payment Mode,Narration,Vendor Email,Vendor Mobile\n");

        for (VendorPayment p : payments) {
            Contact c = contactMap.get(p.getContactId());
            String beneName = c != null ? (c.getCompanyName() != null && !c.getCompanyName().isBlank() ? c.getCompanyName() : c.getDisplayName()) : "";
            String beneAcc = c != null && c.getBankAccountNo() != null ? c.getBankAccountNo() : "";
            String ifsc = c != null && c.getBankIfsc() != null ? c.getBankIfsc() : "";
            String bankName = c != null && c.getBankName() != null ? c.getBankName() : "";
            String email = c != null && c.getEmail() != null ? c.getEmail() : "";
            String mobile = c != null && c.getMobile() != null ? c.getMobile() : (c != null && c.getPhone() != null ? c.getPhone() : "");

            BigDecimal amt = p.getAmount().setScale(2, RoundingMode.HALF_UP);
            String mode = amt.compareTo(new BigDecimal("200000")) >= 0 ? "RTGS" : "NEFT";
            String narration = "Payment for " + p.getPaymentNumber();

            csv.append(escape(p.getPaymentNumber())).append(',')
               .append(escape(p.getPaymentDate().format(DDMMYYYY))).append(',')
               .append(escape(beneName)).append(',')
               .append(escape(beneAcc)).append(',')
               .append(escape(ifsc)).append(',')
               .append(escape(bankName)).append(',')
               .append(amt.toPlainString()).append(',')
               .append(escape(mode)).append(',')
               .append(escape(narration)).append(',')
               .append(escape(email)).append(',')
               .append(escape(mobile)).append('\n');
        }
    }

    private void generateHdfcCms(
            StringBuilder csv,
            List<VendorPayment> payments,
            Map<UUID, Contact> contactMap,
            String orgName
    ) {
        // Standard HDFC CMS Payout File format
        csv.append("Transaction Type,Beneficiary Code,Beneficiary Account No,Instrument Amount,Beneficiary Name,Drawee Location,Print Location,Beneficiary Address 1,Beneficiary Address 2,Beneficiary Address 3,Beneficiary Address 4,Beneficiary Address 5,Instruction Reference No,Customer Reference No,Payment Details 1,Payment Details 2,Payment Details 3,Payment Details 4,Payment Details 5,Payment Details 6,Payment Details 7,Instrument Date,Beneficiary Email Id\n");

        for (VendorPayment p : payments) {
            Contact c = contactMap.get(p.getContactId());
            String beneName = c != null ? (c.getCompanyName() != null && !c.getCompanyName().isBlank() ? c.getCompanyName() : c.getDisplayName()) : "";
            String beneAcc = c != null && c.getBankAccountNo() != null ? c.getBankAccountNo() : "";
            String ifsc = c != null && c.getBankIfsc() != null ? c.getBankIfsc() : "";
            String email = c != null && c.getEmail() != null ? c.getEmail() : "";
            BigDecimal amt = p.getAmount().setScale(2, RoundingMode.HALF_UP);
            String txnType = amt.compareTo(new BigDecimal("200000")) >= 0 ? "R" : "N"; // N=NEFT, R=RTGS

            csv.append(escape(txnType)).append(',')
               .append(escape(c != null && c.getGstin() != null ? c.getGstin() : "")).append(',')
               .append(escape(beneAcc)).append(',')
               .append(amt.toPlainString()).append(',')
               .append(escape(beneName)).append(',')
               .append(',').append(',') // Drawee, Print Location
               .append(escape(ifsc)).append(',') // Used by HDFC for IFSC routing
               .append(',').append(',').append(',').append(',') // Address 2-5
               .append(escape(p.getPaymentNumber())).append(',')
               .append(escape(p.getPaymentNumber())).append(',')
               .append(escape("Payment from " + orgName)).append(',')
               .append(',').append(',').append(',').append(',').append(',').append(',') // Details 2-7
               .append(escape(p.getPaymentDate().format(DDMMYYYY))).append(',')
               .append(escape(email)).append('\n');
        }
    }

    private void generateIciciCib(
            StringBuilder csv,
            List<VendorPayment> payments,
            Map<UUID, Contact> contactMap,
            Map<UUID, Account> accountMap
    ) {
        // ICICI Corporate Internet Banking (CIB) batch format
        csv.append("PYMT_MODE,PYMT_PROD_TYPE_CODE,PYMT_REF_NO,VALUE_DATE,DR_AC_NO,AMOUNT,BENE_NAME,BENE_ACC_NO,BENE_IFSC,BENE_EMAIL,REMARKS\n");

        for (VendorPayment p : payments) {
            Contact c = contactMap.get(p.getContactId());
            Account drAcc = accountMap.get(p.getPaidThroughId());
            String drAccNo = drAcc != null && drAcc.getCode() != null ? drAcc.getCode() : "";

            String beneName = c != null ? (c.getCompanyName() != null && !c.getCompanyName().isBlank() ? c.getCompanyName() : c.getDisplayName()) : "";
            String beneAcc = c != null && c.getBankAccountNo() != null ? c.getBankAccountNo() : "";
            String ifsc = c != null && c.getBankIfsc() != null ? c.getBankIfsc() : "";
            String email = c != null && c.getEmail() != null ? c.getEmail() : "";
            BigDecimal amt = p.getAmount().setScale(2, RoundingMode.HALF_UP);
            String mode = amt.compareTo(new BigDecimal("200000")) >= 0 ? "RTGS" : "NEFT";

            csv.append(escape(mode)).append(',')
               .append("VENDOR_PAYMENT").append(',')
               .append(escape(p.getPaymentNumber())).append(',')
               .append(escape(p.getPaymentDate().format(DDMMYYYY))).append(',')
               .append(escape(drAccNo)).append(',')
               .append(amt.toPlainString()).append(',')
               .append(escape(beneName)).append(',')
               .append(escape(beneAcc)).append(',')
               .append(escape(ifsc)).append(',')
               .append(escape(email)).append(',')
               .append(escape("Payout " + p.getPaymentNumber())).append('\n');
        }
    }

    private void generateSbiCmp(
            StringBuilder csv,
            List<VendorPayment> payments,
            Map<UUID, Contact> contactMap,
            Map<UUID, Account> accountMap
    ) {
        // SBI Corporate Multi-Payment (CMP) format
        csv.append("Payment Mode,Debit Account No,Txn Date,Txn Amount,Beneficiary Name,Beneficiary Account No,Beneficiary IFSC,Remarks,Email\n");

        for (VendorPayment p : payments) {
            Contact c = contactMap.get(p.getContactId());
            Account drAcc = accountMap.get(p.getPaidThroughId());
            String drAccNo = drAcc != null && drAcc.getCode() != null ? drAcc.getCode() : "";

            String beneName = c != null ? (c.getCompanyName() != null && !c.getCompanyName().isBlank() ? c.getCompanyName() : c.getDisplayName()) : "";
            String beneAcc = c != null && c.getBankAccountNo() != null ? c.getBankAccountNo() : "";
            String ifsc = c != null && c.getBankIfsc() != null ? c.getBankIfsc() : "";
            String email = c != null && c.getEmail() != null ? c.getEmail() : "";
            BigDecimal amt = p.getAmount().setScale(2, RoundingMode.HALF_UP);
            String mode = amt.compareTo(new BigDecimal("200000")) >= 0 ? "RTGS" : "NEFT";

            csv.append(escape(mode)).append(',')
               .append(escape(drAccNo)).append(',')
               .append(escape(p.getPaymentDate().format(DDMMYYYY))).append(',')
               .append(amt.toPlainString()).append(',')
               .append(escape(beneName)).append(',')
               .append(escape(beneAcc)).append(',')
               .append(escape(ifsc)).append(',')
               .append(escape("Bill Payout " + p.getPaymentNumber())).append(',')
               .append(escape(email)).append('\n');
        }
    }

    public String filename(String format) {
        String today = LocalDate.now().format(YYYYMMDD);
        String suffix = format != null ? format.toLowerCase() : "neft";
        return "bank_payout_" + suffix + "_" + today + ".csv";
    }

    private String escape(String value) {
        if (value == null) return "";
        if (value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r")) {
            return "\"" + value.replace("\"", "\"\"") + "\"";
        }
        return value;
    }
}
