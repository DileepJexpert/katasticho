package com.katasticho.erp.reporting.dto;

import lombok.Data;

import java.util.List;

@Data
public class ReportScheduleRequest {

    /** Delivery frequency: DAILY, WEEKLY, or MONTHLY */
    private String frequency;

    /** Day of week (0=Sunday…6=Saturday); required when frequency = WEEKLY */
    private Short dayOfWeek;

    /** Day of month (1–31); required when frequency = MONTHLY */
    private Short dayOfMonth;

    /** Time-of-day for delivery in HH:MM format (24-hour) */
    private String sendTime;

    /** List of recipient email addresses */
    private List<String> recipientEmails;

    /** Optional email subject line template; may contain placeholders */
    private String subjectTemplate;

    /** Whether this schedule is currently active */
    private boolean active;
}
