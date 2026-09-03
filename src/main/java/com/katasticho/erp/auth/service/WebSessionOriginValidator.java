package com.katasticho.erp.auth.service;

import com.katasticho.erp.common.exception.BusinessException;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import java.util.Arrays;
import java.util.Set;
import java.util.stream.Collectors;

/**
 * Provides a narrow CSRF defence for the cookie-bearing browser-session routes
 * without imposing browser cookie rules on the existing bearer-token APIs.
 */
@Service
public class WebSessionOriginValidator {

    private final Set<String> allowedOrigins;

    public WebSessionOriginValidator(
            @Value("${app.web-session.allowed-origins:}") String configuredOrigins) {
        allowedOrigins = Arrays.stream(configuredOrigins.split(","))
                .map(String::trim)
                .filter(origin -> !origin.isEmpty())
                .collect(Collectors.toUnmodifiableSet());
    }

    public void requireTrustedOrigin(HttpServletRequest request) {
        String origin = request.getHeader(HttpHeaders.ORIGIN);
        if (origin == null || !allowedOrigins.contains(origin)) {
            throw new BusinessException(
                    "Browser session request origin is not allowed.",
                    "AUTH_WEB_ORIGIN_FORBIDDEN",
                    HttpStatus.FORBIDDEN);
        }
    }
}
