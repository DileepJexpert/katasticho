package com.katasticho.erp.auth.filter;

import com.katasticho.erp.auth.service.JwtService;
import com.katasticho.erp.common.context.TenantContext;
import io.jsonwebtoken.Claims;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
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
public class JwtAuthenticationFilter extends OncePerRequestFilter {

    private final JwtService jwtService;

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response,
                                    FilterChain filterChain) throws ServletException, IOException {
        try {
            String header = request.getHeader("Authorization");
            if (header != null && header.startsWith("Bearer ")) {
                String token = header.substring(7);
                Claims claims = jwtService.validateAndExtract(token);

                if (claims != null) {
                    UUID userId = jwtService.extractUserId(claims);
                    UUID orgId = jwtService.extractOrgId(claims);
                    String role = jwtService.extractRole(claims);

                    // Set TenantContext for org_id filtering
                    TenantContext.setCurrentOrgId(orgId);
                    TenantContext.setCurrentUserId(userId);
                    TenantContext.setCurrentRole(role);

                    // Set Spring Security context
                    var authorities = List.of(new SimpleGrantedAuthority("ROLE_" + role));
                    var authentication = new UsernamePasswordAuthenticationToken(userId, null, authorities);
                    SecurityContextHolder.getContext().setAuthentication(authentication);
                }
            }

            filterChain.doFilter(request, response);
        } finally {
            // Always clear ThreadLocal to prevent leaks
            TenantContext.clear();
        }
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        String path = request.getServletPath();
        return path.startsWith("/api/v1/auth/")
                || path.startsWith("/actuator/")
                || path.startsWith("/v3/api-docs")
                || path.startsWith("/swagger-ui");
    }
}
