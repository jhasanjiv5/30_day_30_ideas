// Package export writes confirmed habits to each agent's own format. Every exporter is
// idempotent and only touches files (or marked sections) that Sakha owns.
package export

import (
	"archive/zip"
	"bytes"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/jhasanjiv5/30_day_30_ideas/sakha/internal/learn"
	"github.com/jhasanjiv5/30_day_30_ideas/sakha/internal/paths"
	"github.com/jhasanjiv5/30_day_30_ideas/sakha/internal/skills"
	"github.com/jhasanjiv5/30_day_30_ideas/sakha/internal/store"
)

// Section markers for files shared with the user (AGENTS.md, copilot-instructions.md).
const (
	BeginMarker = "<!-- sakha:start -->"
	EndMarker   = "<!-- sakha:end -->"
)

// Options controls an export run.
type Options struct {
	Targets []string
	Project string // project folder for project-level targets (cursor, copilot, codex project file)
	Home    string // user home; defaults to $HOME
	Budget  int
}

// Result lists what was written or removed.
type Result struct {
	Written []string
	Removed []string
	Skipped []string
	Trimmed map[string]int // file → rules left out to stay within the word budget
}

// Run exports to every requested target.
func Run(st *store.State, opt Options) (Result, error) {
	if opt.Home == "" {
		opt.Home = paths.UserHome()
	}
	if opt.Budget <= 0 {
		opt.Budget = 120
	}
	res := Result{Trimmed: map[string]int{}}
	byScope := learn.Confirmed(st)
	if opt.Project != "" {
		RecordProject(opt.Project) // so `sakha uninstall --purge` can find what was written there
	}
	for _, target := range opt.Targets {
		var err error
		switch target {
		case "claude-code":
			err = claudeCode(byScope, opt, &res)
		case "claude-ai":
			err = claudeAI(byScope, opt, &res)
		case "cursor":
			err = cursor(byScope, opt, &res)
		case "copilot":
			err = sectionFile(byScope, opt, &res, "copilot", filepath.Join(".github", "copilot-instructions.md"))
		case "codex":
			err = codex(byScope, opt, &res)
		default:
			err = fmt.Errorf("unknown export target %q", target)
		}
		if err != nil {
			return res, err
		}
	}
	return res, nil
}

func rulesOf(list []*store.Candidate) []string {
	out := make([]string, len(list))
	for i, c := range list {
		out[i] = c.Rule
	}
	return out
}

// topicsFor merges global habits with those scoped to project (if any).
func topicsFor(byScope map[string]map[string][]*store.Candidate, project string) map[string][]string {
	out := map[string][]string{}
	for topic, list := range byScope["global"] {
		out[topic] = append(out[topic], rulesOf(list)...)
	}
	if project != "" {
		if abs, err := filepath.Abs(project); err == nil {
			for topic, list := range byScope[abs] {
				out[topic] = append(out[topic], rulesOf(list)...)
			}
		}
	}
	return out
}

func sortedTopics(m map[string][]string) []string {
	var ids []string
	for _, t := range store.Topics {
		if len(m[t.ID]) > 0 {
			ids = append(ids, t.ID)
		}
	}
	return ids
}

// writeIfChanged writes content only when it differs, creating parent folders.
func writeIfChanged(path, content string, res *Result) error {
	if old, err := os.ReadFile(path); err == nil && string(old) == content {
		return nil
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		return err
	}
	res.Written = append(res.Written, path)
	return nil
}

// claudeCode writes ~/.claude/skills/sakha-<topic>/SKILL.md for global habits and
// <project>/.claude/skills/sakha-<topic>/SKILL.md for project-scoped ones.
func claudeCode(byScope map[string]map[string][]*store.Candidate, opt Options, res *Result) error {
	scopes := map[string]string{"global": filepath.Join(opt.Home, ".claude", "skills")}
	for scope := range byScope {
		if scope != "global" {
			scopes[scope] = filepath.Join(scope, ".claude", "skills")
		}
	}
	for scope, dir := range scopes {
		topics := map[string][]string{}
		for topic, list := range byScope[scope] {
			topics[topic] = rulesOf(list)
		}
		for _, t := range store.Topics {
			path := filepath.Join(dir, skills.Name(t.ID), "SKILL.md")
			if len(topics[t.ID]) == 0 {
				removeOwned(path, res)
				continue
			}
			md, dropped := skills.SkillMD(t.ID, topics[t.ID], opt.Budget)
			if dropped > 0 {
				res.Trimmed[path] = dropped
			}
			if err := writeIfChanged(path, md, res); err != nil {
				return err
			}
		}
	}
	return nil
}

// removeOwned deletes a skill file (and its empty folder) only if Sakha wrote it.
func removeOwned(path string, res *Result) {
	b, err := os.ReadFile(path)
	if err != nil || !strings.Contains(string(b), skills.Marker) {
		return
	}
	if os.Remove(path) == nil {
		res.Removed = append(res.Removed, path)
		_ = os.Remove(filepath.Dir(path)) // only succeeds if empty
	}
}

// claudeAI writes uploadable skill zips plus one instructions file for claude.ai / Claude desktop.
func claudeAI(byScope map[string]map[string][]*store.Candidate, opt Options, res *Result) error {
	dir := paths.Join("export", "claude-ai")
	topics := topicsFor(byScope, "")
	for _, t := range store.Topics {
		zipPath := filepath.Join(dir, skills.Name(t.ID)+".zip")
		if len(topics[t.ID]) == 0 {
			if os.Remove(zipPath) == nil {
				res.Removed = append(res.Removed, zipPath)
			}
			continue
		}
		md, _ := skills.SkillMD(t.ID, topics[t.ID], opt.Budget)
		var buf bytes.Buffer
		zw := zip.NewWriter(&buf)
		hdr := &zip.FileHeader{Name: skills.Name(t.ID) + "/SKILL.md", Method: zip.Deflate}
		hdr.Modified = time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC) // stable bytes for idempotency
		w, err := zw.CreateHeader(hdr)
		if err != nil {
			return err
		}
		if _, err := w.Write([]byte(md)); err != nil {
			return err
		}
		if err := zw.Close(); err != nil {
			return err
		}
		if err := writeIfChanged(zipPath, buf.String(), res); err != nil {
			return err
		}
	}
	instr := "Paste into claude.ai → Settings → Profile (personal preferences), or a Project's instructions.\n\n" + section(topics)
	return writeIfChanged(filepath.Join(dir, "instructions.md"), instr, res)
}

// section renders all topics as one markdown block.
func section(topics map[string][]string) string {
	var b strings.Builder
	b.WriteString("## Preferences learned by Sakha\n")
	ids := sortedTopics(topics)
	if len(ids) == 0 {
		b.WriteString("\n_No confirmed preferences yet._\n")
	}
	for _, id := range ids {
		t, _ := store.TopicByID(id)
		fmt.Fprintf(&b, "\n### %s\n", t.Title)
		list := append([]string(nil), topics[id]...)
		for _, r := range list {
			b.WriteString("- " + r + "\n")
		}
	}
	return b.String()
}

// cursor writes <project>/.cursor/rules/sakha-<topic>.mdc (Cursor project rules).
func cursor(byScope map[string]map[string][]*store.Candidate, opt Options, res *Result) error {
	if opt.Project == "" {
		res.Skipped = append(res.Skipped, "cursor (needs --project <folder>)")
		return nil
	}
	topics := topicsFor(byScope, opt.Project)
	for _, t := range store.Topics {
		path := filepath.Join(opt.Project, ".cursor", "rules", skills.Name(t.ID)+".mdc")
		if len(topics[t.ID]) == 0 {
			removeOwned(path, res)
			continue
		}
		body, dropped := skills.Body(t.ID, topics[t.ID], opt.Budget)
		if dropped > 0 {
			res.Trimmed[path] = dropped
		}
		mdc := fmt.Sprintf("---\ndescription: %s\nglobs:\nalwaysApply: false\n---\n\n%s\n%s\n", skills.Description(t.ID), body, skills.Marker)
		if err := writeIfChanged(path, mdc, res); err != nil {
			return err
		}
	}
	return nil
}

// codex updates the Sakha section of ~/.codex/AGENTS.md, and the project's AGENTS.md if a project is given.
func codex(byScope map[string]map[string][]*store.Candidate, opt Options, res *Result) error {
	global := filepath.Join(opt.Home, ".codex", "AGENTS.md")
	if err := writeSection(global, section(topicsFor(byScope, "")), res); err != nil {
		return err
	}
	if opt.Project != "" {
		return writeSection(filepath.Join(opt.Project, "AGENTS.md"), section(topicsFor(byScope, opt.Project)), res)
	}
	return nil
}

func sectionFile(byScope map[string]map[string][]*store.Candidate, opt Options, res *Result, name, rel string) error {
	if opt.Project == "" {
		res.Skipped = append(res.Skipped, name+" (needs --project <folder>)")
		return nil
	}
	return writeSection(filepath.Join(opt.Project, rel), section(topicsFor(byScope, opt.Project)), res)
}

// writeSection replaces the text between Sakha's markers, leaving everything else untouched.
func writeSection(path, content string, res *Result) error {
	old, err := os.ReadFile(path)
	if err != nil && !os.IsNotExist(err) {
		return err
	}
	return writeIfChanged(path, ReplaceSection(string(old), content), res)
}

// ReplaceSection returns text with Sakha's marked section set to content (appended if missing).
func ReplaceSection(text, content string) string {
	block := BeginMarker + "\n" + strings.TrimRight(content, "\n") + "\n" + EndMarker
	start := strings.Index(text, BeginMarker)
	end := strings.Index(text, EndMarker)
	if start >= 0 && end > start {
		return text[:start] + block + text[end+len(EndMarker):]
	}
	if strings.TrimSpace(text) == "" {
		return block + "\n"
	}
	return strings.TrimRight(text, "\n") + "\n\n" + block + "\n"
}

// KnownTargets lists valid export targets in display order.
func KnownTargets() []string {
	return []string{"claude-code", "claude-ai", "cursor", "copilot", "codex"}
}
