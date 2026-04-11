package com.katasticho.erp;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.autoconfigure.security.servlet.UserDetailsServiceAutoConfiguration;
import org.springframework.cache.annotation.EnableCaching;
import org.springframework.scheduling.annotation.EnableAsync;

@SpringBootApplication(exclude = UserDetailsServiceAutoConfiguration.class)
@EnableCaching
@EnableAsync
public class KatastichoErpApplication {

    public static void main(String[] args) {
        SpringApplication.run(KatastichoErpApplication.class, args);
    }
}
