// Package hook turns agent hook calls (Claude Code, Cursor, Codex) into recorded events.
// Hooks must never slow down or break a session: they only append to a queue, do no
// analysis, and always succeed.
package hook

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"
	"time"

	"github.com/jhasanjiv5/30_day_30_ideas/sakha/internal/event"
	"github.com/jhasanjiv5/30_day_30_ideas/sakha/internal/extract"
	"github.com/jhasanjiv5/30_day_30_ideas/sakha/internal/learn"
	"github.com/jhasanjiv5/30_day_30_ideas/sakha/internal/paths"
	"github.com/jhasanjiv5/30_day_30_ideas/sakha/internal/redact"
	"github.com/jhasanjiv5/30_day_30_ideas/sakha/internal/store"
)

// Input is the union of the hook payloads Sakha understands.
type Input struct {
	// Claude Code
	SessionID     string         `json:"session_id"`
	CWD           string         `json:"cwd"`
	HookEventName string         `json:"hook_event_name"`
	Prompt        string         `json:"prompt"`
	ToolName      string         `json:"tool_name"`
	ToolInput     map[string]any `json:"tool_input"`
	// Cursor
	ConversationID string   `json:"conversation_id"`
	FilePath       string   `json:"file_path"`
	WorkspaceRoots []string `json:"workspace_roots"`
	// Codex notify
	Type          string   `json:"type"`
	ThreadID      string   `json:"thread-id"`
	TurnID        string   `json:"turn-id"`
	InputMessages []string `json:"input-messages"`
}

// Handle processes one hook call and returns the JSON (or nothing) to print on stdout.
// tool is claude-code, cursor or codex; eventName is the hook event.
func Handle(tool, eventName string, raw []byte) (out []byte) {
	defer func() {
		if r := recover(); r != nil {
			logf("hook panic: %v", r)
			out = okFor(tool, eventName)
		}
	}()
	var in Input
	if len(strings.TrimSpace(string(raw))) > 0 {
		if err := json.Unmarshal(raw, &in); err != nil {
			logf("hook: bad input for %s/%s: %v", tool, eventName, err)
			return okFor(tool, eventName)
		}
	}
	if eventName == "" {
		eventName = in.HookEventName
	}
	if st, err := store.Load(); err == nil && st.Paused {
		return okFor(tool, eventName)
	}
	session, project := sessionAndProject(tool, in)
	cfg, _ := store.LoadConfig()

	switch normalise(tool, eventName) {
	case "prompt":
		CheckUserEdits(session, tool, project)
		recordPrompt(session, tool, project, in.Prompt, cfg)
	case "before-command":
		// Just before the agent runs a command: anything that changed since the agent last wrote
		// a file was the user's doing. Record it now, before the command's own changes blur it.
		if in.ToolName == "Bash" {
			CheckUserEdits(session, tool, project)
		}
	case "write":
		if p := writtenPath(in); p != "" {
			TrackWrite(session, p)
		} else if in.ToolName == "Bash" {
			// The agent ran a command (a formatter, a script, sed…). Whatever it changed in files
			// the agent wrote is the agent's doing, not the user's: refresh the snapshots silently.
			RefreshTracked(session)
		}
	case "codex-turn":
		for _, msg := range in.InputMessages {
			recordPrompt(session, tool, project, msg, cfg)
		}
	case "session-start":
		spawnAnalyse("--pending", "--except", session)
		if note := checkInNote(session); note != "" {
			return mustJSON(map[string]any{"hookSpecificOutput": map[string]any{
				"hookEventName": "SessionStart", "additionalContext": note}})
		}
	case "session-end":
		CheckUserEdits(session, tool, project)
		spawnAnalyse("--session", session)
	}
	return okFor(tool, eventName)
}

func normalise(tool, ev string) string {
	switch strings.ToLower(ev) {
	case "userpromptsubmit", "beforesubmitprompt":
		return "prompt"
	case "posttooluse", "afterfileedit":
		return "write"
	case "pretooluse":
		return "before-command"
	case "sessionstart":
		return "session-start"
	case "sessionend", "stop":
		return "session-end"
	case "notify", "agent-turn-complete":
		if tool == "codex" {
			return "codex-turn"
		}
	}
	return ""
}

// okFor returns the "carry on" reply each tool expects.
func okFor(tool, ev string) []byte {
	if tool == "cursor" && strings.EqualFold(ev, "beforeSubmitPrompt") {
		return []byte(`{"continue":true}`)
	}
	return nil
}

func sessionAndProject(tool string, in Input) (string, string) {
	session := in.SessionID
	if session == "" {
		session = in.ConversationID
	}
	if session == "" {
		session = in.ThreadID
	}
	if session == "" {
		session = tool + "-" + time.Now().UTC().Format("20060102")
	}
	project := in.CWD
	if project == "" && len(in.WorkspaceRoots) > 0 {
		project = in.WorkspaceRoots[0]
	}
	if project == "" {
		project, _ = os.Getwd()
	}
	return tool + "-" + session, project
}

func recordPrompt(session, tool, project, prompt string, cfg store.Config) {
	text := extract.UserText(prompt)
	if strings.TrimSpace(text) == "" {
		return
	}
	if cfg.UseKavach {
		text = redact.WithKavach(text)
	} else {
		text = redact.Text(text)
	}
	if r := []rune(text); len(r) > event.MaxPromptChars {
		text = string(r[:event.MaxPromptChars])
	}
	_ = event.Append(event.Event{Time: time.Now().UTC(), Session: session, Tool: tool, Project: project,
		Kind: event.KindPrompt, Text: text})
}

// writtenPath finds the file an agent tool just wrote (Claude Code Edit/Write/MultiEdit/NotebookEdit,
// or Cursor afterFileEdit). Other tools are ignored: their output is never learned from.
func writtenPath(in Input) string {
	if in.FilePath != "" {
		return in.FilePath
	}
	switch in.ToolName {
	case "Edit", "Write", "MultiEdit", "NotebookEdit":
		for _, k := range []string{"file_path", "notebook_path"} {
			if p, ok := in.ToolInput[k].(string); ok && p != "" {
				if !filepath.IsAbs(p) && in.CWD != "" {
					p = filepath.Join(in.CWD, p)
				}
				return p
			}
		}
	}
	return ""
}

// checkInNote builds the short session-start note asking Claude to offer a review, once per session.
func checkInNote(session string) string {
	unlock, err := store.Lock()
	if err != nil {
		return ""
	}
	defer unlock()
	st, err := store.Load()
	if err != nil || st.Offered[session] {
		return ""
	}
	note := learn.CheckInNote(st)
	if note == "" {
		return ""
	}
	st.Offered[session] = true
	_ = store.SaveQuiet(st)
	return note
}

// spawnAnalyse starts `sakha analyse` in the background so the hook returns immediately.
func spawnAnalyse(args ...string) {
	if os.Getenv("SAKHA_NO_SPAWN") == "1" {
		return
	}
	exe, err := os.Executable()
	if err != nil {
		return
	}
	logFile, err := os.OpenFile(paths.Join("sakha.log"), os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0o600)
	if err != nil {
		return
	}
	cmd := exec.Command(exe, append([]string{"analyse", "--background"}, args...)...)
	cmd.Stdout, cmd.Stderr = logFile, logFile
	cmd.SysProcAttr = &syscall.SysProcAttr{Setsid: true}
	if err := cmd.Start(); err == nil {
		_ = cmd.Process.Release()
	}
	logFile.Close()
}

func mustJSON(v any) []byte {
	b, _ := json.Marshal(v)
	return b
}

func logf(format string, a ...any) {
	if err := paths.Ensure(); err != nil {
		return
	}
	f, err := os.OpenFile(paths.Join("sakha.log"), os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0o600)
	if err != nil {
		return
	}
	defer f.Close()
	fmt.Fprintf(f, "%s %s\n", time.Now().UTC().Format(time.RFC3339), fmt.Sprintf(format, a...))
}
