package com.yourorg.eventsourcing.query.handler;

import com.yourorg.eventsourcing.event.DomainEvent;
import com.yourorg.eventsourcing.query.model.AccountSummary;
import com.yourorg.eventsourcing.query.model.TransactionEntry;
import com.yourorg.eventsourcing.query.repository.AccountSummaryRepository;
import com.yourorg.eventsourcing.query.repository.TransactionRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;

// ── Projection Handler (Read Side) ────────────────────────────────────────
//
// Receives domain events (from Kafka) and updates the read model.
// The read model is a DENORMALISED PostgreSQL table optimised for
// fast queries — no joins, no aggregate rebuilding.
//
// Read model tables:
//   account_summaries — one row per account, current balance + metadata
//   transaction_log   — every deposit/withdrawal/transfer as a ledger entry
//
// The read model can be REBUILT from scratch by replaying all Kafka events.
// This is a key property of event sourcing: read models are disposable.
// If you add a new read model (e.g. analytics), replay from topic beginning.

@Service
public class AccountProjectionHandler {

    private static final Logger log = LoggerFactory.getLogger(AccountProjectionHandler.class);

    private final AccountSummaryRepository summaries;
    private final TransactionRepository    transactions;

    public AccountProjectionHandler(AccountSummaryRepository summaries,
                                    TransactionRepository transactions) {
        this.summaries    = summaries;
        this.transactions = transactions;
    }

    @Transactional
    public void handle(DomainEvent event) {
        switch (event) {
            case DomainEvent.AccountOpened e      -> onAccountOpened(e);
            case DomainEvent.MoneyDeposited e     -> onMoneyDeposited(e);
            case DomainEvent.MoneyWithdrawn e     -> onMoneyWithdrawn(e);
            case DomainEvent.AccountClosed e      -> onAccountClosed(e);
            case DomainEvent.TransferInitiated e  -> onTransferInitiated(e);
        }
    }

    private void onAccountOpened(DomainEvent.AccountOpened e) {
        AccountSummary summary = new AccountSummary();
        summary.setId(e.aggregateId);
        summary.setOwnerId(e.ownerId);
        summary.setOwnerName(e.ownerName);
        summary.setBalance(e.initialBalance);
        summary.setStatus("ACTIVE");
        summary.setOpenedAt(e.occurredAt);
        summary.setLastUpdatedAt(e.occurredAt);
        summaries.save(summary);

        if (e.initialBalance.signum() > 0) {
            recordTransaction(e.aggregateId, "DEPOSIT", e.initialBalance,
                "Initial deposit", e.occurredAt);
        }
    }

    private void onMoneyDeposited(DomainEvent.MoneyDeposited e) {
        summaries.findById(e.aggregateId).ifPresent(summary -> {
            summary.setBalance(summary.getBalance().add(e.amount));
            summary.setLastUpdatedAt(e.occurredAt);
            summaries.save(summary);
        });
        recordTransaction(e.aggregateId, "DEPOSIT", e.amount, e.description, e.occurredAt);
    }

    private void onMoneyWithdrawn(DomainEvent.MoneyWithdrawn e) {
        summaries.findById(e.aggregateId).ifPresent(summary -> {
            summary.setBalance(summary.getBalance().subtract(e.amount));
            summary.setLastUpdatedAt(e.occurredAt);
            summaries.save(summary);
        });
        recordTransaction(e.aggregateId, "WITHDRAWAL", e.amount, e.description, e.occurredAt);
    }

    private void onAccountClosed(DomainEvent.AccountClosed e) {
        summaries.findById(e.aggregateId).ifPresent(summary -> {
            summary.setStatus("CLOSED");
            summary.setLastUpdatedAt(e.occurredAt);
            summaries.save(summary);
        });
    }

    private void onTransferInitiated(DomainEvent.TransferInitiated e) {
        recordTransaction(e.aggregateId, "TRANSFER_OUT", e.amount,
            "Transfer to " + e.toAccountId, e.occurredAt);
    }

    private void recordTransaction(String accountId, String type,
                                   java.math.BigDecimal amount,
                                   String description, Instant at) {
        TransactionEntry entry = new TransactionEntry();
        entry.setAccountId(accountId);
        entry.setType(type);
        entry.setAmount(amount);
        entry.setDescription(description);
        entry.setOccurredAt(at);
        transactions.save(entry);
    }
}
