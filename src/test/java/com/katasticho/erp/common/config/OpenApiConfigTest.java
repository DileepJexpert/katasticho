package com.katasticho.erp.common.config;

import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.Operation;
import io.swagger.v3.oas.models.security.SecurityRequirement;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springdoc.core.customizers.OperationCustomizer;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.method.HandlerMethod;

import java.lang.reflect.Method;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

class OpenApiConfigTest {

    private OpenApiConfig config;
    private OperationCustomizer customizer;

    @BeforeEach
    void setUp() {
        config = new OpenApiConfig();
        customizer = config.operationSecurityCustomizer();
    }

    @Test
    void testOpenApiMetadataAndSecuritySchemes() {
        OpenAPI openAPI = config.katastichoOpenAPI();

        assertThat(openAPI.getInfo().getTitle()).isEqualTo("Katasticho ERP API");
        assertThat(openAPI.getComponents().getSecuritySchemes()).containsKeys("BearerAuth", "OrgId", "PortalToken");
        assertThat(openAPI.getComponents().getSecuritySchemes().get("BearerAuth").getType()).isEqualTo(io.swagger.v3.oas.models.security.SecurityScheme.Type.HTTP);
        assertThat(openAPI.getComponents().getSecuritySchemes().get("OrgId").getType()).isEqualTo(io.swagger.v3.oas.models.security.SecurityScheme.Type.APIKEY);
        assertThat(openAPI.getComponents().getSecuritySchemes().get("PortalToken").getType()).isEqualTo(io.swagger.v3.oas.models.security.SecurityScheme.Type.HTTP);
    }

    @Test
    void testPublicAuthLoginHasNoSecurity() throws Exception {
        HandlerMethod handlerMethod = createHandlerMethod(SampleAuthController.class, "login");
        Operation op = new Operation();

        Operation result = customizer.customize(op, handlerMethod);

        assertThat(result.getSecurity()).isNullOrEmpty();
    }

    @Test
    void testProtectedAuthMeHasBearerAndOrgId() throws Exception {
        HandlerMethod handlerMethod = createHandlerMethod(SampleAuthController.class, "me");
        Operation op = new Operation();

        Operation result = customizer.customize(op, handlerMethod);

        assertThat(result.getSecurity()).isNotNull().hasSize(1);
        SecurityRequirement sec = result.getSecurity().get(0);
        assertThat(sec).containsKey("BearerAuth").containsKey("OrgId");
    }

    @Test
    void testProtectedErpEndpointHasBearerAndOrgId() throws Exception {
        HandlerMethod handlerMethod = createHandlerMethod(SampleSalesOrderController.class, "list");
        Operation op = new Operation();

        Operation result = customizer.customize(op, handlerMethod);

        assertThat(result.getSecurity()).isNotNull().hasSize(1);
        SecurityRequirement sec = result.getSecurity().get(0);
        assertThat(sec).containsKey("BearerAuth").containsKey("OrgId");
    }

    @Test
    void testPortalEndpointHasPortalTokenOnly() throws Exception {
        HandlerMethod handlerMethod = createHandlerMethod(SamplePortalController.class, "orders");
        Operation op = new Operation();

        Operation result = customizer.customize(op, handlerMethod);

        assertThat(result.getSecurity()).isNotNull().hasSize(1);
        SecurityRequirement sec = result.getSecurity().get(0);
        assertThat(sec).containsKey("PortalToken");
        assertThat(sec).doesNotContainKey("OrgId");
    }

    @Test
    void testPortalPublicAuthHasNoSecurity() throws Exception {
        HandlerMethod handlerMethod = createHandlerMethod(SamplePortalAuthController.class, "login");
        Operation op = new Operation();

        Operation result = customizer.customize(op, handlerMethod);

        assertThat(result.getSecurity()).isNullOrEmpty();
    }

    @Test
    void testWebhookHasNoSecurity() throws Exception {
        HandlerMethod handlerMethod = createHandlerMethod(SampleWebhookController.class, "handleWebhook");
        Operation op = new Operation();

        Operation result = customizer.customize(op, handlerMethod);

        assertThat(result.getSecurity()).isNullOrEmpty();
    }

    @Test
    void testHealthEndpointHasNoSecurity() throws Exception {
        HandlerMethod handlerMethod = createHandlerMethod(SampleHealthController.class, "health");
        Operation op = new Operation();

        Operation result = customizer.customize(op, handlerMethod);

        assertThat(result.getSecurity()).isNullOrEmpty();
    }

    @Test
    void testPlatformAdminEndpointHasBearerAuthOnly() throws Exception {
        HandlerMethod handlerMethod = createHandlerMethod(SamplePlatformAdminController.class, "tenants");
        Operation op = new Operation();

        Operation result = customizer.customize(op, handlerMethod);

        assertThat(result.getSecurity()).isNotNull().hasSize(1);
        SecurityRequirement sec = result.getSecurity().get(0);
        assertThat(sec).containsKey("BearerAuth");
        assertThat(sec).doesNotContainKey("OrgId");
    }

    private HandlerMethod createHandlerMethod(Class<?> beanType, String methodName) throws Exception {
        Object bean = beanType.getDeclaredConstructor().newInstance();
        Method method = beanType.getMethod(methodName);
        return new HandlerMethod(bean, method);
    }

    // Dummy controllers for testing
    @RestController
    @RequestMapping("/api/v1/auth")
    static class SampleAuthController {
        @PostMapping("/login")
        public void login() {}

        @GetMapping("/me")
        @PreAuthorize("isAuthenticated()")
        public void me() {}
    }

    @RestController
    @RequestMapping("/api/v1/sales-orders")
    static class SampleSalesOrderController {
        @GetMapping
        public void list() {}
    }

    @RestController
    @RequestMapping("/api/v1/portal/orders")
    static class SamplePortalController {
        @GetMapping
        public void orders() {}
    }

    @RestController
    @RequestMapping("/api/v1/portal/auth")
    static class SamplePortalAuthController {
        @PostMapping("/login")
        public void login() {}
    }

    @RestController
    @RequestMapping("/api/v1/webhooks/razorpay")
    static class SampleWebhookController {
        @PostMapping("/{orgSlug}")
        public void handleWebhook() {}
    }

    @RestController
    @RequestMapping("/api/v1")
    static class SampleHealthController {
        @GetMapping("/health")
        public void health() {}
    }

    @RestController
    @RequestMapping("/api/platform-admin/v1")
    static class SamplePlatformAdminController {
        @GetMapping("/tenants")
        public void tenants() {}
    }
}
