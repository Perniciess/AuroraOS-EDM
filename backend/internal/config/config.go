// SPDX-License-Identifier: MIT

package config

import (
	"fmt"
	"net"
	"strconv"
	"time"

	"github.com/jackc/pgx/v5"
)

type Config struct {
	HTTPAddr        string
	ShutdownTimeout time.Duration
	DatabaseURL     string
}

// Load reads environment settings without loading files or logging their values.
func Load(getenv func(string) string) (Config, error) {
	cfg := Config{HTTPAddr: "127.0.0.1:8080", ShutdownTimeout: 10 * time.Second}
	if value := getenv("HTTP_ADDR"); value != "" {
		cfg.HTTPAddr = value
	}
	_, port, err := net.SplitHostPort(cfg.HTTPAddr)
	if err != nil {
		return Config{}, fmt.Errorf("HTTP_ADDR must be a host:port address")
	}
	n, err := strconv.Atoi(port)
	if err != nil || n < 1 || n > 65535 {
		return Config{}, fmt.Errorf("HTTP_ADDR must contain a port between 1 and 65535")
	}
	if value := getenv("SHUTDOWN_TIMEOUT"); value != "" {
		cfg.ShutdownTimeout, err = time.ParseDuration(value)
		if err != nil || cfg.ShutdownTimeout <= 0 {
			return Config{}, fmt.Errorf("SHUTDOWN_TIMEOUT must be a positive duration")
		}
	}
	cfg.DatabaseURL = getenv("DATABASE_URL")
	if cfg.DatabaseURL == "" {
		return Config{}, fmt.Errorf("DATABASE_URL is required")
	}
	if _, err := pgx.ParseConfig(cfg.DatabaseURL); err != nil {
		// Parser errors may include the connection string and password.
		return Config{}, fmt.Errorf("DATABASE_URL must be a valid PostgreSQL connection string")
	}
	return cfg, nil
}
