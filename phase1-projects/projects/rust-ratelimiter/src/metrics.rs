use prometheus::{CounterVec, Opts, Registry};
use std::sync::LazyLock;

pub static RATE_CHECK_TOTAL: LazyLock<CounterVec> = LazyLock::new(|| {
    CounterVec::new(
        Opts::new("rate_limiter_checks_total", "Total rate limit checks"),
        &["result"],
    )
    .unwrap()
});

pub fn register_metrics() {
    prometheus::default_registry()
        .register(Box::new(RATE_CHECK_TOTAL.clone()))
        .ok();
}
