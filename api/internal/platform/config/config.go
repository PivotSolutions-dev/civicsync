package config

import (
	"fmt"
	"os"
	"strconv"
	"time"
)

type Config struct {
	Env             string
	Port            int
	AppDatabaseURL  string
	RedisURL        string
	ShutdownTimeout time.Duration
}

func Load() (Config, error) {
	cfg := Config{
		Env:             env("APP_ENV", "development"),
		AppDatabaseURL:  env("APP_DATABASE_URL", ""),
		RedisURL:        env("REDIS_URL", ""),
		ShutdownTimeout: 15 * time.Second,
	}

	port, err := strconv.Atoi(env("PORT", "8080"))
	if err != nil {
		return cfg, fmt.Errorf("PORT must be an integer: %w", err)
	}
	cfg.Port = port

	if cfg.AppDatabaseURL == "" {
		return cfg, fmt.Errorf("APP_DATABASE_URL is required")
	}
	return cfg, nil
}

func env(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
