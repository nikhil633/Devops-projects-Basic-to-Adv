package com.yourorg.eventsourcing.command.repository;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.yourorg.eventsourcing.event.DomainEvent;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

// ── Event Store ────────────────────────────────────────────────────────────
//
// The event store is the ONLY source of truth on the write side.
// It is a simple append-only table:
//
//   CREATE TABLE events (
//     id           BIGSERIAL PRIMARY KEY,
//     aggregate_id VARCHAR(36) NOT NULL,
//     version      BIGINT      NOT NULL,
//     type         VARCHAR(100) NOT NULL,
//     payload      JSONB       NOT NULL,
//     occurred_at  TIMESTAMPTZ NOT NULL,
//     UNIQUE (aggregate_id, version)  -- prevents duplicate events (optimistic locking)
//   );
//
// The UNIQUE constraint on (aggregate_id, version) is optimistic locking:
// if two concurrent commands try to append version=5 for the same account,
// only one succeeds — the other gets a unique constraint violation and retries.

@Repository
public class EventStore {

    private final JdbcTemplate    jdbc;
    private final ObjectMapper    mapper;

    public EventStore(JdbcTemplate jdbc, ObjectMapper mapper) {
        this.jdbc   = jdbc;
        this.mapper = mapper;
    }

    // Append a list of events atomically.
    // If any event's version already exists → throws (optimistic locking violation)
    @Transactional
    public void appendEvents(String aggregateId, List<DomainEvent> events) {
        for (DomainEvent event : events) {
            try {
                String payload = mapper.writeValueAsString(event);
                jdbc.update(
                    """
                    INSERT INTO events (aggregate_id, version, type, payload, occurred_at)
                    VALUES (?, ?, ?, ?::jsonb, ?)
                    """,
                    event.aggregateId,
                    event.version,
                    event.getClass().getSimpleName(),
                    payload,
                    event.occurredAt
                );
            } catch (Exception e) {
                throw new RuntimeException("Failed to append event: " + e.getMessage(), e);
            }
        }
    }

    // Load all events for an aggregate in version order
    public List<DomainEvent> loadEvents(String aggregateId) {
        return jdbc.query(
            "SELECT payload FROM events WHERE aggregate_id = ? ORDER BY version ASC",
            (rs, rowNum) -> {
                try {
                    return mapper.readValue(rs.getString("payload"), DomainEvent.class);
                } catch (Exception e) {
                    throw new RuntimeException("Failed to deserialise event", e);
                }
            },
            aggregateId
        );
    }

    // Load events after a specific version (used for rebuilding projections)
    public List<DomainEvent> loadEventsSince(String aggregateId, long afterVersion) {
        return jdbc.query(
            "SELECT payload FROM events WHERE aggregate_id = ? AND version > ? ORDER BY version ASC",
            (rs, rowNum) -> {
                try {
                    return mapper.readValue(rs.getString("payload"), DomainEvent.class);
                } catch (Exception e) {
                    throw new RuntimeException("Failed to deserialise event", e);
                }
            },
            aggregateId, afterVersion
        );
    }

    // Check if an aggregate exists
    public boolean exists(String aggregateId) {
        Integer count = jdbc.queryForObject(
            "SELECT COUNT(1) FROM events WHERE aggregate_id = ?",
            Integer.class, aggregateId
        );
        return count != null && count > 0;
    }
}
