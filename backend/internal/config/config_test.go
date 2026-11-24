// SPDX-License-Identifier: MIT

package config

import (
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
		{name: "defaults", want: Config{"127.0.0.1:8080", 10 * time.Second}},
		{name: "overrides", env: map[string]string{"HTTP_ADDR": "[::1]:8081", "SHUTDOWN_TIMEOUT": "2s"}, want: Config{"[::1]:8081", 2 * time.Second}},
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
			got, err := Load(func(key string) string { return tt.env[key] })
			if (err != nil) != tt.wantError {
				t.Fatalf("Load error = %v, want error = %v", err, tt.wantError)
			}
			if err == nil && got != tt.want {
				t.Fatalf("Load = %+v, want %+v", got, tt.want)
			}
		})
	}
}
