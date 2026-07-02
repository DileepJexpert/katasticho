package com.katasticho.erp.common.config;

import com.katasticho.erp.auth.filter.ApiKeyAuthenticationFilter;
import com.katasticho.erp.auth.filter.JwtAuthenticationFilter;
import com.katasticho.erp.common.idempotency.IdempotencyFilter;
import com.katasticho.erp.platform.filter.PlatformAdminJwtFilter;
import com.katasticho.erp.portal.filter.PortalAuthenticationFilter;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.security.web.header.writers.ReferrerPolicyHeaderWriter;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

import java.util.List;

@Configuration
@EnableWebSecurity
@EnableMethodSecurity
@RequiredArgsConstructor
public class SecurityConfig {

    private final JwtAuthenticationFilter jwtAuthenticationFilter;
    private final ApiKeyAuthenticationFilter apiKeyAuthenticationFilter;
    private final PlatformAdminJwtFilter platformAdminJwtFilter;
    private final IdempotencyFilter idempotencyFilter;
    private final PortalAuthenticationFilter portalAuthenticationFilter;

    @Value("${app.cors.allowed-origins:*}")
    private List<String> allowedOrigins;

    @Value("${app.cors.dev-mode:true}")
    private boolean devMode;

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
                .cors(cors -> cors.configurationSource(corsConfigurationSource()))
                .csrf(csrf -> csrf.disable())
                .headers(headers -> headers
                        .contentSecurityPolicy(csp -> csp.policyDirectives("default-src 'self'"))
                        .referrerPolicy(referrer -> referrer.policy(ReferrerPolicyHeaderWriter.ReferrerPolicy.NO_REFERRER))
                        .frameOptions(frame -> frame.deny())
                )
                .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .authorizeHttpRequests(auth -> auth
                        .requestMatchers(
                                "/api/v1/auth/**",
                                "/api/v1/portal/auth/**",
                                // Courier webhooks authenticate by a per-org token in the URL path.
                                "/api/v1/courier/webhooks/**",
                                // Razorpay payment webhooks: per-org path token + HMAC signature.
                                "/api/v1/webhooks/razorpay/**",
                                "/api/v1/health",
                                "/api/platform-admin/v1/auth/login",
                                "/actuator/health",
                                "/actuator/info",
                                "/v3/api-docs/**",
                                "/swagger-ui/**",
                                "/swagger-ui.html"
                        ).permitAll()
                        .anyRequest().authenticated()
                )
                .exceptionHandling(ex -> ex
                        .authenticationEntryPoint((request, response, authException) -> {
                            response.setStatus(401);
                            response.setContentType("application/json");
                            response.getWriter().write("{\"error\":\"UNAUTHORIZED\",\"message\":\"Authentication required\"}");
                        })
                )
                .addFilterBefore(platformAdminJwtFilter, UsernamePasswordAuthenticationFilter.class)
                // JWT filter must be registered before anything can anchor to it.
                .addFilterBefore(jwtAuthenticationFilter, UsernamePasswordAuthenticationFilter.class)
                // API-key filter runs before JWT: it authenticates X-API-Key / Bearer kat_…
                // requests; everything else falls through to the JWT filter untouched.
                .addFilterBefore(apiKeyAuthenticationFilter, JwtAuthenticationFilter.class)
                // Portal filter authenticates external customers/vendors on /api/v1/portal/**
                // (it self-skips all other paths, including /api/v1/portal/auth/**).
                .addFilterBefore(portalAuthenticationFilter, JwtAuthenticationFilter.class)
                // Idempotency runs after the auth filters (needs TenantContext org):
                // sits between the JWT filter and UsernamePasswordAuthenticationFilter.
                // Commands with an Idempotency-Key header are replayed on retry.
                .addFilterBefore(idempotencyFilter, UsernamePasswordAuthenticationFilter.class);

        return http.build();
    }

    @Bean
    public CorsConfigurationSource corsConfigurationSource() {
        CorsConfiguration config = new CorsConfiguration();
        if (devMode) {
            // Allow all origins in dev — Flutter web uses a random port
            config.setAllowedOriginPatterns(List.of("*"));
        } else {
            config.setAllowedOriginPatterns(allowedOrigins);
        }
        config.setAllowedMethods(List.of("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"));
        config.setAllowedHeaders(List.of("*"));
        config.setAllowCredentials(true);
        config.setMaxAge(3600L);

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", config);
        return source;
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }
}
