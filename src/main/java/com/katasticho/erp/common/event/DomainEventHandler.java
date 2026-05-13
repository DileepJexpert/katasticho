package com.katasticho.erp.common.event;

public interface DomainEventHandler {

    boolean supports(String eventType);

    void handle(DomainEvent event);
}
