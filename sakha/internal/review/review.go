// Package review runs the interactive keep / edit / drop check-in in a terminal.
package review

import (
	"bufio"
	"fmt"
	"io"
	"strings"
	"time"

	"github.com/jhasanjiv5/30_day_30_ideas/sakha/internal/learn"
	"github.com/jhasanjiv5/30_day_30_ideas/sakha/internal/store"
)

// Run walks through pending habits. It returns how many decisions were recorded.
func Run(st *store.State, in io.Reader, out io.Writer, now time.Time) (int, error) {
	pending := learn.Pending(st)
	if len(pending) == 0 {
		fmt.Fprintln(out, "Nothing to review. Sakha will check in when it has noticed something new.")
		return 0, nil
	}
	r := bufio.NewReader(in)
	fmt.Fprintf(out, "Sakha noticed %d thing(s) about how you like to work.\n", len(pending))
	decided := 0
	for i, c := range pending {
		t, _ := store.TopicByID(c.Topic)
		fmt.Fprintf(out, "\n[%d/%d] %s · %s\n", i+1, len(pending), c.ID, t.Title)
		fmt.Fprintf(out, "  “%s”\n", c.Rule)
		scope := "everywhere"
		if c.Scope != "global" {
			scope = "only in " + c.Scope
		}
		fmt.Fprintf(out, "  Seen %d× in %d session(s), strongest signal: %s, applies %s\n", len(c.Evidence), c.Sessions(), c.Strongest(), scope)
		if c.ReviewNote != "" {
			fmt.Fprintf(out, "  Re-check: %s\n", c.ReviewNote)
		}
		for j, e := range c.Evidence {
			if j == 2 {
				break
			}
			fmt.Fprintf(out, "    · %s\n", e.Snippet)
		}
		for {
			fmt.Fprint(out, "  [k]eep  [e]dit  [d]rop  [s]kip  [q]uit > ")
			line, err := r.ReadString('\n')
			choice := strings.ToLower(strings.TrimSpace(line))
			if err != nil && choice == "" {
				fmt.Fprintln(out)
				return decided, nil
			}
			switch choice {
			case "k", "keep", "y", "yes":
				_ = learn.Decide(st, c.ID, "keep", "", now)
				fmt.Fprintln(out, "  ✓ kept")
				decided++
			case "e", "edit":
				fmt.Fprint(out, "  New wording: ")
				text, _ := r.ReadString('\n')
				if err := learn.Decide(st, c.ID, "edit", text, now); err != nil {
					fmt.Fprintf(out, "  %v\n", err)
					continue
				}
				fmt.Fprintf(out, "  ✓ saved as “%s”\n", c.Rule)
				decided++
			case "d", "drop", "n", "no":
				_ = learn.Decide(st, c.ID, "drop", "", now)
				fmt.Fprintln(out, "  ✗ dropped (won't be suggested again)")
				decided++
			case "s", "skip", "":
				fmt.Fprintln(out, "  · skipped for now")
			case "q", "quit":
				return decided, nil
			default:
				continue
			}
			break
		}
	}
	return decided, nil
}
