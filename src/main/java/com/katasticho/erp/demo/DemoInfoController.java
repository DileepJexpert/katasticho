package com.katasticho.erp.demo;

import com.katasticho.erp.common.dto.ApiResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/**
 * Public read-only endpoint that surfaces the demo login credentials to the
 * Flutter login screen, so the demo-er sees a "Demo credentials" card with
 * one-tap fill instead of having to dig the phone numbers out of a doc.
 *
 * <p>Path lives under {@code /api/v1/auth/**} so it inherits the existing
 * {@code permitAll()} rule in {@code SecurityConfig} — no auth required.
 *
 * <p>When demo mode is OFF (the default), the response carries
 * {@code enabled: false} and an empty user list — the Flutter card hides
 * itself in that case.
 */
@RestController
@RequestMapping("/api/v1/auth")
@EnableConfigurationProperties(DemoSeederProperties.class)
@RequiredArgsConstructor
public class DemoInfoController {

    private final DemoSeederProperties props;

    @GetMapping("/demo-info")
    public ApiResponse<DemoInfo> info() {
        if (!props.enabled()) {
            return ApiResponse.ok(new DemoInfo(false, props.orgName(), List.of()));
        }
        List<DemoLogin> logins = props.users().stream()
                .map(spec -> new DemoLogin(
                        spec.phone(),
                        spec.fullName(),
                        spec.role(),
                        props.sharedPassword()))
                .toList();
        return ApiResponse.ok(new DemoInfo(true, props.orgName(), logins));
    }

    public record DemoInfo(boolean enabled, String orgName, List<DemoLogin> users) {}

    public record DemoLogin(String phone, String fullName, String role, String password) {}
}
