// Package redact removes secrets and personal data before anything is stored.
package redact

import (
	"os/exec"
	"regexp"
	"strings"
	"time"
	"unicode/utf8"
)

type rule struct {
	label string
	re    *regexp.Regexp
}

var rules = []rule{
	{"private-key", regexp.MustCompile(`-----BEGIN [A-Z ]*PRIVATE KEY-----[\s\S]*?(?:-----END [A-Z ]*PRIVATE KEY-----|$)`)},
	{"aws-key", regexp.MustCompile(`\b(?:AKIA|ASIA)[0-9A-Z]{16}\b`)},
	{"github-token", regexp.MustCompile(`\b(?:ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{30,}\b|\bgithub_pat_[A-Za-z0-9_]{30,}\b`)},
	{"api-key", regexp.MustCompile(`\bsk-(?:ant-|proj-)?[A-Za-z0-9_\-]{20,}\b|\bsk_live_[A-Za-z0-9]{16,}\b|\bAIza[0-9A-Za-z_\-]{30,}\b`)},
	{"slack-token", regexp.MustCompile(`\bxox[abprs]-[A-Za-z0-9\-]{10,}\b`)},
	{"jwt", regexp.MustCompile(`\beyJ[A-Za-z0-9_\-]{8,}\.[A-Za-z0-9_\-]{8,}\.[A-Za-z0-9_\-]{8,}\b`)},
	{"secret-assignment", regexp.MustCompile(`(?i)\b((?:api[_-]?key|secret|token|password|passwd|pwd)\s*[:=]\s*)["']?[^\s"']{6,}`)},
	{"url-credentials", regexp.MustCompile(`([a-z][a-z0-9+.\-]*://[^\s:/@]+:)[^\s@/]+@`)},
	{"email", regexp.MustCompile(`\b[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}\b`)},
	{"card", regexp.MustCompile(`\b(?:\d[ \-]?){13,19}\b`)},
	// Phone numbers must look like one: international (+41 …), trunk-prefixed (0…) or with an (area) code.
	{"phone", regexp.MustCompile(`(?:\+\d{1,3}[ \-]?\d{1,4}|\(\d{2,4}\)|\b0\d{1,4})[ \-]?\d{2,4}[ \-]?\d{3,4}(?:[ \-]?\d{2,4})?\b`)},
	{"iban", regexp.MustCompile(`\b[A-Z]{2}\d{2}(?: ?[A-Z0-9]{4}){3,7}(?: ?[A-Z0-9]{1,4})?\b`)},
}

// Text replaces secrets and personal data with [REDACTED:<kind>] markers.
func Text(s string) string {
	for _, r := range rules {
		switch r.label {
		case "secret-assignment", "url-credentials":
			s = r.re.ReplaceAllString(s, "${1}[REDACTED:"+r.label+"]")
		case "card":
			s = r.re.ReplaceAllStringFunc(s, func(m string) string {
				if luhn(m) {
					return "[REDACTED:card]"
				}
				return m
			})
		default:
			s = r.re.ReplaceAllString(s, "[REDACTED:"+r.label+"]")
		}
	}
	return s
}

// WithKavach additionally pipes text through `kavach scan --redact` when Kavach is installed.
// It never fails: if Kavach is missing or slow, the built-in redaction result is returned.
func WithKavach(s string) string {
	s = Text(s)
	path, err := exec.LookPath("kavach")
	if err != nil {
		return s
	}
	cmd := exec.Command(path, "scan", "-", "--redact")
	cmd.Stdin = strings.NewReader(s)
	done := make(chan []byte, 1)
	go func() {
		out, err := cmd.Output()
		if err != nil {
			out = nil
		}
		done <- out
	}()
	select {
	case out := <-done:
		if len(out) > 0 && strings.Contains(string(out), "REDACTED") {
			return strings.TrimRight(string(out), "\n")
		}
	case <-time.After(500 * time.Millisecond):
		_ = cmd.Process.Kill()
	}
	return s
}

// Snippet redacts and shortens text to at most n characters (on a rune boundary).
func Snippet(s string, n int) string {
	s = strings.Join(strings.Fields(Text(s)), " ")
	if utf8.RuneCountInString(s) <= n {
		return s
	}
	r := []rune(s)
	return string(r[:n-1]) + "…"
}

func luhn(s string) bool {
	var digits []int
	for _, c := range s {
		if c >= '0' && c <= '9' {
			digits = append(digits, int(c-'0'))
		}
	}
	if len(digits) < 13 || len(digits) > 19 {
		return false
	}
	sum := 0
	for i := len(digits) - 1; i >= 0; i-- {
		d := digits[i]
		if (len(digits)-1-i)%2 == 1 {
			d *= 2
			if d > 9 {
				d -= 9
			}
		}
		sum += d
	}
	return sum%10 == 0
}
