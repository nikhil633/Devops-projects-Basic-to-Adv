package com.yourorg.eventsourcing.api;

import com.yourorg.eventsourcing.command.handler.AccountCommandHandler;
import com.yourorg.eventsourcing.command.repository.EventStore;
import com.yourorg.eventsourcing.query.model.AccountSummary;
import com.yourorg.eventsourcing.query.model.TransactionEntry;
import com.yourorg.eventsourcing.query.repository.AccountSummaryRepository;
import com.yourorg.eventsourcing.query.repository.TransactionRepository;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api")
public class AccountController {

    private final AccountCommandHandler commands;
    private final AccountSummaryRepository summaries;
    private final TransactionRepository transactions;
    private final EventStore eventStore;

    public AccountController(AccountCommandHandler commands,
                             AccountSummaryRepository summaries,
                             TransactionRepository transactions,
                             EventStore eventStore) {
        this.commands     = commands;
        this.summaries    = summaries;
        this.transactions = transactions;
        this.eventStore   = eventStore;
    }

    // ── Commands (Write side) ──────────────────────────────────────────────

    record OpenAccountRequest(
        @NotBlank String ownerId,
        @NotBlank String ownerName,
        @NotNull @DecimalMin("0.0") BigDecimal initialBalance
    ) {}

    @PostMapping("/accounts")
    public ResponseEntity<Map<String, String>> openAccount(@Valid @RequestBody OpenAccountRequest req) {
        String id = commands.openAccount(req.ownerId(), req.ownerName(), req.initialBalance());
        return ResponseEntity.status(HttpStatus.CREATED).body(Map.of("accountId", id));
    }

    record MoneyRequest(
        @NotNull @DecimalMin("0.01") BigDecimal amount,
        @NotBlank String description
    ) {}

    @PostMapping("/accounts/{id}/deposit")
    public ResponseEntity<Void> deposit(@PathVariable String id, @Valid @RequestBody MoneyRequest req) {
        commands.deposit(id, req.amount(), req.description());
        return ResponseEntity.accepted().build();
    }

    @PostMapping("/accounts/{id}/withdraw")
    public ResponseEntity<Void> withdraw(@PathVariable String id, @Valid @RequestBody MoneyRequest req) {
        try {
            commands.withdraw(id, req.amount(), req.description());
            return ResponseEntity.accepted().build();
        } catch (IllegalStateException e) {
            return ResponseEntity.badRequest().build();
        }
    }

    record TransferRequest(
        @NotBlank String toAccountId,
        @NotNull @DecimalMin("0.01") BigDecimal amount
    ) {}

    @PostMapping("/accounts/{id}/transfer")
    public ResponseEntity<Void> transfer(@PathVariable String id, @Valid @RequestBody TransferRequest req) {
        try {
            commands.transfer(id, req.toAccountId(), req.amount());
            return ResponseEntity.accepted().build();
        } catch (IllegalStateException e) {
            return ResponseEntity.badRequest().build();
        }
    }

    @DeleteMapping("/accounts/{id}")
    public ResponseEntity<Void> closeAccount(@PathVariable String id,
                                             @RequestParam(defaultValue = "Customer request") String reason) {
        commands.closeAccount(id, reason);
        return ResponseEntity.accepted().build();
    }

    // ── Queries (Read side) ────────────────────────────────────────────────

    @GetMapping("/accounts")
    public List<AccountSummary> listAccounts(@RequestParam(required = false) String status) {
        if (status != null) return summaries.findByStatus(status);
        return summaries.findAll();
    }

    @GetMapping("/accounts/{id}")
    public ResponseEntity<AccountSummary> getAccount(@PathVariable String id) {
        return summaries.findById(id)
            .map(ResponseEntity::ok)
            .orElse(ResponseEntity.notFound().build());
    }

    @GetMapping("/accounts/{id}/transactions")
    public List<TransactionEntry> getTransactions(
            @PathVariable String id,
            @RequestParam(defaultValue = "20") int limit) {
        return transactions.findByAccountIdOrderByOccurredAtDesc(
            id, PageRequest.of(0, Math.min(limit, 100))
        );
    }

    // Returns the raw event log for an account — great for debugging and auditing
    @GetMapping("/accounts/{id}/events")
    public ResponseEntity<?> getEventHistory(@PathVariable String id) {
        var events = eventStore.loadEvents(id);
        if (events.isEmpty()) return ResponseEntity.notFound().build();
        return ResponseEntity.ok(events);
    }

    @GetMapping("/health")
    public Map<String, String> health() {
        return Map.of("status", "ok");
    }
}
