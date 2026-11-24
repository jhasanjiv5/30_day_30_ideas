package hook

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"os"
	"strings"
	"time"

	"github.com/jhasanjiv5/30_day_30_ideas/sakha/internal/event"
	"github.com/jhasanjiv5/30_day_30_ideas/sakha/internal/paths"
	"github.com/jhasanjiv5/30_day_30_ideas/sakha/internal/redact"
)

// Files larger than this are not tracked for user edits.
const maxTrackedBytes = 256 * 1024

// tracked is a file Claude just wrote: its hash and a redacted snapshot, kept only
// until the session is analysed, so a later change can be recognised as the user's edit.
type tracked struct {
	Hash     string `json:"hash"`
	Snapshot string `json:"snapshot"`
}

func writesFile(session string) string {
	return paths.Join("writes", sanitize(session)+".json")
}

func sanitize(s string) string {
	b := []byte(s)
	for i, c := range b {
		if !(c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z' || c >= '0' && c <= '9' || c == '-' || c == '_') {
			b[i] = '_'
		}
	}
	if len(b) == 0 {
		return "unknown"
	}
	if len(b) > 80 {
		b = b[:80]
	}
	return string(b)
}

func loadTracked(session string) map[string]tracked {
	m := map[string]tracked{}
	if b, err := os.ReadFile(writesFile(session)); err == nil {
		_ = json.Unmarshal(b, &m)
	}
	return m
}

func saveTracked(session string, m map[string]tracked) {
	if err := paths.Ensure(); err != nil {
		return
	}
	b, err := json.Marshal(m)
	if err != nil {
		return
	}
	_ = os.WriteFile(writesFile(session), b, 0o600)
}

// readText returns a file's contents if it is a reasonably small text file.
func readText(path string) ([]byte, bool) {
	info, err := os.Stat(path)
	if err != nil || info.IsDir() || info.Size() > maxTrackedBytes {
		return nil, false
	}
	b, err := os.ReadFile(path)
	if err != nil || bytes.IndexByte(b, 0) >= 0 {
		return nil, false
	}
	return b, true
}

func hashOf(b []byte) string {
	h := sha256.Sum256(b)
	return hex.EncodeToString(h[:])
}

// TrackWrite remembers the state of a file right after the agent wrote it.
func TrackWrite(session, path string) {
	b, ok := readText(path)
	if !ok {
		return
	}
	m := loadTracked(session)
	m[path] = tracked{Hash: hashOf(b), Snapshot: redact.Text(string(b))}
	saveTracked(session, m)
}

// CheckUserEdits looks at every file the agent wrote this session. If the file changed
// since, the user (or something the user ran) edited it: record a user_edit event with
// the changed lines, then update the snapshot so the same edit isn't counted twice.
func CheckUserEdits(session, tool, project string) int {
	m := loadTracked(session)
	if len(m) == 0 {
		return 0
	}
	found := 0
	for path, t := range m {
		b, ok := readText(path)
		if !ok {
			delete(m, path)
			continue
		}
		h := hashOf(b)
		if h == t.Hash {
			continue
		}
		current := redact.Text(string(b))
		before, after := changedBlock(t.Snapshot, current)
		if strings.TrimSpace(before+after) != "" {
			_ = event.Append(event.Event{
				Time: time.Now().UTC(), Session: session, Tool: tool, Project: project,
				Kind: event.KindUserEdit, File: path,
				Text: redact.Snippet(before, 200) + " → " + redact.Snippet(after, 200),
			})
			found++
		}
		m[path] = tracked{Hash: h, Snapshot: current}
	}
	saveTracked(session, m)
	return found
}

// changedBlock trims the common leading and trailing lines and returns the differing middle.
func changedBlock(a, b string) (before, after string) {
	al, bl := strings.Split(a, "\n"), strings.Split(b, "\n")
	i := 0
	for i < len(al) && i < len(bl) && al[i] == bl[i] {
		i++
	}
	j := 0
	for j < len(al)-i && j < len(bl)-i && al[len(al)-1-j] == bl[len(bl)-1-j] {
		j++
	}
	return strings.Join(al[i:len(al)-j], "\n"), strings.Join(bl[i:len(bl)-j], "\n")
}

// ForgetWrites drops the snapshots of a session once it has been analysed.
func ForgetWrites(session string) {
	_ = os.Remove(writesFile(session))
}

// RefreshTracked re-snapshots files the agent wrote, without recording anything. Called after
// the agent's own shell commands, so their changes are never attributed to the user.
func RefreshTracked(session string) {
	m := loadTracked(session)
	if len(m) == 0 {
		return
	}
	changed := false
	for path, t := range m {
		b, ok := readText(path)
		if !ok {
			delete(m, path)
			changed = true
			continue
		}
		if h := hashOf(b); h != t.Hash {
			m[path] = tracked{Hash: h, Snapshot: redact.Text(string(b))}
			changed = true
		}
	}
	if changed {
		saveTracked(session, m)
	}
}
