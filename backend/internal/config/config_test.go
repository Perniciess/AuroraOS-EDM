// SPDX-License-Identifier: MIT

package config

import (
	"strings"
	"testing"
	"time"
)

func TestLoad(t *testing.T) {
	tests := []struct {
		name      string
		env       map[string]string
		want      Config
		wantError bool
	}{
		{name: "defaults", want: Config{HTTPAddr: "127.0.0.1:8080", ShutdownTimeout: 10 * time.Second}},
		{name: "overrides", env: map[string]string{"HTTP_ADDR": "[::1]:8081", "SHUTDOWN_TIMEOUT": "2s"}, want: Config{HTTPAddr: "[::1]:8081", ShutdownTimeout: 2 * time.Second}},
		{name: "missing port", env: map[string]string{"HTTP_ADDR": "localhost"}, wantError: true},
		{name: "zero port", env: map[string]string{"HTTP_ADDR": ":0"}, wantError: true},
		{name: "large port", env: map[string]string{"HTTP_ADDR": ":65536"}, wantError: true},
		{name: "named port", env: map[string]string{"HTTP_ADDR": ":http"}, wantError: true},
		{name: "invalid duration", env: map[string]string{"SHUTDOWN_TIMEOUT": "soon"}, wantError: true},
		{name: "zero duration", env: map[string]string{"SHUTDOWN_TIMEOUT": "0s"}, wantError: true},
		{name: "negative duration", env: map[string]string{"SHUTDOWN_TIMEOUT": "-1s"}, wantError: true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := Load(func(key string) string {
				if key == "DATABASE_URL" {
					return "postgres://localhost/edm"
				}
				return tt.env[key]
			})
			tt.want.DatabaseURL = "postgres://localhost/edm"
			if (err != nil) != tt.wantError {
				t.Fatalf("Load error = %v, want error = %v", err, tt.wantError)
			}
			if err == nil && got != tt.want {
				t.Fatalf("Load = %+v, want %+v", got, tt.want)
			}
		})
	}
}

func TestDatabaseURL(t *testing.T) {
	for _, value := range []string{"", "postgres://user:secret@localhost:bad/edm"} {
		_, err := Load(func(key string) string {
			if key == "DATABASE_URL" {
				return value
			}
			return ""
		})
		if err == nil || strings.Contains(err.Error(), "secret") {
			t.Fatalf("expected sanitized configuration error, got %v", err)
		}
	}
}
