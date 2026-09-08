package com.katasticho.erp.common.config;

import io.swagger.v3.oas.models.Components;
import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Contact;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.security.SecurityScheme;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

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
                        .addSecuritySchemes("OrgId", new SecurityScheme()
                                .name("X-Org-Id")
                                .type(SecurityScheme.Type.APIKEY)
                                .in(SecurityScheme.In.HEADER)
                                .description("Organization UUID tenant header")));
    }
}
