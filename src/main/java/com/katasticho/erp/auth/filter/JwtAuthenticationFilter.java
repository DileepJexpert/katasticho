package com.katasticho.erp.auth.filter;

import com.katasticho.erp.auth.entity.AppUser;
import com.katasticho.erp.auth.repository.AppUserRepository;
import com.katasticho.erp.auth.service.JwtService;
import com.katasticho.erp.ca.repository.DelegatedAccessTokenRepository;
import com.katasticho.erp.ca.repository.CaClientLinkRepository;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.service.OrgBootstrapService;
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
import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Component
@RequiredArgsConstructor
@Slf4j
public class JwtAuthenticationFilter extends OncePerRequestFilter {

    private final JwtService jwtService;
    private final OrgBootstrapService orgBootstrapService;
    private final AppUserRepository userRepository;
    private final CaClientLinkRepository caClientLinkRepository;
    private final DelegatedAccessTokenRepository delegatedAccessTokenRepository;

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response,
                                    FilterChain filterChain) throws ServletException, IOException {
        try {
            String header = request.getHeader("Authorization");
            if (header != null && header.startsWith("Bearer ")) {
                String token = header.substring(7);
                Claims claims = jwtService.validateAndExtract(token);

                if (claims == null) {
                    response.setStatus(HttpStatus.UNAUTHORIZED.value());
                    response.setContentType("application/json");
                    response.getWriter().write("{\"error\":\"AUTH_TOKEN_INVALID\",\"message\":\"Token is invalid or expired\"}");
                    return;
                }

                UUID userId = jwtService.extractUserId(claims);
                UUID orgId = jwtService.extractOrgId(claims);
                String role = jwtService.extractRole(claims);

                AppUser user = userRepository.findById(userId).orElse(null);
                if (user == null || !user.isActive() || user.isDeleted()) {
                    response.setStatus(HttpStatus.UNAUTHORIZED.value());
                    response.setContentType("application/json");
                    response.getWriter().write("{\"error\":\"AUTH_ACCOUNT_INACTIVE\",\"message\":\"Account is deactivated or deleted\"}");
                    return;
                }

                String effectiveRole = role;
                if ("CA_EXTERNAL".equals(role)) {
                    boolean validDelegatedToken = user.getCaFirmId() != null
                            && caClientLinkRepository.existsActiveDelegatedAccess(user.getCaFirmId(), orgId)
                            && delegatedAccessTokenRepository
                                    .findByTokenHashAndCaUserIdAndClientOrgIdAndUsedFalseAndExpiresAtAfter(
                                            jwtService.hashToken(token), userId, orgId, Instant.now())
                                    .isPresent();
                    if (!validDelegatedToken) {
                        response.setStatus(HttpStatus.UNAUTHORIZED.value());
                        response.setContentType("application/json");
                        response.getWriter().write("{\"error\":\"CA_DELEGATED_ACCESS_INVALID\",\"message\":\"CA delegated access is expired or inactive for this client\"}");
                        return;
                    }
                    effectiveRole = "ACCOUNTANT";
                }

                TenantContext.setCurrentOrgId(orgId);
                TenantContext.setCurrentUserId(userId);
                TenantContext.setCurrentRole(effectiveRole);

                var authorities = List.of(new SimpleGrantedAuthority("ROLE_" + effectiveRole));
                var authentication = new UsernamePasswordAuthenticationToken(userId, null, authorities);
                SecurityContextHolder.getContext().setAuthentication(authentication);

                try {
                    orgBootstrapService.ensureBootstrapped(orgId);
                } catch (Exception e) {
                    log.warn("Lazy bootstrap check failed for org {}: {}", orgId, e.getMessage());
                }
            }

            filterChain.doFilter(request, response);
        } finally {
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
