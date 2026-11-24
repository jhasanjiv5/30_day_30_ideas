package redact

import (
	"strings"
	"testing"
)

func TestTextRedactsSecretsAndPersonalData(t *testing.T) {
	in := "key AKIAIOSFODNN7EXAMPLE mail maria.rossi@example.com card 4111 1111 1111 1111 " +
		"call +41 78 123 4567 password=hunter2hunter postgres://app:s3cretpw@db/prod"
	out := Text(in)
	for _, leak := range []string{"AKIAIOSFODNN7EXAMPLE", "maria.rossi@example.com", "4111 1111 1111 1111", "78 123 4567", "hunter2hunter", "s3cretpw"} {
		if strings.Contains(out, leak) {
			t.Errorf("%q survived redaction: %s", leak, out)
		}
	}
	if !strings.Contains(out, "[REDACTED:aws-key]") || !strings.Contains(out, "[REDACTED:email]") {
		t.Errorf("expected labelled markers, got %s", out)
	}
}

func TestTextKeepsOrdinaryNumbers(t *testing.T) {
	in := "Keep commit messages under 60 characters; version 1234 5678 9012 is fine."
	if out := Text(in); out != in {
		t.Errorf("non-card digits changed: %s", out)
	}
}

func TestSnippetIsShortAndRedacted(t *testing.T) {
	s := Snippet(strings.Repeat("word ", 100)+" maria@example.com", 50)
	if len([]rune(s)) > 50 || strings.Contains(s, "maria@") {
		t.Errorf("bad snippet %q", s)
	}
}
