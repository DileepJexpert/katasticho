package com.katasticho.erp.common.config;

import com.katasticho.erp.auth.controller.AuthController;
import com.katasticho.erp.health.HealthController;
import com.katasticho.erp.payment.controller.PaymentWebhookController;
import com.katasticho.erp.portal.controller.PortalAuthController;
import com.katasticho.erp.portal.controller.PortalSelfController;
import com.katasticho.erp.portal.controller.PortalUserAdminController;
import com.katasticho.erp.sales.controller.SalesOrderController;
import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.Operation;
import io.swagger.v3.oas.models.security.SecurityRequirement;
import io.swagger.v3.oas.models.security.SecurityScheme;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springdoc.core.customizers.OperationCustomizer;
import org.springframework.web.method.HandlerMethod;

import java.lang.reflect.Method;
import java.util.Arrays;
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
        assertThat(openAPI.getComponents().getSecuritySchemes()).containsKeys("BearerAuth", "ApiKeyAuth", "PortalToken");
        assertThat(openAPI.getComponents().getSecuritySchemes()).doesNotContainKey("OrgId");
        assertThat(openAPI.getComponents().getSecuritySchemes().get("BearerAuth").getType()).isEqualTo(SecurityScheme.Type.HTTP);
        assertThat(openAPI.getComponents().getSecuritySchemes().get("ApiKeyAuth").getType()).isEqualTo(SecurityScheme.Type.APIKEY);
        assertThat(openAPI.getComponents().getSecuritySchemes().get("PortalToken").getType()).isEqualTo(SecurityScheme.Type.HTTP);
    }

    @Test
    void testPortalUserAdminControllerIsProtectedErpEndpointNotPortalToken() {
        HandlerMethod handlerMethod = createHandlerMethod(PortalUserAdminController.class, "list");
        Operation op = new Operation();

        Operation result = customizer.customize(op, handlerMethod);

        List<SecurityRequirement> sec = result.getSecurity();
        assertThat(sec).isNotNull().hasSize(2);
        assertThat(sec.get(0)).containsKey("BearerAuth");
        assertThat(sec.get(1)).containsKey("ApiKeyAuth");
        assertThat(sec.get(0)).doesNotContainKey("PortalToken").doesNotContainKey("OrgId");
        assertThat(sec.get(1)).doesNotContainKey("PortalToken").doesNotContainKey("OrgId");
    }

    @Test
    void testPortalSelfControllerRequiresPortalToken() {
        HandlerMethod handlerMethod = createHandlerMethod(PortalSelfController.class, "me");
        Operation op = new Operation();

        Operation result = customizer.customize(op, handlerMethod);

        List<SecurityRequirement> sec = result.getSecurity();
        assertThat(sec).isNotNull().hasSize(1);
        assertThat(sec.get(0)).containsKey("PortalToken");
        assertThat(sec.get(0)).doesNotContainKey("BearerAuth").doesNotContainKey("ApiKeyAuth").doesNotContainKey("OrgId");
    }

    @Test
    void testPortalAuthControllerLoginIsPublic() {
        HandlerMethod handlerMethod = createHandlerMethod(PortalAuthController.class, "login");
        Operation op = new Operation();

        Operation result = customizer.customize(op, handlerMethod);

        assertThat(result.getSecurity()).isNullOrEmpty();
    }

    @Test
    void testAuthControllerLoginIsPublic() {
        HandlerMethod handlerMethod = createHandlerMethod(AuthController.class, "login");
        Operation op = new Operation();

        Operation result = customizer.customize(op, handlerMethod);

        assertThat(result.getSecurity()).isNullOrEmpty();
    }

    @Test
    void testAuthControllerMeIsProtectedErpEndpoint() {
        HandlerMethod handlerMethod = createHandlerMethod(AuthController.class, "me");
        Operation op = new Operation();

        Operation result = customizer.customize(op, handlerMethod);

        List<SecurityRequirement> sec = result.getSecurity();
        assertThat(sec).isNotNull().hasSize(2);
        assertThat(sec.get(0)).containsKey("BearerAuth");
        assertThat(sec.get(1)).containsKey("ApiKeyAuth");
    }

    @Test
    void testAuthControllerChangePasswordIsProtectedErpEndpoint() {
        HandlerMethod handlerMethod = createHandlerMethod(AuthController.class, "changePassword");
        Operation op = new Operation();

        Operation result = customizer.customize(op, handlerMethod);

        List<SecurityRequirement> sec = result.getSecurity();
        assertThat(sec).isNotNull().hasSize(2);
        assertThat(sec.get(0)).containsKey("BearerAuth");
        assertThat(sec.get(1)).containsKey("ApiKeyAuth");
    }

    @Test
    void testSalesOrderControllerIsProtectedErpEndpoint() {
        HandlerMethod handlerMethod = createHandlerMethod(SalesOrderController.class, "list");
        Operation op = new Operation();

        Operation result = customizer.customize(op, handlerMethod);

        List<SecurityRequirement> sec = result.getSecurity();
        assertThat(sec).isNotNull().hasSize(2);
        assertThat(sec.get(0)).containsKey("BearerAuth");
        assertThat(sec.get(1)).containsKey("ApiKeyAuth");
    }

    @Test
    void testHealthControllerIsPublic() {
        HandlerMethod handlerMethod = createHandlerMethod(HealthController.class, "health");
        Operation op = new Operation();

        Operation result = customizer.customize(op, handlerMethod);

        assertThat(result.getSecurity()).isNullOrEmpty();
    }

    @Test
    void testPaymentWebhookControllerIsPublic() {
        HandlerMethod handlerMethod = createHandlerMethod(PaymentWebhookController.class, "receive");
        Operation op = new Operation();

        Operation result = customizer.customize(op, handlerMethod);

        assertThat(result.getSecurity()).isNullOrEmpty();
    }

    private HandlerMethod createHandlerMethod(Class<?> controllerClass, String methodName) {
        Method method = Arrays.stream(controllerClass.getMethods())
                .filter(m -> m.getName().equals(methodName))
                .findFirst()
                .orElseThrow(() -> new IllegalArgumentException("Method not found: " + methodName + " on " + controllerClass.getName()));
        Object bean = Mockito.mock(controllerClass);
        return new HandlerMethod(bean, method);
    }
}
