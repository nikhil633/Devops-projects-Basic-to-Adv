package com.yourorg.eventsourcing.command.model;

import com.yourorg.eventsourcing.event.DomainEvent;
import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;

// ── Account Aggregate (Write Side) ────────────────────────────────────────
//
// In event sourcing there is NO "read from DB then update" pattern.
// Instead:
//   1. Load all past events for account (from event store)
//   2. REPLAY them to rebuild current state (apply() methods below)
//   3. Run business logic / validation against current state
//   4. Append new events to the event store
//   5. Publish events to Kafka so the read side can update
//
// The aggregate never touches the read-side (query) database.
// The read side is a projection built from events via Kafka.

public class Account {

    // ── Current state (rebuilt by replaying events) ────────────────────────
    private String     id;
    private String     ownerId;
    private String     ownerName;
    private BigDecimal balance;
    private boolean    closed;
    private long       version;  // last applied event version

    // New uncommitted events — flushed to the event store after validation
    private final List<DomainEvent> uncommittedEvents = new ArrayList<>();

    // Private constructor — use static factory or reconstitute()
    private Account() {}

    // ── Factory: open a new account ───────────────────────────────────────
    public static Account open(String accountId, String ownerId,
                               String ownerName, BigDecimal initialBalance) {
        if (initialBalance.compareTo(BigDecimal.ZERO) < 0) {
            throw new IllegalArgumentException("Initial balance cannot be negative");
        }

        Account account = new Account();
        account.applyAndRecord(new DomainEvent.AccountOpened(
            accountId, 1L, ownerId, ownerName, initialBalance
        ));
        return account;
    }

    // ── Factory: rebuild account by replaying stored events ──────────────
    public static Account reconstitute(List<DomainEvent> events) {
        if (events.isEmpty()) throw new IllegalArgumentException("Cannot reconstitute from empty events");
        Account account = new Account();
        events.forEach(account::apply);
        return account;
    }

    // ── Commands (business operations) ───────────────────────────────────

    public void deposit(BigDecimal amount, String description) {
        assertNotClosed();
        if (amount.compareTo(BigDecimal.ZERO) <= 0) {
            throw new IllegalArgumentException("Deposit amount must be positive");
        }
        applyAndRecord(new DomainEvent.MoneyDeposited(id, version + 1, amount, description));
    }

    public void withdraw(BigDecimal amount, String description) {
        assertNotClosed();
        if (amount.compareTo(BigDecimal.ZERO) <= 0) {
            throw new IllegalArgumentException("Withdrawal amount must be positive");
        }
        if (balance.compareTo(amount) < 0) {
            throw new IllegalStateException(
                "Insufficient funds: balance=" + balance + " requested=" + amount);
        }
        applyAndRecord(new DomainEvent.MoneyWithdrawn(id, version + 1, amount, description));
    }

    public void close(String reason) {
        assertNotClosed();
        if (balance.compareTo(BigDecimal.ZERO) != 0) {
            throw new IllegalStateException("Cannot close account with non-zero balance");
        }
        applyAndRecord(new DomainEvent.AccountClosed(id, version + 1, reason));
    }

    public void initiateTransfer(String toAccountId, BigDecimal amount) {
        assertNotClosed();
        if (balance.compareTo(amount) < 0) {
            throw new IllegalStateException("Insufficient funds for transfer");
        }
        applyAndRecord(new DomainEvent.TransferInitiated(id, version + 1, toAccountId, amount));
        // Transfer also triggers a withdrawal
        applyAndRecord(new DomainEvent.MoneyWithdrawn(id, version + 1, amount, "Transfer to " + toAccountId));
    }

    // ── Event application (pure state transitions) ─────────────────────────
    // apply() methods ONLY update state — no side effects, no validation.
    // They are called both when recording new events AND when replaying history.

    private void apply(DomainEvent event) {
        switch (event) {
            case DomainEvent.AccountOpened e -> {
                this.id       = e.aggregateId;
                this.ownerId  = e.ownerId;
                this.ownerName = e.ownerName;
                this.balance  = e.initialBalance;
                this.closed   = false;
                this.version  = e.version;
            }
            case DomainEvent.MoneyDeposited e -> {
                this.balance = this.balance.add(e.amount);
                this.version = e.version;
            }
            case DomainEvent.MoneyWithdrawn e -> {
                this.balance = this.balance.subtract(e.amount);
                this.version = e.version;
            }
            case DomainEvent.AccountClosed e -> {
                this.closed  = true;
                this.version = e.version;
            }
            case DomainEvent.TransferInitiated e -> {
                this.version = e.version;
            }
        }
    }

    private void applyAndRecord(DomainEvent event) {
        apply(event);
        uncommittedEvents.add(event);
    }

    private void assertNotClosed() {
        if (closed) throw new IllegalStateException("Account " + id + " is closed");
    }

    // ── Getters ───────────────────────────────────────────────────────────
    public String     getId()               { return id; }
    public String     getOwnerId()          { return ownerId; }
    public String     getOwnerName()        { return ownerName; }
    public BigDecimal getBalance()          { return balance; }
    public boolean    isClosed()            { return closed; }
    public long       getVersion()          { return version; }

    public List<DomainEvent> getUncommittedEvents() {
        return List.copyOf(uncommittedEvents);
    }

    public void clearUncommittedEvents() {
        uncommittedEvents.clear();
    }
}
