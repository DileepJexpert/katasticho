package com.katasticho.erp.attendance.biometric.entity;

import com.katasticho.erp.common.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;
import java.util.UUID;

/**
 * Raw punch event from a biometric hardware clock / cloud push terminal.
 */
@Entity
@Table(name = "biometric_attendance_log")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class BiometricAttendanceLog extends BaseEntity {

    @Column(name = "device_id")
    private UUID deviceId;

    @Column(name = "employee_id")
    private UUID employeeId;

    @Column(name = "biometric_pin", nullable = false, length = 50)
    private String biometricPin;

    @Column(name = "punch_time", nullable = false)
    private Instant punchTime;

    @Column(name = "punch_type", nullable = false, length = 20)
    @Builder.Default
    private String punchType = "CHECK_IN"; // CHECK_IN | CHECK_OUT | BREAK_OUT | BREAK_IN

    @Column(name = "verify_mode", length = 20)
    @Builder.Default
    private String verifyMode = "FINGERPRINT"; // FINGERPRINT | FACE | CARD | PASSWORD | MANUAL

    @Column(name = "sync_status", nullable = false, length = 20)
    @Builder.Default
    private String syncStatus = "PROCESSED"; // PROCESSED | PENDING | UNMATCHED | ERROR

    @Column(name = "raw_payload", columnDefinition = "TEXT")
    private String rawPayload;
}
