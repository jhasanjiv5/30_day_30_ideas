package redact

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"unicode/utf8"

	"github.com/kavach-sec/kavach/internal/types"
)

const (
	saltFileName = "salt"
	saltBytes    = 32
)

// Preview produces a safe redacted preview such as "AKIA…MPLE" without ever
// exposing the full secret or sensitive value.
func Preview(raw string) string {
	trimmed := strings.TrimSpace(raw)
	if trimmed == "" {
		return "••••"
	}
	runes := []rune(trimmed)
	n := len(runes)
	switch {
	case n >= 12:
		return string(runes[:4]) + "…" + string(runes[n-4:])
	case n >= 8:
		return string(runes[:2]) + "…" + string(runes[n-2:])
	default:
		return "••••"
	}
}

// Fingerprint returns a deterministic salted SHA-256 fingerprint ("kvfp_<16hex>")
// so findings can be correlated, deduplicated, and allowlisted without storing raw secrets.
func Fingerprint(salt, raw string) string {
	h := sha256.New()
	_, _ = h.Write([]byte(salt))
	_, _ = h.Write([]byte(":"))
	_, _ = h.Write([]byte(raw))
	sum := h.Sum(nil)
	return "kvfp_" + hex.EncodeToString(sum[:8])
}

// LoadOrCreateSalt reads the local 32-byte salt from ~/.kavach/salt or creates
// one with 0600 permissions if absent.
func LoadOrCreateSalt(kavachDir string) (string, error) {
	if kavachDir == "" {
		return EphemeralSalt(), nil
	}
	path := filepath.Join(kavachDir, saltFileName)
	data, err := os.ReadFile(path)
	if err == nil {
		s := strings.TrimSpace(string(data))
		if len(s) >= 32 {
			return s, nil
		}
	}
	if err := os.MkdirAll(kavachDir, 0o700); err != nil {
		return "", fmt.Errorf("create kavach dir: %w", err)
	}
	return writeNewSalt(path)
}

// RotateSalt generates a fresh 32-byte random salt and atomically replaces the existing salt file.
func RotateSalt(kavachDir string) (string, error) {
	if err := os.MkdirAll(kavachDir, 0o700); err != nil {
		return "", fmt.Errorf("create kavach dir: %w", err)
	}
	path := filepath.Join(kavachDir, saltFileName)
	return writeNewSalt(path)
}

func writeNewSalt(path string) (string, error) {
	buf := make([]byte, saltBytes)
	if _, err := rand.Read(buf); err != nil {
		return "", fmt.Errorf("generate random salt: %w", err)
	}
	encoded := hex.EncodeToString(buf)
	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, []byte(encoded+"\n"), 0o600); err != nil {
		return "", fmt.Errorf("write salt temp file: %w", err)
	}
	if err := os.Rename(tmp, path); err != nil {
		_ = os.Remove(tmp)
		return "", fmt.Errorf("rename salt file: %w", err)
	}
	return encoded, nil
}

// EphemeralSalt returns a process-local fallback salt used only when no state directory is provided (e.g. selftest).
func EphemeralSalt() string {
	return "kavach-ephemeral-selftest-salt-0000"
}

var nonPlaceholderChars = regexp.MustCompile(`[^A-Z0-9]+`)

// Placeholder generates an environment-variable-style placeholder name for a rule ID.
func Placeholder(ruleID string) string {
	upper := strings.ToUpper(ruleID)
	clean := nonPlaceholderChars.ReplaceAllString(upper, "_")
	clean = strings.Trim(clean, "_")
	if clean == "" {
		clean = "SECRET"
	}
	return "${" + clean + "}"
}

// RedactText replaces the byte spans of findings in input with safe placeholders.
// Overlapping spans are merged or skipped cleanly so indices stay valid.
func RedactText(input string, findings []types.Finding) string {
	if input == "" || len(findings) == 0 {
		return input
	}
	type span struct {
		start int
		end   int
		repl  string
	}
	var spans []span
	for _, f := range findings {
		if f.AllowListed {
			continue
		}
		if f.StartOffset < 0 || f.EndOffset <= f.StartOffset || f.EndOffset > len(input) {
			continue
		}
		if !utf8.ValidString(input[f.StartOffset:f.EndOffset]) {
			continue
		}
		repl := f.Placeholder
		if repl == "" {
			repl = Placeholder(f.RuleID)
		}
		spans = append(spans, span{start: f.StartOffset, end: f.EndOffset, repl: repl})
	}
	if len(spans) == 0 {
		return input
	}
	sort.Slice(spans, func(i, j int) bool {
		if spans[i].start == spans[j].start {
			return spans[i].end > spans[j].end
		}
		return spans[i].start < spans[j].start
	})

	var b strings.Builder
	b.Grow(len(input))
	cursor := 0
	for _, sp := range spans {
		if sp.start < cursor {
			continue
		}
		b.WriteString(input[cursor:sp.start])
		b.WriteString(sp.repl)
		cursor = sp.end
	}
	b.WriteString(input[cursor:])
	return b.String()
}
