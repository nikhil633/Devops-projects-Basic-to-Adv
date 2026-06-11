package com.yourorg.eventsourcing.query.model;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.Instant;

@Entity
@Table(name = "transaction_log",
       indexes = @Index(name = "idx_txn_account", columnList = "accountId"))
public class TransactionEntry {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String accountId;

    @Column(nullable = false)
    private String type;         // DEPOSIT | WITHDRAWAL | TRANSFER_OUT | TRANSFER_IN

    @Column(nullable = false, precision = 19, scale = 4)
    private BigDecimal amount;

    private String description;

    @Column(nullable = false)
    private Instant occurredAt;

    public Long       getId()            { return id; }
    public String     getAccountId()     { return accountId; }
    public void       setAccountId(String v) { this.accountId = v; }
    public String     getType()          { return type; }
    public void       setType(String v)  { this.type = v; }
    public BigDecimal getAmount()        { return amount; }
    public void       setAmount(BigDecimal v) { this.amount = v; }
    public String     getDescription()   { return description; }
    public void       setDescription(String v) { this.description = v; }
    public Instant    getOccurredAt()    { return occurredAt; }
    public void       setOccurredAt(Instant v) { this.occurredAt = v; }
}
