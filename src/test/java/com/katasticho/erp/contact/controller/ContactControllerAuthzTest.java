package com.katasticho.erp.contact.controller;

import org.junit.jupiter.api.Test;
import org.springframework.security.access.prepost.PreAuthorize;

import java.lang.reflect.Method;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Structural guard: contact WRITE endpoints must carry a role gate that excludes
 * VIEWER. Regression for the audit finding that create/update/delete had no
 * {@code @PreAuthorize}, so any authenticated role (including VIEWER) could
 * create, edit or delete contacts via the API.
 *
 * <p>{@code @PreAuthorize} is enforced by Spring's method-security interceptor at
 * runtime; this test asserts the annotation is present and correctly scoped
 * without standing up a full security context.
 */
class ContactControllerAuthzTest {

    private String preAuthorize(String method, Class<?>... params) throws NoSuchMethodException {
        Method m = ContactController.class.getMethod(method, params);
        PreAuthorize pa = m.getAnnotation(PreAuthorize.class);
        assertNotNull(pa, method + " must carry a @PreAuthorize role gate");
        return pa.value();
    }

    @Test
    void writeEndpoints_excludeViewer() throws NoSuchMethodException {
        // create / update / addPerson / deletePerson — OPERATOR keeps counter access,
        // VIEWER is blocked.
        for (String[] sig : new String[][]{
                {"create", "com.katasticho.erp.contact.dto.CreateContactRequest"},
                {"update", "java.util.UUID", "com.katasticho.erp.contact.dto.CreateContactRequest"},
                {"addPerson", "java.util.UUID", "com.katasticho.erp.contact.dto.ContactPersonRequest"},
                {"deletePerson", "java.util.UUID", "java.util.UUID"},
                {"delete", "java.util.UUID"}}) {
            Class<?>[] params = new Class<?>[sig.length - 1];
            for (int i = 1; i < sig.length; i++) params[i - 1] = classFor(sig[i]);
            String expr = preAuthorize(sig[0], params);
            assertFalse(expr.contains("VIEWER"),
                    sig[0] + " must not grant VIEWER: " + expr);
            assertTrue(expr.contains("OWNER") && expr.contains("ADMIN"),
                    sig[0] + " must grant OWNER/ADMIN: " + expr);
        }
    }

    @Test
    void deleteIsStricterThanCreate() throws NoSuchMethodException {
        // delete excludes OPERATOR (destructive); create allows OPERATOR (counter).
        assertFalse(preAuthorize("delete", java.util.UUID.class).contains("OPERATOR"));
        assertTrue(preAuthorize("create", classFor("com.katasticho.erp.contact.dto.CreateContactRequest"))
                .contains("OPERATOR"));
    }

    private static Class<?> classFor(String name) {
        try {
            return Class.forName(name);
        } catch (ClassNotFoundException e) {
            throw new AssertionError("Unknown param type " + name, e);
        }
    }
}
