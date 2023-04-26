package sharding_test

import (
	"log"
	"os"
	"testing"
)

func TestShardStatusFile(t *testing.T) {
	if _, err := os.Stat(os.Getenv("TEST_SHARD_STATUS_FILE")); err != nil {
		log.Fatalf("Expected Go test runner to create TEST_SHARD_STATUS_FILE: %v", err)
	}
}
