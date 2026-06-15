package com.katasticho.erp.portal.filter;

import com.katasticho.erp.auth.service.JwtService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.portal.entity.PortalUser;
import com.katasticho.erp.portal.repository.PortalUserRepository;
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

/**
 * Authenticates external portal users on {@code /api/v1/portal/**} (except the
 * public {@code /api/v1/portal/auth/**}). Reads a Bearer portal JWT (signed with
 * the isolated portal key), loads the {@link PortalUser}, and sets a
 * {@code ROLE_PORTAL} authentication + {@link TenantContext} scoped to the
 * portal user's org. The app's JWT filter never runs for these paths.
 */
@Component
@RequiredArgsConstructor
public class PortalAuthenticationFilter extends OncePerRequestFilter {

    private final JwtService jwtService;
    private final PortalUserRepository portalUserRepository;

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response,
                                    FilterChain filterChain) throws ServletException, IOException {
        try {
            String header = request.getHeader("Authorization");
            if (header == null || !header.startsWith("Bearer ")) {
                unauthorized(response, "PORTAL_AUTH_REQUIRED", "Portal authentication required");
                return;
            }
            Claims claims = jwtService.parsePortalToken(header.substring(7));
            if (claims == null) {
                unauthorized(response, "PORTAL_TOKEN_INVALID", "Portal token is invalid or expired");
                return;
            }

            UUID portalUserId = UUID.fromString(claims.getSubject());
            PortalUser pu = portalUserRepository.findByIdAndIsDeletedFalse(portalUserId).orElse(null);
            if (pu == null || !"ACTIVE".equals(pu.getStatus())) {
                unauthorized(response, "PORTAL_ACCOUNT_INACTIVE", "Portal account is inactive");
                return;
            }
            int tokenVersion = claims.containsKey("tokenVersion")
                    ? ((Number) claims.get("tokenVersion")).intValue() : 0;
            if (tokenVersion != pu.getTokenVersion()) {
                unauthorized(response, "PORTAL_SESSION_EXPIRED", "Portal session was invalidated");
                return;
            }

            TenantContext.setCurrentOrgId(pu.getOrgId());
            TenantContext.setCurrentUserId(pu.getId());
            TenantContext.setCurrentRole("PORTAL");

            var authorities = List.of(new SimpleGrantedAuthority("ROLE_PORTAL"));
            var authentication = new UsernamePasswordAuthenticationToken(pu.getId(), null, authorities);
            SecurityContextHolder.getContext().setAuthentication(authentication);

            filterChain.doFilter(request, response);
        } finally {
            TenantContext.clear();
        }
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        String path = request.getServletPath();
        // Only guard the portal API surface; the public auth endpoints are open.
        return !path.startsWith("/api/v1/portal/") || path.startsWith("/api/v1/portal/auth/");
    }

    private void unauthorized(HttpServletResponse response, String code, String message) throws IOException {
        response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
        response.setContentType("application/json");
        response.getWriter().write("{\"error\":\"" + code + "\",\"message\":\"" + message + "\"}");
    }
}
