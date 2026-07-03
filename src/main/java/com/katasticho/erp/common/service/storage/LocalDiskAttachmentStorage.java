package com.katasticho.erp.common.service.storage;

import com.katasticho.erp.common.exception.BusinessException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;

/**
 * Historical local-disk storage under {@code app.attachment.storage-path}.
 * Fine for a single instance; on multiple replicas an upload lands on one
 * node's disk and 404s on the others — switch to the s3 backend before
 * scaling out.
 */
@Component
@Slf4j
@ConditionalOnProperty(name = "app.attachment.storage", havingValue = "local", matchIfMissing = true)
public class LocalDiskAttachmentStorage implements AttachmentStorage {

    @Value("${app.attachment.storage-path:./attachments}")
    private String storagePath;

    @Override
    public void store(String relativePath, MultipartFile file) {
        Path target = Paths.get(storagePath).resolve(relativePath).normalize();
        if (!target.startsWith(Paths.get(storagePath).normalize())) {
            throw new BusinessException("Invalid attachment path",
                    "ATTACHMENT_BAD_PATH", HttpStatus.BAD_REQUEST);
        }
        try {
            Files.createDirectories(target.getParent());
            file.transferTo(target.toAbsolutePath());
        } catch (IOException e) {
            log.error("Failed to store attachment: {}", e.getMessage());
            throw new BusinessException("Failed to store file: " + e.getMessage(),
                    "ATTACHMENT_STORE_FAILED", HttpStatus.INTERNAL_SERVER_ERROR);
        }
    }

    @Override
    public byte[] read(String relativePath) {
        Path source = Paths.get(storagePath).resolve(relativePath).normalize();
        if (!source.startsWith(Paths.get(storagePath).normalize())) {
            throw new BusinessException("Invalid attachment path",
                    "ATTACHMENT_BAD_PATH", HttpStatus.BAD_REQUEST);
        }
        try {
            return Files.readAllBytes(source);
        } catch (IOException e) {
            throw new BusinessException("Attachment file not found on storage",
                    "ATTACHMENT_FILE_MISSING", HttpStatus.NOT_FOUND);
        }
    }
}
