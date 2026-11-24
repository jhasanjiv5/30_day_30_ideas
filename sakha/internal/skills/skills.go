// Package skills renders confirmed habits as small, topic-wise skill files.
package skills

import (
	"fmt"
	"strings"

	"github.com/jhasanjiv5/30_day_30_ideas/sakha/internal/store"
)

// Marker identifies files Sakha owns; files without it are never changed or removed.
const Marker = "<!-- managed by sakha: review with `sakha review`, change with `sakha edit` -->"

// Name is the skill (and folder) name for a topic.
func Name(topic string) string { return "sakha-" + topic }

// Description is the one-line description agents use to decide when to load the skill.
func Description(topic string) string {
	t, ok := store.TopicByID(topic)
	if !ok {
		return "Preferences the user confirmed with Sakha."
	}
	return fmt.Sprintf("%s the user has confirmed (learned by Sakha). Use when %s.", t.Title, t.When)
}

// Body renders the markdown body (no front matter) within the word budget.
// It returns the body and how many rules were left out to fit the budget (newest are kept).
func Body(topic string, rules []string, budget int) (string, int) {
	t, _ := store.TopicByID(topic)
	title := t.Title
	if title == "" {
		title = topic
	}
	header := "# " + title + "\n\nFollow these preferences unless the user asks otherwise in the moment:\n\n"
	words := len(strings.Fields(header))
	kept := []string{}
	dropped := 0
	for i := len(rules) - 1; i >= 0; i-- { // newest first while filling the budget
		w := len(strings.Fields(rules[i])) + 1
		if words+w > budget {
			dropped++
			continue
		}
		words += w
		kept = append([]string{rules[i]}, kept...)
	}
	var b strings.Builder
	b.WriteString(header)
	for _, r := range kept {
		b.WriteString("- " + r + "\n")
	}
	return b.String(), dropped
}

// SkillMD renders a complete SKILL.md file for Claude Code / claude.ai.
func SkillMD(topic string, rules []string, budget int) (string, int) {
	body, dropped := Body(topic, rules, budget)
	return fmt.Sprintf("---\nname: %s\ndescription: %s\n---\n\n%s\n%s\n", Name(topic), Description(topic), body, Marker), dropped
}

// WordCount counts words in the body of a rendered skill (front matter and marker excluded).
func WordCount(skillMD string) int {
	s := skillMD
	if strings.HasPrefix(s, "---\n") {
		if end := strings.Index(s[4:], "\n---\n"); end >= 0 {
			s = s[4+end+5:]
		}
	}
	s = strings.Replace(s, Marker, "", 1)
	return len(strings.Fields(s))
}
