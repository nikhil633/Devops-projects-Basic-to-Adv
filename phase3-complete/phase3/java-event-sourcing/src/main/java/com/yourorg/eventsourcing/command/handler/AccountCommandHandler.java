package com.yourorg.eventsourcing.command.handler;

import com.yourorg.eventsourcing.command.model.Account;
import com.yourorg.eventsourcing.command.repository.EventStore;
import com.yourorg.eventsourcing.event.DomainEvent;
import com.yourorg.eventsourcing.kafka.EventPublisher;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

// ── Command Handlers (Write Side) ─────────────────────────────────────────
//
// A command handler:
//   1. Loads the aggregate's event history from the event store
//   2. Rebuilds the aggregate by replaying events
//   3. Calls the business method (deposit, withdraw, etc.)
//   4. Saves the new events to the event store (in a DB transaction)
//   5. Publishes the events to Kafka (read side will consume them)
//
// Steps 4 and 5 happen in the SAME @Transactional block using the
// Outbox Pattern: events are first written to an outbox table in the
// same DB transaction, then a separate process publishes them to Kafka.
// This guarantees no event is lost if the service crashes between 4 and 5.
// (Simplified here: we publish directly for clarity)

@Service
public class AccountCommandHandler {

    private final EventStore     eventStore;
    private final EventPublisher publisher;
    private final Counter        commandsProcessed;

    public AccountCommandHandler(EventStore eventStore,
                                 EventPublisher publisher,
                                 MeterRegistry registry) {
        this.eventStore        = eventStore;
        this.publisher         = publisher;
        this.commandsProcessed = Counter.builder("cqrs_commands_processed_total")
            .description("Total commands processed on the write side")
            .register(registry);
    }

    @Transactional
    public String openAccount(String ownerId, String ownerName, BigDecimal initialBalance) {
        String accountId = UUID.randomUUID().toString();

        Account account = Account.open(accountId, ownerId, ownerName, initialBalance);

        saveAndPublish(account);
        commandsProcessed.increment();
        return accountId;
    }

    @Transactional
    public void deposit(String accountId, BigDecimal amount, String description) {
        Account account = load(accountId);
        account.deposit(amount, description);
        saveAndPublish(account);
        commandsProcessed.increment();
    }

    @Transactional
    public void withdraw(String accountId, BigDecimal amount, String description) {
        Account account = load(accountId);
        account.withdraw(amount, description);
        saveAndPublish(account);
        commandsProcessed.increment();
    }

    @Transactional
    public void closeAccount(String accountId, String reason) {
        Account account = load(accountId);
        account.close(reason);
        saveAndPublish(account);
        commandsProcessed.increment();
    }

    @Transactional
    public void transfer(String fromAccountId, String toAccountId, BigDecimal amount) {
        Account from = load(fromAccountId);
        from.initiateTransfer(toAccountId, amount);
        saveAndPublish(from);

        Account to = load(toAccountId);
        to.deposit(amount, "Transfer from " + fromAccountId);
        saveAndPublish(to);

        commandsProcessed.increment();
    }

    // ── Helpers ───────────────────────────────────────────────────────────

    private Account load(String accountId) {
        List<DomainEvent> events = eventStore.loadEvents(accountId);
        if (events.isEmpty()) {
            throw new IllegalArgumentException("Account not found: " + accountId);
        }
        return Account.reconstitute(events);
    }

    private void saveAndPublish(Account account) {
        List<DomainEvent> newEvents = account.getUncommittedEvents();
        if (newEvents.isEmpty()) return;

        // 1. Persist to event store (DB transaction)
        eventStore.appendEvents(account.getId(), newEvents);

        // 2. Publish to Kafka (read side consumes these)
        newEvents.forEach(publisher::publish);

        account.clearUncommittedEvents();
    }
}
