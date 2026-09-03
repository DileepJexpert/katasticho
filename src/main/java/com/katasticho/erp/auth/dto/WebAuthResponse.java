package com.katasticho.erp.auth.dto;

/**
 * Browser-session response. The refresh token is intentionally omitted because
 * it is delivered only as an HttpOnly cookie to the web client.
 */
public record WebAuthResponse(
        String accessToken,
        AuthResponse.UserInfo user
) {
    public static WebAuthResponse from(AuthResponse authResponse) {
        return new WebAuthResponse(authResponse.accessToken(), authResponse.user());
    }
}
