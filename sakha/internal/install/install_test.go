package install

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func setup(t *testing.T) string {
	home := t.TempDir()
	t.Setenv("SAKHA_HOME", filepath.Join(home, ".sakha"))
	return home
}

func TestClaudeInstallKeepsOtherHooksAndUninstallRestoresBytes(t *testing.T) {
	home := setup(t)
	settings := filepath.Join(home, ".claude", "settings.json")
	os.MkdirAll(filepath.Dir(settings), 0o755)
	original := `{
    "theme": "dark",
    "hooks": {"PreToolUse": [{"matcher": "Bash", "hooks": [{"type": "command", "command": "kavach hook PreToolUse"}]}]}
}
`
	os.WriteFile(settings, []byte(original), 0o644)
	tg := Target{Tool: "claude-code", Home: home, Exe: "/usr/local/bin/sakha"}

	if _, err := Install(tg); err != nil {
		t.Fatal(err)
	}
	if _, err := Install(tg); err != nil { // idempotent
		t.Fatal(err)
	}
	b, _ := os.ReadFile(settings)
	s := string(b)
	if strings.Count(s, "hook --tool claude-code UserPromptSubmit") != 1 || strings.Count(s, "hook --tool claude-code PreToolUse") != 1 || !strings.Contains(s, "kavach hook PreToolUse") || !strings.Contains(s, `"theme": "dark"`) {
		t.Fatalf("bad install:\n%s", s)
	}
	if !Installed(tg) {
		t.Fatal("Installed should be true")
	}
	if _, err := Uninstall(tg); err != nil {
		t.Fatal(err)
	}
	b, _ = os.ReadFile(settings)
	if string(b) != original {
		t.Fatalf("uninstall did not restore the original bytes:\n%s", b)
	}
}

func TestClaudeUninstallKeepsLaterUserChanges(t *testing.T) {
	home := setup(t)
	tg := Target{Tool: "claude-code", Home: home, Exe: "/bin/sakha"}
	settings := filepath.Join(home, ".claude", "settings.json")
	if _, err := Install(tg); err != nil {
		t.Fatal(err)
	}
	b, _ := os.ReadFile(settings)
	os.WriteFile(settings, []byte(strings.Replace(string(b), "{", "{\n  \"model\": \"opus\",", 1)), 0o644)
	if _, err := Uninstall(tg); err != nil {
		t.Fatal(err)
	}
	b, _ = os.ReadFile(settings)
	if strings.Contains(string(b), "sakha") || !strings.Contains(string(b), `"model": "opus"`) {
		t.Fatalf("wrong result:\n%s", b)
	}
}

func TestFileThatDidNotExistIsRemovedAgain(t *testing.T) {
	home := setup(t)
	tg := Target{Tool: "cursor", Home: home, Exe: "/bin/sakha"}
	path, err := Install(tg)
	if err != nil {
		t.Fatal(err)
	}
	b, _ := os.ReadFile(path)
	for _, ev := range []string{"beforeSubmitPrompt", "afterFileEdit", "stop"} {
		if !strings.Contains(string(b), ev) {
			t.Errorf("cursor hooks missing %s", ev)
		}
	}
	if _, err := Uninstall(tg); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(path); !os.IsNotExist(err) {
		t.Fatal("hooks.json should be gone again")
	}
}

func TestCodexNotify(t *testing.T) {
	home := setup(t)
	cfg := filepath.Join(home, ".codex", "config.toml")
	os.MkdirAll(filepath.Dir(cfg), 0o755)
	original := "model = \"o4\"\n\n[profiles.fast]\nmodel = \"mini\"\n"
	os.WriteFile(cfg, []byte(original), 0o644)
	tg := Target{Tool: "codex", Home: home, Exe: "/bin/sakha"}
	if _, err := Install(tg); err != nil {
		t.Fatal(err)
	}
	b, _ := os.ReadFile(cfg)
	if !strings.HasPrefix(string(b), codexMarker+"\nnotify = [") {
		t.Fatalf("notify must be a top-level key at the top:\n%s", b)
	}
	if _, err := Uninstall(tg); err != nil {
		t.Fatal(err)
	}
	b, _ = os.ReadFile(cfg)
	if string(b) != original {
		t.Fatalf("not restored:\n%q", b)
	}

	os.WriteFile(cfg, []byte("notify = [\"other\"]\n"), 0o644)
	os.RemoveAll(filepath.Join(home, ".sakha"))
	if _, err := Install(tg); err == nil {
		t.Fatal("must refuse to replace an existing notify program")
	}
}

func TestInvalidJSONIsLeftAlone(t *testing.T) {
	home := setup(t)
	settings := filepath.Join(home, ".claude", "settings.json")
	os.MkdirAll(filepath.Dir(settings), 0o755)
	os.WriteFile(settings, []byte("{ not json"), 0o644)
	if _, err := Install(Target{Tool: "claude-code", Home: home, Exe: "/bin/sakha"}); err == nil {
		t.Fatal("expected an error")
	}
	b, _ := os.ReadFile(settings)
	if string(b) != "{ not json" {
		t.Fatal("broken config was modified")
	}
}

func TestReinstallUpgradesMatcher(t *testing.T) {
	home := setup(t)
	settings := filepath.Join(home, ".claude", "settings.json")
	old := `{"hooks":{"PostToolUse":[{"matcher":"Edit|Write|MultiEdit|NotebookEdit","hooks":[{"type":"command","command":"\"/bin/sakha\" hook --tool claude-code PostToolUse"}]},{"matcher":"Bash","hooks":[{"type":"command","command":"other-tool"}]}]}}`
	os.MkdirAll(filepath.Dir(settings), 0o755)
	os.WriteFile(settings, []byte(old), 0o644)
	if _, err := Install(Target{Tool: "claude-code", Home: home, Exe: "/bin/sakha"}); err != nil {
		t.Fatal(err)
	}
	b, _ := os.ReadFile(settings)
	s := string(b)
	if !strings.Contains(s, PostToolUseMatcher) || strings.Count(s, "hook --tool claude-code PostToolUse") != 1 || !strings.Contains(s, `"matcher": "Bash"`) {
		t.Fatalf("matcher not upgraded cleanly:\n%s", s)
	}
}
