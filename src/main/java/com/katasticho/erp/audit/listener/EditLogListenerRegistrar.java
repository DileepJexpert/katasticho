package com.katasticho.erp.audit.listener;

import jakarta.annotation.PostConstruct;
import jakarta.persistence.EntityManagerFactory;
import lombok.RequiredArgsConstructor;
import org.hibernate.engine.spi.SessionFactoryImplementor;
import org.hibernate.event.service.spi.EventListenerRegistry;
import org.hibernate.event.spi.EventType;
import org.springframework.stereotype.Component;

/**
 * Hooks {@link EditLogHibernateListener} into the session factory's event
 * pipeline at startup. Spring Boot exposes no property for Hibernate event
 * listeners, so registration goes through the service registry directly.
 */
@Component
@RequiredArgsConstructor
public class EditLogListenerRegistrar {

    private final EntityManagerFactory entityManagerFactory;
    private final EditLogHibernateListener editLogListener;

    @PostConstruct
    public void registerListeners() {
        SessionFactoryImplementor sessionFactory =
                entityManagerFactory.unwrap(SessionFactoryImplementor.class);
        EventListenerRegistry registry = sessionFactory.getServiceRegistry()
                .requireService(EventListenerRegistry.class);
        registry.appendListeners(EventType.POST_INSERT, editLogListener);
        registry.appendListeners(EventType.POST_UPDATE, editLogListener);
        registry.appendListeners(EventType.POST_DELETE, editLogListener);
    }
}
