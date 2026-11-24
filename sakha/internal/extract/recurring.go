package extract

import (
	"regexp"
	"strings"

	"github.com/jhasanjiv5/30_day_30_ideas/sakha/internal/redact"
	"github.com/jhasanjiv5/30_day_30_ideas/sakha/internal/store"
)

// Things people keep asking an agent to include. Asked once, it's a task detail; asked across
// several sessions ("…with a dataflow diagram", "…add user interaction diagrams…"), it's a habit.
var deliverables = map[string]string{
	"diagram": "ui-design", "chart": "ui-design", "graph": "ui-design", "illustration": "ui-design",
	"visual": "ui-design", "screenshot": "ui-design", "mockup": "ui-design", "wireframe": "ui-design",
	"gif": "ui-design", "frame": "ui-design",
	"test": "coding", "example": "writing-tone", "citation": "writing-tone",
	"summary": "writing-tone", "recap": "workflow", "checklist": "workflow", "timeline": "workflow",
	"glossary": "writing-tone", "faq": "writing-tone",
	// Left out on purpose: "source" (usually source text, not citations) and "readme"
	// (usually the file being edited, not something to add).
}

// "test" only counts as a software test with a qualifier: "field test" or "blind test" is
// research vocabulary, not a request for unit tests.
var softwareTest = map[string]bool{
	"unit": true, "integration": true, "end-to-end": true, "e2e": true, "automated": true,
	"regression": true, "snapshot": true, "smoke": true, "ui": true, "playwright": true, "golden": true,
}

var (
	requestVerbRe = regexp.MustCompile(`(?i)\b(?:add|adding|include|including|with|show|create|generate|attach|provide|give|plus|need|want|instruct)\b`)
	screenshotRe  = regexp.MustCompile(`(?i)\bscr+e+n[\s-]*shots?\b`)
	wordRe        = regexp.MustCompile(`[a-z][a-z\-]*`)
	notModifier   = map[string]bool{
		"a": true, "an": true, "the": true, "some": true, "any": true, "more": true, "few": true, "clear": true,
		"good": true, "nice": true, "simple": true, "necessary": true, "important": true, "relevant": true,
		"complete": true, "full": true, "and": true, "or": true, "with": true, "of": true, "in": true, "to": true,
		"add": true, "include": true, "show": true, "create": true, "also": true, "my": true, "your": true,
		"its": true, "their": true, "this": true, "that": true, "these": true, "those": true, "other": true,
		"new": true, "small": true, "quick": true, "short": true, "detailed": true, "proper": true, "for": true,
	}
)

// requested finds deliverables the user asks for in one sentence, as quiet-pattern sightings.
func requested(sentence string) []Habit {
	if !requestVerbRe.MatchString(sentence) {
		return nil
	}
	low := screenshotRe.ReplaceAllString(strings.ToLower(sentence), "screenshot")
	words := wordRe.FindAllString(low, -1)
	seen := map[string]bool{}
	var out []Habit
	for i, w := range words {
		noun := strings.TrimSuffix(w, "s")
		topic, ok := deliverables[noun]
		if !ok {
			continue
		}
		if noun == "test" && (i == 0 || !softwareTest[words[i-1]]) {
			continue
		}
		phrase := plural(noun)
		if i > 0 && !notModifier[words[i-1]] && len(words[i-1]) > 2 {
			phrase = words[i-1] + " " + phrase
		}
		if seen[phrase] {
			continue
		}
		seen[phrase] = true
		out = append(out, Habit{
			Topic:   topic,
			Rule:    "When relevant, include " + phrase + ".",
			Signal:  store.SignalPattern,
			Snippet: redact.Snippet(sentence, 200),
		})
	}
	return out
}

func plural(noun string) string {
	switch {
	case noun == "readme" || noun == "faq" || noun == "gif":
		return noun + "s"
	case strings.HasSuffix(noun, "y") && noun != "summary":
		return noun + "s"
	case noun == "summary":
		return "summaries"
	}
	return noun + "s"
}
