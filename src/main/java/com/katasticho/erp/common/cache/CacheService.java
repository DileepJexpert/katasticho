package com.katasticho.erp.common.cache;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.util.*;
import java.util.concurrent.TimeUnit;

@Service
@RequiredArgsConstructor
@Slf4j
public class CacheService {

    private final StringRedisTemplate redisTemplate;
    private final ObjectMapper objectMapper;

    private static final Duration DEFAULT_TTL = Duration.ofHours(12);
    private static final Duration SHORT_TTL = Duration.ofMinutes(30);

    public <T> void put(String key, T value, Duration ttl) {
        try {
            String json = objectMapper.writeValueAsString(value);
            redisTemplate.opsForValue().set(key, json, ttl);
            log.debug("Cache PUT key={}", key);
        } catch (Exception e) {
            log.error("Cache PUT failed key={}: {}", key, e.getMessage());
        }
    }

    public <T> void put(String key, T value) {
        put(key, value, DEFAULT_TTL);
    }

    public <T> Optional<T> get(String key, Class<T> type) {
        try {
            String json = redisTemplate.opsForValue().get(key);
            if (json == null) {
                log.debug("Cache MISS key={}", key);
                return Optional.empty();
            }
            log.debug("Cache HIT key={}", key);
            return Optional.of(objectMapper.readValue(json, type));
        } catch (Exception e) {
            log.warn("Cache GET failed key={}: {}", key, e.getMessage());
            evict(key);
            return Optional.empty();
        }
    }

    public <T> Optional<T> get(String key, TypeReference<T> typeRef) {
        try {
            String json = redisTemplate.opsForValue().get(key);
            if (json == null) {
                log.debug("Cache MISS key={}", key);
                return Optional.empty();
            }
            log.debug("Cache HIT key={}", key);
            return Optional.of(objectMapper.readValue(json, typeRef));
        } catch (Exception e) {
            log.warn("Cache GET failed key={}: {}", key, e.getMessage());
            evict(key);
            return Optional.empty();
        }
    }

    public void evict(String key) {
        try {
            redisTemplate.delete(key);
            log.debug("Cache EVICT key={}", key);
        } catch (Exception e) {
            log.warn("Cache EVICT failed key={}: {}", key, e.getMessage());
        }
    }

    public void evictPattern(String pattern) {
        try {
            Set<String> keys = redisTemplate.keys(pattern);
            if (keys != null && !keys.isEmpty()) {
                redisTemplate.delete(keys);
                log.info("Cache EVICT pattern={} count={}", pattern, keys.size());
            }
        } catch (Exception e) {
            log.warn("Cache EVICT pattern failed pattern={}: {}", pattern, e.getMessage());
        }
    }

    public void evictOrgCache(String prefix, UUID orgId) {
        evictPattern(CacheKeys.orgPattern(prefix, orgId));
    }

    public boolean exists(String key) {
        try {
            return Boolean.TRUE.equals(redisTemplate.hasKey(key));
        } catch (Exception e) {
            return false;
        }
    }

    public Map<String, Object> getStats() {
        Map<String, Object> stats = new LinkedHashMap<>();
        try {
            var info = redisTemplate.getConnectionFactory().getConnection().serverCommands().info("memory");
            if (info != null) {
                stats.put("usedMemory", info.getProperty("used_memory_human"));
                stats.put("maxMemory", info.getProperty("maxmemory_human"));
            }
            Long dbSize = redisTemplate.getConnectionFactory().getConnection().serverCommands().dbSize();
            stats.put("totalKeys", dbSize);
        } catch (Exception e) {
            stats.put("error", e.getMessage());
        }
        return stats;
    }

    public Duration getShortTtl() {
        return SHORT_TTL;
    }

    public Duration getDefaultTtl() {
        return DEFAULT_TTL;
    }
}
