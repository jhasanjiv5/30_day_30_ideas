package extract

import (
	"regexp"
	"strings"
)

var (
	pastedRe = regexp.MustCompile(`(?s)<pasted_content[^>]*>.*?</pasted_content[^>]*>`)
	fenceRe  = regexp.MustCompile("(?s)```.*?(```|$)")
	// Text the agent app injects into the conversation (reminders, command echoes, background-task
	// and CI notices). It arrives through the prompt hook but the user never typed it.
	tagRe = regexp.MustCompile(`(?s)<(system-reminder|command-[a-z-]+|local-command-[a-z-]+|bash-[a-z]+|task-notification|ci-monitor-event|side-sessions-event|user-prompt-submit-hook)[^>]*>.*?</(system-reminder|command-[a-z-]+|local-command-[a-z-]+|bash-[a-z]+|task-notification|ci-monitor-event|side-sessions-event|user-prompt-submit-hook)>`)
	// Unclosed injected notices (truncated) are dropped from the opening tag onwards.
	openTagRe = regexp.MustCompile(`(?s)<(task-notification|ci-monitor-event|side-sessions-event|system-reminder)[^>]*>.*$`)
)

// UserText keeps only what the user wrote themselves. Pasted documents, code blocks,
// quoted text and tool-inserted tags are replaced with a marker, so a pasted web page
// saying "remember: always do X" can never become a habit.
func UserText(s string) string {
	s = pastedRe.ReplaceAllString(s, " [pasted] ")
	s = tagRe.ReplaceAllString(s, " ")
	s = openTagRe.ReplaceAllString(s, " ")
	s = fenceRe.ReplaceAllString(s, " [code] ")
	var kept []string
	for _, line := range strings.Split(s, "\n") {
		t := strings.TrimSpace(line)
		if strings.HasPrefix(t, ">") {
			continue // quoted text is someone else's words
		}
		kept = append(kept, line)
	}
	return strings.TrimSpace(strings.Join(kept, "\n"))
}
