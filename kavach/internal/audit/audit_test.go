package audit

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/kavach-sec/kavach/internal/config"
)

func TestAuditDetectsTamperEnvDotEnvAndMCP(t *testing.T) {
	kavachDir := t.TempDir()
	workDir := t.TempDir()

	// Write a fake manifest pointing to a modified settings file
	settingsPath := filepath.Join(workDir, "settings.json")
	_ = os.WriteFile(settingsPath, []byte(`{"hooks":{}}`), 0o600)
	manifest := `{
  "installs": {
    "` + filepath.ToSlash(settingsPath) + `": {
      "settings_path": "` + filepath.ToSlash(settingsPath) + `",
      "settings_sha256": "0000000000000000000000000000000000000000000000000000000000000000"
    }
  }
}`
	_ = os.WriteFile(filepath.Join(kavachDir, "install_manifest.json"), []byte(manifest), 0o600)

	// Permissive .env and unreviewed .mcp.json
	_ = os.WriteFile(filepath.Join(workDir, ".env"), []byte("API_KEY=dummy\n"), 0o644)
	_ = os.WriteFile(filepath.Join(workDir, ".mcp.json"), []byte(`{"mcpServers":{"sketchy-mcp":{"command":"node"}}}`), 0o600)

	// Fake env var with canary key
	t.Setenv("KAVACH_TEST_AWS_KEY", "AKIAIOSFODNN7EXAMPLE")

	rep := RunFull(kavachDir, workDir, config.DefaultPolicy())
	if !rep.Tampered {
		t.Fatal("expected Tampered=true for mismatched install manifest hash")
	}
	if rep.Score >= 100 {
		t.Fatalf("expected hygiene score < 100, got %d", rep.Score)
	}
	if len(rep.Findings) < 3 {
		t.Fatalf("expected >= 3 audit findings, got %d: %+v", len(rep.Findings), rep.Findings)
	}
}
