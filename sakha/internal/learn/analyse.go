package learn

import (
	"context"
	"strings"
	"time"

	"github.com/jhasanjiv5/30_day_30_ideas/sakha/internal/event"
	"github.com/jhasanjiv5/30_day_30_ideas/sakha/internal/extract"
	"github.com/jhasanjiv5/30_day_30_ideas/sakha/internal/llm"
	"github.com/jhasanjiv5/30_day_30_ideas/sakha/internal/store"
)

// Report summarises one analysis run.
type Report struct {
	Sessions  int
	Sightings int
	NewReady  int
	Decayed   int
	ModelUsed bool
	ModelErr  string
	Rephrased int // long proposals shortened by the model
	Pruned    int // stale one-off observations forgotten
}

// SightingsFor extracts habits from one session's events with the rules extractor and,
// if gen is not nil, the local model. Each habit is attributed to the session's tool and project.
func SightingsFor(ctx context.Context, session string, evs []event.Event, gen llm.Generator) ([]Sighting, error) {
	if len(evs) == 0 {
		return nil, nil
	}
	tool, project, at := evs[0].Tool, evs[0].Project, evs[len(evs)-1].Time
	var habits []extract.Habit
	habits = append(habits, extract.Rules(evs)...)
	var modelErr error
	if gen != nil {
		h, err := llm.Extract(ctx, gen, evs)
		if err != nil {
			modelErr = err
		}
		habits = append(habits, h...)
	}
	out := make([]Sighting, 0, len(habits))
	for _, h := range habits {
		out = append(out, Sighting{Habit: h, Session: session, Tool: tool, Project: project, Time: at})
	}
	return out, modelErr
}

// Analyse processes queued sessions: extracts, merges, applies decay and clears the queue.
// sessions == nil means every session not yet analysed, except those in skip.
func Analyse(ctx context.Context, st *store.State, cfg store.Config, sessions []string, skip map[string]bool, gen llm.Generator, now time.Time) (Report, []string, error) {
	var rep Report
	if sessions == nil {
		all, err := event.Sessions()
		if err != nil {
			return rep, nil, err
		}
		for _, s := range all {
			if !skip[s] {
				sessions = append(sessions, s)
			}
		}
	}
	var done []string
	for _, s := range sessions {
		evs, err := event.Load(s)
		if err != nil {
			continue
		}
		sightings, mErr := SightingsFor(ctx, s, evs, gen)
		if gen != nil {
			rep.ModelUsed = mErr == nil
			if mErr != nil {
				rep.ModelErr = mErr.Error()
			}
		}
		rep.Sightings += len(sightings)
		wasProposed := map[string]bool{}
		for _, c := range st.InState(store.StateProposed) {
			wasProposed[c.ID] = true
		}
		rep.NewReady += Merge(st, cfg, sightings)
		if gen != nil {
			rep.Rephrased += rephraseNew(ctx, st, gen, wasProposed)
		}
		st.Analysed[s] = true
		rep.Sessions++
		done = append(done, s)
	}
	rep.Decayed = Decay(st, cfg, now)
	rep.Pruned = PruneStale(st, cfg, now)
	return rep, done, nil
}

// rephraseNew asks the model to shorten long, newly proposed rules. Your original words stay
// in the evidence, and a rewrite is kept only if it passes llm.Rephrase's checks.
func rephraseNew(ctx context.Context, st *store.State, gen llm.Generator, wasProposed map[string]bool) int {
	n := 0
	for _, c := range st.InState(store.StateProposed) {
		if wasProposed[c.ID] || (len(strings.Fields(c.Rule)) <= 10 && !strings.HasSuffix(c.Rule, "…")) {
			continue
		}
		cctx, cancel := context.WithTimeout(ctx, 30*time.Second)
		if r, ok := llm.Rephrase(cctx, gen, c.Rule); ok {
			c.Rule = r
			n++
		}
		cancel()
	}
	return n
}

// PruneStale forgets single-sighting observations that haven't recurred within the decay window,
// so "collecting evidence" doesn't fill up with one-off remarks.
func PruneStale(st *store.State, cfg store.Config, now time.Time) int {
	if cfg.DecayDays <= 0 {
		return 0
	}
	kept := st.Candidates[:0]
	n := 0
	for _, c := range st.Candidates {
		if c.State == store.StateObserved && len(c.Evidence) <= 1 &&
			now.Sub(c.LastSeen) > time.Duration(cfg.DecayDays)*24*time.Hour {
			n++
			continue
		}
		kept = append(kept, c)
	}
	st.Candidates = kept
	return n
}
