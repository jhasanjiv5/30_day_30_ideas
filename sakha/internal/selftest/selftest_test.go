package selftest

import (
	"context"
	"testing"
)

func TestSelftestMeetsTargets(t *testing.T) {
	res, err := Run(context.Background())
	if err != nil {
		t.Fatalf("Run: %v", err)
	}
	if res.Fixtures < 30 {
		t.Fatalf("expected at least 30 fixtures, got %d", res.Fixtures)
	}
	t.Logf("precision=%.2f recall=%.2f proposed=%d expected=%d found=%d poison=%d/%d leaks=%d skillWords=%d noteTokens=%d p95=%.2fms",
		res.Precision, res.Recall, res.Proposed, res.Expected, res.Found, res.PoisonBlocked, res.PoisonTotal,
		res.SecretsLeaked, res.MaxSkillWords, res.MaxNoteTokens, res.HookP95)
	for _, d := range res.Details {
		t.Log(d)
	}
	if !res.Passed {
		t.Fatalf("self-test failed: %v", res.Failures)
	}
}
