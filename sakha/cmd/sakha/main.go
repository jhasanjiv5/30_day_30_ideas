// Command sakha learns how you like to work with AI agents and turns it into small, confirmed skills.
package main

import (
	"archive/zip"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"github.com/jhasanjiv5/30_day_30_ideas/sakha/internal/event"
	"github.com/jhasanjiv5/30_day_30_ideas/sakha/internal/export"
	"github.com/jhasanjiv5/30_day_30_ideas/sakha/internal/extract"
	"github.com/jhasanjiv5/30_day_30_ideas/sakha/internal/hook"
	"github.com/jhasanjiv5/30_day_30_ideas/sakha/internal/install"
	"github.com/jhasanjiv5/30_day_30_ideas/sakha/internal/learn"
	"github.com/jhasanjiv5/30_day_30_ideas/sakha/internal/llm"
	"github.com/jhasanjiv5/30_day_30_ideas/sakha/internal/paths"
	"github.com/jhasanjiv5/30_day_30_ideas/sakha/internal/purge"
	"github.com/jhasanjiv5/30_day_30_ideas/sakha/internal/redact"
	"github.com/jhasanjiv5/30_day_30_ideas/sakha/internal/review"
	"github.com/jhasanjiv5/30_day_30_ideas/sakha/internal/selftest"
	"github.com/jhasanjiv5/30_day_30_ideas/sakha/internal/skills"
	"github.com/jhasanjiv5/30_day_30_ideas/sakha/internal/store"
)

var version = "0.1.0-dev"

const usage = `Sakha — learns how you like to work, and remembers it as small confirmed skills.

Usage:
  sakha install --tool claude-code|cursor|codex [--project DIR]   Add hooks (backs up your config first)
  sakha uninstall --tool claude-code|cursor|codex [--project DIR] Remove only Sakha's hooks
  sakha uninstall --purge [--yes]      Remove everything Sakha created (after all hooks are removed)
  sakha doctor                         Check hooks, data folder, local model and queue
  sakha review                         Keep / edit / drop the habits Sakha noticed
  sakha list [--all]                   Pending and confirmed habits
  sakha show [TOPIC]                   Print the skill file(s) Sakha generates
  sakha decide ID keep|drop            Record a decision (used by Claude during the check-in)
  sakha decide ID edit "new wording"   Change a habit's wording and confirm it
  sakha forget ID|TOPIC                Remove a habit, or every habit in a topic
  sakha export [--target LIST] [--project DIR]   Write skills for claude-code, claude-ai, cursor, copilot, codex
  sakha analyse [--all] [--no-model]   Analyse queued sessions now (normally runs in the background)
  sakha import FILE                    Learn from a claude.ai data export (zip or conversations.json)
  sakha undo                           Restore the previous set of habits
  sakha pause | resume                 Stop or restart learning
  sakha selftest [--json]              Replay the built-in fixtures and score accuracy, privacy and speed
  sakha hook [--tool T] EVENT          Hook entry point (called by your agent, reads JSON on stdin)
  sakha version

Topics: writing-tone, ui-design, coding, workflow, domain. Data lives in ~/.sakha (override with SAKHA_HOME).
`

func main() {
	if len(os.Args) < 2 {
		fmt.Print(usage)
		os.Exit(2)
	}
	cmd, args := os.Args[1], os.Args[2:]
	if cmd == "hook" {
		runHook(args) // never fails
		return
	}
	var err error
	switch cmd {
	case "install":
		err = runInstall(args, true)
	case "uninstall":
		err = runInstall(args, false)
	case "doctor":
		err = runDoctor()
	case "review":
		err = runReview()
	case "list":
		err = runList(args)
	case "show":
		err = runShow(args)
	case "decide":
		err = runDecide(args)
	case "edit":
		if len(args) < 2 {
			err = errors.New(`usage: sakha edit ID "new wording"`)
		} else {
			err = runDecide([]string{args[0], "edit", strings.Join(args[1:], " ")})
		}
	case "forget":
		err = runForget(args)
	case "export":
		err = runExport(args)
	case "analyse", "analyze":
		err = runAnalyse(args)
	case "import":
		err = runImport(args)
	case "undo":
		err = runUndo()
	case "pause", "resume":
		err = runPause(cmd == "pause")
	case "selftest":
		err = runSelftest(args)
	case "version", "--version", "-v":
		fmt.Println("sakha", version)
	case "help", "--help", "-h":
		fmt.Print(usage)
	default:
		err = fmt.Errorf("unknown command %q\n\n%s", cmd, usage)
	}
	if err != nil {
		fmt.Fprintln(os.Stderr, "sakha:", err)
		os.Exit(1)
	}
}

// ---------------------------------------------------------------- hook

func runHook(args []string) {
	tool, rest := "claude-code", []string{}
	for i := 0; i < len(args); i++ {
		if args[i] == "--tool" && i+1 < len(args) {
			tool = args[i+1]
			i++
			continue
		}
		rest = append(rest, args[i])
	}
	eventName := ""
	if len(rest) > 0 {
		eventName = rest[0]
	}
	var raw []byte
	if tool == "codex" && len(rest) > 1 {
		raw = []byte(rest[len(rest)-1]) // Codex passes the notification JSON as an argument
	} else {
		raw, _ = io.ReadAll(io.LimitReader(os.Stdin, 4<<20))
	}
	if out := hook.Handle(tool, eventName, raw); len(out) > 0 {
		os.Stdout.Write(out)
		os.Stdout.Write([]byte("\n"))
	}
}

// ---------------------------------------------------------------- state helpers

// mutate loads the state under the lock, applies fn, saves, and refreshes exports.
func mutate(fn func(st *store.State) error) error {
	unlock, err := store.Lock()
	if err != nil {
		return err
	}
	defer unlock()
	st, err := store.Load()
	if err != nil {
		return err
	}
	if err := fn(st); err != nil {
		return err
	}
	if err := store.Save(st); err != nil {
		return err
	}
	return exportConfigured(st)
}

func exportConfigured(st *store.State) error {
	cfg, _ := store.LoadConfig()
	res, err := export.Run(st, export.Options{Targets: cfg.Targets, Budget: cfg.SkillWordBudget})
	for _, p := range res.Written {
		fmt.Println("  updated", tilde(p))
	}
	for _, p := range res.Removed {
		fmt.Println("  removed", tilde(p))
	}
	for p, n := range res.Trimmed {
		fmt.Printf("  note: %s is over the word budget; %d older rule(s) left out\n", tilde(p), n)
	}
	return err
}

func tilde(p string) string {
	h := filepath.Clean(paths.UserHome())
	p = filepath.Clean(p)
	if p == h || strings.HasPrefix(p, h+string(filepath.Separator)) {
		return "~" + strings.TrimPrefix(p, h)
	}
	return p
}

// ---------------------------------------------------------------- install / doctor

func flagValue(args []string, name string) string {
	for i := 0; i < len(args); i++ {
		if args[i] == name && i+1 < len(args) {
			return args[i+1]
		}
		if strings.HasPrefix(args[i], name+"=") {
			return strings.TrimPrefix(args[i], name+"=")
		}
	}
	return ""
}

func hasFlag(args []string, name string) bool {
	for _, a := range args {
		if a == name {
			return true
		}
	}
	return false
}

func executable() string {
	exe, err := os.Executable()
	if err != nil {
		return "sakha"
	}
	if real, err := filepath.EvalSymlinks(exe); err == nil {
		return real
	}
	return exe
}

func runInstall(args []string, add bool) error {
	tool := flagValue(args, "--tool")
	if tool == "" && hasFlag(args, "--claude-code") {
		tool = "claude-code"
	}
	purgeAll := !add && hasFlag(args, "--purge")
	if tool == "" && !purgeAll {
		return errors.New("choose a tool: --tool claude-code, --tool cursor or --tool codex")
	}
	project := flagValue(args, "--project")
	if project != "" {
		abs, err := filepath.Abs(project)
		if err != nil {
			return err
		}
		project = abs
	}
	t := install.Target{Tool: tool, Project: project, Exe: executable()}
	if !add {
		if tool != "" {
			path, err := install.Uninstall(t)
			if err != nil {
				return err
			}
			fmt.Printf("Removed Sakha's %s hooks from %s.\n", tool, tilde(path))
		}
		if purgeAll {
			return runPurge(project, hasFlag(args, "--yes"))
		}
		fmt.Printf("Your habits stay in %s. To remove everything Sakha created: sakha uninstall --purge\n", tilde(paths.Home()))
		return nil
	}
	if _, err := os.Stat(paths.Join("config.json")); errors.Is(err, os.ErrNotExist) {
		if err := store.SaveConfig(store.DefaultConfig()); err != nil {
			return err
		}
	}
	path, err := install.Install(t)
	if err != nil {
		return err
	}
	fmt.Printf("Sakha is listening in %s (hooks added to %s; backup in %s).\n", tool, tilde(path), tilde(paths.Join("backups")))
	switch tool {
	case "claude-code":
		fmt.Println("It learns from your own messages and edits only, and will check in at the start of a session once it has noticed something.")
	case "cursor":
		fmt.Println("Cursor hooks are experimental. Export rules into a project with: sakha export --target cursor --project DIR")
	case "codex":
		fmt.Println("Codex reports each finished turn to Sakha. Export to ~/.codex/AGENTS.md with: sakha export --target codex")
	}
	fmt.Println("Next: sakha doctor")
	return nil
}

// runPurge removes everything Sakha created, after showing the list and asking.
func runPurge(project string, yes bool) error {
	var projects []string
	if project != "" {
		projects = []string{project}
	}
	plan, err := purge.Make(purge.Options{Projects: projects})
	var still purge.ErrStillInstalled
	if errors.As(err, &still) {
		for i, c := range still.Configs {
			still.Configs[i] = tilde(c)
		}
		return still
	}
	if err != nil {
		return err
	}
	if len(plan.Items) == 0 {
		fmt.Println("Nothing left to remove: Sakha has no data folder, skills or sections on this machine.")
		return nil
	}
	fmt.Println("This will permanently remove everything Sakha created:")
	for _, it := range plan.Items {
		switch it.Kind {
		case purge.KindDataFolder:
			fmt.Printf("  • %s (all habits, history, backups and exports)\n", tilde(it.Path))
		case purge.KindSection:
			fmt.Printf("  • Sakha's section in %s (the rest of the file stays)\n", tilde(it.Path))
		default:
			fmt.Printf("  • %s\n", tilde(it.Path))
		}
	}
	if !yes {
		if info, err := os.Stdin.Stat(); err != nil || info.Mode()&os.ModeCharDevice == 0 {
			return errors.New("not running in a terminal: add --yes to confirm the purge")
		}
		fmt.Printf("Delete these %d item(s)? This can't be undone. [y/N] ", len(plan.Items))
		var answer string
		fmt.Scanln(&answer)
		if a := strings.ToLower(strings.TrimSpace(answer)); a != "y" && a != "yes" {
			fmt.Println("Cancelled. Nothing was deleted.")
			return nil
		}
	}
	done, err := purge.Execute(plan, "")
	fmt.Printf("Removed %d of %d item(s).\n", len(done), len(plan.Items))
	if err != nil {
		return err
	}
	fmt.Println("Sakha has forgotten everything. To remove the program too:", `rm "$(go env GOPATH)/bin/sakha"`)
	return nil
}

func runDoctor() error {
	ok := func(good bool, msg string) {
		mark := "✓"
		if !good {
			mark = "✗"
		}
		fmt.Printf("  %s %s\n", mark, msg)
	}
	cfg, cfgErr := store.LoadConfig()
	fmt.Println("Sakha doctor")
	fmt.Printf("  · version %s at %s\n", version, tilde(executable()))
	info, err := os.Stat(paths.Home())
	ok(err == nil && info.Mode().Perm() == 0o700, fmt.Sprintf("data folder %s is private (0700)", tilde(paths.Home())))
	ok(cfgErr == nil, "config readable")
	for _, tool := range []string{"claude-code", "cursor", "codex"} {
		t := install.Target{Tool: tool}
		if install.Installed(t) {
			ok(true, fmt.Sprintf("%s hooks installed (%s)", tool, tilde(t.ConfigPath())))
		} else {
			fmt.Printf("  · %s hooks not installed\n", tool)
		}
	}
	if cfg.UseModel {
		o := llm.Ollama{URL: cfg.OllamaURL, Model: cfg.OllamaModel}
		ctx, cancel := context.WithTimeout(context.Background(), 4*time.Second)
		err := o.Available(ctx)
		cancel()
		if err != nil {
			fmt.Printf("  · local model unavailable (%v); rules-only learning still works\n", err)
		} else {
			ok(true, fmt.Sprintf("local model %s ready at %s", cfg.OllamaModel, cfg.OllamaURL))
		}
	} else {
		fmt.Println("  · local model disabled in config (rules-only learning)")
	}
	sessions, _ := event.Sessions()
	fmt.Printf("  · %d session(s) waiting for analysis\n", len(sessions))
	st, err := store.Load()
	if err != nil {
		return err
	}
	if st.Paused {
		fmt.Println("  · learning is paused (sakha resume to restart)")
	}
	fmt.Printf("  · habits: %d waiting for review, %d confirmed, %d still collecting evidence\n",
		len(learn.Pending(st)), len(st.InState(store.StateConfirmed)), len(st.InState(store.StateObserved)))
	return nil
}

// ---------------------------------------------------------------- learning

func generator(cfg store.Config, disable bool) llm.Generator {
	if disable || !cfg.UseModel {
		return nil
	}
	o := llm.Ollama{URL: cfg.OllamaURL, Model: cfg.OllamaModel}
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	if o.Available(ctx) != nil {
		return nil
	}
	return o
}

func runAnalyse(args []string) error {
	cfg, _ := store.LoadConfig()
	var sessions []string
	if s := flagValue(args, "--session"); s != "" {
		sessions = []string{s}
	}
	skip := map[string]bool{}
	if s := flagValue(args, "--except"); s != "" {
		skip[s] = true
	}
	gen := generator(cfg, hasFlag(args, "--no-model"))
	unlock, err := store.Lock()
	if err != nil {
		return err
	}
	defer unlock()
	st, err := store.Load()
	if err != nil {
		return err
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
	defer cancel()
	rep, done, err := learn.Analyse(ctx, st, cfg, sessions, skip, gen, time.Now().UTC())
	if err != nil {
		return err
	}
	if err := store.Save(st); err != nil {
		return err
	}
	for _, s := range done {
		_ = event.Remove(s)
		hook.ForgetWrites(s)
	}
	mode := "rules only"
	if rep.ModelUsed {
		mode = "rules + local model " + cfg.OllamaModel
	} else if rep.ModelErr != "" {
		mode = "rules only (model error: " + rep.ModelErr + ")"
	}
	fmt.Printf("Analysed %d session(s) with %s: %d sighting(s), %d new habit(s) ready for review, %d re-offered.\n",
		rep.Sessions, mode, rep.Sightings, rep.NewReady, rep.Decayed)
	return nil
}

func runReview() error {
	st, err := store.Load()
	if err != nil {
		return err
	}
	before := map[string]string{}
	for _, c := range st.Candidates {
		before[c.ID] = c.State + "|" + c.Rule
	}
	n, err := review.Run(st, os.Stdin, os.Stdout, time.Now().UTC())
	if err != nil || n == 0 {
		return err
	}
	// Apply the decisions to the latest state (background analysis may have run meanwhile).
	return mutate(func(fresh *store.State) error {
		for _, c := range st.Candidates {
			if before[c.ID] == c.State+"|"+c.Rule {
				continue
			}
			if fc := fresh.Find(c.ID); fc != nil {
				fc.State, fc.Rule, fc.ConfirmedAt, fc.LastSeen = c.State, c.Rule, c.ConfirmedAt, c.LastSeen
				fc.Contradictions, fc.ReviewNote = c.Contradictions, c.ReviewNote
			}
		}
		return nil
	})
}

func runDecide(args []string) error {
	if len(args) < 2 {
		return errors.New(`usage: sakha decide ID keep|drop  or  sakha decide ID edit "new wording"`)
	}
	id, action, text := args[0], args[1], strings.Join(args[2:], " ")
	err := mutate(func(st *store.State) error { return learn.Decide(st, id, action, text, time.Now().UTC()) })
	if err == nil {
		fmt.Printf("Recorded: %s → %s\n", id, action)
	}
	return err
}

func runForget(args []string) error {
	if len(args) != 1 {
		return errors.New("usage: sakha forget ID|TOPIC")
	}
	target := args[0]
	return mutate(func(st *store.State) error {
		if _, isTopic := store.TopicByID(target); isTopic {
			n := 0
			for _, c := range st.Candidates {
				if c.Topic == target && c.State != store.StateDropped && c.State != store.StateRetired {
					c.State = store.StateRetired
					n++
				}
			}
			fmt.Printf("Forgot %d habit(s) in %s.\n", n, target)
			return nil
		}
		if err := learn.Decide(st, target, "drop", "", time.Now().UTC()); err != nil {
			return err
		}
		fmt.Printf("Forgot %s.\n", target)
		return nil
	})
}

func runPause(pause bool) error {
	unlock, err := store.Lock()
	if err != nil {
		return err
	}
	defer unlock()
	st, err := store.Load()
	if err != nil {
		return err
	}
	st.Paused = pause
	if err := store.SaveQuiet(st); err != nil {
		return err
	}
	if pause {
		fmt.Println("Paused: Sakha won't record anything until `sakha resume`.")
	} else {
		fmt.Println("Resumed: Sakha is learning again.")
	}
	return nil
}

func runUndo() error {
	unlock, err := store.Lock()
	if err != nil {
		return err
	}
	name, err := store.Undo()
	unlock()
	if err != nil {
		return err
	}
	fmt.Printf("Restored the habits as they were before the last change (%s).\n", strings.TrimSuffix(name, ".json"))
	st, err := store.Load()
	if err != nil {
		return err
	}
	return exportConfigured(st)
}

// ---------------------------------------------------------------- viewing

func runList(args []string) error {
	st, err := store.Load()
	if err != nil {
		return err
	}
	print := func(title string, list []*store.Candidate) {
		if len(list) == 0 {
			return
		}
		fmt.Printf("%s (%d)\n", title, len(list))
		for _, c := range list {
			scope := ""
			if c.Scope != "global" {
				scope = "  [" + filepath.Base(c.Scope) + " only]"
			}
			fmt.Printf("  %-4s %-13s %s%s\n", c.ID, c.Topic, c.Rule, scope)
			if c.State == store.StateObserved {
				fmt.Printf("       %d sighting(s) in %d session(s) so far\n", len(c.Evidence), c.Sessions())
			}
		}
		fmt.Println()
	}
	pending := learn.Pending(st)
	print("Waiting for your review — run `sakha review`", pending)
	print("Confirmed", st.InState(store.StateConfirmed))
	if hasFlag(args, "--all") {
		print("Collecting evidence", st.InState(store.StateObserved))
		print("Dropped or retired", st.InState(store.StateDropped, store.StateRetired))
	}
	if len(pending) == 0 && len(st.InState(store.StateConfirmed)) == 0 {
		fmt.Println("No habits yet. Sakha learns as you work; check back after a few sessions.")
	}
	return nil
}

func runShow(args []string) error {
	st, err := store.Load()
	if err != nil {
		return err
	}
	cfg, _ := store.LoadConfig()
	byScope := learn.Confirmed(st)
	shown := 0
	scopes := make([]string, 0, len(byScope))
	for s := range byScope {
		scopes = append(scopes, s)
	}
	sort.Strings(scopes)
	for _, scope := range scopes {
		for _, t := range store.Topics {
			if len(args) > 0 && args[0] != t.ID {
				continue
			}
			list := byScope[scope][t.ID]
			if len(list) == 0 {
				continue
			}
			rules := make([]string, len(list))
			for i, c := range list {
				rules[i] = c.Rule
			}
			md, _ := skills.SkillMD(t.ID, rules, cfg.SkillWordBudget)
			where := "~/.claude/skills/"
			if scope != "global" {
				where = tilde(scope) + "/.claude/skills/"
			}
			fmt.Printf("── %s%s/SKILL.md (%d words) ──\n%s\n", where, skills.Name(t.ID), skills.WordCount(md), md)
			shown++
		}
	}
	if shown == 0 {
		fmt.Println("No confirmed habits yet.")
	}
	return nil
}

func runExport(args []string) error {
	cfg, _ := store.LoadConfig()
	targets := cfg.Targets
	if t := flagValue(args, "--target"); t != "" {
		targets = strings.Split(t, ",")
	}
	project := flagValue(args, "--project")
	if project != "" {
		abs, err := filepath.Abs(project)
		if err != nil {
			return err
		}
		project = abs
	}
	st, err := store.Load()
	if err != nil {
		return err
	}
	res, err := export.Run(st, export.Options{Targets: targets, Project: project, Budget: cfg.SkillWordBudget})
	for _, p := range res.Written {
		fmt.Println("  updated", tilde(p))
	}
	for _, p := range res.Removed {
		fmt.Println("  removed", tilde(p))
	}
	for _, s := range res.Skipped {
		fmt.Println("  skipped", s)
	}
	if err == nil && len(res.Written)+len(res.Removed) == 0 {
		fmt.Println("Everything is already up to date.")
	}
	return err
}

// ---------------------------------------------------------------- import

// runImport reads a claude.ai data export and queues the human messages as sessions.
func runImport(args []string) error {
	if len(args) != 1 {
		return errors.New("usage: sakha import FILE (claude.ai export .zip or conversations.json)")
	}
	data, err := readConversations(args[0])
	if err != nil {
		return err
	}
	var convs []struct {
		UUID     string `json:"uuid"`
		Messages []struct {
			Sender    string    `json:"sender"`
			Text      string    `json:"text"`
			CreatedAt time.Time `json:"created_at"`
		} `json:"chat_messages"`
	}
	if err := json.Unmarshal(data, &convs); err != nil {
		return fmt.Errorf("not a claude.ai conversations.json: %w", err)
	}
	var sessions []string
	msgs := 0
	for _, c := range convs {
		session := "import-" + c.UUID
		added := false
		for _, m := range c.Messages {
			if m.Sender != "human" {
				continue // only the user's own words
			}
			text := redact.Text(extract.UserText(m.Text))
			if strings.TrimSpace(text) == "" {
				continue
			}
			if r := []rune(text); len(r) > event.MaxPromptChars {
				text = string(r[:event.MaxPromptChars])
			}
			_ = event.Append(event.Event{Time: m.CreatedAt, Session: session, Tool: "import", Kind: event.KindPrompt, Text: text})
			added = true
			msgs++
		}
		if added {
			sessions = append(sessions, session)
		}
	}
	fmt.Printf("Imported %d message(s) from %d conversation(s).\n", msgs, len(sessions))
	if len(sessions) == 0 {
		return nil
	}
	return runAnalyseSessions(sessions)
}

func runAnalyseSessions(sessions []string) error {
	for _, s := range sessions {
		if err := runAnalyse([]string{"--session", s}); err != nil {
			return err
		}
	}
	return nil
}

func readConversations(path string) ([]byte, error) {
	if strings.HasSuffix(strings.ToLower(path), ".zip") {
		zr, err := zip.OpenReader(path)
		if err != nil {
			return nil, err
		}
		defer zr.Close()
		for _, f := range zr.File {
			if filepath.Base(f.Name) == "conversations.json" {
				rc, err := f.Open()
				if err != nil {
					return nil, err
				}
				defer rc.Close()
				return io.ReadAll(io.LimitReader(rc, 512<<20))
			}
		}
		return nil, errors.New("no conversations.json in the export")
	}
	return os.ReadFile(path)
}

// ---------------------------------------------------------------- selftest

func runSelftest(args []string) error {
	res, err := selftest.Run(context.Background())
	if err != nil {
		return err
	}
	if hasFlag(args, "--json") {
		b, _ := json.MarshalIndent(res, "", "  ")
		fmt.Println(string(b))
	} else {
		pct := func(f float64) string { return fmt.Sprintf("%.0f%%", f*100) }
		fmt.Printf("Sakha self-test: %d fixtures replayed through the real hooks (rules extractor, no model)\n\n", res.Fixtures)
		fmt.Printf("  Habit precision        %6s   (target ≥ %s)  %d of %d proposals correct\n", pct(res.Precision), pct(selftest.TargetPrecision), res.Correct, res.Proposed)
		fmt.Printf("  Habit recall           %6s   (target ≥ %s)  %d of %d planted habits found\n", pct(res.Recall), pct(selftest.TargetRecall), res.Found, res.Expected)
		fmt.Printf("  Poisoning blocked      %3d / %-3d (target all)\n", res.PoisonBlocked, res.PoisonTotal)
		fmt.Printf("  Secrets on disk        %6d   (target 0)\n", res.SecretsLeaked)
		fmt.Printf("  Largest skill          %3d words (target ≤ 120)\n", res.MaxSkillWords)
		fmt.Printf("  Check-in note        ~%3d tokens (target ≤ %d)\n", res.MaxNoteTokens, selftest.TargetNoteToks)
		fmt.Printf("  Hook latency p50/p95  %.2f / %.2f ms (target p95 < 20 ms)\n\n", res.HookP50, res.HookP95)
		for _, d := range res.Details {
			fmt.Println("  ·", d)
		}
		if res.Passed {
			fmt.Println("RESULT: PASS")
		} else {
			fmt.Println("RESULT: FAIL —", strings.Join(res.Failures, "; "))
		}
	}
	if !res.Passed {
		os.Exit(1)
	}
	return nil
}
