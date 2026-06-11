package com.katasticho.erp.auth.filter;

import com.katasticho.erp.auth.entity.ApiKey;
import com.katasticho.erp.auth.entity.AppUser;
import com.katasticho.erp.auth.repository.AppUserRepository;
import com.katasticho.erp.auth.service.ApiKeyService;
import com.katasticho.erp.common.context.TenantContext;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.List;
import java.util.Optional;

/**
 * Authenticates org-scoped API keys, so external agents (the Katasticho MCP
 * server, integrations, scripts) can call the API without a user JWT.
 *
 * <p>Reads {@code X-API-Key: kat_...} (or {@code Authorization: Bearer kat_...}).
 * On a valid key it populates the SAME {@link TenantContext} + {@code ROLE_<role>}
 * authority as {@link JwtAuthenticationFilter}, so {@code @PreAuthorize} and
 * {@code @RequiresModule} behave identically. Requests without an API key header
 * pass straight through to the JWT filter untouched.
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class ApiKeyAuthenticationFilter extends OncePerRequestFilter {

    private final ApiKeyService apiKeyService;
    private final AppUserRepository userRepository;

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response,
                                    FilterChain filterChain) throws ServletException, IOException {
        String rawKey = extractKey(request);
        if (rawKey == null) {
            // Not an API-key request — leave it for the JWT filter.
            filterChain.doFilter(request, response);
            return;
        }

        try {
            Optional<ApiKey> keyOpt = apiKeyService.resolveUsableKey(rawKey);
            if (keyOpt.isEmpty()) {
                unauthorized(response, "API_KEY_INVALID",
                        "API key is invalid, expired, or revoked");
                return;
            }
            ApiKey key = keyOpt.get();

            AppUser user = userRepository
                    .findByIdAndOrgIdAndIsDeletedFalse(key.getUserId(), key.getOrgId())
                    .orElse(null);
            if (user == null || !user.isActive()) {
                unauthorized(response, "API_KEY_USER_INACTIVE",
                        "The user this API key acts as is inactive");
                return;
            }

            TenantContext.setCurrentOrgId(key.getOrgId());
            TenantContext.setCurrentUserId(key.getUserId());
            TenantContext.setCurrentRole(user.getRole());

            var authorities = List.of(new SimpleGrantedAuthority("ROLE_" + user.getRole()));
            var authentication = new UsernamePasswordAuthenticationToken(key.getUserId(), null, authorities);
            SecurityContextHolder.getContext().setAuthentication(authentication);

            try {
                apiKeyService.touchLastUsed(key.getId());
            } catch (Exception e) {
                log.debug("Could not stamp api_key.last_used_at: {}", e.getMessage());
            }

            filterChain.doFilter(request, response);
        } finally {
            TenantContext.clear();
        }
    }

    private String extractKey(HttpServletRequest request) {
        String headerKey = request.getHeader("X-API-Key");
        if (headerKey != null && !headerKey.isBlank()) {
            return headerKey.trim();
        }
        String auth = request.getHeader("Authorization");
        if (auth != null && auth.startsWith("Bearer " + ApiKeyService.KEY_PREFIX)) {
            return auth.substring("Bearer ".length()).trim();
        }
        return null;
    }

    private void unauthorized(HttpServletResponse response, String code, String message) throws IOException {
        response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
        response.setContentType("application/json");
        response.getWriter().write("{\"error\":\"" + code + "\",\"message\":\"" + message + "\"}");
    }
}
