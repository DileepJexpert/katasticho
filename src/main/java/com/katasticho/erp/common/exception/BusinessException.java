package com.katasticho.erp.common.exception;

import lombok.Getter;
import org.springframework.http.HttpStatus;

@Getter
public class BusinessException extends RuntimeException {

    private final HttpStatus status;
    private final String errorCode;

    public BusinessException(String message, String errorCode, HttpStatus status) {
        super(message);
        this.errorCode = errorCode;
        this.status = status;
    }

    public BusinessException(String message, String errorCode) {
        this(message, errorCode, HttpStatus.BAD_REQUEST);
    }

    // Common factory methods
    public static BusinessException notFound(String entity, Object id) {
        return new BusinessException(
                entity + " not found with id: " + id,
                "ERR_" + entity.toUpperCase() + "_NOT_FOUND",
                HttpStatus.NOT_FOUND
        );
    }

    public static BusinessException accessDenied(String message) {
        return new BusinessException(message, "ERR_ACCESS_DENIED", HttpStatus.FORBIDDEN);
    }

    public static BusinessException conflict(String message, String errorCode) {
        return new BusinessException(message, errorCode, HttpStatus.CONFLICT);
    }
}
