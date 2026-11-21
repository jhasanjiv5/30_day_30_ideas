package config

import (
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/kavach-sec/kavach/internal/types"
)

func TestLoadPolicyWithRepoOverride(t *testing.T) {
	kavachDir := t.TempDir()
	if _, err := EnsureDefaultPolicy(kavachDir); err != nil {
		t.Fatalf("EnsureDefaultPolicy: %v", err)
	}

	repo := t.TempDir()
	sub := filepath.Join(repo, "cmd", "app")
	if err := os.MkdirAll(sub, 0o755); err != nil {
		t.Fatalf("mkdir: %v", err)
	}
	repoCfg := `
tiers:
  unreviewed_mcp: HIGH
allowlist:
  hosts:
    - internal.corp.example
  mcp_servers:
    - github-readonly
rule_overrides:
  pii-email: LOW
`
	if err := os.WriteFile(filepath.Join(repo, ".kavach.yaml"), []byte(repoCfg), 0o644); err != nil {
		t.Fatalf("write .kavach.yaml: %v", err)
	}

	pol, err := LoadPolicy(kavachDir, sub)
	if err != nil {
		t.Fatalf("LoadPolicy: %v", err)
	}
	if pol.Tiers.UnreviewedMCP != types.TierHigh {
		t.Errorf("UnreviewedMCP tier = %s, want HIGH", pol.Tiers.UnreviewedMCP)
	}
	if pol.RuleOverrides["pii-email"] != types.TierLow {
		t.Errorf("rule override pii-email = %s, want LOW", pol.RuleOverrides["pii-email"])
	}
	foundHost := false
	for _, h := range pol.Allowlist.Hosts {
		if h == "internal.corp.example" {
			foundHost = true
		}
	}
	if !foundHost {
		t.Errorf("expected internal.corp.example in merged allowlist hosts")
	}
}

func TestAllowOnceStoreConsume(t *testing.T) {
	dir := t.TempDir()
	store := NewAllowOnceStore(dir)
	if _, err := store.Add("kvfp_deadbeef12345678", "", time.Minute, 1); err == nil {
		t.Fatal("expected error when reason is empty")
	}
	if _, err := store.Add("kvfp_deadbeef12345678", "fixture in unit test", time.Minute, 1); err != nil {
		t.Fatalf("Add: %v", err)
	}
	entry, ok := store.Consume("kvfp_deadbeef12345678")
	if !ok || entry.Reason != "fixture in unit test" {
		t.Fatalf("expected active allow-once entry, got ok=%v entry=%+v", ok, entry)
	}
	if _, ok := store.Consume("kvfp_deadbeef12345678"); ok {
		t.Fatal("expected single-use allow-once entry to be consumed")
	}
}
