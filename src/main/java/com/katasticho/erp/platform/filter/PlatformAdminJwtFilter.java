package com.katasticho.erp.platform.filter;

import com.katasticho.erp.auth.service.JwtService;
import com.katasticho.erp.platform.context.PlatformAdminContext;
import com.katasticho.erp.platform.entity.PlatformAdmin;
import com.katasticho.erp.platform.repository.PlatformAdminRepository;
import io.jsonwebtoken.Claims;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.List;
import java.util.UUID;

@Component
@RequiredArgsConstructor
@Slf4j
public class PlatformAdminJwtFilter extends OncePerRequestFilter {

    private final JwtService jwtService;
    private final PlatformAdminRepository platformAdminRepository;

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response,
                                    FilterChain filterChain) throws ServletException, IOException {
        try {
            String header = request.getHeader("Authorization");
            if (header == null || !header.startsWith("Bearer ")) {
                writeUnauthorized(response, "AUTH_TOKEN_MISSING", "Authorization token is required");
                return;
            }

            String token = header.substring(7);
            Claims claims = jwtService.parsePlatformAdminToken(token);

            if (claims == null) {
                writeUnauthorized(response, "AUTH_TOKEN_INVALID", "Token is invalid or expired");
                return;
            }

            UUID adminId = UUID.fromString(claims.getSubject());
            String role = claims.get("role", String.class);
            int jwtTokenVersion = claims.containsKey("tokenVersion")
                    ? ((Number) claims.get("tokenVersion")).intValue() : 0;

            PlatformAdmin admin = platformAdminRepository.findById(adminId).orElse(null);
            if (admin == null || !admin.isActive()) {
                writeUnauthorized(response, "AUTH_ACCOUNT_INACTIVE", "Platform admin account is inactive");
                return;
            }

            if (jwtTokenVersion != admin.getTokenVersion()) {
                writeUnauthorized(response, "AUTH_SESSION_INVALIDATED", "Session invalidated — please log in again");
                return;
            }

            PlatformAdminContext.set(adminId, role);

            var authorities = List.of(new SimpleGrantedAuthority("ROLE_PLATFORM_ADMIN"));
            var authentication = new UsernamePasswordAuthenticationToken(adminId, null, authorities);
            SecurityContextHolder.getContext().setAuthentication(authentication);

            filterChain.doFilter(request, response);
        } finally {
            PlatformAdminContext.clear();
        }
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        String path = request.getServletPath();
        // Only apply this filter to platform-admin paths, but skip the login endpoint
        if (!path.startsWith("/api/platform-admin/")) {
            return true;
        }
        // Login endpoint doesn't need authentication
        return path.endsWith("/auth/login");
    }

    private void writeUnauthorized(HttpServletResponse response, String code, String message) throws IOException {
        response.setStatus(HttpStatus.UNAUTHORIZED.value());
        response.setContentType("application/json");
        response.getWriter().write("{\"error\":\"" + code + "\",\"message\":\"" + message + "\"}");
    }
}
