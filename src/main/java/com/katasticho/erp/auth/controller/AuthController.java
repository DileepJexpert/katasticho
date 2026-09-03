package com.katasticho.erp.auth.controller;

import com.katasticho.erp.auth.dto.*;
import com.katasticho.erp.auth.entity.UserInvitation;
import com.katasticho.erp.auth.service.AuthService;
import com.katasticho.erp.auth.service.WebSessionCookieService;
import com.katasticho.erp.auth.service.WebSessionOriginValidator;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.dto.ApiResponse;
import com.katasticho.erp.common.exception.BusinessException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/v1/auth")
@RequiredArgsConstructor
public class AuthController {

    private final AuthService authService;
    private final WebSessionCookieService webSessionCookieService;
    private final WebSessionOriginValidator webSessionOriginValidator;

    @PostMapping("/otp/request")
    public ResponseEntity<ApiResponse<Map<String, String>>> requestOtp(@Valid @RequestBody OtpRequest request) {
        authService.requestOtp(request);
        return ResponseEntity.ok(ApiResponse.ok(
                Map.of("message", "OTP sent successfully"),
                "OTP sent to " + request.phone()));
    }

    @PostMapping("/otp/verify")
    public ResponseEntity<ApiResponse<AuthResponse>> verifyOtp(@Valid @RequestBody OtpVerifyRequest request) {
        AuthResponse response = authService.verifyOtpAndLogin(request);
        return ResponseEntity.ok(ApiResponse.ok(response, "Login successful"));
    }

    @PostMapping("/signup")
    public ResponseEntity<ApiResponse<AccountSubmissionResponse>> signup(@Valid @RequestBody SignupRequest request) {
        AccountSubmissionResponse response = authService.signup(request);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.created(response));
    }

    @PostMapping("/register")
    public ResponseEntity<ApiResponse<AccountSubmissionResponse>> register(@Valid @RequestBody RegisterRequest request) {
        AccountSubmissionResponse response = authService.register(request);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.created(response));
    }

    @PostMapping("/login")
    public ResponseEntity<ApiResponse<AuthResponse>> login(@Valid @RequestBody LoginRequest request) {
        AuthResponse response = authService.login(request);
        return ResponseEntity.ok(ApiResponse.ok(response, "Login successful"));
    }

    /**
     * Browser-only login. It leaves the short-lived access token in the
     * response, while the rotating refresh token is held in an HttpOnly cookie.
     */
    @PostMapping("/web/login")
    public ResponseEntity<ApiResponse<WebAuthResponse>> webLogin(
            HttpServletRequest servletRequest, @Valid @RequestBody LoginRequest request) {
        webSessionOriginValidator.requireTrustedOrigin(servletRequest);
        return webSessionResponse(authService.login(request), "Login successful");
    }

    @PostMapping("/refresh")
    public ResponseEntity<ApiResponse<AuthResponse>> refresh(@Valid @RequestBody RefreshRequest request) {
        AuthResponse response = authService.refreshToken(request);
        return ResponseEntity.ok(ApiResponse.ok(response, "Token refreshed"));
    }

    @PostMapping("/web/refresh")
    public ResponseEntity<ApiResponse<WebAuthResponse>> refreshWebSession(HttpServletRequest request) {
        webSessionOriginValidator.requireTrustedOrigin(request);
        AuthResponse response = authService.refreshToken(new RefreshRequest(requireWebRefreshToken(request)));
        return webSessionResponse(response, "Token refreshed");
    }

    @PostMapping("/logout")
    public ResponseEntity<ApiResponse<Void>> logout(@Valid @RequestBody RefreshRequest request) {
        authService.logout(request);
        return ResponseEntity.ok(ApiResponse.ok(null, "Logged out"));
    }

    @PostMapping("/web/logout")
    public ResponseEntity<ApiResponse<Void>> logoutWebSession(HttpServletRequest request) {
        webSessionOriginValidator.requireTrustedOrigin(request);
        webSessionCookieService.readRefreshToken(request)
                .ifPresent(refreshToken -> authService.logout(new RefreshRequest(refreshToken)));
        return ResponseEntity.ok()
                .header(HttpHeaders.SET_COOKIE, webSessionCookieService.expire().toString())
                .body(ApiResponse.ok(null, "Logged out"));
    }

    @PostMapping("/password/forgot")
    public ResponseEntity<ApiResponse<Map<String, String>>> forgotPassword(
            @Valid @RequestBody ForgotPasswordRequest request) {
        authService.requestPasswordReset(request);
        return ResponseEntity.ok(ApiResponse.ok(
                Map.of("message", "Password reset OTP sent"),
                "Password reset OTP sent"));
    }

    @PostMapping("/password/reset")
    public ResponseEntity<ApiResponse<Map<String, String>>> resetPassword(
            @Valid @RequestBody ResetPasswordRequest request) {
        authService.resetPassword(request);
        return ResponseEntity.ok(ApiResponse.ok(
                Map.of("message", "Password reset successfully"),
                "Password reset successfully"));
    }

    @PostMapping("/change-password")
    @PreAuthorize("isAuthenticated()")
    public ResponseEntity<ApiResponse<Map<String, String>>> changePassword(
            @Valid @RequestBody ChangePasswordRequest request) {
        authService.changePassword(
                TenantContext.getCurrentUserId(),
                TenantContext.getCurrentOrgId(),
                request);
        return ResponseEntity.ok(ApiResponse.ok(
                Map.of("message", "Password changed successfully"),
                "Password changed successfully"));
    }

    @PostMapping("/invite")
    @PreAuthorize("hasAnyRole('OWNER','ADMIN')")
    public ResponseEntity<ApiResponse<Map<String, String>>> invite(@Valid @RequestBody InviteRequest request) {
        UserInvitation invitation = authService.invite(
                request, TenantContext.getCurrentOrgId(), TenantContext.getCurrentUserId());
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.created(Map.of(
                        "token", invitation.getToken(),
                        "expiresAt", invitation.getExpiresAt().toString()
                )));
    }

    @PostMapping("/invite/accept")
    public ResponseEntity<ApiResponse<AuthResponse>> acceptInvite(@Valid @RequestBody InviteAcceptRequest request) {
        AuthResponse response = authService.acceptInvitation(request);
        return ResponseEntity.ok(ApiResponse.ok(response, "Welcome! Account created."));
    }

    @GetMapping("/me")
    @PreAuthorize("isAuthenticated()")
    public ResponseEntity<ApiResponse<AuthResponse.UserInfo>> me() {
        AuthResponse.UserInfo user = authService.getCurrentUser(
                TenantContext.getCurrentUserId(), TenantContext.getCurrentOrgId());
        return ResponseEntity.ok(ApiResponse.ok(user));
    }

    private ResponseEntity<ApiResponse<WebAuthResponse>> webSessionResponse(
            AuthResponse authResponse, String message) {
        return ResponseEntity.ok()
                .header(HttpHeaders.SET_COOKIE, webSessionCookieService.issue(authResponse.refreshToken()).toString())
                .body(ApiResponse.ok(WebAuthResponse.from(authResponse), message));
    }

    private String requireWebRefreshToken(HttpServletRequest request) {
        return webSessionCookieService.readRefreshToken(request)
                .orElseThrow(() -> new BusinessException(
                        "Browser session has expired. Please sign in again.",
                        "AUTH_WEB_SESSION_MISSING",
                        HttpStatus.UNAUTHORIZED));
    }
}
