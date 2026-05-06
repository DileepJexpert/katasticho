package com.katasticho.erp.admin.backup;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.katasticho.erp.audit.AuditService;
import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Instant;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.zip.ZipEntry;
import java.util.zip.ZipOutputStream;

@Service
@RequiredArgsConstructor
public class OrgBackupService {

    private static final DateTimeFormatter FILE_TS =
            DateTimeFormatter.ofPattern("yyyyMMdd-HHmmss").withZone(ZoneId.of("UTC"));

    private final JdbcTemplate jdbcTemplate;
    private final ObjectMapper objectMapper;
    private final AuditService auditService;

    public OrgBackupFile createCurrentOrgBackup() {
        UUID orgId = TenantContext.getCurrentOrgId();
        UUID userId = TenantContext.getCurrentUserId();
        if (orgId == null || userId == null) {
            throw new BusinessException("Authenticated organisation context is required",
                    "BACKUP_NO_TENANT", HttpStatus.UNAUTHORIZED);
        }

        List<TableRef> tables = loadTables();
        Map<String, List<ForeignKeyRef>> foreignKeysByChild = loadForeignKeys();
        Map<String, String> scopeSqlCache = new HashMap<>();
        List<TableExport> exports = new ArrayList<>();
        List<String> skipped = new ArrayList<>();

        for (TableRef table : tables) {
            String scopeSql = buildScopeSql(table, tables, foreignKeysByChild, scopeSqlCache, new HashSet<>());
            if (scopeSql == null) {
                skipped.add(table.name());
                continue;
            }

            List<String> rows = jdbcTemplate.queryForList(
                    "select to_jsonb(t)::text from " + table.quoted() + " t where " + scopeSql + " order by 1",
                    String.class,
                    queryArgs(orgId, scopeSql));
            exports.add(new TableExport(table.name(), rows));
        }

        exports.sort(Comparator.comparing(TableExport::tableName));
        String fileName = "katasticho-org-" + orgId + "-" + FILE_TS.format(Instant.now()) + ".zip";
        byte[] zip = writeZip(orgId, userId, exports, skipped);
        String checksum = sha256(zip);

        auditService.logSync(orgId, userId, "ORG_BACKUP", orgId, "EXPORT", null,
                "{\"fileName\":\"" + fileName + "\",\"checksum\":\"" + checksum + "\"}");

        return new OrgBackupFile(fileName, zip, checksum);
    }

    private byte[] writeZip(UUID orgId, UUID userId, List<TableExport> exports, List<String> skipped) {
        try {
            ByteArrayOutputStream out = new ByteArrayOutputStream();
            try (ZipOutputStream zip = new ZipOutputStream(out, StandardCharsets.UTF_8)) {
                Map<String, Object> manifest = new LinkedHashMap<>();
                manifest.put("format", "katasticho-org-backup-v1");
                manifest.put("createdAt", Instant.now().toString());
                manifest.put("orgId", orgId.toString());
                manifest.put("createdBy", userId.toString());
                manifest.put("scope", "ACTIVE_ORGANISATION_ONLY");
                manifest.put("restoreMode", "CONTROLLED_IMPORT_REQUIRED");
                manifest.put("tableCounts", exports.stream()
                        .collect(LinkedHashMap::new,
                                (m, e) -> m.put(e.tableName(), e.rows().size()),
                                LinkedHashMap::putAll));
                manifest.put("skippedTables", skipped);
                writeJson(zip, "manifest.json", manifest);

                for (TableExport export : exports) {
                    List<Object> parsedRows = new ArrayList<>();
                    for (String row : export.rows()) {
                        parsedRows.add(objectMapper.readValue(row, Object.class));
                    }
                    writeJson(zip, "data/" + export.tableName() + ".json", parsedRows);
                }
            }
            return out.toByteArray();
        } catch (IOException e) {
            throw new BusinessException("Could not create organisation backup",
                    "BACKUP_EXPORT_FAILED", HttpStatus.INTERNAL_SERVER_ERROR);
        }
    }

    private void writeJson(ZipOutputStream zip, String path, Object value) throws IOException {
        zip.putNextEntry(new ZipEntry(path));
        objectMapper.writerWithDefaultPrettyPrinter().writeValue(zip, value);
        zip.closeEntry();
    }

    private String buildScopeSql(TableRef table,
                                 List<TableRef> tables,
                                 Map<String, List<ForeignKeyRef>> foreignKeysByChild,
                                 Map<String, String> cache,
                                 Set<String> visiting) {
        if (cache.containsKey(table.name())) return cache.get(table.name());
        if (!visiting.add(table.name())) return null;

        if ("organisation".equals(table.name())) {
            String sql = "t.id = ?";
            cache.put(table.name(), sql);
            visiting.remove(table.name());
            return sql;
        }

        if (table.hasOrgId()) {
            String sql = "t.org_id = ?";
            cache.put(table.name(), sql);
            visiting.remove(table.name());
            return sql;
        }

        for (ForeignKeyRef fk : foreignKeysByChild.getOrDefault(table.name(), List.of())) {
            TableRef parent = tables.stream()
                    .filter(candidate -> candidate.name().equals(fk.parentTable()))
                    .findFirst()
                    .orElse(null);
            if (parent == null) continue;

            String parentScope = buildParentScopeSql(parent, tables, foreignKeysByChild, cache, visiting, "p");
            if (parentScope == null) continue;

            String sql = "exists (select 1 from " + parent.quoted() + " p where t." +
                    quote(fk.childColumn()) + " = p." + quote(fk.parentColumn()) + " and " + parentScope + ")";
            cache.put(table.name(), sql);
            visiting.remove(table.name());
            return sql;
        }

        visiting.remove(table.name());
        return null;
    }

    private String buildParentScopeSql(TableRef parent,
                                       List<TableRef> tables,
                                       Map<String, List<ForeignKeyRef>> foreignKeysByChild,
                                       Map<String, String> cache,
                                       Set<String> visiting,
                                       String alias) {
        if ("organisation".equals(parent.name())) {
            return alias + ".id = ?";
        }
        if (parent.hasOrgId()) {
            return alias + ".org_id = ?";
        }

        for (ForeignKeyRef fk : foreignKeysByChild.getOrDefault(parent.name(), List.of())) {
            TableRef grandParent = tables.stream()
                    .filter(candidate -> candidate.name().equals(fk.parentTable()))
                    .findFirst()
                    .orElse(null);
            if (grandParent == null || visiting.contains(grandParent.name())) continue;
            visiting.add(grandParent.name());
            String grandScope = buildParentScopeSql(grandParent, tables, foreignKeysByChild, cache, visiting, "gp");
            visiting.remove(grandParent.name());
            if (grandScope == null) continue;
            return "exists (select 1 from " + grandParent.quoted() + " gp where " + alias + "." +
                    quote(fk.childColumn()) + " = gp." + quote(fk.parentColumn()) + " and " + grandScope + ")";
        }
        return null;
    }

    private List<TableRef> loadTables() {
        return jdbcTemplate.query("""
                select c.table_name,
                       bool_or(c.column_name = 'org_id') as has_org_id
                from information_schema.columns c
                join information_schema.tables t
                  on t.table_schema = c.table_schema
                 and t.table_name = c.table_name
                where c.table_schema = 'public'
                  and t.table_type = 'BASE TABLE'
                group by c.table_name
                order by c.table_name
                """, (rs, rowNum) -> new TableRef(rs.getString("table_name"), rs.getBoolean("has_org_id")));
    }

    private Map<String, List<ForeignKeyRef>> loadForeignKeys() {
        List<ForeignKeyRef> refs = jdbcTemplate.query("""
                select tc.table_name as child_table,
                       kcu.column_name as child_column,
                       ccu.table_name as parent_table,
                       ccu.column_name as parent_column
                from information_schema.table_constraints tc
                join information_schema.key_column_usage kcu
                  on tc.constraint_name = kcu.constraint_name
                 and tc.table_schema = kcu.table_schema
                join information_schema.constraint_column_usage ccu
                  on ccu.constraint_name = tc.constraint_name
                 and ccu.table_schema = tc.table_schema
                where tc.constraint_type = 'FOREIGN KEY'
                  and tc.table_schema = 'public'
                order by tc.table_name, kcu.column_name
                """, (rs, rowNum) -> new ForeignKeyRef(
                rs.getString("child_table"),
                rs.getString("child_column"),
                rs.getString("parent_table"),
                rs.getString("parent_column")));

        Map<String, List<ForeignKeyRef>> byChild = new HashMap<>();
        for (ForeignKeyRef ref : refs) {
            byChild.computeIfAbsent(ref.childTable(), ignored -> new ArrayList<>()).add(ref);
        }
        return byChild;
    }

    private String sha256(byte[] bytes) {
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256").digest(bytes);
            StringBuilder out = new StringBuilder(digest.length * 2);
            for (byte b : digest) {
                out.append(String.format("%02x", b));
            }
            return out.toString();
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 not available", e);
        }
    }

    private Object[] queryArgs(UUID orgId, String sql) {
        int count = 0;
        for (int i = 0; i < sql.length(); i++) {
            if (sql.charAt(i) == '?') count++;
        }
        Object[] args = new Object[count];
        for (int i = 0; i < count; i++) {
            args[i] = orgId;
        }
        return args;
    }

    private String quote(String identifier) {
        return "\"" + identifier.replace("\"", "\"\"") + "\"";
    }

    public record OrgBackupFile(String fileName, byte[] bytes, String checksum) {}

    private record TableRef(String name, boolean hasOrgId) {
        String quoted() {
            return "public.\"" + name.replace("\"", "\"\"") + "\"";
        }
    }

    private record ForeignKeyRef(String childTable, String childColumn, String parentTable, String parentColumn) {}

    private record TableExport(String tableName, List<String> rows) {}
}
