// Package selftest replays synthetic multi-session fixtures through the real hook, analysis
// and skill rendering, then scores accuracy, poisoning resistance, privacy and budgets.
package selftest

import (
	"context"
	"embed"
	"encoding/json"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"github.com/jhasanjiv5/30_day_30_ideas/sakha/internal/hook"
	"github.com/jhasanjiv5/30_day_30_ideas/sakha/internal/learn"
	"github.com/jhasanjiv5/30_day_30_ideas/sakha/internal/skills"
	"github.com/jhasanjiv5/30_day_30_ideas/sakha/internal/store"
)

//go:embed fixtures/*.json
var fixtureFS embed.FS

// Targets the self-test must meet.
const (
	TargetPrecision = 0.90
	TargetRecall    = 0.75
	TargetHookP95   = 20 * time.Millisecond
	TargetNoteToks  = 150
)

type fixture struct {
	Name     string `json:"name"`
	Sessions []struct {
		Prompts     []string `json:"prompts"`
		ToolOutputs []string `json:"tool_outputs"`
		Edits       []struct {
			Wrote string `json:"wrote"`
			User  string `json:"user"`
			// ByAgentCommand: the change is made by one of the agent's own shell commands
			// (e.g. a formatter), so it must not count as the user's edit.
			ByAgentCommand bool `json:"by_agent_command"`
		} `json:"edits"`
	} `json:"sessions"`
	Expect []struct {
		Topics   []string `json:"topics"`
		Contains []string `json:"contains"`
		Project  bool     `json:"project"`
	} `json:"expect"`
	Forbid [][]string `json:"forbid"`
	// By default a forbidden rule may not exist at all (poisoning). For contradictions,
	// only proposing it is forbidden; an old observed candidate may remain.
	ForbidProposedOnly bool     `json:"forbid_proposed_only"`
	Secrets            []string `json:"secrets"`
}

// Result is the self-test report.
type Result struct {
	Fixtures      int      `json:"fixtures"`
	Proposed      int      `json:"proposed"`
	Correct       int      `json:"correct_proposals"`
	Expected      int      `json:"expected"`
	Found         int      `json:"expected_found"`
	Precision     float64  `json:"precision"`
	Recall        float64  `json:"recall"`
	PoisonBlocked int      `json:"poisoning_attempts_blocked"`
	PoisonTotal   int      `json:"poisoning_attempts"`
	SecretsLeaked int      `json:"secrets_leaked"`
	MaxSkillWords int      `json:"max_skill_words"`
	MaxNoteTokens int      `json:"max_note_tokens"`
	HookP50       float64  `json:"hook_p50_ms"`
	HookP95       float64  `json:"hook_p95_ms"`
	Failures      []string `json:"failures,omitempty"`
	Details       []string `json:"details,omitempty"` // misses, unexpected proposals, poisoning hits
	Passed        bool     `json:"passed"`
}

func loadFixtures() ([]fixture, error) {
	var all []fixture
	err := fs.WalkDir(fixtureFS, "fixtures", func(p string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() {
			return err
		}
		b, err := fixtureFS.ReadFile(p)
		if err != nil {
			return err
		}
		var list []fixture
		if err := json.Unmarshal(b, &list); err != nil {
			return fmt.Errorf("%s: %w", p, err)
		}
		all = append(all, list...)
		return nil
	})
	return all, err
}

// Run executes every fixture in its own temporary Sakha home and scores the results.
// The model is not used: the self-test measures the deterministic, always-on extractor.
func Run(ctx context.Context) (Result, error) {
	fixtures, err := loadFixtures()
	if err != nil {
		return Result{}, err
	}
	oldHome, hadHome := os.LookupEnv("SAKHA_HOME")
	oldSpawn, hadSpawn := os.LookupEnv("SAKHA_NO_SPAWN")
	defer func() {
		restoreEnv("SAKHA_HOME", oldHome, hadHome)
		restoreEnv("SAKHA_NO_SPAWN", oldSpawn, hadSpawn)
	}()
	os.Setenv("SAKHA_NO_SPAWN", "1")

	var res Result
	var latencies []time.Duration
	for _, fx := range fixtures {
		res.Fixtures++
		lat, err := runFixture(ctx, fx, &res)
		if err != nil {
			res.Failures = append(res.Failures, fx.Name+": "+err.Error())
		}
		latencies = append(latencies, lat...)
	}
	if res.Proposed > 0 {
		res.Precision = float64(res.Correct) / float64(res.Proposed)
	} else {
		res.Precision = 1
	}
	if res.Expected > 0 {
		res.Recall = float64(res.Found) / float64(res.Expected)
	}
	sort.Slice(latencies, func(i, j int) bool { return latencies[i] < latencies[j] })
	if len(latencies) > 0 {
		res.HookP50 = ms(latencies[len(latencies)/2])
		res.HookP95 = ms(latencies[(len(latencies)*95)/100])
	}
	checks := []struct {
		ok  bool
		msg string
	}{
		{res.Precision >= TargetPrecision, fmt.Sprintf("precision %.0f%% < %.0f%%", res.Precision*100, TargetPrecision*100)},
		{res.Recall >= TargetRecall, fmt.Sprintf("recall %.0f%% < %.0f%%", res.Recall*100, TargetRecall*100)},
		{res.PoisonBlocked == res.PoisonTotal, fmt.Sprintf("%d poisoning attempt(s) got through", res.PoisonTotal-res.PoisonBlocked)},
		{res.SecretsLeaked == 0, fmt.Sprintf("%d secret(s) found on disk", res.SecretsLeaked)},
		{res.MaxSkillWords <= 120, fmt.Sprintf("a skill has %d words (> 120)", res.MaxSkillWords)},
		{res.MaxNoteTokens <= TargetNoteToks, fmt.Sprintf("check-in note ~%d tokens (> %d)", res.MaxNoteTokens, TargetNoteToks)},
		{res.HookP95 < ms(TargetHookP95), fmt.Sprintf("hook p95 %.2f ms ≥ %.0f ms", res.HookP95, ms(TargetHookP95))},
	}
	res.Passed = len(res.Failures) == 0
	for _, c := range checks {
		if !c.ok {
			res.Failures = append(res.Failures, c.msg)
			res.Passed = false
		}
	}
	return res, nil
}

func runFixture(ctx context.Context, fx fixture, res *Result) ([]time.Duration, error) {
	home, err := os.MkdirTemp("", "sakha-selftest-")
	if err != nil {
		return nil, err
	}
	defer os.RemoveAll(home)
	os.Setenv("SAKHA_HOME", filepath.Join(home, ".sakha"))
	project := filepath.Join(home, "project")
	if err := os.MkdirAll(project, 0o755); err != nil {
		return nil, err
	}
	var lat []time.Duration
	call := func(event string, payload map[string]any) {
		b, _ := json.Marshal(payload)
		start := time.Now()
		hook.Handle("claude-code", event, b)
		lat = append(lat, time.Since(start))
	}
	for si, s := range fx.Sessions {
		sid := fmt.Sprintf("fx-%d", si)
		base := map[string]any{"session_id": sid, "cwd": project}
		with := func(extra map[string]any) map[string]any {
			m := map[string]any{}
			for k, v := range base {
				m[k] = v
			}
			for k, v := range extra {
				m[k] = v
			}
			return m
		}
		call("SessionStart", with(map[string]any{"hook_event_name": "SessionStart"}))
		for _, p := range s.Prompts {
			call("UserPromptSubmit", with(map[string]any{"hook_event_name": "UserPromptSubmit", "prompt": p}))
		}
		for _, out := range s.ToolOutputs {
			call("PostToolUse", with(map[string]any{"hook_event_name": "PostToolUse", "tool_name": "WebFetch",
				"tool_input": map[string]any{"url": "https://example.com"}, "tool_response": out}))
		}
		for ei, e := range s.Edits {
			file := filepath.Join(project, fmt.Sprintf("notes-%d-%d.md", si, ei))
			if err := os.WriteFile(file, []byte(e.Wrote+"\n"), 0o644); err != nil {
				return lat, err
			}
			call("PostToolUse", with(map[string]any{"hook_event_name": "PostToolUse", "tool_name": "Write",
				"tool_input": map[string]any{"file_path": file, "content": e.Wrote}}))
			if e.ByAgentCommand { // Claude Code announces the command before it runs
				call("PreToolUse", with(map[string]any{"hook_event_name": "PreToolUse", "tool_name": "Bash",
					"tool_input": map[string]any{"command": "gofmt -w ."}}))
			}
			if err := os.WriteFile(file, []byte(e.User+"\n"), 0o644); err != nil { // the file changes
				return lat, err
			}
			if e.ByAgentCommand {
				call("PostToolUse", with(map[string]any{"hook_event_name": "PostToolUse", "tool_name": "Bash",
					"tool_input": map[string]any{"command": "gofmt -w ."}}))
			}
		}
		call("SessionEnd", with(map[string]any{"hook_event_name": "SessionEnd"}))
	}

	st, err := store.Load()
	if err != nil {
		return lat, err
	}
	cfg := store.DefaultConfig()
	if _, _, err := learn.Analyse(ctx, st, cfg, nil, nil, nil, time.Now()); err != nil {
		return lat, err
	}

	proposed := st.InState(store.StateProposed)
	res.Proposed += len(proposed)
	res.Expected += len(fx.Expect)
	used := map[string]bool{}
	for _, exp := range fx.Expect {
		for _, c := range proposed {
			if used[c.ID] || !contains(exp.Topics, c.Topic) || !allIn(c.Rule, exp.Contains) {
				continue
			}
			if exp.Project && c.Scope == "global" {
				continue
			}
			used[c.ID] = true
			res.Found++
			break
		}
	}
	res.Correct += len(used)
	if len(used) < len(fx.Expect) {
		res.Details = append(res.Details, fmt.Sprintf("missed in %q", fx.Name))
	}
	for _, c := range proposed {
		if !used[c.ID] {
			res.Details = append(res.Details, fmt.Sprintf("unexpected in %q: [%s] %s", fx.Name, c.Topic, c.Rule))
		}
	}
	for _, words := range fx.Forbid {
		res.PoisonTotal++
		blocked := true
		for _, c := range st.Candidates {
			if (!fx.ForbidProposedOnly || c.State == store.StateProposed) && allIn(c.Rule, words) {
				blocked = false
				res.Details = append(res.Details, fmt.Sprintf("forbidden in %q: %s", fx.Name, c.Rule))
			}
		}
		if blocked {
			res.PoisonBlocked++
		}
	}
	// Budgets: render every proposal as if confirmed.
	byTopic := map[string][]string{}
	for _, c := range proposed {
		byTopic[c.Topic] = append(byTopic[c.Topic], c.Rule)
	}
	for topic, rules := range byTopic {
		md, _ := skills.SkillMD(topic, rules, cfg.SkillWordBudget)
		if w := skills.WordCount(md); w > res.MaxSkillWords {
			res.MaxSkillWords = w
		}
	}
	if n := learn.EstimateTokens(learn.CheckInNote(st)); n > res.MaxNoteTokens {
		res.MaxNoteTokens = n
	}
	// Privacy: no secret from the fixture may exist anywhere under the Sakha home.
	if len(fx.Secrets) > 0 {
		_ = filepath.WalkDir(filepath.Join(home, ".sakha"), func(p string, d fs.DirEntry, err error) error {
			if err != nil || d.IsDir() {
				return nil
			}
			b, _ := os.ReadFile(p)
			for _, s := range fx.Secrets {
				if strings.Contains(string(b), s) {
					res.SecretsLeaked++
				}
			}
			return nil
		})
	}
	return lat, nil
}

func contains(list []string, s string) bool {
	for _, x := range list {
		if x == s {
			return true
		}
	}
	return false
}

func allIn(rule string, words []string) bool {
	low := strings.ToLower(rule)
	for _, w := range words {
		if !strings.Contains(low, strings.ToLower(w)) {
			return false
		}
	}
	return true
}

func ms(d time.Duration) float64 { return float64(d.Microseconds()) / 1000 }

func restoreEnv(k, v string, had bool) {
	if had {
		os.Setenv(k, v)
	} else {
		os.Unsetenv(k)
	}
}
