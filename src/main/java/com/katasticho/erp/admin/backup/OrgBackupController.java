package com.katasticho.erp.admin.backup;

import lombok.RequiredArgsConstructor;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/admin/backups")
@RequiredArgsConstructor
public class OrgBackupController {

    private final OrgBackupService orgBackupService;

    @GetMapping("/org/export")
    @PreAuthorize("hasRole('OWNER')")
    public ResponseEntity<byte[]> exportCurrentOrg() {
        OrgBackupService.OrgBackupFile backup = orgBackupService.createCurrentOrgBackup();
        return ResponseEntity.ok()
                .contentType(MediaType.APPLICATION_OCTET_STREAM)
                .header(HttpHeaders.CONTENT_DISPOSITION,
                        ContentDisposition.attachment().filename(backup.fileName()).build().toString())
                .header("X-Backup-Checksum-SHA256", backup.checksum())
                .body(backup.bytes());
    }
}
