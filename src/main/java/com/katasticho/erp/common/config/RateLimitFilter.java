package com.katasticho.erp.common.config;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.dto.ApiResponse;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.time.Clock;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;

@Component
@Order(Ordered.HIGHEST_PRECEDENCE + 20)
@RequiredArgsConstructor
public class RateLimitFilter extends OncePerRequestFilter {

    private final ObjectMapper objectMapper;
    private final Clock clock = Clock.systemUTC();
    private final Map<String, Window> windows = new ConcurrentHashMap<>();

    @Value("${app.rate-limit.requests-per-minute:1000}")
    private int requestsPerMinute;

    @Value("${app.rate-limit.auth-requests-per-minute:20}")
    private int authRequestsPerMinute;

    @Value("${app.rate-limit.ai-requests-per-minute:10}")
    private int aiRequestsPerMinute;

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response,
                                    FilterChain filterChain) throws ServletException, IOException {
        String path = request.getServletPath();
        if (path.startsWith("/actuator/") || "OPTIONS".equalsIgnoreCase(request.getMethod())) {
            filterChain.doFilter(request, response);
            return;
        }

        int limit = limitFor(path);
        String key = keyFor(request, path);

        if (!allow(key, limit)) {
            response.setStatus(HttpStatus.TOO_MANY_REQUESTS.value());
            response.setContentType(MediaType.APPLICATION_JSON_VALUE);
            response.setHeader("Retry-After", "60");
            objectMapper.writeValue(response.getWriter(),
                    ApiResponse.error("Too many requests. Please try again shortly.",
                            List.of("RATE_LIMIT_EXCEEDED")));
            return;
        }

        filterChain.doFilter(request, response);
    }

    private int limitFor(String path) {
        if (path.startsWith("/api/v1/auth/")) return authRequestsPerMinute;
        if (path.startsWith("/api/v1/ai/")) return aiRequestsPerMinute;
        return requestsPerMinute;
    }

    private String keyFor(HttpServletRequest request, String path) {
        String principal = currentPrincipal();
        if (principal == null) {
            principal = clientIp(request);
        }
        String bucket = path.startsWith("/api/v1/auth/")
                ? "auth"
                : path.startsWith("/api/v1/ai/") ? "ai" : "api";
        return bucket + ":" + principal;
    }

    private String currentPrincipal() {
        UUID orgId = TenantContext.getCurrentOrgId();
        UUID userId = TenantContext.getCurrentUserId();
        if (orgId == null || userId == null) return null;
        return orgId + ":" + userId;
    }

    private String clientIp(HttpServletRequest request) {
        String forwarded = request.getHeader("X-Forwarded-For");
        if (forwarded != null && !forwarded.isBlank()) {
            return forwarded.split(",")[0].trim();
        }
        return request.getRemoteAddr();
    }

    private boolean allow(String key, int limit) {
        long currentMinute = clock.millis() / 60000L;
        Window window = windows.compute(key, (ignored, existing) -> {
            if (existing == null || existing.minute != currentMinute) {
                return new Window(currentMinute);
            }
            return existing;
        });

        cleanup(currentMinute);
        return window.count.incrementAndGet() <= limit;
    }

    private void cleanup(long currentMinute) {
        if (windows.size() < 10_000) return;
        windows.entrySet().removeIf(entry -> entry.getValue().minute < currentMinute);
    }

    private static final class Window {
        private final long minute;
        private final AtomicInteger count = new AtomicInteger();

        private Window(long minute) {
            this.minute = minute;
        }
    }
}
