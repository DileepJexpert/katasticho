package com.katasticho.erp.auth.service;

import jakarta.servlet.http.Cookie;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseCookie;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.util.Arrays;
import java.util.Optional;

/**
 * Keeps browser refresh tokens outside JavaScript while mobile clients retain
 * their existing JSON-token contract.
 */
@Service
public class WebSessionCookieService {

    static final String REFRESH_COOKIE_NAME = "katasticho_web_refresh";
    private static final String WEB_SESSION_PATH = "/api/v1/auth/web";

    private final boolean secure;
    private final Duration maxAge;

    public WebSessionCookieService(
            @Value("${app.web-session.cookie.secure:true}") boolean secure,
            @Value("${app.jwt.refresh-token-expiry-days}") long refreshTokenExpiryDays) {
        this.secure = secure;
        this.maxAge = Duration.ofDays(refreshTokenExpiryDays);
    }

    public ResponseCookie issue(String refreshToken) {
        return baseCookie()
                .value(refreshToken)
                .maxAge(maxAge)
                .build();
    }

    public ResponseCookie expire() {
        return baseCookie()
                .value("")
                .maxAge(Duration.ZERO)
                .build();
    }

    public Optional<String> readRefreshToken(HttpServletRequest request) {
        if (request.getCookies() == null) {
            return Optional.empty();
        }
        return Arrays.stream(request.getCookies())
                .filter(cookie -> REFRESH_COOKIE_NAME.equals(cookie.getName()))
                .map(Cookie::getValue)
                .filter(value -> value != null && !value.isBlank())
                .findFirst();
    }

    private ResponseCookie.ResponseCookieBuilder baseCookie() {
        return ResponseCookie.from(REFRESH_COOKIE_NAME)
                .httpOnly(true)
                .secure(secure)
                .sameSite("Lax")
                .path(WEB_SESSION_PATH);
    }
}
