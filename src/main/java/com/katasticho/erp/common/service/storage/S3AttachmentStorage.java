package com.katasticho.erp.common.service.storage;

import com.katasticho.erp.common.exception.BusinessException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.multipart.MultipartFile;
import software.amazon.awssdk.auth.credentials.AwsBasicCredentials;
import software.amazon.awssdk.auth.credentials.DefaultCredentialsProvider;
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.S3Configuration;
import software.amazon.awssdk.services.s3.model.GetObjectRequest;
import software.amazon.awssdk.services.s3.model.NoSuchKeyException;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;

import jakarta.annotation.PostConstruct;
import java.io.IOException;
import java.net.URI;

/**
 * S3-compatible attachment storage — AWS S3 or any MinIO-style endpoint.
 * Enable with:
 *
 *   app.attachment.storage: s3
 *   app.attachment.s3.bucket: katasticho-attachments
 *   app.attachment.s3.region: ap-south-1
 *   app.attachment.s3.endpoint: http://minio:9000        # optional (MinIO)
 *   app.attachment.s3.access-key / secret-key            # optional — falls
 *                                                        # back to the AWS
 *                                                        # default chain
 *
 * This is the horizontally-scalable backend: uploads survive redeploys and
 * are visible from every replica.
 */
@Component
@Slf4j
@ConditionalOnProperty(name = "app.attachment.storage", havingValue = "s3")
public class S3AttachmentStorage implements AttachmentStorage {

    @Value("${app.attachment.s3.bucket}")
    private String bucket;

    @Value("${app.attachment.s3.region:ap-south-1}")
    private String region;

    @Value("${app.attachment.s3.endpoint:}")
    private String endpoint;

    @Value("${app.attachment.s3.access-key:}")
    private String accessKey;

    @Value("${app.attachment.s3.secret-key:}")
    private String secretKey;

    private S3Client s3;

    @PostConstruct
    void init() {
        var builder = S3Client.builder().region(Region.of(region));
        if (!endpoint.isBlank()) {
            // MinIO-compatible endpoints need path-style addressing.
            builder = builder.endpointOverride(URI.create(endpoint))
                    .serviceConfiguration(S3Configuration.builder()
                            .pathStyleAccessEnabled(true).build());
        }
        if (!accessKey.isBlank() && !secretKey.isBlank()) {
            builder = builder.credentialsProvider(StaticCredentialsProvider.create(
                    AwsBasicCredentials.create(accessKey, secretKey)));
        } else {
            builder = builder.credentialsProvider(DefaultCredentialsProvider.create());
        }
        this.s3 = builder.build();
        log.info("Attachment storage: S3 bucket '{}' ({})", bucket,
                endpoint.isBlank() ? "AWS " + region : endpoint);
    }

    @Override
    public void store(String relativePath, MultipartFile file) {
        try {
            s3.putObject(PutObjectRequest.builder()
                            .bucket(bucket).key(relativePath)
                            .contentType(file.getContentType())
                            .build(),
                    RequestBody.fromInputStream(file.getInputStream(), file.getSize()));
        } catch (IOException | software.amazon.awssdk.core.exception.SdkException e) {
            log.error("Failed to store attachment to S3: {}", e.getMessage());
            throw new BusinessException("Failed to store file: " + e.getMessage(),
                    "ATTACHMENT_STORE_FAILED", HttpStatus.INTERNAL_SERVER_ERROR);
        }
    }

    @Override
    public byte[] read(String relativePath) {
        try {
            return s3.getObjectAsBytes(GetObjectRequest.builder()
                    .bucket(bucket).key(relativePath).build()).asByteArray();
        } catch (NoSuchKeyException e) {
            throw new BusinessException("Attachment file not found on storage",
                    "ATTACHMENT_FILE_MISSING", HttpStatus.NOT_FOUND);
        } catch (software.amazon.awssdk.core.exception.SdkException e) {
            log.error("Failed to read attachment from S3: {}", e.getMessage());
            throw new BusinessException("Failed to read file: " + e.getMessage(),
                    "ATTACHMENT_READ_FAILED", HttpStatus.INTERNAL_SERVER_ERROR);
        }
    }
}
