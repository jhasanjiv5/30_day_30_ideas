package export

import (
	"archive/zip"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/jhasanjiv5/30_day_30_ideas/sakha/internal/skills"
	"github.com/jhasanjiv5/30_day_30_ideas/sakha/internal/store"
)

func confirmedState(project string) *store.State {
	now := time.Date(2026, 11, 2, 0, 0, 0, 0, time.UTC)
	return &store.State{Candidates: []*store.Candidate{
		{ID: "h1", Topic: "writing-tone", Rule: "Use British spelling.", Scope: "global", State: store.StateConfirmed, ConfirmedAt: now},
		{ID: "h2", Topic: "ui-design", Rule: "Prefer Apple-like neutrals with one blue accent.", Scope: "global", State: store.StateConfirmed, ConfirmedAt: now},
		{ID: "h3", Topic: "coding", Rule: "Use snake_case for Python variables.", Scope: project, State: store.StateConfirmed, ConfirmedAt: now},
		{ID: "h4", Topic: "coding", Rule: "Proposed only, not exported.", Scope: "global", State: store.StateProposed},
	}}
}

func TestAllTargetsAndIdempotency(t *testing.T) {
	home := t.TempDir()
	t.Setenv("SAKHA_HOME", filepath.Join(home, ".sakha"))
	project := filepath.Join(home, "proj")
	os.MkdirAll(project, 0o755)
	// Pre-existing user content must survive.
	os.WriteFile(filepath.Join(project, "AGENTS.md"), []byte("# My agent notes\n\nBe kind.\n"), 0o644)

	st := confirmedState(project)
	opt := Options{Targets: KnownTargets(), Project: project, Home: home, Budget: 120}
	res, err := Run(st, opt)
	if err != nil {
		t.Fatal(err)
	}
	want := []string{
		filepath.Join(home, ".claude", "skills", "sakha-writing-tone", "SKILL.md"),
		filepath.Join(home, ".claude", "skills", "sakha-ui-design", "SKILL.md"),
		filepath.Join(project, ".claude", "skills", "sakha-coding", "SKILL.md"),
		filepath.Join(project, ".cursor", "rules", "sakha-coding.mdc"),
		filepath.Join(project, ".github", "copilot-instructions.md"),
		filepath.Join(home, ".codex", "AGENTS.md"),
		filepath.Join(project, "AGENTS.md"),
		filepath.Join(home, ".sakha", "export", "claude-ai", "sakha-ui-design.zip"),
		filepath.Join(home, ".sakha", "export", "claude-ai", "instructions.md"),
	}
	for _, w := range want {
		if _, err := os.Stat(w); err != nil {
			t.Errorf("missing %s", w)
		}
	}
	skill, _ := os.ReadFile(want[0])
	if !strings.HasPrefix(string(skill), "---\nname: sakha-writing-tone\ndescription: ") || !strings.Contains(string(skill), "- Use British spelling.") {
		t.Errorf("unexpected SKILL.md:\n%s", skill)
	}
	if strings.Contains(string(skill), "Proposed only") {
		t.Error("unconfirmed habit exported")
	}
	if _, err := os.Stat(filepath.Join(home, ".claude", "skills", "sakha-coding", "SKILL.md")); err == nil {
		t.Error("project-scoped habit leaked into the global skills")
	}
	agents, _ := os.ReadFile(filepath.Join(project, "AGENTS.md"))
	if !strings.HasPrefix(string(agents), "# My agent notes\n\nBe kind.\n") || !strings.Contains(string(agents), "snake_case") {
		t.Errorf("AGENTS.md user content or section wrong:\n%s", agents)
	}
	zr, err := zip.OpenReader(want[7])
	if err != nil || len(zr.File) != 1 || zr.File[0].Name != "sakha-ui-design/SKILL.md" {
		t.Fatalf("bad claude.ai zip: %v", err)
	}
	zr.Close()

	res2, err := Run(st, opt)
	if err != nil || len(res2.Written) != 0 {
		t.Fatalf("second export should change nothing, wrote %v (err %v)", res2.Written, err)
	}
	_ = res

	// Retiring a habit removes its skill file, and only Sakha-owned files.
	own := filepath.Join(home, ".claude", "skills", "my-own-skill", "SKILL.md")
	os.MkdirAll(filepath.Dir(own), 0o755)
	os.WriteFile(own, []byte("mine"), 0o644)
	st.Candidates[0].State = store.StateRetired
	if _, err := Run(st, opt); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(want[0]); !os.IsNotExist(err) {
		t.Error("retired topic's skill should be removed")
	}
	if _, err := os.Stat(own); err != nil {
		t.Error("a skill Sakha doesn't own was touched")
	}
}

func TestReplaceSection(t *testing.T) {
	text := "intro\n\n" + BeginMarker + "\nold\n" + EndMarker + "\n\noutro\n"
	got := ReplaceSection(text, "new")
	if got != "intro\n\n"+BeginMarker+"\nnew\n"+EndMarker+"\n\noutro\n" {
		t.Fatalf("got %q", got)
	}
	if ReplaceSection(got, "new") != got {
		t.Fatal("not idempotent")
	}
}

func TestWordBudget(t *testing.T) {
	var rules []string
	for i := 0; i < 40; i++ {
		rules = append(rules, "Rule number with several extra words to fill space.")
	}
	md, dropped := skills.SkillMD("coding", rules, 120)
	if skills.WordCount(md) > 120 || dropped == 0 {
		t.Fatalf("budget not enforced: %d words, %d dropped", skills.WordCount(md), dropped)
	}
}
