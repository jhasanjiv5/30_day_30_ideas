package purge

import (
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/jhasanjiv5/30_day_30_ideas/sakha/internal/export"
	"github.com/jhasanjiv5/30_day_30_ideas/sakha/internal/install"
	"github.com/jhasanjiv5/30_day_30_ideas/sakha/internal/store"
)

func write(t *testing.T, path, content string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}
}

// world builds a home with Sakha data, exported skills, a project, and files Sakha doesn't own.
func world(t *testing.T) (home, project string) {
	home = t.TempDir()
	t.Setenv("SAKHA_HOME", filepath.Join(home, ".sakha"))
	project = filepath.Join(home, "code", "app")
	now := time.Date(2026, 11, 2, 0, 0, 0, 0, time.UTC)
	st := &store.State{Analysed: map[string]bool{}, Candidates: []*store.Candidate{
		{ID: "h1", Topic: "writing-tone", Rule: "Use British spelling.", Scope: "global", State: store.StateConfirmed, ConfirmedAt: now},
		{ID: "h2", Topic: "coding", Rule: "Use snake_case.", Scope: project, State: store.StateConfirmed, ConfirmedAt: now},
	}}
	if err := store.Save(st); err != nil {
		t.Fatal(err)
	}
	write(t, filepath.Join(project, "AGENTS.md"), "# Team notes\n\nBe kind.\n")
	if _, err := export.Run(st, export.Options{Targets: export.KnownTargets(), Project: project, Home: home}); err != nil {
		t.Fatal(err)
	}
	// Files that are not Sakha's must survive.
	write(t, filepath.Join(home, ".claude", "skills", "my-skill", "SKILL.md"), "mine")
	write(t, filepath.Join(home, ".claude", "skills", "sakha-lookalike", "SKILL.md"), "named like Sakha but written by me")
	write(t, filepath.Join(project, ".cursor", "rules", "team.mdc"), "team rule")
	return home, project
}

func TestPurgeRemovesOnlyWhatSakhaCreated(t *testing.T) {
	home, project := world(t)
	plan, err := Make(Options{Home: home})
	if err != nil {
		t.Fatal(err)
	}
	got := map[string]string{}
	for _, it := range plan.Items {
		got[it.Path] = it.Kind
	}
	for path, kind := range map[string]string{
		filepath.Join(home, ".claude", "skills", "sakha-writing-tone", "SKILL.md"): KindFile,
		filepath.Join(project, ".claude", "skills", "sakha-coding", "SKILL.md"):    KindFile,
		filepath.Join(project, ".cursor", "rules", "sakha-coding.mdc"):             KindFile,
		filepath.Join(project, "AGENTS.md"):                                        KindSection,
		filepath.Join(project, ".github", "copilot-instructions.md"):               KindSection,
		filepath.Join(home, ".codex", "AGENTS.md"):                                 KindSection,
		filepath.Join(home, ".sakha"):                                              KindDataFolder,
	} {
		if got[path] != kind {
			t.Errorf("plan missing %s (%s); plan: %v", path, kind, got)
		}
	}
	if _, ok := got[filepath.Join(home, ".claude", "skills", "sakha-lookalike", "SKILL.md")]; ok {
		t.Error("a file without Sakha's marker was planned for deletion")
	}

	done, err := Execute(plan, home)
	if err != nil || len(done) != len(plan.Items) {
		t.Fatalf("execute: %d/%d done, err %v", len(done), len(plan.Items), err)
	}
	for _, gone := range []string{
		filepath.Join(home, ".sakha"),
		filepath.Join(home, ".claude", "skills", "sakha-writing-tone"),
		filepath.Join(project, ".cursor", "rules", "sakha-coding.mdc"),
		filepath.Join(home, ".codex", "AGENTS.md"),                   // held only Sakha's section
		filepath.Join(project, ".github", "copilot-instructions.md"), // same
	} {
		if _, err := os.Stat(gone); !os.IsNotExist(err) {
			t.Errorf("%s should be gone", gone)
		}
	}
	for _, kept := range []string{
		filepath.Join(home, ".claude", "skills", "my-skill", "SKILL.md"),
		filepath.Join(home, ".claude", "skills", "sakha-lookalike", "SKILL.md"),
		filepath.Join(project, ".cursor", "rules", "team.mdc"),
	} {
		if _, err := os.Stat(kept); err != nil {
			t.Errorf("%s should survive", kept)
		}
	}
	agents, _ := os.ReadFile(filepath.Join(project, "AGENTS.md"))
	if string(agents) != "# Team notes\n\nBe kind.\n" {
		t.Errorf("user's AGENTS.md not restored exactly: %q", agents)
	}
}

func TestPurgeRefusesWhileHooksInstalled(t *testing.T) {
	home, _ := world(t)
	if _, err := install.Install(install.Target{Tool: "cursor", Home: home, Exe: "/bin/sakha"}); err != nil {
		t.Fatal(err)
	}
	_, err := Make(Options{Home: home})
	var still ErrStillInstalled
	if !errors.As(err, &still) || !strings.Contains(err.Error(), "hooks.json") {
		t.Fatalf("expected a refusal naming hooks.json, got %v", err)
	}
	if _, err := os.Stat(filepath.Join(home, ".sakha")); err != nil {
		t.Fatal("nothing may be deleted when refusing")
	}
}

func TestDataFolderSafetyChecks(t *testing.T) {
	home := t.TempDir()
	for _, bad := range []string{"", "/", home, filepath.Dir(home)} {
		if err := CheckDataFolder(bad, home); err == nil {
			t.Errorf("accepted dangerous path %q", bad)
		}
	}
	// A folder with someone else's files must be refused.
	other := filepath.Join(home, "notes")
	write(t, filepath.Join(other, "state.json"), "{}")
	write(t, filepath.Join(other, "thesis.docx"), "precious")
	if err := CheckDataFolder(other, home); err == nil || !strings.Contains(err.Error(), "thesis.docx") {
		t.Errorf("should refuse a folder with foreign files, got %v", err)
	}
	// An empty folder isn't recognisably Sakha's.
	empty := filepath.Join(home, "empty")
	os.MkdirAll(empty, 0o755)
	if err := CheckDataFolder(empty, home); err == nil {
		t.Error("should refuse a folder without Sakha's files")
	}
	// A symlink is never followed.
	real := filepath.Join(home, "real")
	write(t, filepath.Join(real, "state.json"), "{}")
	link := filepath.Join(home, "link")
	os.Symlink(real, link)
	if err := CheckDataFolder(link, home); err == nil {
		t.Error("should refuse a symlink")
	}
}

func TestPurgeWhenNothingIsThere(t *testing.T) {
	home := t.TempDir()
	t.Setenv("SAKHA_HOME", filepath.Join(home, ".sakha"))
	plan, err := Make(Options{Home: home})
	if err != nil || len(plan.Items) != 0 {
		t.Fatalf("expected an empty plan, got %+v, %v", plan, err)
	}
}

func TestRemoveSection(t *testing.T) {
	cases := map[string]string{
		"intro\n\n" + export.BeginMarker + "\nx\n" + export.EndMarker + "\n\noutro\n": "intro\n\noutro\n",
		export.BeginMarker + "\nx\n" + export.EndMarker + "\n":                        "",
		"intro\n\n" + export.BeginMarker + "\nx\n" + export.EndMarker + "\n":          "intro\n",
	}
	for in, want := range cases {
		if got, ok := export.RemoveSection(in); !ok || got != want {
			t.Errorf("RemoveSection(%q) = %q, want %q", in, got, want)
		}
	}
}
