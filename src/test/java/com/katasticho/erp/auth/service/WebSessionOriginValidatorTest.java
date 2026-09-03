package com.katasticho.erp.auth.service;

import com.katasticho.erp.common.exception.BusinessException;
import jakarta.servlet.http.HttpServletRequest;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class WebSessionOriginValidatorTest {

    @Test
    void acceptsAnExplicitlyAllowedBrowserOrigin() {
        HttpServletRequest request = mock(HttpServletRequest.class);
        when(request.getHeader(HttpHeaders.ORIGIN)).thenReturn("http://127.0.0.1:5173");

        assertThatCode(() -> new WebSessionOriginValidator(
                "http://127.0.0.1:5173,http://localhost:5173").requireTrustedOrigin(request))
                .doesNotThrowAnyException();
    }

    @Test
    void rejectsMissingOrUntrustedOriginsFailClosed() {
        HttpServletRequest request = mock(HttpServletRequest.class);
        when(request.getHeader(HttpHeaders.ORIGIN)).thenReturn("https://attacker.example");

        assertThatThrownBy(() -> new WebSessionOriginValidator("").requireTrustedOrigin(request))
                .isInstanceOfSatisfying(BusinessException.class, exception -> {
                    org.assertj.core.api.Assertions.assertThat(exception.getStatus()).isEqualTo(HttpStatus.FORBIDDEN);
                    org.assertj.core.api.Assertions.assertThat(exception.getErrorCode()).isEqualTo("AUTH_WEB_ORIGIN_FORBIDDEN");
                });
    }
}
