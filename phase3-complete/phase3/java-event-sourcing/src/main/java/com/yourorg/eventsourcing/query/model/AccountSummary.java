package com.yourorg.eventsourcing.query.model;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.Instant;

// ── Account Summary (Read Model) ──────────────────────────────────────────
// Denormalised table — optimised for reads. No joins needed.
// Rebuilt entirely from domain events via Kafka projections.

@Entity
@Table(name = "account_summaries")
public class AccountSummary {

    @Id
    private String id;

    @Column(nullable = false)
    private String ownerId;

    @Column(nullable = false)
    private String ownerName;

    @Column(nullable = false, precision = 19, scale = 4)
    private BigDecimal balance;

    @Column(nullable = false)
    private String status;   // ACTIVE | CLOSED

    @Column(nullable = false)
    private Instant openedAt;

    @Column(nullable = false)
    private Instant lastUpdatedAt;

    // Getters and setters
    public String     getId()            { return id; }
    public void       setId(String v)    { this.id = v; }
    public String     getOwnerId()       { return ownerId; }
    public void       setOwnerId(String v) { this.ownerId = v; }
    public String     getOwnerName()     { return ownerName; }
    public void       setOwnerName(String v) { this.ownerName = v; }
    public BigDecimal getBalance()       { return balance; }
    public void       setBalance(BigDecimal v) { this.balance = v; }
    public String     getStatus()        { return status; }
    public void       setStatus(String v) { this.status = v; }
    public Instant    getOpenedAt()      { return openedAt; }
    public void       setOpenedAt(Instant v) { this.openedAt = v; }
    public Instant    getLastUpdatedAt() { return lastUpdatedAt; }
    public void       setLastUpdatedAt(Instant v) { this.lastUpdatedAt = v; }
}
