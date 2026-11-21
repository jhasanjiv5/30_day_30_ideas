package policy

import (
	"testing"
	"time"

	"github.com/kavach-sec/kavach/internal/config"
	"github.com/kavach-sec/kavach/internal/types"
)

func TestPolicyTiersAndAllowOnce(t *testing.T) {
	pol := config.DefaultPolicy()
	store := config.NewAllowOnceStore(t.TempDir())

	raw := []types.Finding{
		{
			RuleID:      "aws-access-key-id",
			Category:    types.CategorySecrets,
			Tier:        types.TierHigh,
			Fingerprint: "kvfp_1111222233334444",
			Preview:     "AKIA…MPLE",
			Placeholder: "${AWS_ACCESS_KEY_ID}",
		},
	}

	act, tier, _, fixes := Evaluate(pol, types.EvalInput{Event: types.EventUserPromptSubmit}, raw, store)
	if act != types.ActionBlock || tier != types.TierHigh || len(fixes) == 0 {
		t.Fatalf("expected BLOCK/HIGH with fixes, got %s/%s fixes=%v", act, tier, fixes)
	}

	// Allow-once with reason
	if _, err := store.Add("kvfp_1111222233334444", "documented canary test", time.Minute, 1); err != nil {
		t.Fatalf("Add: %v", err)
	}
	act, _, evaluated, _ := Evaluate(pol, types.EvalInput{Event: types.EventUserPromptSubmit}, raw, store)
	if act != types.ActionAllow || !evaluated[0].AllowListed {
		t.Fatalf("expected ALLOW after allow-once, got %s (%+v)", act, evaluated)
	}

	// Next call is blocked again (single use consumed)
	act2, _, _, _ := Evaluate(pol, types.EvalInput{Event: types.EventUserPromptSubmit}, raw, store)
	if act2 != types.ActionBlock {
		t.Fatalf("expected BLOCK after single-use allow-once consumed, got %s", act2)
	}
}

func TestPolicyTestFixturePathAllowlist(t *testing.T) {
	pol := config.DefaultPolicy()
	raw := []types.Finding{{RuleID: "aws-access-key-id", Category: types.CategorySecrets, Tier: types.TierHigh}}
	act, _, _, _ := Evaluate(pol, types.EvalInput{Event: types.EventScan, FilePath: "testdata/redteam/secrets.yaml"}, raw, nil)
	if act != types.ActionAllow {
		t.Fatalf("expected test fixture path to be allowlisted, got %s", act)
	}
}
