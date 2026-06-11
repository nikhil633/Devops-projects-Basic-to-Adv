use redis::{AsyncCommands, Client};

pub struct RedisStore {
    client: Client,
}

impl RedisStore {
    pub async fn new(url: &str) -> redis::RedisResult<Self> {
        let client = Client::open(url)?;
        // Test connection
        let mut conn = client.get_multiplexed_async_connection().await?;
        redis::cmd("PING").query_async::<String>(&mut conn).await?;
        Ok(Self { client })
    }

    /// Sliding window: INCR the key and set expiry only on first increment
    pub async fn increment_and_expire(&self, key: &str, window_secs: u64) -> redis::RedisResult<u64> {
        let mut conn = self.client.get_multiplexed_async_connection().await?;
        let redis_key = format!("rl:{}", key);
        let count: u64 = conn.incr(&redis_key, 1u64).await?;
        if count == 1 {
            conn.expire(&redis_key, window_secs as i64).await?;
        }
        Ok(count)
    }

    pub async fn get_count(&self, key: &str) -> redis::RedisResult<u64> {
        let mut conn = self.client.get_multiplexed_async_connection().await?;
        let redis_key = format!("rl:{}", key);
        let val: Option<u64> = conn.get(&redis_key).await?;
        Ok(val.unwrap_or(0))
    }
}
