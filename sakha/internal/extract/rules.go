// Package extract finds habit candidates in user-authored text. The rule-based extractor
// here always runs; the local-model extractor (package llm) adds richer findings when available.
package extract

import (
	"regexp"
	"strings"
	"unicode"

	"github.com/jhasanjiv5/30_day_30_ideas/sakha/internal/event"
	"github.com/jhasanjiv5/30_day_30_ideas/sakha/internal/redact"
	"github.com/jhasanjiv5/30_day_30_ideas/sakha/internal/store"
)

// Habit is one sighting of a possible habit.
type Habit struct {
	Topic   string
	Rule    string
	Signal  string
	Snippet string
	Project bool // true if the user scoped it to the current project
}

// Rules runs the rule-based extractor over one session's events.
func Rules(evs []event.Event) []Habit {
	var out []Habit
	for _, ev := range evs {
		switch ev.Kind {
		case event.KindPrompt:
			out = append(out, fromPrompt(ev.Text)...)
		case event.KindUserEdit:
			out = append(out, fromEdit(ev.Text)...)
		}
	}
	return out
}

var (
	sentenceSplit = regexp.MustCompile(`[.!?;\n]+\s*`)
	projectScope  = regexp.MustCompile(`(?i)\b(?:in|for) this (?:project|repo|repository|codebase|app|folder)\b|\bhere\b`)

	// Words that make an ask durable rather than about the current task.
	durableRe = regexp.MustCompile(`(?i)\b(?:from now on|going forward|in (?:the )?future|by default|as a rule|always|never|every time|whenever|don'?t ever|do not ever|i (?:always |really )?(?:prefer|like)|i (?:don'?t|do not) like|i hate|i(?:'d| would) rather|make sure (?:to|you)|remember to|stick to)\b`)
	// Base-form verbs allowed right after "always"/"never", so "it always crashes" is not an instruction.
	imperativeAfter = regexp.MustCompile(`(?i)\b(?:always|never)\s+(?:use|write|keep|add|make|include|put|start|end|ask|run|prefer|be|say|call|name|format|sort|show|give|reply|answer|respond|explain|mention|check|test|commit|push|wrap|split|limit|avoid|stick|default|go|do|leave|place|choose|pick|stay|follow|capitali[sz]e|spell|open|close|create|delete|remove|lead|finish|summari[sz]e|label|cite|link|title|number|align|center|centre|round|apply|design|build|support|provide|offer|draft|structure|organi[sz]e|separate|paste|share|log|print|store|hardcode|expose|present|translate|quote|ship|deploy|mark|tag|document|describe|list|highlight)\b`)
	alwaysNever     = regexp.MustCompile(`(?i)\b(?:always|never)\b`)
	otherDurableRe  = regexp.MustCompile(`(?i)\b(?:prefer|like|hate|rather|from now on|going forward|by default|make sure|remember to|stick to)\b`)
	neverMindRe     = regexp.MustCompile(`(?i)\bnever ?mind\b`)

	noPrefix     = regexp.MustCompile(`(?i)^(?:no|nope|not like that)[,.!:\-–—\s]+(.{8,})$`)
	tooRe        = regexp.MustCompile(`(?i)\b(?:it'?s|this is|that'?s|they'?re|way|a bit|far|much|still)?\s*too (long|short|wordy|verbose|formal|casual|informal|bright|dark|busy|cluttered|colou?rful|technical|salesy|stiff|loud|playful|dense|plain|saturated|small|big|large)\b`)
	moreLessRe   = regexp.MustCompile(`(?i)\bmake (?:it|this|them|that|the [a-z]+) (more|less) ([a-z\-]+(?: [a-z\-]+)?)`)
	insteadRe    = regexp.MustCompile(`(?i)\buse ([^,.;]{2,80}?) instead of ([^,.;]{2,80})`)
	insteadRe2   = regexp.MustCompile(`(?i)\binstead of ([^,]{2,80}?),? (?:use|go with|try|prefer) ([^,.;]{2,80})`)
	shorterRe    = regexp.MustCompile(`(?i)^(?:(?:much|way|a lot|a bit)\s+)?(?:shorter|more concise|less wordy|tighter|briefer)(?: please)?$`)
	leadingNoise = regexp.MustCompile(`(?i)^(?:(?:please|pls|also|and|but|so|ok(?:ay)?|hey|oh|btw|remember|note)[,:]?\s+)+`)
)

func fromPrompt(text string) []Habit {
	text = UserText(text)
	var out []Habit
	british := 0
	american := 0
	for _, raw := range sentenceSplit.Split(text, -1) {
		s := strings.TrimSpace(raw)
		if s == "" || strings.Contains(s, "[pasted]") || strings.Contains(s, "[code]") {
			continue
		}
		b, a := spelling(s)
		british += b
		american += a
		out = append(out, requested(s)...)
		if h, ok := explicit(s); ok {
			out = append(out, h)
			continue
		}
		if h, ok := correction(s); ok {
			out = append(out, h)
		}
	}
	if british >= 1 && american == 0 {
		out = append(out, Habit{Topic: "writing-tone", Rule: "Use British spelling (colour, organise, behaviour).",
			Signal: store.SignalPattern, Snippet: redact.Snippet("British spelling in your message: "+strings.Join(britishWords(text), ", "), 200)})
	}
	return out
}

// maxRuleSentenceWords: longer sentences are task descriptions, not standing preferences.
const maxRuleSentenceWords = 35

// durableAtStart reports whether a durable marker opens the sentence or one of its clauses.
// "From now on, use…", "For slides, always use…" and "I prefer…" qualify; "create skills for
// quick reference in the future" and "make a one-pager whenever required" do not: there the
// marker is buried in a task request.
func durableAtStart(s string) bool {
	loc := durableRe.FindStringIndex(s)
	if loc == nil {
		return false
	}
	before := s[:loc[0]]
	if len(strings.Fields(before)) <= 2 {
		return true
	}
	cut := strings.LastIndexAny(before, ",:—–")
	if cut < 0 {
		return false
	}
	return len(strings.Fields(before[cut+1:])) <= 2 && len(strings.Fields(before[:cut])) <= 6
}

func explicit(s string) (Habit, bool) {
	if !durableRe.MatchString(s) || len(strings.Fields(s)) > maxRuleSentenceWords || !durableAtStart(s) {
		return Habit{}, false
	}
	if alwaysNever.MatchString(s) && !imperativeAfter.MatchString(s) && !otherDurableRe.MatchString(s) {
		return Habit{}, false // e.g. "it always crashes"
	}
	if neverMindRe.MatchString(s) {
		return Habit{}, false
	}
	if len(strings.Fields(s)) < 3 {
		return Habit{}, false
	}
	rule := imperative(s)
	if rule == "" {
		return Habit{}, false
	}
	return Habit{Topic: Classify(s, "workflow"), Rule: rule, Signal: store.SignalExplicit,
		Snippet: redact.Snippet(s, 200), Project: projectScope.MatchString(s)}, true
}

func correction(s string) (Habit, bool) {
	var rule string
	switch {
	case shorterRe.MatchString(s):
		rule = "Keep responses short and concise."
	case insteadRe.MatchString(s):
		m := insteadRe.FindStringSubmatch(s)
		rule = "Use " + firstWords(m[1], 6) + " instead of " + firstWords(m[2], 6) + "."
	case insteadRe2.MatchString(s):
		m := insteadRe2.FindStringSubmatch(s)
		rule = "Use " + firstWords(m[2], 6) + " instead of " + firstWords(m[1], 6) + "."
	case moreLessRe.MatchString(s):
		m := moreLessRe.FindStringSubmatch(s)
		rule = "Make it " + strings.ToLower(m[1]) + " " + strings.ToLower(m[2]) + "."
	case tooRe.MatchString(s):
		m := tooRe.FindStringSubmatch(s)
		rule = tooRule(strings.ToLower(m[1]))
	case noPrefix.MatchString(s):
		m := noPrefix.FindStringSubmatch(s)
		rest := strings.TrimSpace(m[1])
		if n := len(strings.Fields(rest)); n < 3 || n > 20 {
			return Habit{}, false // too short to mean anything, or a long task re-explanation
		}
		rule = imperative(rest)
	default:
		return Habit{}, false
	}
	if rule == "" {
		return Habit{}, false
	}
	def := "writing-tone"
	return Habit{Topic: Classify(s+" "+rule, def), Rule: rule, Signal: store.SignalCorrection,
		Snippet: redact.Snippet(s, 200), Project: projectScope.MatchString(s)}, true
}

func tooRule(word string) string {
	switch word {
	case "long", "wordy", "verbose", "dense":
		return "Keep responses short and concise."
	case "formal", "stiff":
		return "Keep the tone relaxed rather than formal."
	case "casual", "informal", "playful", "salesy", "loud":
		return "Keep the tone professional and understated."
	case "bright", "colourful", "colorful", "saturated", "busy", "cluttered":
		return "Prefer calm, minimal visuals with restrained colour."
	case "technical":
		return "Explain in plain language; keep jargon out."
	case "short", "plain":
		return "Give a little more detail and context."
	case "dark":
		return "Avoid overly dark colours."
	case "small":
		return "Use larger sizes for text and controls."
	case "big", "large":
		return "Use more compact sizes."
	}
	return ""
}

var imperativeRepl = []struct {
	re *regexp.Regexp
	to string
}{
	{regexp.MustCompile(`(?i)^(?:from now on|going forward|in (?:the )?future|by default|as a rule)[,:]?\s*`), ""},
	{regexp.MustCompile(`(?i)^(?:please\s+)?(?:don'?t|do not) ever\s+`), "Never "},
	{regexp.MustCompile(`(?i)^i(?:'d| would) rather\s+(?:you\s+)?`), "Prefer to "},
	{regexp.MustCompile(`(?i)^i (?:always |really )?(?:prefer|like)\s+(?:it )?(?:when you|if you|you to)\s+`), ""},
	{regexp.MustCompile(`(?i)^i (?:always |really )?(?:prefer|like)\s+`), "Prefer "},
	{regexp.MustCompile(`(?i)^i (?:don'?t|do not) like\s+(?:it when you\s+|when you\s+)?`), "Avoid "},
	{regexp.MustCompile(`(?i)^i hate\s+(?:it when you\s+|when you\s+)?`), "Avoid "},
	{regexp.MustCompile(`(?i)^i (?:want|need) you to\s+`), ""},
	{regexp.MustCompile(`(?i)^(?:make sure (?:to|you)|remember to)\s+`), ""},
	{regexp.MustCompile(`(?i)^(?:you should|you must|you need to|can you|could you)\s+`), ""},
}

// MaxRuleWords keeps rules short enough to read at a glance in a review or skill file.
const MaxRuleWords = 16

var clauseBreak = regexp.MustCompile(`\s*(?:--|—|–|;|,\s+(?:and|but|so|then|which|because)\b|\s+(?:but|because|so that)\b)\s*`)

// TrimRule shortens a rule to at most max words, preferring to cut at a clause boundary
// and never cutting inside a word.
func TrimRule(s string, max int) string {
	s = strings.TrimSpace(s)
	if len(strings.Fields(s)) <= max {
		return s
	}
	for _, loc := range clauseBreak.FindAllStringIndex(s, -1) {
		head := strings.TrimSpace(s[:loc[0]])
		if n := len(strings.Fields(head)); n >= 4 && n <= max {
			return strings.TrimRight(head, " ,.") + "."
		}
	}
	return strings.Join(strings.Fields(s)[:max], " ") + "…"
}

// imperative turns a user sentence into a short rule in the imperative.
func imperative(s string) string {
	s = strings.TrimSpace(leadingNoise.ReplaceAllString(strings.TrimSpace(s), ""))
	for _, r := range imperativeRepl {
		s = r.re.ReplaceAllString(s, r.to)
	}
	s = strings.TrimSpace(strings.TrimRight(s, " ,:"))
	words := strings.Fields(s)
	if len(words) < 2 {
		return ""
	}
	s = TrimRule(s, MaxRuleWords)
	r := []rune(s)
	r[0] = unicode.ToUpper(r[0])
	s = string(r)
	if !strings.HasSuffix(s, ".") && !strings.HasSuffix(s, "…") {
		s += "."
	}
	return s
}

var (
	emojiRe = regexp.MustCompile(`[\x{1F300}-\x{1FAFF}\x{2600}-\x{27BF}]`)
)

// fromEdit learns from the user changing text the agent wrote ("before → after").
func fromEdit(text string) []Habit {
	parts := strings.SplitN(text, " → ", 2)
	if len(parts) != 2 {
		return nil
	}
	before, after := parts[0], parts[1]
	var out []Habit
	add := func(topic, rule string) {
		out = append(out, Habit{Topic: topic, Rule: rule, Signal: store.SignalCorrection, Snippet: redact.Snippet(text, 200)})
	}
	if emojiRe.MatchString(before) && !emojiRe.MatchString(after) {
		add("writing-tone", "Don't use emoji.")
	}
	if strings.Count(before, "!") > strings.Count(after, "!") && strings.Count(after, "!") == 0 {
		add("writing-tone", "Avoid exclamation marks.")
	}
	b1, a1 := spelling(before)
	b2, a2 := spelling(after)
	if a1 > 0 && b2 > b1 && a2 < a1 {
		add("writing-tone", "Use British spelling (colour, organise, behaviour).")
	}
	if wb, wa := len(strings.Fields(before)), len(strings.Fields(after)); wb >= 25 && wa > 0 && float64(wa) < 0.6*float64(wb) {
		add("writing-tone", "Keep responses short and concise.")
	}
	return out
}

var spellingPairs = [][2]string{
	{"colour", "color"}, {"favourite", "favorite"}, {"behaviour", "behavior"}, {"organise", "organize"},
	{"organisation", "organization"}, {"centre", "center"}, {"analyse", "analyze"}, {"optimise", "optimize"},
	{"customise", "customize"}, {"prioritise", "prioritize"}, {"summarise", "summarize"}, {"realise", "realize"},
	{"recognise", "recognize"}, {"licence", "license"}, {"grey", "gray"}, {"neighbour", "neighbor"},
	{"honour", "honor"}, {"labour", "labor"}, {"travelling", "traveling"}, {"modelling", "modeling"},
	{"catalogue", "catalog"}, {"programme", "program"}, {"defence", "defense"}, {"apologise", "apologize"},
}

// britishWords lists the British spellings found in s.
func britishWords(s string) []string {
	low := " " + strings.ToLower(s) + " "
	var found []string
	for _, p := range spellingPairs {
		if countWord(low, p[0]) > 0 {
			found = append(found, p[0])
		}
	}
	return found
}

// spelling counts British and American spellings in s.
func spelling(s string) (british, american int) {
	low := " " + strings.ToLower(s) + " "
	for _, p := range spellingPairs {
		british += countWord(low, p[0])
		american += countWord(low, p[1])
	}
	return
}

func countWord(text, w string) int {
	n := 0
	for _, f := range strings.FieldsFunc(text, func(r rune) bool { return !unicode.IsLetter(r) }) {
		if f == w || f == w+"s" || f == w+"ed" || f == w+"d" || f == w+"ing" || strings.TrimSuffix(f, "s") == w {
			n++
		}
	}
	return n
}

// firstWords keeps at most n whole words, stopping early at "with", "to", "and" or "so"
// clauses that usually add task detail ("apple like style with linked in arrangements").
func firstWords(s string, n int) string {
	var out []string
	for i, w := range strings.Fields(strings.TrimSpace(s)) {
		lw := strings.ToLower(w)
		if i >= 2 && (lw == "with" || lw == "to" || lw == "so" || lw == "because") {
			break
		}
		if i == n {
			break
		}
		out = append(out, w)
	}
	return strings.Join(out, " ")
}
