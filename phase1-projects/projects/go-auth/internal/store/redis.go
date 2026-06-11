package store

import (
	"context"
	"time"

	"github.com/redis/go-redis/v9"
)

type RedisStore struct {
	client *redis.Client
}

func NewRedisStore(url string) (*RedisStore, error) {
	opts, err := redis.ParseURL(url)
	if err != nil {
		return nil, err
	}
	c := redis.NewClient(opts)
	if err := c.Ping(context.Background()).Err(); err != nil {
		return nil, err
	}
	return &RedisStore{client: c}, nil
}

func (s *RedisStore) StoreRefresh(ctx context.Context, username, token string) error {
	return s.client.Set(ctx, "refresh:"+username, token, 7*24*time.Hour).Err()
}

func (s *RedisStore) GetRefresh(ctx context.Context, username string) (string, error) {
	return s.client.Get(ctx, "refresh:"+username).Result()
}

func (s *RedisStore) DeleteRefresh(ctx context.Context, username string) error {
	return s.client.Del(ctx, "refresh:"+username).Err()
}
