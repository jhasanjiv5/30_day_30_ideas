package detect

import (
	"fmt"
	"math"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"gopkg.in/yaml.v3"

	"github.com/kavach-sec/kavach/internal/redact"
	"github.com/kavach-sec/kavach/internal/types"
)

// SecretRule defines a gitleaks-compatible secret detection pattern.
type SecretRule struct {
	ID          string   `yaml:"id"`
	Title       string   `yaml:"title"`
	Regex       string   `yaml:"regex"`
	SecretGroup int      `yaml:"secret_group,omitempty"`
	MinEntropy  float64  `yaml:"min_entropy,omitempty"`
	Keywords    []string `yaml:"keywords,omitempty"`
	Tier        string   `yaml:"tier,omitempty"`
	Confidence  float64  `yaml:"confidence,omitempty"`
	re          *regexp.Regexp
}

// RulesBundle represents ~/.kavach/rules.yaml for offline/local rule updates.
type RulesBundle struct {
	Version int          `yaml:"version"`
	Updated string       `yaml:"updated"`
	Rules   []SecretRule `yaml:"rules"`
}

// DefaultSecretRules returns the embedded gitleaks-compatible secret rule set.
func DefaultSecretRules() []SecretRule {
	return []SecretRule{
		{
			ID:          "aws-access-key-id",
			Title:       "AWS Access Key ID",
			Regex:       `\b((?:AKIA|ASIA|AROA|AIDA)[0-9A-Z]{16})\b`,
			SecretGroup: 1,
			Confidence:  0.98,
		},
		{
			ID:          "aws-secret-access-key",
			Title:       "AWS Secret Access Key",
			Regex:       `(?i)(?:aws_secret_access_key|aws_secret_key|secret_access_key)\s*[:=]\s*["']?([A-Za-z0-9/+=]{40})["']?`,
			SecretGroup: 1,
			MinEntropy:  3.5,
			Confidence:  0.95,
		},
		{
			ID:          "github-pat",
			Title:       "GitHub Personal Access Token",
			Regex:       `\b(gh[pousr]_[A-Za-z0-9_]{20,255})\b`,
			SecretGroup: 1,
			Confidence:  0.99,
		},
		{
			ID:          "github-fine-grained-pat",
			Title:       "GitHub Fine-Grained PAT",
			Regex:       `\b(github_pat_[A-Za-z0-9_]{22,255})\b`,
			SecretGroup: 1,
			Confidence:  0.99,
		},
		{
			ID:          "anthropic-api-key",
			Title:       "Anthropic API Key",
			Regex:       `\b(sk-ant-(?:api\d{2}|admin\d{2})-[A-Za-z0-9_\-]{16,128})\b`,
			SecretGroup: 1,
			Confidence:  0.99,
		},
		{
			ID:          "openai-api-key",
			Title:       "OpenAI API Key",
			Regex:       `\b(sk-(?:proj-|svcacct-)?[A-Za-z0-9_\-]{20,160})\b`,
			SecretGroup: 1,
			MinEntropy:  3.4,
			Confidence:  0.96,
		},
		{
			ID:          "gcp-api-key",
			Title:       "Google Cloud / AI API Key",
			Regex:       `\b(AIza[0-9A-Za-z\-_]{35})\b`,
			SecretGroup: 1,
			Confidence:  0.98,
		},
		{
			ID:          "slack-token",
			Title:       "Slack Token",
			Regex:       `\b(xox[baprs]-[0-9]{8,14}-[0-9A-Za-z\-]{10,64})\b`,
			SecretGroup: 1,
			Confidence:  0.98,
		},
		{
			ID:          "slack-webhook",
			Title:       "Slack Incoming Webhook",
			Regex:       `(https://hooks\.slack\.com/services/T[A-Z0-9]{6,}/B[A-Z0-9]{6,}/[A-Za-z0-9]{16,})`,
			SecretGroup: 1,
			Confidence:  0.97,
		},
		{
			ID:          "stripe-secret-key",
			Title:       "Stripe Secret / Restricted Key",
			Regex:       `\b([rs]k_(?:live|test)_[0-9A-Za-z]{20,99})\b`,
			SecretGroup: 1,
			Confidence:  0.98,
		},
		{
			ID:          "sendgrid-api-key",
			Title:       "SendGrid API Key",
			Regex:       `\b(SG\.[A-Za-z0-9_\-]{16,}\.[A-Za-z0-9_\-]{16,})\b`,
			SecretGroup: 1,
			Confidence:  0.98,
		},
		{
			ID:          "twilio-api-key",
			Title:       "Twilio API Key",
			Regex:       `\b(SK[0-9a-fA-F]{32})\b`,
			SecretGroup: 1,
			MinEntropy:  3.3,
			Confidence:  0.92,
		},
		{
			ID:          "npm-access-token",
			Title:       "npm Access Token",
			Regex:       `\b(npm_[A-Za-z0-9]{24,64})\b`,
			SecretGroup: 1,
			Confidence:  0.98,
		},
		{
			ID:          "pypi-api-token",
			Title:       "PyPI API Token",
			Regex:       `\b(pypi-AgE[A-Za-z0-9\-_]{24,})\b`,
			SecretGroup: 1,
			Confidence:  0.98,
		},
		{
			ID:          "hashicorp-vault-token",
			Title:       "HashiCorp Vault Token",
			Regex:       `\b(hvs\.[A-Za-z0-9_\-]{20,})\b`,
			SecretGroup: 1,
			Confidence:  0.96,
		},
		{
			ID:          "huggingface-token",
			Title:       "Hugging Face Access Token",
			Regex:       `\b(hf_[A-Za-z0-9]{24,})\b`,
			SecretGroup: 1,
			Confidence:  0.97,
		},
		{
			ID:          "telegram-bot-token",
			Title:       "Telegram Bot Token",
			Regex:       `\b(\d{8,10}:AA[A-Za-z0-9_\-]{30,40})\b`,
			SecretGroup: 1,
			Confidence:  0.95,
		},
		{
			ID:          "private-key-pem",
			Title:       "Private Key PEM Block",
			Regex:       `(-----BEGIN (?:RSA |EC |DSA |OPENSSH |PGP |ENCRYPTED )?PRIVATE KEY-----)`,
			SecretGroup: 1,
			Confidence:  0.99,
		},
		{
			ID:          "jwt-token",
			Title:       "JSON Web Token (JWT)",
			Regex:       `\b(eyJ[A-Za-z0-9_\-]{10,}\.eyJ[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9_\-]{10,})\b`,
			SecretGroup: 1,
			MinEntropy:  3.5,
			Confidence:  0.92,
		},
		{
			ID:          "database-uri-credentials",
			Title:       "Database Connection String with Password",
			Regex:       `\b((?:postgres|postgresql|mysql|mongodb(?:\+srv)?|redis|amqp)://[^:\s/@]+:([^@\s]{6,})@[^\s"']+)`,
			SecretGroup: 2,
			Confidence:  0.95,
		},
		{
			ID:          "dotenv-secret-assignment",
			Title:       ".env Secret Assignment",
			Regex:       `(?m)^(?:export\s+)?([A-Z][A-Z0-9_]{2,}(?:KEY|SECRET|TOKEN|PASSWORD|PASSWD|PWD|CREDENTIAL|AUTH|DSN|PRIVATE)[A-Z0-9_]*)\s*=\s*["']?([^\s"'#]{12,})["']?`,
			SecretGroup: 2,
			MinEntropy:  3.3,
			Confidence:  0.90,
		},
		{
			ID:          "generic-bearer-or-key",
			Title:       "Generic High-Entropy API Key / Bearer Token",
			Regex:       `(?i)(?:api[_\-]?key|auth[_\-]?token|bearer|secret[_\-]?key|access[_\-]?token|client[_\-]?secret)\s*[:=]\s*["']?([A-Za-z0-9_\-/+=.]{20,})["']?`,
			SecretGroup: 1,
			MinEntropy:  3.7,
			Confidence:  0.88,
		},
	}
}

// SecretScanner compiles and runs L0 secret rules.
type SecretScanner struct {
	rules []SecretRule
}

// NewSecretScanner loads rules from ~/.kavach/rules.yaml if present, falling back to DefaultSecretRules.
func NewSecretScanner(kavachDir string) (*SecretScanner, error) {
	rules := DefaultSecretRules()
	if kavachDir != "" {
		rulesPath := filepath.Join(kavachDir, "rules.yaml")
		if data, err := os.ReadFile(rulesPath); err == nil {
			var bundle RulesBundle
			if err := yaml.Unmarshal(data, &bundle); err == nil && len(bundle.Rules) > 0 {
				rules = bundle.Rules
			}
		}
	}
	return CompileSecretRules(rules)
}

// CompileSecretRules validates and compiles a list of SecretRule definitions.
func CompileSecretRules(rules []SecretRule) (*SecretScanner, error) {
	compiled := make([]SecretRule, 0, len(rules))
	for _, r := range rules {
		re, err := regexp.Compile(r.Regex)
		if err != nil {
			return nil, fmt.Errorf("compile rule %s: %w", r.ID, err)
		}
		r.re = re
		if r.Confidence == 0 {
			r.Confidence = 0.90
		}
		compiled = append(compiled, r)
	}
	return &SecretScanner{rules: compiled}, nil
}

// RuleCount returns the active L0 secret rule count.
func (s *SecretScanner) RuleCount() int {
	return len(s.rules)
}

// Scan inspects text for secrets, returning findings with redacted previews and salted fingerprints.
func (s *SecretScanner) Scan(text, location, salt string) []types.Finding {
	if text == "" {
		return nil
	}
	var findings []types.Finding
	seen := make(map[string]struct{})

	for _, rule := range s.rules {
		matches := rule.re.FindAllStringSubmatchIndex(text, -1)
		for _, loc := range matches {
			groupIdx := rule.SecretGroup
			if groupIdx*2+1 >= len(loc) || loc[groupIdx*2] < 0 {
				groupIdx = 0
			}
			start := loc[groupIdx*2]
			end := loc[groupIdx*2+1]
			if start < 0 || end <= start {
				continue
			}
			secretVal := text[start:end]

			if isBenignPlaceholder(secretVal) {
				continue
			}
			if rule.MinEntropy > 0 && shannonEntropy(secretVal) < rule.MinEntropy {
				continue
			}
			if rule.ID == "generic-bearer-or-key" && looksLikePathOrType(secretVal) {
				continue
			}
			if rule.ID == "dotenv-secret-assignment" && looksLikeEnvPlaceholder(secretVal) {
				continue
			}

			fp := redact.Fingerprint(salt, secretVal)
			dedupKey := rule.ID + ":" + fp
			if _, ok := seen[dedupKey]; ok {
				continue
			}
			seen[dedupKey] = struct{}{}

			line := lineNumberAt(text, start)
			locStr := fmt.Sprintf("%s:line %d", location, line)
			if location == "" {
				locStr = fmt.Sprintf("line %d", line)
			}

			tier := types.TierHigh
			if rule.Tier != "" {
				tier = types.Tier(strings.ToUpper(rule.Tier))
			}

			findings = append(findings, types.Finding{
				RuleID:      rule.ID,
				Title:       rule.Title,
				Category:    types.CategorySecrets,
				Layer:       types.LayerL0,
				Tier:        tier,
				Confidence:  rule.Confidence,
				Location:    locStr,
				Preview:     redact.Preview(secretVal),
				Fingerprint: fp,
				Placeholder: redact.Placeholder(rule.ID),
				Explanation: fmt.Sprintf("Detected %s (%s) at %s before reaching model.", rule.Title, redact.Preview(secretVal), locStr),
				Remediation: fmt.Sprintf("Replace with %s via environment variable or .env (gitignored), or allow once with `kavach allow-once %s --reason \"...\"`.", redact.Placeholder(rule.ID), fp),
				StartOffset: start,
				EndOffset:   end,
			})
		}
	}
	return findings
}

func shannonEntropy(s string) float64 {
	if len(s) == 0 {
		return 0
	}
	counts := make(map[rune]int)
	total := 0
	for _, r := range s {
		counts[r]++
		total++
	}
	var entropy float64
	fTotal := float64(total)
	for _, c := range counts {
		p := float64(c) / fTotal
		entropy -= p * math.Log2(p)
	}
	return entropy
}

func isBenignPlaceholder(val string) bool {
	lower := strings.ToLower(strings.TrimSpace(val))
	if lower == "" {
		return true
	}
	// Never suppress AWS's documented example key AKIAIOSFODNN7EXAMPLE (canary fixture),
	// while suppressing obvious template placeholders like YOUR_API_KEY_HERE or ${API_KEY}.
	if strings.HasPrefix(lower, "${") || strings.HasPrefix(lower, "<") || strings.HasPrefix(lower, "{{") {
		return true
	}
	for _, prefix := range []string{"your_", "my_", "replace_with_", "changeme", "placeholder", "dummy_", "fake_placeholder"} {
		if strings.HasPrefix(lower, prefix) {
			return true
		}
	}
	if strings.Count(lower, "x") >= len(lower)-2 || strings.Count(lower, "*") >= len(lower)-2 {
		return true
	}
	if lower == "postgres" || lower == "password" || lower == "secret" || lower == "changeme123" {
		return true
	}
	return false
}

func looksLikeEnvPlaceholder(val string) bool {
	upper := strings.ToUpper(val)
	return strings.Contains(upper, "REPLACE_WITH") ||
		strings.Contains(upper, "YOUR_") ||
		strings.Contains(upper, "MY_GEMINI_API_KEY") ||
		strings.Contains(upper, "CHANGEME") ||
		strings.HasPrefix(val, "$")
}

func looksLikePathOrType(val string) bool {
	if strings.HasPrefix(val, "/") || strings.HasPrefix(val, "./") || strings.HasPrefix(val, "http://") || strings.HasPrefix(val, "https://") {
		return true
	}
	if strings.Contains(val, "example.com") {
		return true
	}
	// Plain CamelCase or snake_case identifier without digits is rarely a token.
	hasDigit := false
	for _, r := range val {
		if r >= '0' && r <= '9' {
			hasDigit = true
			break
		}
	}
	return !hasDigit && !strings.ContainsAny(val, "+/=-_")
}

func lineNumberAt(text string, offset int) int {
	if offset <= 0 {
		return 1
	}
	if offset > len(text) {
		offset = len(text)
	}
	return 1 + strings.Count(text[:offset], "\n")
}

// SyncRulesBundle writes the latest embedded rules bundle to ~/.kavach/rules.yaml,
// or installs a custom local rules file after compiling/validating every rule.
func SyncRulesBundle(kavachDir, fromPath string) (int, string, error) {
	var bundle RulesBundle
	if fromPath != "" {
		data, err := os.ReadFile(fromPath)
		if err != nil {
			return 0, "", fmt.Errorf("read rules file: %w", err)
		}
		if err := yaml.Unmarshal(data, &bundle); err != nil {
			return 0, "", fmt.Errorf("parse rules yaml: %w", err)
		}
		if len(bundle.Rules) == 0 {
			return 0, "", fmt.Errorf("rules file %s contains zero rules", fromPath)
		}
	} else {
		bundle = RulesBundle{
			Version: 1,
			Updated: "2026-11-21",
			Rules:   DefaultSecretRules(),
		}
	}
	if _, err := CompileSecretRules(bundle.Rules); err != nil {
		return 0, "", fmt.Errorf("validate rules: %w", err)
	}
	if err := os.MkdirAll(kavachDir, 0o700); err != nil {
		return 0, "", err
	}
	outPath := filepath.Join(kavachDir, "rules.yaml")
	raw, err := yaml.Marshal(bundle)
	if err != nil {
		return 0, "", err
	}
	if err := os.WriteFile(outPath, raw, 0o600); err != nil {
		return 0, "", err
	}
	return len(bundle.Rules), outPath, nil
}
