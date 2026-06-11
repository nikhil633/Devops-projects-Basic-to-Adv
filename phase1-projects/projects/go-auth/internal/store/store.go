package store

import "context"

type Store interface {
	StoreRefresh(ctx context.Context, username, token string) error
	GetRefresh(ctx context.Context, username string) (string, error)
	DeleteRefresh(ctx context.Context, username string) error
}
