package redact

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/kavach-sec/kavach/internal/types"
)

func TestPreviewNeverExposesFullSecret(t *testing.T) {
	cases := []struct {
		in   string
		want string
	}{
		{"AKIAIOSFODNN7EXAMPLE", "AKIA…MPLE"},
		{"sk-ant-api03-1234567890abcdef", "sk-a…cdef"},
		{"12345678", "12…78"},
		{"short", "••••"},
		{"", "••••"},
	}
	for _, tc := range cases {
		got := Preview(tc.in)
		if got != tc.want {
			t.Errorf("Preview(%q) = %q, want %q", tc.in, got, tc.want)
		}
		if tc.in != "" && strings.Contains(got, tc.in) {
			t.Errorf("Preview leaked full input %q", tc.in)
		}
	}
}

func TestFingerprintAndSaltRotation(t *testing.T) {
	dir := t.TempDir()
	salt1, err := LoadOrCreateSalt(dir)
	if err != nil {
		t.Fatalf("LoadOrCreateSalt: %v", err)
	}
	info, err := os.Stat(filepath.Join(dir, "salt"))
	if err != nil {
		t.Fatalf("stat salt: %v", err)
	}
	if info.Mode().Perm() != 0o600 {
		t.Errorf("salt perms = %o, want 0600", info.Mode().Perm())
	}

	salt1Again, err := LoadOrCreateSalt(dir)
	if err != nil || salt1Again != salt1 {
		t.Fatalf("expected persisted salt to match: %q vs %q (%v)", salt1, salt1Again, err)
	}

	fp1 := Fingerprint(salt1, "AKIAIOSFODNN7EXAMPLE")
	if !strings.HasPrefix(fp1, "kvfp_") || len(fp1) != 21 {
		t.Errorf("unexpected fingerprint format: %q", fp1)
	}

	salt2, err := RotateSalt(dir)
	if err != nil {
		t.Fatalf("RotateSalt: %v", err)
	}
	if salt2 == salt1 {
		t.Fatalf("expected rotated salt to differ")
	}
	fp2 := Fingerprint(salt2, "AKIAIOSFODNN7EXAMPLE")
	if fp2 == fp1 {
		t.Errorf("expected fingerprint to change after salt rotation")
	}
}

func TestRedactText(t *testing.T) {
	raw := "export AWS_KEY=AKIAIOSFODNN7EXAMPLE and TOKEN=ghp_123456789012345678901234567890123456"
	findings := []types.Finding{
		{
			RuleID:      "aws-access-key",
			Placeholder: "${AWS_ACCESS_KEY}",
			StartOffset: strings.Index(raw, "AKIA"),
			EndOffset:   strings.Index(raw, "AKIA") + len("AKIAIOSFODNN7EXAMPLE"),
		},
		{
			RuleID:      "github-pat",
			Placeholder: "${GITHUB_PAT}",
			StartOffset: strings.Index(raw, "ghp_"),
			EndOffset:   len(raw),
		},
	}
	out := RedactText(raw, findings)
	if strings.Contains(out, "AKIAIOSFODNN7EXAMPLE") || strings.Contains(out, "ghp_") {
		t.Fatalf("RedactText leaked raw secrets: %q", out)
	}
	if !strings.Contains(out, "${AWS_ACCESS_KEY}") || !strings.Contains(out, "${GITHUB_PAT}") {
		t.Fatalf("expected placeholders in %q", out)
	}
}
