package com.katasticho.erp.courier.service;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class CourierStatusMapperTest {

    @Test
    void mapsCommonShiprocketVocabulary() {
        assertThat(CourierStatusMapper.toCanonical("Delivered")).isEqualTo("DELIVERED");
        assertThat(CourierStatusMapper.toCanonical("Out For Delivery")).isEqualTo("OUT_FOR_DELIVERY");
        assertThat(CourierStatusMapper.toCanonical("In Transit")).isEqualTo("IN_TRANSIT");
        assertThat(CourierStatusMapper.toCanonical("Shipped")).isEqualTo("IN_TRANSIT");
        assertThat(CourierStatusMapper.toCanonical("Picked Up")).isEqualTo("PICKED_UP");
        assertThat(CourierStatusMapper.toCanonical("PICKUP DONE")).isEqualTo("PICKED_UP");
        assertThat(CourierStatusMapper.toCanonical("Undelivered")).isEqualTo("EXCEPTION");
        assertThat(CourierStatusMapper.toCanonical("Delivery Attempted")).isEqualTo("EXCEPTION");
    }

    @Test
    void rtoCheckedBeforeDeliveredAndTransit() {
        assertThat(CourierStatusMapper.toCanonical("RTO Delivered")).isEqualTo("RTO_DELIVERED");
        assertThat(CourierStatusMapper.toCanonical("RTO Initiated")).isEqualTo("RTO_INITIATED");
        assertThat(CourierStatusMapper.toCanonical("RTO In Transit")).isEqualTo("RTO_INITIATED");
    }

    @Test
    void ignoredOrUnknownStatusesReturnNull() {
        assertThat(CourierStatusMapper.toCanonical("New")).isNull();
        assertThat(CourierStatusMapper.toCanonical("Pickup Scheduled")).isNull();
        assertThat(CourierStatusMapper.toCanonical("Cancelled")).isNull();
        assertThat(CourierStatusMapper.toCanonical(null)).isNull();
        assertThat(CourierStatusMapper.toCanonical("   ")).isNull();
    }

    @Test
    void caseAndSeparatorInsensitive() {
        assertThat(CourierStatusMapper.toCanonical("out-for-delivery")).isEqualTo("OUT_FOR_DELIVERY");
        assertThat(CourierStatusMapper.toCanonical("IN_TRANSIT")).isEqualTo("IN_TRANSIT");
    }
}
