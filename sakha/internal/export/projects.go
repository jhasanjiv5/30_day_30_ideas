package export

import (
	"encoding/json"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/jhasanjiv5/30_day_30_ideas/sakha/internal/paths"
)

func projectsFile() string { return paths.Join("exported-projects.json") }

// RecordProject remembers a project folder Sakha exported into.
func RecordProject(project string) {
	abs, err := filepath.Abs(project)
	if err != nil {
		return
	}
	list := ExportedProjects()
	for _, p := range list {
		if p == abs {
			return
		}
	}
	list = append(list, abs)
	sort.Strings(list)
	if paths.Ensure() != nil {
		return
	}
	b, _ := json.MarshalIndent(list, "", "  ")
	_ = os.WriteFile(projectsFile(), b, 0o600)
}

// ExportedProjects lists project folders Sakha has exported into.
func ExportedProjects() []string {
	var list []string
	if b, err := os.ReadFile(projectsFile()); err == nil {
		_ = json.Unmarshal(b, &list)
	}
	return list
}

// RemoveSection deletes Sakha's marked section from text. It reports whether a section was found.
func RemoveSection(text string) (string, bool) {
	start := strings.Index(text, BeginMarker)
	end := strings.Index(text, EndMarker)
	if start < 0 || end < start {
		return text, false
	}
	before := strings.TrimRight(text[:start], "\n")
	after := strings.TrimLeft(text[end+len(EndMarker):], "\n")
	switch {
	case before == "" && after == "":
		return "", true
	case before == "":
		return after, true
	case after == "":
		return before + "\n", true
	}
	return before + "\n\n" + after, true
}
