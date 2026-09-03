package com.katasticho.erp.auth.service;

import jakarta.servlet.http.Cookie;
import jakarta.servlet.http.HttpServletRequest;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class WebSessionCookieServiceTest {

    private final WebSessionCookieService service = new WebSessionCookieService(false, 30);

    @Test
    void issue_createsHttpOnlyScopedRefreshCookie() {
        String header = service.issue("refresh-token").toString();

        assertThat(header)
                .contains("katasticho_web_refresh=refresh-token")
                .contains("HttpOnly")
                .contains("SameSite=Lax")
                .contains("Path=/api/v1/auth/web")
                .contains("Max-Age=2592000")
                .doesNotContain("Secure");
    }

    @Test
    void expire_clearsTheSameCookieScope() {
        String header = service.expire().toString();

        assertThat(header)
                .contains("katasticho_web_refresh=")
                .contains("Path=/api/v1/auth/web")
                .contains("Max-Age=0");
    }

    @Test
    void readRefreshToken_usesOnlyTheWebSessionCookie() {
        HttpServletRequest request = mock(HttpServletRequest.class);
        when(request.getCookies()).thenReturn(new Cookie[]{
                new Cookie("other", "ignored"),
                new Cookie("katasticho_web_refresh", "refresh-token")
        });

        assertThat(service.readRefreshToken(request)).contains("refresh-token");
    }
}
