// Package store keeps Sakha's habit candidates and confirmed skills in ~/.sakha/state.json,
// with a version history for undo and a lock so background analysis and the CLI don't collide.
package store

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"github.com/jhasanjiv5/30_day_30_ideas/sakha/internal/paths"
)

// Topics Sakha knows about. Keys are stable ids used in skill names.
var Topics = []Topic{
	{"writing-tone", "Writing & speaking tone", "drafting prose, messages, docs, talks or slides"},
	{"ui-design", "UI design & colour", "designing interfaces, pages, slides, charts or choosing colours and type"},
	{"coding", "Coding conventions", "writing, reviewing or refactoring code"},
	{"workflow", "Workflow habits", "planning, committing, summarising, or deciding when to ask versus act"},
	{"domain", "Domain knowledge", "the user's projects, terms, people and context"},
}

// Topic describes one skill area.
type Topic struct {
	ID    string `json:"id"`
	Title string `json:"title"`
	When  string `json:"when"`
}

// TopicByID returns a topic and whether it exists.
func TopicByID(id string) (Topic, bool) {
	for _, t := range Topics {
		if t.ID == id {
			return t, true
		}
	}
	return Topic{}, false
}

// Signal strengths.
const (
	SignalExplicit   = "explicit"   // "always…", "never…", "from now on…"
	SignalCorrection = "correction" // "no, like this", or the user editing Claude's output
	SignalPattern    = "pattern"    // quiet habit in the user's own writing
)

// Candidate states.
const (
	StateObserved  = "observed"  // collecting evidence
	StateProposed  = "proposed"  // enough evidence; waiting for the user
	StateConfirmed = "confirmed" // part of a skill
	StateDropped   = "dropped"   // user said no; never proposed again
	StateDecaying  = "decaying"  // confirmed but stale or contradicted; offered for re-review
	StateRetired   = "retired"   // removed after review
)

// Evidence is one sighting of a habit.
type Evidence struct {
	Session string    `json:"session"`
	Time    time.Time `json:"time"`
	Signal  string    `json:"signal"`
	Snippet string    `json:"snippet"` // redacted, ≤ 200 chars
	Tool    string    `json:"tool"`
}

// Candidate is a possible habit and its evidence.
type Candidate struct {
	ID             string     `json:"id"`
	Topic          string     `json:"topic"`
	Rule           string     `json:"rule"`
	Scope          string     `json:"scope"` // "global" or an absolute project path
	State          string     `json:"state"`
	Evidence       []Evidence `json:"evidence"`
	Contradictions int        `json:"contradictions"`
	FirstSeen      time.Time  `json:"first_seen"`
	LastSeen       time.Time  `json:"last_seen"`
	ConfirmedAt    time.Time  `json:"confirmed_at,omitempty"`
	ReviewNote     string     `json:"review_note,omitempty"` // why it is being re-offered
}

// Sessions counts distinct sessions in the evidence.
func (c *Candidate) Sessions() int {
	seen := map[string]bool{}
	for _, e := range c.Evidence {
		seen[e.Session] = true
	}
	return len(seen)
}

// Strongest returns the strongest signal seen.
func (c *Candidate) Strongest() string {
	best := SignalPattern
	for _, e := range c.Evidence {
		if e.Signal == SignalExplicit {
			return SignalExplicit
		}
		if e.Signal == SignalCorrection {
			best = SignalCorrection
		}
	}
	return best
}

// Count counts evidence with a given signal.
func (c *Candidate) Count(signal string) int {
	n := 0
	for _, e := range c.Evidence {
		if e.Signal == signal {
			n++
		}
	}
	return n
}

// State is everything Sakha remembers.
type State struct {
	Version    int             `json:"version"`
	Paused     bool            `json:"paused"`
	Candidates []*Candidate    `json:"candidates"`
	Analysed   map[string]bool `json:"analysed_sessions"`
	NextID     int             `json:"next_id"`
	Offered    map[string]bool `json:"offered_sessions,omitempty"` // sessions already shown the check-in note
}

// Find returns a candidate by id.
func (s *State) Find(id string) *Candidate {
	for _, c := range s.Candidates {
		if c.ID == id {
			return c
		}
	}
	return nil
}

// InState lists candidates in any of the given states, sorted by topic then id.
func (s *State) InState(states ...string) []*Candidate {
	want := map[string]bool{}
	for _, st := range states {
		want[st] = true
	}
	var out []*Candidate
	for _, c := range s.Candidates {
		if want[c.State] {
			out = append(out, c)
		}
	}
	sort.SliceStable(out, func(i, j int) bool {
		if out[i].Topic != out[j].Topic {
			return out[i].Topic < out[j].Topic
		}
		return idNum(out[i].ID) < idNum(out[j].ID)
	})
	return out
}

func idNum(id string) int {
	var n int
	fmt.Sscanf(strings.TrimPrefix(id, "h"), "%d", &n)
	return n
}

// NewID hands out short ids like h7.
func (s *State) NewID() string {
	s.NextID++
	return fmt.Sprintf("h%d", s.NextID)
}

func stateFile() string { return paths.Join("state.json") }

// Load reads the state (an empty state if none exists yet).
func Load() (*State, error) {
	st := &State{Version: 1, Analysed: map[string]bool{}, Offered: map[string]bool{}}
	b, err := os.ReadFile(stateFile())
	if errors.Is(err, os.ErrNotExist) {
		return st, nil
	}
	if err != nil {
		return nil, err
	}
	if err := json.Unmarshal(b, st); err != nil {
		return nil, fmt.Errorf("read %s: %w", stateFile(), err)
	}
	if st.Analysed == nil {
		st.Analysed = map[string]bool{}
	}
	if st.Offered == nil {
		st.Offered = map[string]bool{}
	}
	return st, nil
}

// Save writes the state atomically, first copying the previous version into history.
func Save(st *State) error {
	if err := paths.Ensure(); err != nil {
		return err
	}
	if prev, err := os.ReadFile(stateFile()); err == nil {
		name := time.Now().UTC().Format("20060102T150405.000000000") + ".json"
		_ = os.WriteFile(paths.Join("history", name), prev, 0o600)
		pruneHistory(50)
	}
	return writeAtomic(stateFile(), st)
}

// SaveQuiet writes the state without adding a history entry (bookkeeping only).
func SaveQuiet(st *State) error {
	if err := paths.Ensure(); err != nil {
		return err
	}
	return writeAtomic(stateFile(), st)
}

func writeAtomic(path string, v any) error {
	b, err := json.MarshalIndent(v, "", "  ")
	if err != nil {
		return err
	}
	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, b, 0o600); err != nil {
		return err
	}
	return os.Rename(tmp, path)
}

func pruneHistory(keep int) {
	entries, err := os.ReadDir(paths.Join("history"))
	if err != nil || len(entries) <= keep {
		return
	}
	names := make([]string, 0, len(entries))
	for _, e := range entries {
		names = append(names, e.Name())
	}
	sort.Strings(names)
	for _, n := range names[:len(names)-keep] {
		_ = os.Remove(paths.Join("history", n))
	}
}

// Undo restores the most recent history entry. It returns the restored file's name.
func Undo() (string, error) {
	entries, err := os.ReadDir(paths.Join("history"))
	if err != nil || len(entries) == 0 {
		return "", errors.New("nothing to undo")
	}
	names := make([]string, 0, len(entries))
	for _, e := range entries {
		names = append(names, e.Name())
	}
	sort.Strings(names)
	last := names[len(names)-1]
	b, err := os.ReadFile(paths.Join("history", last))
	if err != nil {
		return "", err
	}
	if err := os.WriteFile(stateFile()+".tmp", b, 0o600); err != nil {
		return "", err
	}
	if err := os.Rename(stateFile()+".tmp", stateFile()); err != nil {
		return "", err
	}
	return last, os.Remove(paths.Join("history", last))
}

// Lock takes an exclusive lock for read-modify-write. Stale locks (> 2 min) are broken.
func Lock() (unlock func(), err error) {
	if err := paths.Ensure(); err != nil {
		return nil, err
	}
	lock := paths.Join("state.lock")
	deadline := time.Now().Add(10 * time.Second)
	for {
		f, err := os.OpenFile(lock, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0o600)
		if err == nil {
			f.Close()
			return func() { _ = os.Remove(lock) }, nil
		}
		if info, statErr := os.Stat(lock); statErr == nil && time.Since(info.ModTime()) > 2*time.Minute {
			_ = os.Remove(lock)
			continue
		}
		if time.Now().After(deadline) {
			return nil, fmt.Errorf("another sakha process holds %s", filepath.Base(lock))
		}
		time.Sleep(50 * time.Millisecond)
	}
}
