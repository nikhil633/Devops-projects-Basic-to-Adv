package com.yourorg.eventsourcing.query.repository;

import com.yourorg.eventsourcing.query.model.TransactionEntry;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.domain.Pageable;
import java.util.List;

public interface TransactionRepository extends JpaRepository<TransactionEntry, Long> {
    List<TransactionEntry> findByAccountIdOrderByOccurredAtDesc(String accountId, Pageable pageable);
}
