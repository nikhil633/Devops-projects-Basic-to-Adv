package com.yourorg.eventsourcing.event;

import com.fasterxml.jackson.annotation.JsonSubTypes;
import com.fasterxml.jackson.annotation.JsonTypeInfo;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

// ── Base event ─────────────────────────────────────────────────────────────
// Every domain event has a common header. The 'type' field in JSON tells
// Jackson which concrete class to deserialise into.
//
// Event sourcing principle:
//   - Events are IMMUTABLE facts: "AccountOpened", "MoneyDeposited"
//   - They are PAST TENSE — they describe something that already happened
//   - They are NEVER deleted or modified — only appended
//   - The current state of any aggregate is the REPLAY of all its events

@JsonTypeInfo(use = JsonTypeInfo.Id.NAME, property = "type")
@JsonSubTypes({
    @JsonSubTypes.Type(value = DomainEvent.AccountOpened.class,     name = "AccountOpened"),
    @JsonSubTypes.Type(value = DomainEvent.MoneyDeposited.class,    name = "MoneyDeposited"),
    @JsonSubTypes.Type(value = DomainEvent.MoneyWithdrawn.class,    name = "MoneyWithdrawn"),
    @JsonSubTypes.Type(value = DomainEvent.AccountClosed.class,     name = "AccountClosed"),
    @JsonSubTypes.Type(value = DomainEvent.TransferInitiated.class, name = "TransferInitiated"),
})
public abstract sealed class DomainEvent
    permits DomainEvent.AccountOpened,
            DomainEvent.MoneyDeposited,
            DomainEvent.MoneyWithdrawn,
            DomainEvent.AccountClosed,
            DomainEvent.TransferInitiated {

    // Every event carries these fields
    public final String  eventId;      // unique ID for this event
    public final String  aggregateId;  // which account this event belongs to
    public final long    version;      // optimistic locking — sequence number
    public final Instant occurredAt;

    protected DomainEvent(String aggregateId, long version) {
        this.eventId     = UUID.randomUUID().toString();
        this.aggregateId = aggregateId;
        this.version     = version;
        this.occurredAt  = Instant.now();
    }

    // ── Concrete event types ────────────────────────────────────────────────

    public static final class AccountOpened extends DomainEvent {
        public final String     ownerId;
        public final String     ownerName;
        public final BigDecimal initialBalance;

        public AccountOpened(String accountId, long version,
                             String ownerId, String ownerName, BigDecimal initialBalance) {
            super(accountId, version);
            this.ownerId        = ownerId;
            this.ownerName      = ownerName;
            this.initialBalance = initialBalance;
        }
    }

    public static final class MoneyDeposited extends DomainEvent {
        public final BigDecimal amount;
        public final String     description;

        public MoneyDeposited(String accountId, long version, BigDecimal amount, String description) {
            super(accountId, version);
            this.amount      = amount;
            this.description = description;
        }
    }

    public static final class MoneyWithdrawn extends DomainEvent {
        public final BigDecimal amount;
        public final String     description;

        public MoneyWithdrawn(String accountId, long version, BigDecimal amount, String description) {
            super(accountId, version);
            this.amount      = amount;
            this.description = description;
        }
    }

    public static final class AccountClosed extends DomainEvent {
        public final String reason;

        public AccountClosed(String accountId, long version, String reason) {
            super(accountId, version);
            this.reason = reason;
        }
    }

    public static final class TransferInitiated extends DomainEvent {
        public final String     toAccountId;
        public final BigDecimal amount;

        public TransferInitiated(String fromAccountId, long version,
                                 String toAccountId, BigDecimal amount) {
            super(fromAccountId, version);
            this.toAccountId = toAccountId;
            this.amount      = amount;
        }
    }
}
