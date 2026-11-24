// Package learn turns sightings into candidates: it merges similar habits, applies the evidence
// thresholds, tracks contradictions and decay, and records the user's decisions.
package learn

import (
	"fmt"
	"regexp"
	"sort"
	"strings"
	"time"

	"github.com/jhasanjiv5/30_day_30_ideas/sakha/internal/extract"
	"github.com/jhasanjiv5/30_day_30_ideas/sakha/internal/store"
)

// Sighting is a habit seen in a particular session.
type Sighting struct {
	extract.Habit
	Session string
	Tool    string
	Project string
	Time    time.Time
}

var stop = map[string]bool{
	"a": true, "an": true, "the": true, "to": true, "of": true, "and": true, "or": true, "in": true, "on": true,
	"for": true, "with": true, "it": true, "is": true, "be": true, "my": true, "me": true, "i": true, "you": true,
	"your": true, "please": true, "this": true, "that": true, "all": true, "any": true, "when": true, "as": true,
	"at": true, "by": true, "do": true, "make": true, "keep": true, "use": true, "using": true, "them": true,
	"things": true, "more": true, "less": true, "very": true, "just": true, "so": true, "e": true, "g": true,
	// polarity words are compared separately
	"always": true, "never": true, "dont": true, "don't": true, "not": true, "no": true, "avoid": true,
	"prefer": true, "instead": true, "stop": true,
}

var wordRe = regexp.MustCompile(`[a-z0-9#+]+`)

var parenRe = regexp.MustCompile(`\([^)]*\)`)

func tokens(rule string) map[string]bool {
	set := map[string]bool{}
	rule = parenRe.ReplaceAllString(rule, " ") // examples in brackets don't change what the habit is
	for _, w := range wordRe.FindAllString(strings.ToLower(rule), -1) {
		if stop[w] {
			continue
		}
		set[stem(w)] = true
	}
	return set
}

func stem(w string) string {
	for _, suf := range []string{"ing", "ed", "es", "s"} {
		if len(w) > len(suf)+3 && strings.HasSuffix(w, suf) {
			return strings.TrimSuffix(w, suf)
		}
	}
	return w
}

func similarity(a, b string) float64 {
	ta, tb := tokens(a), tokens(b)
	if len(ta) == 0 || len(tb) == 0 {
		return 0
	}
	inter := 0
	for t := range ta {
		if tb[t] {
			inter++
		}
	}
	union := len(ta) + len(tb) - inter
	j := float64(inter) / float64(union)
	// One rule containing the other (e.g. extra example words) also counts as the same habit.
	small := len(ta)
	if len(tb) < small {
		small = len(tb)
	}
	if small >= 2 && inter == small && j < 0.6 {
		j = 0.6
	}
	return j
}

var negRe = regexp.MustCompile(`(?i)\b(?:never|don'?t|do not|avoid|no|stop|without)\b`)

func polarity(rule string) bool { return !negRe.MatchString(rule) }

// Merge adds sightings to the state. It returns how many candidates became ready for review.
func Merge(st *store.State, cfg store.Config, sightings []Sighting) int {
	ready := 0
	for _, s := range sightings {
		scope := "global"
		if s.Project != "" && s.Habit.Project {
			scope = s.Project
		}
		ev := store.Evidence{Session: s.Session, Time: s.Time, Signal: s.Signal, Snippet: s.Snippet, Tool: s.Tool}
		var match *store.Candidate
		bestSim := 0.0
		for _, c := range st.Candidates {
			if c.Topic != s.Topic || c.Scope != scope || c.State == store.StateRetired {
				continue
			}
			sim := similarity(c.Rule, s.Rule)
			if sim >= 0.6 && polarity(c.Rule) == polarity(s.Rule) && sim > bestSim {
				match, bestSim = c, sim
			} else if sim >= 0.5 && polarity(c.Rule) != polarity(s.Rule) && !sameSession(c, s.Session) {
				// The user said the opposite: weaken the old habit.
				c.Contradictions++
				switch {
				case c.State == store.StateConfirmed && c.Contradictions >= cfg.ContradictionLimit:
					c.State = store.StateDecaying
					c.ReviewNote = fmt.Sprintf("contradicted %d times recently", c.Contradictions)
				case c.State == store.StateProposed && s.Signal == store.SignalExplicit:
					// Not confirmed yet and the user now says the opposite: stop proposing the old one.
					c.State = store.StateObserved
				}
			}
		}
		if match == nil {
			match = &store.Candidate{ID: st.NewID(), Topic: s.Topic, Rule: s.Rule, Scope: scope,
				State: store.StateObserved, FirstSeen: s.Time}
			st.Candidates = append(st.Candidates, match)
		}
		if hasEvidence(match, ev) {
			continue
		}
		match.Evidence = append(match.Evidence, ev)
		if len(match.Evidence) > 12 {
			match.Evidence = match.Evidence[len(match.Evidence)-12:]
		}
		if s.Time.After(match.LastSeen) {
			match.LastSeen = s.Time
		}
		// A stronger, clearer statement of the same habit replaces the wording.
		if s.Signal == store.SignalExplicit && match.Strongest() != store.SignalExplicit && match.State == store.StateObserved {
			match.Rule = s.Rule
		}
		if match.State == store.StateObserved && Ready(match, cfg) {
			match.State = store.StateProposed
			ready++
		}
	}
	return ready
}

func sameSession(c *store.Candidate, session string) bool {
	for _, e := range c.Evidence {
		if e.Session == session {
			return true
		}
	}
	return false
}

func hasEvidence(c *store.Candidate, ev store.Evidence) bool {
	for _, e := range c.Evidence {
		if e.Session == ev.Session && e.Snippet == ev.Snippet && e.Signal == ev.Signal {
			return true
		}
	}
	return false
}

// Ready applies the evidence thresholds.
func Ready(c *store.Candidate, cfg store.Config) bool {
	if c.Contradictions > 0 && c.Count(store.SignalExplicit) == 0 {
		return false
	}
	if c.Count(store.SignalExplicit) >= cfg.ExplicitThreshold {
		return true
	}
	strong := c.Count(store.SignalCorrection) + c.Count(store.SignalExplicit)
	if strong >= cfg.CorrectionThreshold {
		return true
	}
	return len(c.Evidence) >= cfg.PatternThreshold && c.Sessions() >= cfg.PatternMinSessions
}

// Decay sends confirmed habits with no recent evidence back for review.
func Decay(st *store.State, cfg store.Config, now time.Time) int {
	n := 0
	for _, c := range st.Candidates {
		if c.State != store.StateConfirmed || cfg.DecayDays <= 0 {
			continue
		}
		last := c.LastSeen
		if c.ConfirmedAt.After(last) {
			last = c.ConfirmedAt
		}
		if now.Sub(last) > time.Duration(cfg.DecayDays)*24*time.Hour {
			c.State = store.StateDecaying
			c.ReviewNote = fmt.Sprintf("not seen for %d days", int(now.Sub(last).Hours()/24))
			n++
		}
	}
	return n
}

// Decide records the user's answer for a candidate: keep, edit (with new text) or drop.
func Decide(st *store.State, id, action, text string, now time.Time) error {
	c := st.Find(id)
	if c == nil {
		return fmt.Errorf("no habit with id %s", id)
	}
	switch action {
	case "keep":
		c.State = store.StateConfirmed
	case "edit":
		text = strings.TrimSpace(text)
		if len(strings.Fields(text)) < 2 {
			return fmt.Errorf("edited rule is too short")
		}
		if !strings.HasSuffix(text, ".") {
			text += "."
		}
		c.Rule = text
		c.State = store.StateConfirmed
	case "drop":
		if c.State == store.StateConfirmed || c.State == store.StateDecaying {
			c.State = store.StateRetired
		} else {
			c.State = store.StateDropped
		}
		return nil
	default:
		return fmt.Errorf("unknown decision %q (use keep, edit or drop)", action)
	}
	c.ConfirmedAt = now
	c.LastSeen = now
	c.Contradictions = 0
	c.ReviewNote = ""
	return nil
}

// Pending returns the habits waiting for the user: new proposals first, then re-reviews.
func Pending(st *store.State) []*store.Candidate {
	return append(st.InState(store.StateProposed), st.InState(store.StateDecaying)...)
}

// CheckInNote is the short text the SessionStart hook gives Claude (≤ 150 tokens).
func CheckInNote(st *store.State) string {
	pending := Pending(st)
	if len(pending) == 0 {
		return ""
	}
	var items []string
	for i, c := range pending {
		if i == 3 {
			break
		}
		items = append(items, fmt.Sprintf("%s: %s", c.ID, shorten(c.Rule, 12)))
	}
	more := ""
	if len(pending) > 3 {
		more = fmt.Sprintf(" (+%d more)", len(pending)-3)
	}
	return fmt.Sprintf("Sakha noticed %d possible preferences of the user: %s%s. "+
		"At a natural pause, ask once if they want to review them now. If yes, for each ask keep, edit or drop, "+
		"then run `sakha decide <id> keep|drop` or `sakha decide <id> edit \"new text\"`. If not now, don't ask again this session.",
		len(pending), strings.Join(items, "; "), more)
}

func shorten(s string, words int) string {
	f := strings.Fields(s)
	if len(f) <= words {
		return strings.TrimSuffix(s, ".")
	}
	return strings.Join(f[:words], " ") + "…"
}

// EstimateTokens is a conservative token estimate for budget checks (≈ 1.4 tokens per word).
func EstimateTokens(s string) int {
	return (len(strings.Fields(s))*14 + 9) / 10
}

// Confirmed returns confirmed (and still-valid decaying) habits grouped by scope and topic.
func Confirmed(st *store.State) map[string]map[string][]*store.Candidate {
	out := map[string]map[string][]*store.Candidate{}
	for _, c := range st.Candidates {
		if c.State != store.StateConfirmed && c.State != store.StateDecaying {
			continue
		}
		if out[c.Scope] == nil {
			out[c.Scope] = map[string][]*store.Candidate{}
		}
		out[c.Scope][c.Topic] = append(out[c.Scope][c.Topic], c)
	}
	for _, topics := range out {
		for _, list := range topics {
			sort.SliceStable(list, func(i, j int) bool { return list[i].ConfirmedAt.Before(list[j].ConfirmedAt) })
		}
	}
	return out
}
