package learn

import (
	"strings"
	"testing"
	"time"

	"github.com/jhasanjiv5/30_day_30_ideas/sakha/internal/extract"
	"github.com/jhasanjiv5/30_day_30_ideas/sakha/internal/store"
)

var t0 = time.Date(2026, 11, 1, 10, 0, 0, 0, time.UTC)

func sight(session, topic, rule, signal string, at time.Time) Sighting {
	return Sighting{Habit: extract.Habit{Topic: topic, Rule: rule, Signal: signal, Snippet: rule + " (" + session + ")"},
		Session: session, Tool: "claude-code", Project: "/p", Time: at}
}

func newState() *store.State {
	return &store.State{Analysed: map[string]bool{}, Offered: map[string]bool{}}
}

func TestThresholdsBySignal(t *testing.T) {
	cfg := store.DefaultConfig()
	st := newState()
	Merge(st, cfg, []Sighting{sight("s1", "writing-tone", "Use British spelling.", store.SignalExplicit, t0)})
	if got := st.Candidates[0].State; got != store.StateProposed {
		t.Fatalf("explicit ask should be proposed at once, got %s", got)
	}

	st = newState()
	Merge(st, cfg, []Sighting{sight("s1", "ui-design", "Make it less saturated.", store.SignalCorrection, t0)})
	if st.Candidates[0].State != store.StateObserved {
		t.Fatal("one correction must not be enough")
	}
	Merge(st, cfg, []Sighting{sight("s2", "ui-design", "Make it less saturated.", store.SignalCorrection, t0)})
	if st.Candidates[0].State != store.StateProposed {
		t.Fatal("two corrections should propose")
	}

	st = newState()
	Merge(st, cfg, []Sighting{
		sight("s1", "writing-tone", "Use British spelling.", store.SignalPattern, t0),
		{Habit: extract.Habit{Topic: "writing-tone", Rule: "Use British spelling.", Signal: store.SignalPattern, Snippet: "other"}, Session: "s1", Time: t0},
		{Habit: extract.Habit{Topic: "writing-tone", Rule: "Use British spelling.", Signal: store.SignalPattern, Snippet: "third"}, Session: "s1", Time: t0},
	})
	if st.Candidates[0].State != store.StateObserved {
		t.Fatal("patterns from a single session must not be proposed")
	}
	Merge(st, cfg, []Sighting{sight("s2", "writing-tone", "Use British spelling.", store.SignalPattern, t0)})
	if st.Candidates[0].State != store.StateProposed {
		t.Fatal("3 pattern sightings across 2 sessions should propose")
	}
}

func TestSimilarWordingMerges(t *testing.T) {
	st := newState()
	cfg := store.DefaultConfig()
	Merge(st, cfg, []Sighting{
		sight("s1", "writing-tone", "Use British spelling.", store.SignalPattern, t0),
		sight("s2", "writing-tone", "Use British spelling (colour, organise, behaviour).", store.SignalPattern, t0),
	})
	if len(st.Candidates) != 1 {
		t.Fatalf("expected one merged candidate, got %d", len(st.Candidates))
	}
}

func TestDecideKeepEditDropAndRetire(t *testing.T) {
	st := newState()
	cfg := store.DefaultConfig()
	Merge(st, cfg, []Sighting{
		sight("s1", "coding", "Always add unit tests.", store.SignalExplicit, t0),
		sight("s1", "workflow", "Never push to main without asking.", store.SignalExplicit, t0),
	})
	a, b := st.Candidates[0], st.Candidates[1]
	if err := Decide(st, a.ID, "edit", "Add unit tests for every changed function", t0); err != nil {
		t.Fatal(err)
	}
	if a.State != store.StateConfirmed || a.Rule != "Add unit tests for every changed function." {
		t.Fatalf("edit failed: %+v", a)
	}
	_ = Decide(st, b.ID, "drop", "", t0)
	if b.State != store.StateDropped {
		t.Fatalf("drop of a proposal should be dropped, got %s", b.State)
	}
	_ = Decide(st, a.ID, "drop", "", t0)
	if a.State != store.StateRetired {
		t.Fatalf("drop of a confirmed habit should retire it, got %s", a.State)
	}
	// Dropped habits are never proposed again.
	Merge(st, cfg, []Sighting{sight("s9", "workflow", "Never push to main without asking.", store.SignalExplicit, t0)})
	if b.State != store.StateDropped {
		t.Fatal("a dropped habit came back")
	}
	if err := Decide(st, "h999", "keep", "", t0); err == nil {
		t.Fatal("unknown id should fail")
	}
}

func TestContradictionAndDecay(t *testing.T) {
	cfg := store.DefaultConfig()
	st := newState()
	Merge(st, cfg, []Sighting{sight("s1", "coding", "Always use tabs for indentation.", store.SignalExplicit, t0)})
	c := st.Candidates[0]
	_ = Decide(st, c.ID, "keep", "", t0)
	Merge(st, cfg, []Sighting{sight("s2", "coding", "Never use tabs for indentation.", store.SignalExplicit, t0.Add(time.Hour))})
	Merge(st, cfg, []Sighting{sight("s3", "coding", "Never use tabs for indentation, use spaces.", store.SignalExplicit, t0.Add(2*time.Hour))})
	if c.State != store.StateDecaying || !strings.Contains(c.ReviewNote, "contradicted") {
		t.Fatalf("contradicted habit should be re-offered, got %s (%s)", c.State, c.ReviewNote)
	}

	st = newState()
	Merge(st, cfg, []Sighting{sight("s1", "writing-tone", "Use British spelling.", store.SignalExplicit, t0)})
	_ = Decide(st, st.Candidates[0].ID, "keep", "", t0)
	if n := Decay(st, cfg, t0.Add(30*24*time.Hour)); n != 0 {
		t.Fatal("decayed too early")
	}
	if n := Decay(st, cfg, t0.Add(61*24*time.Hour)); n != 1 || st.Candidates[0].State != store.StateDecaying {
		t.Fatal("stale habit should be re-offered after 60 days")
	}
}

func TestCheckInNoteIsShort(t *testing.T) {
	st := newState()
	cfg := store.DefaultConfig()
	for i, r := range []string{"Use British spelling.", "Never push to main without asking me first.",
		"Prefer calm, Apple-like neutrals with one blue accent colour and generous whitespace everywhere.",
		"Always add unit tests.", "Keep commit messages short."} {
		Merge(st, cfg, []Sighting{sight("s1", store.Topics[i%len(store.Topics)].ID, r, store.SignalExplicit, t0)})
	}
	note := CheckInNote(st)
	if EstimateTokens(note) > 150 {
		t.Fatalf("note too long (%d tokens): %s", EstimateTokens(note), note)
	}
	if !strings.Contains(note, "+2 more") || !strings.Contains(note, "sakha decide") {
		t.Fatalf("note missing parts: %s", note)
	}
	if CheckInNote(newState()) != "" {
		t.Fatal("no note when nothing is pending")
	}
}
