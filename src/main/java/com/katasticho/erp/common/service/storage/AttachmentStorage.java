package com.katasticho.erp.common.service.storage;

import org.springframework.web.multipart.MultipartFile;

/**
 * Where attachment bytes live. The metadata row (EntityAttachment) always
 * stays in PostgreSQL; only the file body goes through this interface.
 *
 * Selected via {@code app.attachment.storage}: {@code local} (default —
 * single-instance disk, the historical behaviour) or {@code s3} (AWS S3 or
 * any MinIO-compatible endpoint — required the moment the app runs on more
 * than one replica or an ephemeral filesystem).
 */
public interface AttachmentStorage {

    /** Store the uploaded file body under the given relative path. */
    void store(String relativePath, MultipartFile file);

    /** Read a previously stored file body. */
    byte[] read(String relativePath);
}
