package auditlog

import (
	"bufio"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sync"
	"time"

	"github.com/kavach-sec/kavach/internal/config"
	"github.com/kavach-sec/kavach/internal/types"
)

// Entry represents one redacted security event in ~/.kavach/audit.jsonl.
// Raw secrets and raw prompts are NEVER stored.
type Entry struct {
	Timestamp   time.Time      `json:"timestamp"`
	Event       types.HookEvent `json:"event"`
	SessionID   string         `json:"session_id,omitempty"`
	ToolName    string         `json:"tool_name,omitempty"`
	Layer       types.Layer    `json:"layer"`
	RuleID      string         `json:"rule_id"`
	Category    types.Category `json:"category"`
	Tier        types.Tier     `json:"tier"`
	Action      types.Action   `json:"action"`
	Location    string         `json:"location"`
	Preview     string         `json:"preview"`
	Fingerprint string         `json:"fingerprint"`
	AllowReason string         `json:"allow_reason,omitempty"`
}

// Logger provides thread-safe, rotating JSONL audit logging.
type Logger struct {
	mu       sync.Mutex
	path     string
	maxBytes int64
	maxFiles int
}

// NewLogger creates a logger rooted at kavachDir/audit.jsonl.
func NewLogger(kavachDir string, cfg config.LogConfig) *Logger {
	if kavachDir == "" {
		return &Logger{}
	}
	maxMB := cfg.MaxSizeMB
	if maxMB <= 0 {
		maxMB = 20
	}
	maxFiles := cfg.MaxFiles
	if maxFiles <= 0 {
		maxFiles = 5
	}
	return &Logger{
		path:     filepath.Join(kavachDir, "audit.jsonl"),
		maxBytes: int64(maxMB) * 1024 * 1024,
		maxFiles: maxFiles,
	}
}

// LogVerdict records all findings from an evaluated verdict without exposing raw secrets.
func (l *Logger) LogVerdict(in types.EvalInput, v types.Verdict) error {
	if l == nil || l.path == "" || len(v.Findings) == 0 {
		return nil
	}
	l.mu.Lock()
	defer l.mu.Unlock()

	if err := os.MkdirAll(filepath.Dir(l.path), 0o700); err != nil {
		return err
	}
	l.rotateIfNeeded()

	f, err := os.OpenFile(l.path, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0o600)
	if err != nil {
		return err
	}
	defer func() { _ = f.Close() }()

	now := v.EvaluatedAt
	if now.IsZero() {
		now = time.Now().UTC()
	}

	for _, finding := range v.Findings {
		act := v.Action
		if finding.AllowListed {
			act = types.ActionAllow
		}
		e := Entry{
			Timestamp:   now,
			Event:       in.Event,
			SessionID:   in.SessionID,
			ToolName:    in.ToolName,
			Layer:       finding.Layer,
			RuleID:      finding.RuleID,
			Category:    finding.Category,
			Tier:        finding.Tier,
			Action:      act,
			Location:    finding.Location,
			Preview:     finding.Preview,
			Fingerprint: finding.Fingerprint,
			AllowReason: finding.AllowReason,
		}
		line, err := json.Marshal(e)
		if err != nil {
			continue
		}
		if _, err := f.Write(append(line, '\n')); err != nil {
			return err
		}
	}
	return nil
}

// Query reads audit entries newer than `since` (zero means all), returning up to `limit` newest entries.
func (l *Logger) Query(since time.Time, limit int) ([]Entry, error) {
	if l == nil || l.path == "" {
		return nil, nil
	}
	f, err := os.Open(l.path)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, nil
		}
		return nil, err
	}
	defer func() { _ = f.Close() }()

	var entries []Entry
	sc := bufio.NewScanner(f)
	sc.Buffer(make([]byte, 0, 64*1024), 1024*1024)
	for sc.Scan() {
		var e Entry
		if err := json.Unmarshal(sc.Bytes(), &e); err != nil {
			continue
		}
		if !since.IsZero() && e.Timestamp.Before(since) {
			continue
		}
		entries = append(entries, e)
	}
	if err := sc.Err(); err != nil {
		return nil, err
	}
	if limit > 0 && len(entries) > limit {
		entries = entries[len(entries)-limit:]
	}
	return entries, nil
}

// Path returns the active JSONL log file path.
func (l *Logger) Path() string {
	if l == nil {
		return ""
	}
	return l.path
}

func (l *Logger) rotateIfNeeded() {
	info, err := os.Stat(l.path)
	if err != nil || info.Size() < l.maxBytes {
		return
	}
	for i := l.maxFiles - 1; i >= 1; i-- {
		src := fmt.Sprintf("%s.%d", l.path, i)
		dst := fmt.Sprintf("%s.%d", l.path, i+1)
		if _, err := os.Stat(src); err == nil {
			_ = os.Rename(src, dst)
		}
	}
	_ = os.Rename(l.path, l.path+".1")
}
