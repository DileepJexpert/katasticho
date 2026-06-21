package com.katasticho.erp.demo;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

class DemoInfoControllerTest {

    @Test
    void returns_empty_user_list_when_demo_mode_is_off() {
        DemoSeederProperties props = new DemoSeederProperties(false, null, null, null, null, null);
        DemoInfoController.DemoInfo info = new DemoInfoController(props).info().data();
        assertNotNull(info);
        assertFalse(info.enabled());
        assertTrue(info.users().isEmpty());
        // Org name still surfaced so the Flutter card can hint "Demo Distributor (disabled)".
        assertEquals("Demo Distributor", info.orgName());
    }

    @Test
    void exposes_all_eight_demo_logins_with_shared_password_when_demo_mode_is_on() {
        DemoSeederProperties props = new DemoSeederProperties(true, null, null, null, null, null);
        DemoInfoController.DemoInfo info = new DemoInfoController(props).info().data();

        assertNotNull(info);
        assertTrue(info.enabled());
        assertEquals(8, info.users().size());
        // First entry is the owner — driving the bootstrap.
        assertEquals("9000000001", info.users().get(0).phone());
        assertEquals("OWNER", info.users().get(0).role());
        // Every login carries the shared password the seeder used to hash.
        for (DemoInfoController.DemoLogin login : info.users()) {
            assertEquals("Demo@1234", login.password());
        }
    }
}
