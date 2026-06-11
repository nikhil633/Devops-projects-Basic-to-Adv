package com.yourorg.eventsourcing.kafka;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.yourorg.eventsourcing.event.DomainEvent;
import com.yourorg.eventsourcing.query.handler.AccountProjectionHandler;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Component;

// ── Event Publisher ────────────────────────────────────────────────────────
// Serialises domain events to JSON and sends them to Kafka.
// The partition key is the aggregateId so all events for one account
// land on the same partition — preserving order.

@Component
public class EventPublisher {

    private static final Logger log = LoggerFactory.getLogger(EventPublisher.class);
    public  static final String TOPIC = "account-events";

    private final KafkaTemplate<String, String> kafka;
    private final ObjectMapper                  mapper;

    public EventPublisher(KafkaTemplate<String, String> kafka, ObjectMapper mapper) {
        this.kafka  = kafka;
        this.mapper = mapper;
    }

    public void publish(DomainEvent event) {
        try {
            String json = mapper.writeValueAsString(event);
            // Key = aggregateId → same partition = ordered delivery
            kafka.send(TOPIC, event.aggregateId, json);
            log.debug("Published {} for account {}", event.getClass().getSimpleName(), event.aggregateId);
        } catch (Exception e) {
            log.error("Failed to publish event {}: {}", event.eventId, e.getMessage());
            throw new RuntimeException("Event publish failed", e);
        }
    }
}

// ── Event Consumer (Read Side Projector) ──────────────────────────────────
// Consumes events from Kafka and updates the read-side PostgreSQL view.
// This is the CQRS read model — a denormalised table optimised for queries.
//
// Why a separate consumer group?
//   Multiple read models can consume the same events independently.
//   You could add a second consumer group for analytics, reporting,
//   notifications, etc. — all from the same Kafka topic.

@Component
class AccountEventConsumer {

    private static final Logger log = LoggerFactory.getLogger(AccountEventConsumer.class);

    private final ObjectMapper             mapper;
    private final AccountProjectionHandler projectionHandler;

    AccountEventConsumer(ObjectMapper mapper, AccountProjectionHandler projectionHandler) {
        this.mapper            = mapper;
        this.projectionHandler = projectionHandler;
    }

    @KafkaListener(
        topics            = EventPublisher.TOPIC,
        groupId           = "account-read-model",
        concurrency       = "3"   // 3 consumer threads for parallelism
    )
    public void consume(ConsumerRecord<String, String> record) {
        try {
            DomainEvent event = mapper.readValue(record.value(), DomainEvent.class);
            projectionHandler.handle(event);
            log.debug("Projected {} for account {}", event.getClass().getSimpleName(), event.aggregateId);
        } catch (Exception e) {
            log.error("Failed to project event from partition {} offset {}: {}",
                record.partition(), record.offset(), e.getMessage());
            // In production: send to Dead Letter Topic, alert on error
            throw new RuntimeException("Projection failed", e);
        }
    }
}
