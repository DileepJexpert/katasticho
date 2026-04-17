package com.katasticho.erp.common.config;

import org.flywaydb.core.Flyway;
import org.springframework.boot.autoconfigure.flyway.FlywayMigrationStrategy;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;

@Configuration
public class FlywayConfig {

    /**
     * In non-production environments, repair the schema history before migrating.
     * This handles checksum mismatches when migration files are edited during development.
     * In production, we validate strictly — never silently accept tampered migrations.
     */
    @Bean
    @Profile("!prod")
    public FlywayMigrationStrategy repairThenMigrate() {
        return flyway -> {
            flyway.repair();
            flyway.migrate();
        };
    }
}
