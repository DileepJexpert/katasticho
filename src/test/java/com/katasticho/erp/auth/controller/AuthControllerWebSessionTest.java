package com.katasticho.erp.auth.controller;

import com.katasticho.erp.auth.dto.AuthResponse;
import com.katasticho.erp.auth.dto.LoginRequest;
import com.katasticho.erp.auth.dto.RefreshRequest;
import com.katasticho.erp.auth.service.AuthService;
import com.katasticho.erp.auth.service.WebSessionCookieService;
import com.katasticho.erp.auth.service.WebSessionOriginValidator;
import com.katasticho.erp.common.exception.BusinessException;
import jakarta.servlet.http.HttpServletRequest;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseCookie;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class AuthControllerWebSessionTest {

    @Mock
    private AuthService authService;

    @Mock
    private WebSessionCookieService webSessionCookieService;

    @Mock
    private WebSessionOriginValidator webSessionOriginValidator;

    @Mock
    private HttpServletRequest request;

    @InjectMocks
    private AuthController controller;

    @Test
    void legacyMobileLoginKeepsTheJsonAccessAndRefreshTokenContract() {
        LoginRequest loginRequest = new LoginRequest("demo@example.com", "password");
        AuthResponse authResponse = new AuthResponse("access-token", "refresh-token", sampleUser());
        when(authService.login(loginRequest)).thenReturn(authResponse);

        var response = controller.login(loginRequest);

        assertThat(response.getBody()).isNotNull();
        assertThat(response.getBody().data()).isEqualTo(authResponse);
        assertThat(response.getBody().data().accessToken()).isEqualTo("access-token");
        assertThat(response.getBody().data().refreshToken()).isEqualTo("refresh-token");
        verifyNoInteractions(webSessionCookieService, webSessionOriginValidator);
    }

    @Test
    void legacyMobileRefreshKeepsTheJsonAccessAndRefreshTokenContract() {
        RefreshRequest refreshRequest = new RefreshRequest("current-refresh-token");
        AuthResponse authResponse = new AuthResponse("new-access-token", "new-refresh-token", sampleUser());
        when(authService.refreshToken(refreshRequest)).thenReturn(authResponse);

        var response = controller.refresh(refreshRequest);

        assertThat(response.getBody()).isNotNull();
        assertThat(response.getBody().data()).isEqualTo(authResponse);
        assertThat(response.getBody().data().refreshToken()).isEqualTo("new-refresh-token");
        verifyNoInteractions(webSessionCookieService, webSessionOriginValidator);
    }

    @Test
    void webLoginReturnsOnlyTheAccessTokenAndWritesTheRefreshCookie() {
        AuthResponse authResponse = new AuthResponse("access-token", "refresh-token", sampleUser());
        when(authService.login(any(LoginRequest.class))).thenReturn(authResponse);
        when(webSessionCookieService.issue("refresh-token"))
                .thenReturn(ResponseCookie.from("katasticho_web_refresh", "refresh-token")
                        .httpOnly(true)
                        .sameSite("Lax")
                        .path("/api/v1/auth/web")
                        .build());

        var response = controller.webLogin(request, new LoginRequest("demo@example.com", "password"));

        assertThat(response.getBody()).isNotNull();
        assertThat(response.getBody().data().accessToken()).isEqualTo("access-token");
        assertThat(response.getBody().data().getClass().getRecordComponents())
                .extracting(component -> component.getName())
                .containsExactly("accessToken", "user");
        assertThat(response.getHeaders().getFirst("Set-Cookie")).contains("HttpOnly", "SameSite=Lax");
        verify(webSessionOriginValidator).requireTrustedOrigin(request);
    }

    @Test
    void refreshWebSessionRejectsARequestWithoutTheHttpOnlyCookie() {
        when(webSessionCookieService.readRefreshToken(request)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> controller.refreshWebSession(request))
                .isInstanceOfSatisfying(BusinessException.class, exception -> {
                    assertThat(exception.getStatus()).isEqualTo(HttpStatus.UNAUTHORIZED);
                    assertThat(exception.getErrorCode()).isEqualTo("AUTH_WEB_SESSION_MISSING");
                });

        verifyNoInteractions(authService);
        verify(webSessionOriginValidator).requireTrustedOrigin(request);
    }

    private AuthResponse.UserInfo sampleUser() {
        return new AuthResponse.UserInfo(
                UUID.randomUUID(), UUID.randomUUID(), "Demo Admin", "demo@example.com", "9876543210",
                "ADMIN", "Demo Distributor", "DISTRIBUTION", "FMCG", "FMCG", true, "/");
    }
}
