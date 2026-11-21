package selftest

import (
	"context"
	"path/filepath"
	"testing"
)

func TestRedTeamCorpusPassesAllThresholds(t *testing.T) {
	corpusDir := filepath.Join("..", "..", "testdata", "redteam")
	res, err := Run(context.Background(), corpusDir)
	if err != nil {
		t.Fatalf("selftest.Run: %v", err)
	}
	if res.TotalCases < 60 {
		t.Fatalf("expected >= 60 corpus cases, got %d", res.TotalCases)
	}
	if !res.PassedThresholds {
		t.Fatalf("selftest thresholds failed: secrets=%.2f%% risky=%.2f%% inj=%.2f%% fp=%.2f%% p95=%.2fms failures=%v",
			res.SecretsRate*100, res.RiskyCommandsRate*100, res.InjectionRate*100, res.FalsePositiveRate*100, res.OverallP95Ms, res.Failures)
	}
}
