-- Event store (write side) — append-only, never updated
CREATE TABLE IF NOT EXISTS events (
    id           BIGSERIAL    PRIMARY KEY,
    aggregate_id VARCHAR(36)  NOT NULL,
    version      BIGINT       NOT NULL,
    type         VARCHAR(100) NOT NULL,
    payload      JSONB        NOT NULL,
    occurred_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_aggregate_version UNIQUE (aggregate_id, version)
);
CREATE INDEX IF NOT EXISTS idx_events_aggregate ON events (aggregate_id, version);

-- Read model: account summaries (updated by Kafka projections)
CREATE TABLE IF NOT EXISTS account_summaries (
    id              VARCHAR(36)    PRIMARY KEY,
    owner_id        VARCHAR(36)    NOT NULL,
    owner_name      VARCHAR(255)   NOT NULL,
    balance         NUMERIC(19,4)  NOT NULL DEFAULT 0,
    status          VARCHAR(20)    NOT NULL DEFAULT 'ACTIVE',
    opened_at       TIMESTAMPTZ    NOT NULL,
    last_updated_at TIMESTAMPTZ    NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_summary_owner ON account_summaries (owner_id);
CREATE INDEX IF NOT EXISTS idx_summary_status ON account_summaries (status);

-- Read model: transaction log (append-only, built from events)
CREATE TABLE IF NOT EXISTS transaction_log (
    id          BIGSERIAL      PRIMARY KEY,
    account_id  VARCHAR(36)    NOT NULL,
    type        VARCHAR(30)    NOT NULL,
    amount      NUMERIC(19,4)  NOT NULL,
    description TEXT,
    occurred_at TIMESTAMPTZ    NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_txn_account ON transaction_log (account_id, occurred_at DESC);
