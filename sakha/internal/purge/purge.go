// Package purge removes everything Sakha created: its data folder, the skill and rule files it
// wrote, and its marked sections in shared files. It plans first (so the user can see exactly
// what goes), refuses while any tool still has Sakha's hooks, and only touches files that carry
// Sakha's markers.
package purge

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/jhasanjiv5/30_day_30_ideas/sakha/internal/export"
	"github.com/jhasanjiv5/30_day_30_ideas/sakha/internal/install"
	"github.com/jhasanjiv5/30_day_30_ideas/sakha/internal/paths"
	"github.com/jhasanjiv5/30_day_30_ideas/sakha/internal/skills"
	"github.com/jhasanjiv5/30_day_30_ideas/sakha/internal/store"
)

// Kinds of items in a plan.
const (
	KindDataFolder = "data folder" // the whole Sakha data folder
	KindFile       = "file"        // a skill or rule file Sakha wrote
	KindSection    = "section"     // Sakha's marked section inside a shared file
)

// Item is one thing the purge will remove.
type Item struct {
	Kind string
	Path string
}

// Plan lists what would be removed.
type Plan struct {
	Items []Item
}

// Options configures planning (Home defaults to $HOME; tests set it).
type Options struct {
	Home     string
	Projects []string // extra project folders to clean (e.g. --project)
}

// ErrStillInstalled means another tool still has Sakha's hooks.
type ErrStillInstalled struct{ Configs []string }

func (e ErrStillInstalled) Error() string {
	return "Sakha's hooks are still installed in: " + strings.Join(e.Configs, ", ") +
		". Uninstall those first (sakha uninstall --tool …), then purge."
}

// knownEntries are names that prove a folder is Sakha's data folder.
var knownEntries = []string{"state.json", "config.json", "queue", "backups", "history", "writes", "export"}

// CheckDataFolder refuses anything that doesn't look like Sakha's own data folder.
func CheckDataFolder(dir, home string) error {
	if dir == "" {
		return errors.New("data folder path is empty")
	}
	abs, err := filepath.Abs(dir)
	if err != nil {
		return err
	}
	abs = filepath.Clean(abs)
	homeAbs, _ := filepath.Abs(home)
	homeAbs = filepath.Clean(homeAbs)
	if abs == string(filepath.Separator) || abs == homeAbs || strings.HasPrefix(homeAbs+string(filepath.Separator), abs+string(filepath.Separator)) {
		return fmt.Errorf("refusing to delete %s: it is the root, your home folder, or contains it", abs)
	}
	if len(strings.Split(strings.Trim(abs, string(filepath.Separator)), string(filepath.Separator))) < 2 {
		return fmt.Errorf("refusing to delete %s: path is too short to be Sakha's data folder", abs)
	}
	info, err := os.Lstat(abs)
	if err != nil {
		return err
	}
	if !info.IsDir() || info.Mode()&os.ModeSymlink != 0 {
		return fmt.Errorf("refusing to delete %s: not a real folder", abs)
	}
	entries, err := os.ReadDir(abs)
	if err != nil {
		return err
	}
	known := map[string]bool{}
	for _, k := range knownEntries {
		known[k] = true
	}
	found := false
	for _, e := range entries {
		switch {
		case known[e.Name()]:
			found = true
		case e.Name() == "state.lock" || e.Name() == "sakha.log" || e.Name() == "exported-projects.json" ||
			e.Name() == ".DS_Store" || strings.HasSuffix(e.Name(), ".tmp"):
		default:
			return fmt.Errorf("refusing to delete %s: it contains %q, which Sakha didn't create", abs, e.Name())
		}
	}
	if !found {
		return fmt.Errorf("refusing to delete %s: it doesn't look like Sakha's data folder", abs)
	}
	return nil
}

// projects gathers every project folder Sakha may have written into.
func projects(opt Options) []string {
	set := map[string]bool{}
	for _, p := range opt.Projects {
		if abs, err := filepath.Abs(p); err == nil {
			set[abs] = true
		}
	}
	for _, p := range export.ExportedProjects() {
		set[p] = true
	}
	if st, err := store.Load(); err == nil {
		for _, c := range st.Candidates {
			if c.Scope != "global" && c.Scope != "" {
				set[c.Scope] = true
			}
		}
	}
	out := make([]string, 0, len(set))
	for p := range set {
		out = append(out, p)
	}
	sort.Strings(out)
	return out
}

func ownedFile(path string) bool {
	b, err := os.ReadFile(path)
	return err == nil && strings.Contains(string(b), skills.Marker)
}

func hasSection(path string) bool {
	b, err := os.ReadFile(path)
	return err == nil && strings.Contains(string(b), export.BeginMarker) && strings.Contains(string(b), export.EndMarker)
}

// Make builds the plan. It returns ErrStillInstalled if any tool still has Sakha's hooks.
func Make(opt Options) (Plan, error) {
	if opt.Home == "" {
		opt.Home = paths.UserHome()
	}
	projs := projects(opt)

	var still []string
	for _, t := range []install.Target{{Tool: "claude-code", Home: opt.Home}, {Tool: "cursor", Home: opt.Home}, {Tool: "codex", Home: opt.Home}} {
		if install.Installed(t) {
			still = append(still, t.ConfigPath())
		}
	}
	for _, p := range projs {
		t := install.Target{Tool: "claude-code", Project: p, Home: opt.Home}
		if install.Installed(t) {
			still = append(still, t.ConfigPath())
		}
	}
	if len(still) > 0 {
		return Plan{}, ErrStillInstalled{Configs: still}
	}

	var plan Plan
	addSkills := func(dir string) {
		matches, _ := filepath.Glob(filepath.Join(dir, "sakha-*", "SKILL.md"))
		sort.Strings(matches)
		for _, m := range matches {
			if ownedFile(m) {
				plan.Items = append(plan.Items, Item{KindFile, m})
			}
		}
	}
	addSkills(filepath.Join(opt.Home, ".claude", "skills"))
	if p := filepath.Join(opt.Home, ".codex", "AGENTS.md"); hasSection(p) {
		plan.Items = append(plan.Items, Item{KindSection, p})
	}
	for _, p := range projs {
		addSkills(filepath.Join(p, ".claude", "skills"))
		rules, _ := filepath.Glob(filepath.Join(p, ".cursor", "rules", "sakha-*.mdc"))
		sort.Strings(rules)
		for _, r := range rules {
			if ownedFile(r) {
				plan.Items = append(plan.Items, Item{KindFile, r})
			}
		}
		for _, rel := range []string{"AGENTS.md", filepath.Join(".github", "copilot-instructions.md")} {
			if f := filepath.Join(p, rel); hasSection(f) {
				plan.Items = append(plan.Items, Item{KindSection, f})
			}
		}
	}
	if _, err := os.Stat(paths.Home()); err == nil {
		if err := CheckDataFolder(paths.Home(), opt.Home); err != nil {
			return Plan{}, err
		}
		plan.Items = append(plan.Items, Item{KindDataFolder, paths.Home()})
	}
	return plan, nil
}

// Execute removes every item in the plan, re-checking ownership just before each step.
// It returns what was removed and the first error, if any.
func Execute(plan Plan, home string) ([]Item, error) {
	if home == "" {
		home = paths.UserHome()
	}
	var done []Item
	for _, it := range plan.Items {
		switch it.Kind {
		case KindFile:
			if !ownedFile(it.Path) {
				continue // changed since planning: leave it alone
			}
			if err := os.Remove(it.Path); err != nil {
				return done, err
			}
			_ = os.Remove(filepath.Dir(it.Path)) // only removes an empty skill folder
			done = append(done, it)
		case KindSection:
			b, err := os.ReadFile(it.Path)
			if err != nil {
				return done, err
			}
			rest, found := export.RemoveSection(string(b))
			if !found {
				continue
			}
			if strings.TrimSpace(rest) == "" {
				err = os.Remove(it.Path) // the file held nothing but Sakha's section
			} else {
				err = os.WriteFile(it.Path, []byte(rest), 0o644)
			}
			if err != nil {
				return done, err
			}
			done = append(done, it)
		case KindDataFolder:
			if err := CheckDataFolder(it.Path, home); err != nil {
				return done, err
			}
			if err := os.RemoveAll(it.Path); err != nil {
				return done, err
			}
			done = append(done, it)
		}
	}
	return done, nil
}
