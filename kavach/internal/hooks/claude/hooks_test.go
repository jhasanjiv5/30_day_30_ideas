package claude

import (
	"bytes"
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/kavach-sec/kavach/internal/engine"
	"github.com/kavach-sec/kavach/internal/types"
)

func TestPostToolUseWithholdsFlaggedUnstructuredToolOutput(t *testing.T) {
	verdict := types.Verdict{
		Action:  types.ActionBlock,
		Summary: "prompt injection detected",
		Findings: []types.Finding{{
			Category: types.CategoryIndirectInject,
		}},
	}

	for _, toolName := range []string{"WebFetch", "Read"} {
		t.Run(toolName, func(t *testing.T) {
			out := formatOutput(types.EventPostToolUse, HookInput{
				ToolName:     toolName,
				ToolResponse: json.RawMessage(`{"body":"untrusted content"}`),
			}, verdict)
			if out == nil {
				t.Fatal("expected hook output")
			}
			updated, ok := out.HookSpecificOutput["updatedToolOutput"].(map[string]any)
			if !ok {
				t.Fatalf("expected updatedToolOutput map, got %#v", out.HookSpecificOutput["updatedToolOutput"])
			}
			if updated["kavach_withheld"] != true {
				t.Fatalf("expected flagged output to be withheld, got %#v", updated)
			}
		})
	}
}

func TestPostToolUseWithholdsBashOutputWhenRedactionIsUnavailable(t *testing.T) {
	out := formatOutput(types.EventPostToolUse, HookInput{
		ToolName:     "Bash",
		ToolResponse: json.RawMessage(`{"stdout":"sensitive test content","stderr":""}`),
	}, types.Verdict{
		Action:  types.ActionBlock,
		Summary: "sensitive content detected",
		Findings: []types.Finding{{
			Category: types.CategorySecrets,
		}},
	})
	if out == nil {
		t.Fatal("expected hook output")
	}
	updated, ok := out.HookSpecificOutput["updatedToolOutput"].(map[string]any)
	if !ok {
		t.Fatalf("expected updatedToolOutput map, got %#v", out.HookSpecificOutput["updatedToolOutput"])
	}
	stdout, ok := updated["stdout"].(string)
	if !ok {
		t.Fatalf("expected replacement stdout string, got %#v", updated["stdout"])
	}
	if strings.Contains(stdout, "sensitive test content") {
		t.Fatalf("raw content was not withheld: %#v", updated)
	}
}

func TestInstallUninstallRoundTripByteForByteAndTamperCheck(t *testing.T) {
	kavachDir := t.TempDir()
	projDir := t.TempDir()
	claudeDir := filepath.Join(projDir, ".claude")
	if err := os.MkdirAll(claudeDir, 0o755); err != nil {
		t.Fatalf("mkdir: %v", err)
	}
	settingsPath := filepath.Join(claudeDir, "settings.json")
	original := []byte("{\n  \"theme\": \"dark\",\n  \"hooks\": {\n    \"PostToolUse\": [\n      {\n        \"matcher\": \"Edit\",\n        \"hooks\": [{\"type\": \"command\", \"command\": \"gofmt -w .\"}]\n      }\n    ]\n  }\n}\n")
	if err := os.WriteFile(settingsPath, original, 0o640); err != nil {
		t.Fatalf("write original settings: %v", err)
	}

	entry, err := Install(ScopeProject, projDir, kavachDir, "/usr/local/bin/kavach")
	if err != nil {
		t.Fatalf("Install: %v", err)
	}
	if entry.SettingsPath != settingsPath {
		t.Fatalf("SettingsPath mismatch: %s vs %s", entry.SettingsPath, settingsPath)
	}

	// Verify existing non-Kavach hook preserved alongside Kavach hooks.
	afterInstall, err := os.ReadFile(settingsPath)
	if err != nil {
		t.Fatalf("read installed settings: %v", err)
	}
	if !strings.Contains(string(afterInstall), "gofmt -w .") || !strings.Contains(string(afterInstall), "kavach hook PreToolUse") {
		t.Fatalf("installed settings missing expected hooks:\n%s", string(afterInstall))
	}

	// Verify tamper check passes initially.
	installed, tampered, err := VerifyIntegrity(kavachDir)
	if err != nil || !installed || len(tampered) != 0 {
		t.Fatalf("VerifyIntegrity initial = installed:%v tampered:%v err:%v", installed, tampered, err)
	}

	// Mutate settings.json and ensure tamper check catches it!
	if err := os.WriteFile(settingsPath, []byte(`{"hooks":{}}`), 0o640); err != nil {
		t.Fatalf("tamper write: %v", err)
	}
	_, tampered, err = VerifyIntegrity(kavachDir)
	if err != nil || len(tampered) != 1 {
		t.Fatalf("expected tamper check to flag modified settings.json, got tampered=%v err=%v", tampered, err)
	}

	// Uninstall must restore exact original bytes!
	if _, err := Uninstall(ScopeProject, projDir, kavachDir); err != nil {
		t.Fatalf("Uninstall: %v", err)
	}
	restored, err := os.ReadFile(settingsPath)
	if err != nil {
		t.Fatalf("read restored: %v", err)
	}
	if !bytes.Equal(restored, original) {
		t.Fatalf("restored settings did not match original byte-for-byte!\ngot:\n%s\nwant:\n%s", restored, original)
	}
}

func TestHandleHookUserPromptSubmitSecretBlockedWithSuppressOriginalPrompt(t *testing.T) {
	kavachDir := t.TempDir()
	eng, err := engine.New(engine.Options{KavachDir: kavachDir})
	if err != nil {
		t.Fatalf("engine.New: %v", err)
	}

	payload := map[string]any{
		"session_id":      "sess-1",
		"hook_event_name": "UserPromptSubmit",
		"prompt":          "Deploy using AKIAIOSFODNN7EXAMPLE please",
	}
	raw, _ := json.Marshal(payload)

	out, verdict, err := HandleHook(context.Background(), eng, kavachDir, "UserPromptSubmit", raw)
	if err != nil {
		t.Fatalf("HandleHook: %v", err)
	}
	if verdict.Action != "BLOCK" || out == nil || out.Decision != "block" {
		t.Fatalf("expected BLOCK decision, got verdict=%+v out=%+v", verdict, out)
	}
	if strings.Contains(out.Reason, "AKIAIOSFODNN7EXAMPLE") {
		t.Fatalf("hook output leaked raw secret: %s", out.Reason)
	}
	if out.HookSpecificOutput["suppressOriginalPrompt"] != true {
		t.Fatalf("expected suppressOriginalPrompt=true, got %+v", out.HookSpecificOutput)
	}
}

func TestUninstallPreservesPostInstallModesAppsAndHooks(t *testing.T) {
	kavachDir := t.TempDir()
	projDir := t.TempDir()
	claudeDir := filepath.Join(projDir, ".claude")
	if err := os.MkdirAll(claudeDir, 0o755); err != nil {
		t.Fatalf("mkdir: %v", err)
	}
	settingsPath := filepath.Join(claudeDir, "settings.json")
	original := []byte("{\n  \"theme\": \"dark\"\n}\n")
	if err := os.WriteFile(settingsPath, original, 0o600); err != nil {
		t.Fatalf("write original: %v", err)
	}

	if _, err := Install(ScopeProject, projDir, kavachDir, "/usr/local/bin/kavach"); err != nil {
		t.Fatalf("Install: %v", err)
	}

	// Simulate user installing modes, MCP apps, plugins, and another hook AFTER installing Kavach.
	raw, err := os.ReadFile(settingsPath)
	if err != nil {
		t.Fatalf("read after install: %v", err)
	}
	var root map[string]any
	if err := json.Unmarshal(raw, &root); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}
	root["permissionMode"] = "plan"
	root["mcpServers"] = map[string]any{
		"trusted-postgres": map[string]any{"command": "npx", "args": []string{"-y", "@modelcontextprotocol/server-postgres"}},
	}
	root["enabledPlugins"] = map[string]any{"custom-mode@team": true}

	hooksMap := root["hooks"].(map[string]any)
	preList := hooksMap["PreToolUse"].([]any)
	preList = append(preList, map[string]any{
		"matcher": "Write",
		"hooks":   []any{map[string]any{"type": "command", "command": "prettier --write"}},
	})
	// Also append a user hook inside the same group as Kavach to ensure group-level sharing is safe.
	firstGroup := preList[0].(map[string]any)
	firstGroup["hooks"] = append(firstGroup["hooks"].([]any), map[string]any{
		"type":    "command",
		"command": "echo user-hook-kept",
	})
	hooksMap["PreToolUse"] = preList

	updatedBytes, _ := json.MarshalIndent(root, "", "  ")
	if err := os.WriteFile(settingsPath, updatedBytes, 0o600); err != nil {
		t.Fatalf("write post-install edits: %v", err)
	}

	res, err := UninstallWithOptions(ScopeProject, projDir, kavachDir, UninstallOptions{})
	if err != nil {
		t.Fatalf("UninstallWithOptions: %v", err)
	}
	if res.Strategy != "surgical_merge" {
		t.Fatalf("expected surgical_merge strategy, got %q", res.Strategy)
	}
	if res.HooksRemoved != 4 {
		t.Fatalf("expected 4 Kavach hooks removed, got %d", res.HooksRemoved)
	}

	afterBytes, err := os.ReadFile(settingsPath)
	if err != nil {
		t.Fatalf("read after uninstall: %v", err)
	}
	afterStr := string(afterBytes)
	if strings.Contains(afterStr, "kavach hook ") {
		t.Fatalf("Kavach hooks were not removed:\n%s", afterStr)
	}
	for _, want := range []string{"\"permissionMode\": \"plan\"", "trusted-postgres", "custom-mode@team", "prettier --write", "user-hook-kept", "\"theme\": \"dark\""} {
		if !strings.Contains(afterStr, want) {
			t.Fatalf("post-install setting %q was lost during uninstall!\n%s", want, afterStr)
		}
	}
}

func TestUninstallPreservesCreatedFileIfUserAddedSettingsAfterInstall(t *testing.T) {
	kavachDir := t.TempDir()
	projDir := t.TempDir()
	settingsPath, _ := SettingsPath(ScopeProject, projDir)

	if _, err := Install(ScopeProject, projDir, kavachDir, "/usr/local/bin/kavach"); err != nil {
		t.Fatalf("Install: %v", err)
	}

	// User adds an app config after install into previously nonexistent settings.json.
	raw, _ := os.ReadFile(settingsPath)
	var root map[string]any
	_ = json.Unmarshal(raw, &root)
	root["mcpServers"] = map[string]any{"local-docs": map[string]any{"command": "docs-mcp"}}
	b, _ := json.MarshalIndent(root, "", "  ")
	_ = os.WriteFile(settingsPath, b, 0o600)

	res, err := UninstallWithOptions(ScopeProject, projDir, kavachDir, UninstallOptions{})
	if err != nil {
		t.Fatalf("UninstallWithOptions: %v", err)
	}
	if res.Strategy != "surgical_merge" {
		t.Fatalf("expected surgical_merge, got %q", res.Strategy)
	}

	afterBytes, err := os.ReadFile(settingsPath)
	if err != nil {
		t.Fatalf("settings.json should not be deleted when user settings exist: %v", err)
	}
	afterStr := string(afterBytes)
	if strings.Contains(afterStr, "kavach hook") || !strings.Contains(afterStr, "local-docs") {
		t.Fatalf("unexpected settings after uninstall:\n%s", afterStr)
	}
}

func TestUninstallAllCleansAllRecordedScopes(t *testing.T) {
	kavachDir := t.TempDir()
	proj1 := t.TempDir()
	proj2 := t.TempDir()

	if _, err := Install(ScopeProject, proj1, kavachDir, "kavach"); err != nil {
		t.Fatalf("Install proj1: %v", err)
	}
	if _, err := Install(ScopeProject, proj2, kavachDir, "kavach"); err != nil {
		t.Fatalf("Install proj2: %v", err)
	}

	results, err := UninstallAll(kavachDir, UninstallOptions{})
	if err != nil {
		t.Fatalf("UninstallAll: %v", err)
	}
	if len(results) != 2 {
		t.Fatalf("expected 2 uninstalled entries, got %d", len(results))
	}
	installed, _, err := VerifyIntegrity(kavachDir)
	if err != nil || installed {
		t.Fatalf("expected 0 installed entries after UninstallAll, got installed=%v err=%v", installed, err)
	}
}
