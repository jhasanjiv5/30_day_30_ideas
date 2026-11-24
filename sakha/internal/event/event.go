// Package event records what Sakha observes during a session, in an append-only queue.
//
// Only user-authored content is ever recorded: the user's prompts and the user's own
// edits to files Claude wrote. Tool output, web pages and model replies are never stored.
package event

import (
	"bufio"
	"encoding/json"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"github.com/jhasanjiv5/30_day_30_ideas/sakha/internal/paths"
)

// Kinds of events.
const (
	KindPrompt   = "prompt"    // a message the user typed
	KindUserEdit = "user_edit" // the user changed a file right after Claude wrote it
)

// Event is one observation, already redacted.
type Event struct {
	Time    time.Time `json:"time"`
	Session string    `json:"session"`
	Tool    string    `json:"tool"`              // claude-code, cursor, codex, import
	Project string    `json:"project,omitempty"` // working directory of the session
	Kind    string    `json:"kind"`
	Text    string    `json:"text"`           // redacted prompt, or "before → after" for edits
	File    string    `json:"file,omitempty"` // for user edits
}

// MaxPromptChars caps how much of a prompt is kept.
const MaxPromptChars = 2000

func queueFile(session string) string {
	return paths.Join("queue", safe(session)+".jsonl")
}

func safe(s string) string {
	s = strings.Map(func(r rune) rune {
		if r >= 'a' && r <= 'z' || r >= 'A' && r <= 'Z' || r >= '0' && r <= '9' || r == '-' || r == '_' {
			return r
		}
		return '_'
	}, s)
	if s == "" {
		return "unknown"
	}
	if len(s) > 80 {
		s = s[:80]
	}
	return s
}

// Append adds an event to its session's queue file.
func Append(ev Event) error {
	if err := paths.Ensure(); err != nil {
		return err
	}
	f, err := os.OpenFile(queueFile(ev.Session), os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0o600)
	if err != nil {
		return err
	}
	defer f.Close()
	b, err := json.Marshal(ev)
	if err != nil {
		return err
	}
	_, err = f.Write(append(b, '\n'))
	return err
}

// Sessions lists session ids that have queued events, oldest first.
func Sessions() ([]string, error) {
	entries, err := os.ReadDir(paths.Join("queue"))
	if os.IsNotExist(err) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	type item struct {
		id  string
		mod time.Time
	}
	var items []item
	for _, e := range entries {
		if !strings.HasSuffix(e.Name(), ".jsonl") {
			continue
		}
		info, err := e.Info()
		if err != nil {
			continue
		}
		items = append(items, item{strings.TrimSuffix(e.Name(), ".jsonl"), info.ModTime()})
	}
	sort.Slice(items, func(i, j int) bool { return items[i].mod.Before(items[j].mod) })
	out := make([]string, len(items))
	for i, it := range items {
		out[i] = it.id
	}
	return out, nil
}

// Load reads all events of a session.
func Load(session string) ([]Event, error) {
	f, err := os.Open(queueFile(session))
	if err != nil {
		return nil, err
	}
	defer f.Close()
	var evs []Event
	sc := bufio.NewScanner(f)
	sc.Buffer(make([]byte, 0, 64*1024), 1024*1024)
	for sc.Scan() {
		var ev Event
		if json.Unmarshal(sc.Bytes(), &ev) == nil {
			evs = append(evs, ev)
		}
	}
	return evs, sc.Err()
}

// Remove deletes a session's queue file once it has been analysed.
func Remove(session string) error {
	err := os.Remove(queueFile(session))
	if os.IsNotExist(err) {
		return nil
	}
	return err
}

// QueueDir is exposed for diagnostics.
func QueueDir() string { return filepath.Dir(queueFile("x")) }
