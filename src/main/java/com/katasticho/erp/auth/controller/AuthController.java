package com.katasticho.erp.auth.controller;

import com.katasticho.erp.auth.dto.*;
import com.katasticho.erp.auth.entity.UserInvitation;
import com.katasticho.erp.auth.service.AuthService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.dto.ApiResponse;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
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
    public ResponseEntity<ApiResponse<AuthResponse>> signup(@Valid @RequestBody SignupRequest request) {
        AuthResponse response = authService.signup(request);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.created(response));
    }

    @PostMapping("/login")
    public ResponseEntity<ApiResponse<AuthResponse>> login(@Valid @RequestBody LoginRequest request) {
        AuthResponse response = authService.login(request);
        return ResponseEntity.ok(ApiResponse.ok(response, "Login successful"));
    }

    @PostMapping("/refresh")
    public ResponseEntity<ApiResponse<AuthResponse>> refresh(@Valid @RequestBody RefreshRequest request) {
        AuthResponse response = authService.refreshToken(request);
        return ResponseEntity.ok(ApiResponse.ok(response, "Token refreshed"));
    }

    @PostMapping("/logout")
    public ResponseEntity<ApiResponse<Void>> logout(@Valid @RequestBody RefreshRequest request) {
        authService.logout(request);
        return ResponseEntity.ok(ApiResponse.ok(null, "Logged out"));
    }

    @PostMapping("/invite")
    @PreAuthorize("hasRole('OWNER')")
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
}
