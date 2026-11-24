// Package install adds and removes Sakha's hooks in each agent's config, backing up first
// and never disturbing hooks or settings that belong to anything else.
package install

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"time"

	"github.com/jhasanjiv5/30_day_30_ideas/sakha/internal/paths"
)

// Target describes where hooks are installed.
type Target struct {
	Tool    string // claude-code, cursor, codex
	Project string // for claude-code project scope; empty = user scope
	Home    string // defaults to $HOME
	Exe     string // path of the sakha binary
}

func (t Target) home() string {
	if t.Home != "" {
		return t.Home
	}
	return paths.UserHome()
}

// ConfigPath is the agent config file Sakha edits.
func (t Target) ConfigPath() string {
	switch t.Tool {
	case "claude-code":
		if t.Project != "" {
			return filepath.Join(t.Project, ".claude", "settings.json")
		}
		return filepath.Join(t.home(), ".claude", "settings.json")
	case "cursor":
		return filepath.Join(t.home(), ".cursor", "hooks.json")
	case "codex":
		return filepath.Join(t.home(), ".codex", "config.toml")
	}
	return ""
}

// record remembers what the config looked like before install, for an exact restore.
type record struct {
	Config  string    `json:"config"`
	Existed bool      `json:"existed"`
	Backup  string    `json:"backup"`
	At      time.Time `json:"at"`
}

func recordPath(t Target) string {
	key := strings.NewReplacer("/", "_", ":", "_", "\\", "_").Replace(t.ConfigPath())
	return paths.Join("backups", "install-"+t.Tool+"-"+key+".json")
}

func command(t Target, event string) string {
	return fmt.Sprintf("%q hook --tool %s %s", t.Exe, t.Tool, event)
}

// isOurs recognises a hook command written by Sakha.
func isOurs(cmd string) bool {
	return strings.Contains(cmd, "sakha") && strings.Contains(cmd, " hook --tool ")
}

// Install adds the hooks. It is idempotent.
func Install(t Target) (string, error) {
	if err := paths.Ensure(); err != nil {
		return "", err
	}
	cfgPath := t.ConfigPath()
	if cfgPath == "" {
		return "", fmt.Errorf("unknown tool %q (use claude-code, cursor or codex)", t.Tool)
	}
	old, err := os.ReadFile(cfgPath)
	existed := err == nil
	if err != nil && !errors.Is(err, os.ErrNotExist) {
		return "", err
	}
	if _, statErr := os.Stat(recordPath(t)); errors.Is(statErr, os.ErrNotExist) {
		backup := paths.Join("backups", fmt.Sprintf("%s-%s.bak", t.Tool, time.Now().UTC().Format("20060102T150405")))
		if existed {
			if err := os.WriteFile(backup, old, 0o600); err != nil {
				return "", err
			}
		}
		rec, _ := json.MarshalIndent(record{Config: cfgPath, Existed: existed, Backup: backup, At: time.Now().UTC()}, "", "  ")
		if err := os.WriteFile(recordPath(t), rec, 0o600); err != nil {
			return "", err
		}
	}
	var updated []byte
	switch t.Tool {
	case "claude-code":
		updated, err = addClaude(old, t)
	case "cursor":
		updated, err = addCursor(old, t)
	case "codex":
		updated, err = addCodex(old, t)
	}
	if err != nil {
		return "", err
	}
	if bytes.Equal(old, updated) {
		return cfgPath, nil
	}
	if err := os.MkdirAll(filepath.Dir(cfgPath), 0o755); err != nil {
		return "", err
	}
	return cfgPath, os.WriteFile(cfgPath, updated, 0o644)
}

// Uninstall removes only Sakha's hooks. If nothing else changed since install,
// the original file is restored byte for byte (or removed if it didn't exist).
func Uninstall(t Target) (string, error) {
	cfgPath := t.ConfigPath()
	cur, err := os.ReadFile(cfgPath)
	if errors.Is(err, os.ErrNotExist) {
		return cfgPath, nil
	}
	if err != nil {
		return "", err
	}
	var cleaned []byte
	switch t.Tool {
	case "claude-code", "cursor":
		cleaned, err = removeJSONHooks(cur)
	case "codex":
		cleaned = removeCodex(cur)
	default:
		return "", fmt.Errorf("unknown tool %q", t.Tool)
	}
	if err != nil {
		return "", err
	}
	if b, rerr := os.ReadFile(recordPath(t)); rerr == nil {
		var rec record
		if json.Unmarshal(b, &rec) == nil {
			orig := []byte{}
			if rec.Existed {
				orig, _ = os.ReadFile(rec.Backup)
			}
			if sameContent(t.Tool, cleaned, orig) {
				_ = os.Remove(recordPath(t))
				if !rec.Existed {
					return cfgPath, os.Remove(cfgPath)
				}
				return cfgPath, os.WriteFile(cfgPath, orig, 0o644)
			}
		}
		_ = os.Remove(recordPath(t))
	}
	return cfgPath, os.WriteFile(cfgPath, cleaned, 0o644)
}

// Installed reports whether Sakha's hooks are present.
func Installed(t Target) bool {
	b, err := os.ReadFile(t.ConfigPath())
	return err == nil && strings.Contains(string(b), "hook --tool "+t.Tool)
}

func sameContent(tool string, a, b []byte) bool {
	if tool == "codex" {
		return bytes.Equal(bytes.TrimSpace(a), bytes.TrimSpace(b))
	}
	var va, vb any
	if len(bytes.TrimSpace(a)) == 0 {
		a = []byte("{}")
	}
	if len(bytes.TrimSpace(b)) == 0 {
		b = []byte("{}")
	}
	if json.Unmarshal(a, &va) != nil || json.Unmarshal(b, &vb) != nil {
		return false
	}
	// Cursor's "version" key is added by Sakha when it creates hooks.json; ignore it if the original lacked it.
	if ma, ok := va.(map[string]any); ok && tool == "cursor" {
		if mb, ok := vb.(map[string]any); ok {
			if _, had := mb["version"]; !had {
				delete(ma, "version")
			}
		}
	}
	return reflect.DeepEqual(va, vb)
}

func parseObject(b []byte) (map[string]any, error) {
	m := map[string]any{}
	if len(bytes.TrimSpace(b)) == 0 {
		return m, nil
	}
	if err := json.Unmarshal(b, &m); err != nil {
		return nil, fmt.Errorf("config is not valid JSON, leaving it untouched: %w", err)
	}
	return m, nil
}

func marshal(m map[string]any) ([]byte, error) {
	b, err := json.MarshalIndent(m, "", "  ")
	if err != nil {
		return nil, err
	}
	return append(b, '\n'), nil
}

// addClaude adds Sakha's Claude Code hooks to settings.json.
func addClaude(old []byte, t Target) ([]byte, error) {
	m, err := parseObject(old)
	if err != nil {
		return nil, err
	}
	hooks, _ := m["hooks"].(map[string]any)
	if hooks == nil {
		hooks = map[string]any{}
	}
	events := []struct{ name, matcher string }{
		{"UserPromptSubmit", ""},
		{"PreToolUse", "Bash"},
		{"PostToolUse", PostToolUseMatcher},
		{"SessionStart", ""},
		{"SessionEnd", ""},
	}
	for _, ev := range events {
		groups, _ := hooks[ev.name].([]any)
		if hasOurs(groups) {
			updateOurMatcher(groups, ev.matcher) // upgrade older installs in place
			continue
		}
		group := map[string]any{"hooks": []any{map[string]any{"type": "command", "command": command(t, ev.name), "timeout": 5}}}
		if ev.matcher != "" {
			group["matcher"] = ev.matcher
		}
		hooks[ev.name] = append(groups, group)
	}
	m["hooks"] = hooks
	return marshal(m)
}

func hasOurs(groups []any) bool {
	for _, g := range groups {
		gm, _ := g.(map[string]any)
		if gm == nil {
			continue
		}
		if cmd, _ := gm["command"].(string); isOurs(cmd) {
			return true
		}
		inner, _ := gm["hooks"].([]any)
		for _, h := range inner {
			hm, _ := h.(map[string]any)
			if cmd, _ := hm["command"].(string); isOurs(cmd) {
				return true
			}
		}
	}
	return false
}

// addCursor adds hooks to ~/.cursor/hooks.json (Cursor's hooks format).
func addCursor(old []byte, t Target) ([]byte, error) {
	m, err := parseObject(old)
	if err != nil {
		return nil, err
	}
	if _, ok := m["version"]; !ok {
		m["version"] = 1
	}
	hooks, _ := m["hooks"].(map[string]any)
	if hooks == nil {
		hooks = map[string]any{}
	}
	for _, ev := range []string{"beforeSubmitPrompt", "afterFileEdit", "stop"} {
		list, _ := hooks[ev].([]any)
		if hasOurs(list) {
			continue
		}
		hooks[ev] = append(list, map[string]any{"command": command(t, ev)})
	}
	m["hooks"] = hooks
	return marshal(m)
}

// removeJSONHooks strips Sakha's entries from Claude Code or Cursor hook config.
func removeJSONHooks(cur []byte) ([]byte, error) {
	m, err := parseObject(cur)
	if err != nil {
		return nil, err
	}
	hooks, _ := m["hooks"].(map[string]any)
	for name, v := range hooks {
		list, _ := v.([]any)
		var kept []any
		for _, g := range list {
			gm, _ := g.(map[string]any)
			if gm == nil {
				kept = append(kept, g)
				continue
			}
			if cmd, _ := gm["command"].(string); isOurs(cmd) {
				continue // Cursor-style entry
			}
			if inner, ok := gm["hooks"].([]any); ok {
				var keptInner []any
				for _, h := range inner {
					hm, _ := h.(map[string]any)
					if cmd, _ := hm["command"].(string); isOurs(cmd) {
						continue
					}
					keptInner = append(keptInner, h)
				}
				if len(keptInner) == 0 {
					continue
				}
				gm["hooks"] = keptInner
			}
			kept = append(kept, gm)
		}
		if len(kept) == 0 {
			delete(hooks, name)
		} else {
			hooks[name] = kept
		}
	}
	if hooks != nil && len(hooks) == 0 {
		delete(m, "hooks")
	}
	return marshal(m)
}

const codexMarker = "# added by sakha (remove with `sakha uninstall --tool codex`)"

// addCodex sets Codex's `notify` program. Codex allows only one, so an existing one is never replaced.
func addCodex(old []byte, t Target) ([]byte, error) {
	text := string(old)
	if strings.Contains(text, codexMarker) {
		return old, nil
	}
	for _, line := range strings.Split(text, "\n") {
		if strings.HasPrefix(strings.TrimSpace(line), "notify") {
			return nil, errors.New("Codex already has a `notify` program in config.toml; Sakha won't replace it. " +
				"Remove it first, or call `sakha hook --tool codex notify` from your own notify script")
		}
	}
	entry := fmt.Sprintf("%s\nnotify = [%q, \"hook\", \"--tool\", \"codex\", \"notify\"]\n", codexMarker, t.Exe)
	// Top-level keys must come before the first [table], so the entry goes at the top.
	if text == "" {
		return []byte(entry), nil
	}
	return []byte(entry + "\n" + text), nil
}

func removeCodex(cur []byte) []byte {
	lines := strings.Split(string(cur), "\n")
	var out []string
	for i := 0; i < len(lines); i++ {
		if lines[i] == codexMarker {
			i++ // skip the notify line too
			if i+1 < len(lines) && lines[i+1] == "" {
				i++
			}
			continue
		}
		out = append(out, lines[i])
	}
	return []byte(strings.Join(out, "\n"))
}

// PostToolUseMatcher: file-writing tools (to snapshot what the agent wrote) and Bash (so changes
// the agent's own commands make aren't mistaken for the user's edits).
const PostToolUseMatcher = "Edit|Write|MultiEdit|NotebookEdit|Bash"

// updateOurMatcher sets the matcher on Sakha's own hook group, leaving other groups alone.
func updateOurMatcher(groups []any, matcher string) {
	if matcher == "" {
		return
	}
	for _, g := range groups {
		gm, _ := g.(map[string]any)
		inner, _ := gm["hooks"].([]any)
		for _, h := range inner {
			hm, _ := h.(map[string]any)
			if cmd, _ := hm["command"].(string); isOurs(cmd) {
				gm["matcher"] = matcher
			}
		}
	}
}
