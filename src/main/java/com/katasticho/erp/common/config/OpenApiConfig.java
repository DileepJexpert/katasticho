package com.katasticho.erp.common.config;

import io.swagger.v3.oas.models.Components;
import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.Operation;
import io.swagger.v3.oas.models.info.Contact;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.security.SecurityRequirement;
import io.swagger.v3.oas.models.security.SecurityScheme;
import org.springdoc.core.customizers.OperationCustomizer;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.annotation.AnnotatedElementUtils;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.method.HandlerMethod;

import java.util.ArrayList;

@Configuration
public class OpenApiConfig {

    @Bean
    public OpenAPI katastichoOpenAPI() {
        return new OpenAPI()
                .info(new Info()
                        .title("Katasticho ERP API")
                        .version("1.0.0")
                        .description("AI-Powered Cloud ERP System for SMEs")
                        .contact(new Contact().name("Katasticho ERP Support").email("support@katasticho.com")))
                .components(new Components()
                        .addSecuritySchemes("BearerAuth", new SecurityScheme()
                                .name("Authorization")
                                .type(SecurityScheme.Type.HTTP)
                                .scheme("bearer")
                                .bearerFormat("JWT")
                                .description("Enter JWT Bearer token"))
                        .addSecuritySchemes("ApiKeyAuth", new SecurityScheme()
                                .name("X-API-Key")
                                .type(SecurityScheme.Type.APIKEY)
                                .in(SecurityScheme.In.HEADER)
                                .description("Organization API key header (X-API-Key)"))
                        .addSecuritySchemes("PortalToken", new SecurityScheme()
                                .name("Authorization")
                                .type(SecurityScheme.Type.HTTP)
                                .scheme("bearer")
                                .bearerFormat("JWT")
                                .description("Enter Portal JWT Bearer token")));
    }

    @Bean
    public OperationCustomizer operationSecurityCustomizer() {
        return (operation, handlerMethod) -> {
            String path = resolvePath(handlerMethod);
            if (isPublicEndpoint(path, handlerMethod)) {
                if (operation.getSecurity() != null) {
                    operation.getSecurity().clear();
                }
                return operation;
            }

            if (operation.getSecurity() == null) {
                operation.setSecurity(new ArrayList<>());
            }

            if (isPortalEndpoint(path)) {
                operation.addSecurityItem(new SecurityRequirement().addList("PortalToken"));
            } else if (isPlatformAdminEndpoint(path)) {
                operation.addSecurityItem(new SecurityRequirement().addList("BearerAuth"));
            } else {
                operation.addSecurityItem(new SecurityRequirement().addList("BearerAuth"));
                operation.addSecurityItem(new SecurityRequirement().addList("ApiKeyAuth"));
            }
            return operation;
        };
    }

    String resolvePath(HandlerMethod handlerMethod) {
        if (handlerMethod == null) {
            return "";
        }
        Class<?> beanType = handlerMethod.getBeanType();
        if (beanType == null || beanType.equals(Class.class) || beanType.equals(Object.class)) {
            if (handlerMethod.getBean() instanceof Class<?> clazz) {
                beanType = clazz;
            } else if (handlerMethod.getMethod() != null) {
                beanType = handlerMethod.getMethod().getDeclaringClass();
            }
        }

        String classPath = "";
        RequestMapping classMapping = AnnotatedElementUtils.findMergedAnnotation(
                beanType, RequestMapping.class);
        if (classMapping != null) {
            if (classMapping.value().length > 0) {
                classPath = classMapping.value()[0];
            } else if (classMapping.path().length > 0) {
                classPath = classMapping.path()[0];
            }
        }

        String methodPath = "";
        RequestMapping methodMapping = AnnotatedElementUtils.findMergedAnnotation(
                handlerMethod.getMethod(), RequestMapping.class);
        if (methodMapping != null) {
            if (methodMapping.value().length > 0) {
                methodPath = methodMapping.value()[0];
            } else if (methodMapping.path().length > 0) {
                methodPath = methodMapping.path()[0];
            }
        }

        String combined;
        if (classPath.isEmpty()) {
            combined = methodPath;
        } else if (methodPath.isEmpty()) {
            combined = classPath;
        } else {
            String p1 = classPath.endsWith("/") ? classPath.substring(0, classPath.length() - 1) : classPath;
            String p2 = methodPath.startsWith("/") ? methodPath : "/" + methodPath;
            combined = p1 + p2;
        }

        if (!combined.startsWith("/") && !combined.isEmpty()) {
            combined = "/" + combined;
        }
        return combined;
    }

    private boolean isPublicEndpoint(String path, HandlerMethod handlerMethod) {
        if (path.equals("/api/v1/auth") || path.startsWith("/api/v1/auth/")) {
            if (path.equals("/api/v1/auth/me")
                    || path.equals("/api/v1/auth/change-password")
                    || (path.startsWith("/api/v1/auth/invite") && !path.equals("/api/v1/auth/invite/accept"))) {
                return false;
            }
            if (handlerMethod != null && AnnotatedElementUtils.hasAnnotation(handlerMethod.getMethod(), PreAuthorize.class)) {
                return false;
            }
            return true;
        }
        if (path.equals("/api/v1/portal/auth") || path.startsWith("/api/v1/portal/auth/")) {
            return true;
        }
        if (path.equals("/api/v1/courier/webhooks") || path.startsWith("/api/v1/courier/webhooks/")
                || path.equals("/api/v1/webhooks/razorpay") || path.startsWith("/api/v1/webhooks/razorpay/")
                || path.equals("/api/v1/whatsapp/webhook") || path.startsWith("/api/v1/whatsapp/webhook/")
                || path.equals("/api/v1/biometric/adms") || path.startsWith("/api/v1/biometric/adms/")
                || path.equals("/api/v1/health")
                || path.equals("/actuator") || path.startsWith("/actuator/")
                || path.equals("/api/platform-admin/v1/auth/login")
                || path.equals("/v3/api-docs") || path.startsWith("/v3/api-docs/")
                || path.equals("/swagger-ui") || path.startsWith("/swagger-ui/")) {
            return true;
        }
        return false;
    }

    private boolean isPortalEndpoint(String path) {
        return path.equals("/api/v1/portal") || path.startsWith("/api/v1/portal/");
    }

    private boolean isPlatformAdminEndpoint(String path) {
        return path.equals("/api/platform-admin") || path.startsWith("/api/platform-admin/");
    }
}
