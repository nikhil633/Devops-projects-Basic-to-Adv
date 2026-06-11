package com.yourorg.eventsourcing.query.repository;

import com.yourorg.eventsourcing.query.model.AccountSummary;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

public interface AccountSummaryRepository extends JpaRepository<AccountSummary, String> {
    List<AccountSummary> findByStatus(String status);
    List<AccountSummary> findByOwnerId(String ownerId);
}
