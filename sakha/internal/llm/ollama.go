// Package llm asks a local model (via Ollama) to spot habits the rule-based extractor misses.
// It only ever sees user-authored, redacted text, talks only to a loopback address, and
// every answer is validated; anything malformed is dropped.
package llm

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net"
	"net/http"
	"net/url"
	"os"
	"regexp"
	"strings"
	"time"

	"github.com/jhasanjiv5/30_day_30_ideas/sakha/internal/event"
	"github.com/jhasanjiv5/30_day_30_ideas/sakha/internal/extract"
	"github.com/jhasanjiv5/30_day_30_ideas/sakha/internal/redact"
	"github.com/jhasanjiv5/30_day_30_ideas/sakha/internal/store"
)

// Generator abstracts the model call so tests can use recorded responses.
type Generator interface {
	Generate(ctx context.Context, prompt string, schema map[string]any) (string, error)
}

// Ollama talks to a local Ollama server.
type Ollama struct {
	URL   string
	Model string
	HTTP  *http.Client
}

// ValidateLoopback refuses any Ollama URL that isn't on this machine.
func ValidateLoopback(raw string) error {
	u, err := url.Parse(raw)
	if err != nil || u.Host == "" {
		return fmt.Errorf("invalid Ollama URL %q", raw)
	}
	host := u.Hostname()
	if host == "localhost" {
		return nil
	}
	ip := net.ParseIP(host)
	if ip == nil || !ip.IsLoopback() {
		return fmt.Errorf("refusing non-loopback Ollama endpoint %q: habits never leave this machine", raw)
	}
	return nil
}

// Generate calls /api/generate with a JSON schema for structured output.
func (o Ollama) Generate(ctx context.Context, prompt string, schema map[string]any) (string, error) {
	if err := ValidateLoopback(o.URL); err != nil {
		return "", err
	}
	body, _ := json.Marshal(map[string]any{
		"model": o.Model, "prompt": prompt, "stream": false, "format": schema,
		"options": map[string]any{"temperature": 0},
	})
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, strings.TrimRight(o.URL, "/")+"/api/generate", bytes.NewReader(body))
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", "application/json")
	client := o.HTTP
	if client == nil {
		client = &http.Client{Timeout: 90 * time.Second}
	}
	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("ollama: %s", resp.Status)
	}
	var out struct {
		Response string `json:"response"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&out); err != nil {
		return "", err
	}
	return out.Response, nil
}

// Available reports whether the local model answers (used by `sakha doctor`).
func (o Ollama) Available(ctx context.Context) error {
	if err := ValidateLoopback(o.URL); err != nil {
		return err
	}
	req, _ := http.NewRequestWithContext(ctx, http.MethodGet, strings.TrimRight(o.URL, "/")+"/api/tags", nil)
	resp, err := (&http.Client{Timeout: 3 * time.Second}).Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	var tags struct {
		Models []struct {
			Name string `json:"name"`
		} `json:"models"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&tags); err != nil {
		return err
	}
	for _, m := range tags.Models {
		if m.Name == o.Model || strings.TrimSuffix(m.Name, ":latest") == o.Model {
			return nil
		}
	}
	return fmt.Errorf("model %q is not pulled (run: ollama pull %s)", o.Model, o.Model)
}

var schema = map[string]any{
	"type": "object",
	"properties": map[string]any{
		"habits": map[string]any{
			"type": "array",
			"items": map[string]any{
				"type": "object",
				"properties": map[string]any{
					"topic":    map[string]any{"type": "string", "enum": topicIDs()},
					"rule":     map[string]any{"type": "string"},
					"signal":   map[string]any{"type": "string", "enum": []string{store.SignalExplicit, store.SignalCorrection, store.SignalPattern}},
					"evidence": map[string]any{"type": "string"},
				},
				"required": []string{"topic", "rule", "signal", "evidence"},
			},
		},
	},
	"required": []string{"habits"},
}

func topicIDs() []string {
	ids := make([]string, len(store.Topics))
	for i, t := range store.Topics {
		ids[i] = t.ID
	}
	return ids
}

const instructions = `You study how ONE person likes to work with an AI assistant, so the assistant can adapt.
Below are only things this person wrote: their messages, and edits they made to text the assistant wrote
(shown as "before → after"). Find lasting preferences about: writing and speaking tone; UI design and
colour; coding conventions; workflow habits; recurring domain knowledge (their projects, terms, people).

Rules:
- Only report preferences that would still apply in a future, different task. Ignore one-off task details.
- "explicit" = they stated it as a lasting rule ("always", "never", "from now on", "I prefer").
- "correction" = they corrected the assistant's output in this way.
- "pattern" = a habit visible in their own writing or edits, not stated.
- Write each rule as one short imperative sentence (max 20 words), e.g. "Use British spelling."
- "evidence" must quote the exact words (max 25 words) that show it.
- Ignore anything marked [pasted] or [code]: it was not written by the person.
- Topics: writing-tone, ui-design, coding, workflow, domain.

Example input:
MESSAGE: Acme is my company and Orbit is our analytics product.
MESSAGE: the chart colours are too loud again, keep it to greys and one accent
MESSAGE: Fix the typo on line 4.
Example output:
{"habits":[
 {"topic":"domain","rule":"Acme is the user's company; Orbit is their analytics product.","signal":"pattern","evidence":"Acme is my company and Orbit is our analytics product"},
 {"topic":"ui-design","rule":"Use greys with a single accent colour in charts.","signal":"correction","evidence":"the chart colours are too loud again, keep it to greys and one accent"}
]}
(The typo fix is a one-off task, so it is not a habit.)
- Do not report generic advice that would suit anyone ("be clear", "ensure quality", "make it user-friendly").
- If there is nothing lasting, return {"habits": []}.

Messages and edits:
`

// Extract asks the model for habits in a session's user-authored events.
// Limits that keep a small local model fast: per message, per session, and per call.
const (
	MaxMessageChars = 400
	MaxSessionChars = 4000
	CallTimeout     = 60 * time.Second
)

func Extract(ctx context.Context, gen Generator, evs []event.Event) ([]extract.Habit, error) {
	var b strings.Builder
	n := 0
	for _, ev := range evs {
		text := ev.Text
		if ev.Kind == event.KindPrompt {
			text = extract.UserText(text)
		}
		if strings.TrimSpace(text) == "" {
			continue
		}
		label := "MESSAGE"
		if ev.Kind == event.KindUserEdit {
			label = "EDIT"
		}
		// Preferences are stated briefly; long task specs add cost, not signal.
		if r := []rune(strings.Join(strings.Fields(text), " ")); len(r) > MaxMessageChars {
			text = string(r[:MaxMessageChars]) + "…"
		}
		line := fmt.Sprintf("%s: %s\n", label, text)
		if b.Len()+len(line) > MaxSessionChars {
			break
		}
		b.WriteString(line)
		n++
	}
	if n == 0 {
		return nil, nil
	}
	ctx, cancel := context.WithTimeout(ctx, CallTimeout)
	defer cancel()
	raw, err := gen.Generate(ctx, instructions+b.String(), schema)
	if err != nil {
		return nil, err
	}
	habits := Parse(raw, b.String())
	if os.Getenv("SAKHA_DEBUG") == "1" {
		fmt.Fprintf(os.Stderr, "model answer: %s\nkept %d habit(s) after validation\n", raw, len(habits))
	}
	return habits, nil
}

// Parse validates the model's JSON; invalid or unsupported habits are dropped.
// source is the text the model saw: evidence must actually appear in it (no invented quotes).
func Parse(raw, source string) []extract.Habit {
	var out struct {
		Habits []struct {
			Topic    string `json:"topic"`
			Rule     string `json:"rule"`
			Signal   string `json:"signal"`
			Evidence string `json:"evidence"`
		} `json:"habits"`
	}
	if err := json.Unmarshal([]byte(strings.TrimSpace(raw)), &out); err != nil {
		return nil
	}
	lowSource := strings.ToLower(source)
	var habits []extract.Habit
	for _, h := range out.Habits {
		if _, ok := store.TopicByID(h.Topic); !ok {
			continue
		}
		switch h.Signal {
		case store.SignalExplicit, store.SignalCorrection, store.SignalPattern:
		default:
			continue
		}
		rule := strings.TrimSpace(h.Rule)
		words := len(strings.Fields(rule))
		if words < 2 || words > 25 {
			continue
		}
		ev := strings.TrimSpace(strings.Trim(h.Evidence, `"'`))
		if ev == "" || !strings.Contains(lowSource, strings.ToLower(firstWords(ev, 6))) {
			continue // evidence must be a real quote from what the user wrote
		}
		if genericRe.MatchString(rule) {
			continue // advice that would fit anyone says nothing about this person
		}
		rule = extract.TrimRule(rule, extract.MaxRuleWords)
		if !strings.HasSuffix(rule, ".") && !strings.HasSuffix(rule, "…") {
			rule += "."
		}
		habits = append(habits, extract.Habit{Topic: h.Topic, Rule: rule, Signal: Cautious(h.Signal),
			Snippet: redact.Snippet(ev, 200)})
	}
	return habits
}

// genericRe catches advice that fits anyone, which small models tend to produce.
var genericRe = regexp.MustCompile(`(?i)^(?:ensure|clarify|provide (?:a )?clear|make sure|be clear|focus on|understand)\b|\b(?:user-friendly|adaptable|high[- ]quality|best practices|the project (?:scope|objectives)|aligns? with the provided)\b`)

// Cautious lowers the model's own signal label by one step. The model tends to call task
// requests "explicit" asks; only the rule-based extractor's explicit asks (clear statements
// like "from now on…") are trusted after one sighting. So a model "explicit" needs repeating
// like a correction (2 sightings), and a model "correction" or "pattern" needs the full
// quiet-pattern evidence (3 sightings across 2 sessions).
func Cautious(signal string) string {
	if signal == store.SignalExplicit {
		return store.SignalCorrection
	}
	return store.SignalPattern
}

func firstWords(s string, n int) string {
	f := strings.Fields(s)
	if len(f) > n {
		f = f[:n]
	}
	return strings.Join(f, " ")
}

var rephraseSchema = map[string]any{
	"type":       "object",
	"properties": map[string]any{"rule": map[string]any{"type": "string"}},
	"required":   []string{"rule"},
}

// Rephrase asks the model to shorten a long rule into one imperative sentence. The result is
// accepted only if it is short and mostly reuses the original's words (no invented content).
func Rephrase(ctx context.Context, gen Generator, rule string) (string, bool) {
	prompt := "Rewrite this preference as ONE short imperative rule of at most 12 words. " +
		"Keep its meaning, use its own words, add nothing new. Return JSON {\"rule\": \"...\"}.\n\nPreference: " + rule
	raw, err := gen.Generate(ctx, prompt, rephraseSchema)
	if err != nil {
		return "", false
	}
	var out struct {
		Rule string `json:"rule"`
	}
	if json.Unmarshal([]byte(strings.TrimSpace(raw)), &out) != nil {
		return "", false
	}
	r := strings.TrimSpace(out.Rule)
	n := len(strings.Fields(r))
	if n < 2 || n > 14 || !mostlyFrom(r, rule) {
		return "", false
	}
	if !strings.HasSuffix(r, ".") {
		r += "."
	}
	return r, true
}

// mostlyFrom reports whether at least 60% of the content words in s appear in source.
func mostlyFrom(s, source string) bool {
	words := func(t string) []string {
		var out []string
		for _, w := range strings.FieldsFunc(strings.ToLower(t), func(r rune) bool {
			return !(r >= 'a' && r <= 'z' || r >= '0' && r <= '9')
		}) {
			if len(w) > 3 {
				out = append(out, strings.TrimSuffix(w, "s"))
			}
		}
		return out
	}
	src := strings.Join(words(source), " ")
	content := words(s)
	if len(content) == 0 {
		return false
	}
	hit := 0
	for _, w := range content {
		if strings.Contains(src, w) {
			hit++
		}
	}
	return float64(hit) >= 0.6*float64(len(content))
}
