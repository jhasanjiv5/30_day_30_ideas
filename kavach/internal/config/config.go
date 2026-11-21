package config

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"gopkg.in/yaml.v3"

	"github.com/kavach-sec/kavach/internal/types"
)

// Policy configures detection tiers, allowlists, national ID patterns, L2, and logging.
type Policy struct {
	Version int `yaml:"version" json:"version"`

	Tiers TiersConfig `yaml:"tiers" json:"tiers"`

	RuleOverrides map[string]types.Tier `yaml:"rule_overrides,omitempty" json:"rule_overrides,omitempty"`

	Allowlist AllowlistConfig `yaml:"allowlist" json:"allowlist"`

	PII PIIConfig `yaml:"pii" json:"pii"`

	L2 L2Config `yaml:"l2" json:"l2"`

	Log LogConfig `yaml:"log" json:"log"`

	Daemon DaemonConfig `yaml:"daemon" json:"daemon"`
}

// TiersConfig defines the default enforcement tier per threat category.
type TiersConfig struct {
	Secrets          types.Tier `yaml:"secrets" json:"secrets"`
	PII              types.Tier `yaml:"pii" json:"pii"`
	Injection        types.Tier `yaml:"injection" json:"injection"`
	IndirectInject   types.Tier `yaml:"indirect_injection" json:"indirect_injection"`
	Unicode          types.Tier `yaml:"unicode" json:"unicode"`
	RiskyCommand     types.Tier `yaml:"risky_command" json:"risky_command"`
	CredentialAccess types.Tier `yaml:"credential_access" json:"credential_access"`
	Exfiltration     types.Tier `yaml:"exfiltration" json:"exfiltration"`
	UnreviewedMCP    types.Tier `yaml:"unreviewed_mcp" json:"unreviewed_mcp"`
}

// AllowlistConfig holds trusted hosts, paths, rules, MCP servers, test fixtures, and fingerprints.
type AllowlistConfig struct {
	Hosts        []string `yaml:"hosts,omitempty" json:"hosts,omitempty"`
	Paths        []string `yaml:"paths,omitempty" json:"paths,omitempty"`
	Rules        []string `yaml:"rules,omitempty" json:"rules,omitempty"`
	MCPServers   []string `yaml:"mcp_servers,omitempty" json:"mcp_servers,omitempty"`
	TestFixtures []string `yaml:"test_fixtures,omitempty" json:"test_fixtures,omitempty"`
	Fingerprints []string `yaml:"fingerprints,omitempty" json:"fingerprints,omitempty"`
}

// NationalIDPattern allows configurable national ID matching.
type NationalIDPattern struct {
	ID      string     `yaml:"id" json:"id"`
	Title   string     `yaml:"title" json:"title"`
	Regex   string     `yaml:"regex" json:"regex"`
	Tier    types.Tier `yaml:"tier,omitempty" json:"tier,omitempty"`
	Context []string   `yaml:"context,omitempty" json:"context,omitempty"`
}

// PIIConfig configures PII detectors.
type PIIConfig struct {
	EmailTier      types.Tier          `yaml:"email_tier,omitempty" json:"email_tier,omitempty"`
	IgnoreDomains  []string            `yaml:"ignore_domains,omitempty" json:"ignore_domains,omitempty"`
	NationalIDs    []NationalIDPattern `yaml:"national_ids,omitempty" json:"national_ids,omitempty"`
}

// L2Config configures the optional local Ollama classifier.
type L2Config struct {
	Enabled             bool    `yaml:"enabled" json:"enabled"`
	Provider            string  `yaml:"provider" json:"provider"`
	Endpoint            string  `yaml:"endpoint" json:"endpoint"`
	Model               string  `yaml:"model" json:"model"`
	TimeoutMs           int     `yaml:"timeout_ms" json:"timeout_ms"`
	UncertainMinScore   float64 `yaml:"uncertain_min_score" json:"uncertain_min_score"`
	UncertainMaxScore   float64 `yaml:"uncertain_max_score" json:"uncertain_max_score"`
}

// LogConfig configures audit log retention and rotation.
type LogConfig struct {
	MaxSizeMB     int `yaml:"max_size_mb" json:"max_size_mb"`
	MaxFiles      int `yaml:"max_files" json:"max_files"`
	RetentionDays int `yaml:"retention_days" json:"retention_days"`
}

// DaemonConfig configures the optional local kavach serve daemon.
type DaemonConfig struct {
	SocketPath   string `yaml:"socket_path,omitempty" json:"socket_path,omitempty"`
	CacheTTLSec  int    `yaml:"cache_ttl_sec" json:"cache_ttl_sec"`
	CacheMaxSize int    `yaml:"cache_max_size" json:"cache_max_size"`
}

// DefaultPolicy returns a production-ready Phase 1 default policy.
func DefaultPolicy() Policy {
	return Policy{
		Version: 1,
		Tiers: TiersConfig{
			Secrets:          types.TierHigh,
			PII:              types.TierHigh,
			Injection:        types.TierHigh,
			IndirectInject:   types.TierHigh,
			Unicode:          types.TierHigh,
			RiskyCommand:     types.TierHigh,
			CredentialAccess: types.TierHigh,
			Exfiltration:     types.TierHigh,
			UnreviewedMCP:    types.TierMedium,
		},
		Allowlist: AllowlistConfig{
			Hosts: []string{
				"127.0.0.1",
				"localhost",
				"::1",
				"github.com",
				"api.github.com",
				"pkg.go.dev",
				"registry.npmjs.org",
				"pypi.org",
			},
			TestFixtures: []string{
				"testdata/redteam/*",
				"*_test.go",
				"*.fixture.*",
			},
		},
		PII: PIIConfig{
			EmailTier: types.TierMedium,
			IgnoreDomains: []string{
				"example.com",
				"example.org",
				"example.net",
				"localhost",
				"users.noreply.github.com",
			},
			NationalIDs: []NationalIDPattern{
				{
					ID:    "pii-us-ssn",
					Title: "US Social Security Number",
					Regex: `\b(?:00[1-9]|0[1-9]\d|[1-5]\d{2}|6(?:[0-57-9]\d|6[0-57-9])|[78]\d{2})-(?:0[1-9]|[1-9]\d)-(?:000[1-9]|00[1-9]\d|0[1-9]\d{2}|[1-9]\d{3})\b`,
					Tier:  types.TierHigh,
				},
				{
					ID:      "pii-in-aadhaar",
					Title:   "Indian Aadhaar Number",
					Regex:   `\b[2-9]\d{3}\s\d{4}\s\d{4}\b`,
					Tier:    types.TierHigh,
					Context: []string{"aadhaar", "aadhar", "uidai", "kyc", "id_number"},
				},
				{
					ID:      "pii-in-pan",
					Title:   "Indian PAN Card Number",
					Regex:   `\b[A-Z]{3}[PCHFATBLJG][A-Z]\d{4}[A-Z]\b`,
					Tier:    types.TierMedium,
					Context: []string{"pan", "tax", "kyc", "income"},
				},
			},
		},
		L2: L2Config{
			Enabled:           false,
			Provider:          "ollama",
			Endpoint:          "http://127.0.0.1:11434",
			Model:             "",
			TimeoutMs:         3000,
			UncertainMinScore: 0.35,
			UncertainMaxScore: 0.70,
		},
		Log: LogConfig{
			MaxSizeMB:     20,
			MaxFiles:      5,
			RetentionDays: 30,
		},
		Daemon: DaemonConfig{
			CacheTTLSec:  300,
			CacheMaxSize: 2048,
		},
	}
}

// DefaultKavachDir returns ~/.kavach or KAVACH_HOME if set.
func DefaultKavachDir() string {
	if env := os.Getenv("KAVACH_HOME"); env != "" {
		return env
	}
	home, err := os.UserHomeDir()
	if err != nil || home == "" {
		return ".kavach"
	}
	return filepath.Join(home, ".kavach")
}

// EnsureDefaultPolicy writes ~/.kavach/policy.yaml if it does not yet exist.
func EnsureDefaultPolicy(kavachDir string) (string, error) {
	if err := os.MkdirAll(kavachDir, 0o700); err != nil {
		return "", fmt.Errorf("create kavach dir: %w", err)
	}
	p := filepath.Join(kavachDir, "policy.yaml")
	if _, err := os.Stat(p); err == nil {
		return p, nil
	}
	raw, err := yaml.Marshal(DefaultPolicy())
	if err != nil {
		return "", fmt.Errorf("marshal default policy: %w", err)
	}
	header := "# Kavach Phase 1 Policy Configuration\n# Tiers: LOW (log), MEDIUM (warn and continue), HIGH (block)\n# Override per repo by creating .kavach.yaml in your project root.\n\n"
	if err := os.WriteFile(p, []byte(header+string(raw)), 0o600); err != nil {
		return "", fmt.Errorf("write policy.yaml: %w", err)
	}
	return p, nil
}

// LoadPolicy loads default policy, overlays ~/.kavach/policy.yaml, and overlays
// any per-repo .kavach.yaml found from cwd upward to the filesystem or git root.
func LoadPolicy(kavachDir, cwd string) (Policy, error) {
	p := DefaultPolicy()

	if kavachDir != "" {
		userPath := filepath.Join(kavachDir, "policy.yaml")
		if err := mergeYAMLFile(&p, userPath); err != nil && !os.IsNotExist(err) {
			return p, fmt.Errorf("load user policy %s: %w", userPath, err)
		}
	}

	if repoPath := FindRepoPolicy(cwd); repoPath != "" {
		if err := mergeYAMLFile(&p, repoPath); err != nil {
			return p, fmt.Errorf("load repo policy %s: %w", repoPath, err)
		}
	}

	return p, nil
}

// FindRepoPolicy searches cwd and its ancestors for .kavach.yaml, stopping at .git or root.
func FindRepoPolicy(cwd string) string {
	if cwd == "" {
		return ""
	}
	dir := filepath.Clean(cwd)
	for {
		candidate := filepath.Join(dir, ".kavach.yaml")
		if info, err := os.Stat(candidate); err == nil && !info.IsDir() {
			return candidate
		}
		if _, err := os.Stat(filepath.Join(dir, ".git")); err == nil {
			break
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			break
		}
		dir = parent
	}
	return ""
}

func mergeYAMLFile(dst *Policy, path string) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	var overlay Policy
	if err := yaml.Unmarshal(data, &overlay); err != nil {
		return err
	}
	mergePolicy(dst, overlay)
	return nil
}

func mergePolicy(dst *Policy, src Policy) {
	if src.Version != 0 {
		dst.Version = src.Version
	}
	if src.Tiers.Secrets != "" {
		dst.Tiers.Secrets = src.Tiers.Secrets
	}
	if src.Tiers.PII != "" {
		dst.Tiers.PII = src.Tiers.PII
	}
	if src.Tiers.Injection != "" {
		dst.Tiers.Injection = src.Tiers.Injection
	}
	if src.Tiers.IndirectInject != "" {
		dst.Tiers.IndirectInject = src.Tiers.IndirectInject
	}
	if src.Tiers.Unicode != "" {
		dst.Tiers.Unicode = src.Tiers.Unicode
	}
	if src.Tiers.RiskyCommand != "" {
		dst.Tiers.RiskyCommand = src.Tiers.RiskyCommand
	}
	if src.Tiers.CredentialAccess != "" {
		dst.Tiers.CredentialAccess = src.Tiers.CredentialAccess
	}
	if src.Tiers.Exfiltration != "" {
		dst.Tiers.Exfiltration = src.Tiers.Exfiltration
	}
	if src.Tiers.UnreviewedMCP != "" {
		dst.Tiers.UnreviewedMCP = src.Tiers.UnreviewedMCP
	}
	if len(src.RuleOverrides) > 0 {
		if dst.RuleOverrides == nil {
			dst.RuleOverrides = make(map[string]types.Tier)
		}
		for k, v := range src.RuleOverrides {
			dst.RuleOverrides[k] = v
		}
	}
	dst.Allowlist.Hosts = appendUnique(dst.Allowlist.Hosts, src.Allowlist.Hosts...)
	dst.Allowlist.Paths = appendUnique(dst.Allowlist.Paths, src.Allowlist.Paths...)
	dst.Allowlist.Rules = appendUnique(dst.Allowlist.Rules, src.Allowlist.Rules...)
	dst.Allowlist.MCPServers = appendUnique(dst.Allowlist.MCPServers, src.Allowlist.MCPServers...)
	dst.Allowlist.TestFixtures = appendUnique(dst.Allowlist.TestFixtures, src.Allowlist.TestFixtures...)
	dst.Allowlist.Fingerprints = appendUnique(dst.Allowlist.Fingerprints, src.Allowlist.Fingerprints...)

	if src.PII.EmailTier != "" {
		dst.PII.EmailTier = src.PII.EmailTier
	}
	dst.PII.IgnoreDomains = appendUnique(dst.PII.IgnoreDomains, src.PII.IgnoreDomains...)
	if len(src.PII.NationalIDs) > 0 {
		dst.PII.NationalIDs = append(dst.PII.NationalIDs, src.PII.NationalIDs...)
	}

	if src.L2.Enabled {
		dst.L2.Enabled = true
	}
	if src.L2.Provider != "" {
		dst.L2.Provider = src.L2.Provider
	}
	if src.L2.Endpoint != "" {
		dst.L2.Endpoint = src.L2.Endpoint
	}
	if src.L2.Model != "" {
		dst.L2.Model = src.L2.Model
	}
	if src.L2.TimeoutMs > 0 {
		dst.L2.TimeoutMs = src.L2.TimeoutMs
	}
	if src.L2.UncertainMinScore > 0 {
		dst.L2.UncertainMinScore = src.L2.UncertainMinScore
	}
	if src.L2.UncertainMaxScore > 0 {
		dst.L2.UncertainMaxScore = src.L2.UncertainMaxScore
	}
	if src.Log.MaxSizeMB > 0 {
		dst.Log.MaxSizeMB = src.Log.MaxSizeMB
	}
	if src.Log.MaxFiles > 0 {
		dst.Log.MaxFiles = src.Log.MaxFiles
	}
	if src.Log.RetentionDays > 0 {
		dst.Log.RetentionDays = src.Log.RetentionDays
	}
	if src.Daemon.SocketPath != "" {
		dst.Daemon.SocketPath = src.Daemon.SocketPath
	}
	if src.Daemon.CacheTTLSec > 0 {
		dst.Daemon.CacheTTLSec = src.Daemon.CacheTTLSec
	}
	if src.Daemon.CacheMaxSize > 0 {
		dst.Daemon.CacheMaxSize = src.Daemon.CacheMaxSize
	}
}

func appendUnique(base []string, extra ...string) []string {
	seen := make(map[string]struct{}, len(base))
	for _, s := range base {
		seen[s] = struct{}{}
	}
	for _, s := range extra {
		s = strings.TrimSpace(s)
		if s == "" {
			continue
		}
		if _, ok := seen[s]; !ok {
			seen[s] = struct{}{}
			base = append(base, s)
		}
	}
	return base
}

// TierForCategory returns the configured tier for a finding category.
func (p Policy) TierForCategory(cat types.Category) types.Tier {
	switch cat {
	case types.CategorySecrets:
		return p.Tiers.Secrets
	case types.CategoryPII:
		return p.Tiers.PII
	case types.CategoryInjection:
		return p.Tiers.Injection
	case types.CategoryIndirectInject:
		return p.Tiers.IndirectInject
	case types.CategoryUnicode:
		return p.Tiers.Unicode
	case types.CategoryRiskyCommand:
		return p.Tiers.RiskyCommand
	case types.CategoryCredentialAccess:
		return p.Tiers.CredentialAccess
	case types.CategoryExfiltration:
		return p.Tiers.Exfiltration
	case types.CategoryUnreviewedMCP:
		return p.Tiers.UnreviewedMCP
	default:
		return types.TierMedium
	}
}

// Hash returns a stable hash of the policy for verdict cache keying.
func (p Policy) Hash() string {
	raw, _ := json.Marshal(p)
	sum := sha256.Sum256(raw)
	return hex.EncodeToString(sum[:8])
}

// AllowOnceStore manages temporary allow-once entries with reasons and expiry.
type AllowOnceStore struct {
	path string
}

// NewAllowOnceStore returns a store backed by ~/.kavach/allow_once.json.
func NewAllowOnceStore(kavachDir string) *AllowOnceStore {
	if kavachDir == "" {
		return &AllowOnceStore{}
	}
	return &AllowOnceStore{path: filepath.Join(kavachDir, "allow_once.json")}
}

// Add records an allow-once bypass for a fingerprint with a mandatory reason.
func (s *AllowOnceStore) Add(fp, reason string, ttl time.Duration, uses int) (types.AllowOnceEntry, error) {
	if strings.TrimSpace(fp) == "" {
		return types.AllowOnceEntry{}, fmt.Errorf("fingerprint cannot be empty")
	}
	if strings.TrimSpace(reason) == "" {
		return types.AllowOnceEntry{}, fmt.Errorf("reason is required for allow-once")
	}
	if ttl <= 0 {
		ttl = 30 * time.Minute
	}
	if uses <= 0 {
		uses = 1
	}
	entries, _ := s.load()
	now := time.Now().UTC()
	entry := types.AllowOnceEntry{
		Fingerprint: fp,
		Reason:      strings.TrimSpace(reason),
		CreatedAt:   now,
		ExpiresAt:   now.Add(ttl),
		UsesLeft:    uses,
	}
	filtered := pruneExpired(entries, now)
	filtered = append(filtered, entry)
	if err := s.save(filtered); err != nil {
		return types.AllowOnceEntry{}, err
	}
	return entry, nil
}

// Consume checks if a fingerprint has an active allow-once entry and decrements its remaining uses.
func (s *AllowOnceStore) Consume(fp string) (types.AllowOnceEntry, bool) {
	if s.path == "" || fp == "" {
		return types.AllowOnceEntry{}, false
	}
	entries, err := s.load()
	if err != nil {
		return types.AllowOnceEntry{}, false
	}
	now := time.Now().UTC()
	var matched types.AllowOnceEntry
	var found bool
	var next []types.AllowOnceEntry
	for _, e := range pruneExpired(entries, now) {
		if !found && e.Fingerprint == fp && e.UsesLeft > 0 {
			matched = e
			found = true
			e.UsesLeft--
			if e.UsesLeft > 0 {
				next = append(next, e)
			}
			continue
		}
		next = append(next, e)
	}
	if found {
		_ = s.save(next)
	}
	return matched, found
}

func pruneExpired(entries []types.AllowOnceEntry, now time.Time) []types.AllowOnceEntry {
	var out []types.AllowOnceEntry
	for _, e := range entries {
		if e.UsesLeft > 0 && now.Before(e.ExpiresAt) {
			out = append(out, e)
		}
	}
	return out
}

func (s *AllowOnceStore) load() ([]types.AllowOnceEntry, error) {
	if s.path == "" {
		return nil, nil
	}
	data, err := os.ReadFile(s.path)
	if err != nil {
		return nil, err
	}
	var entries []types.AllowOnceEntry
	if err := json.Unmarshal(data, &entries); err != nil {
		return nil, err
	}
	return entries, nil
}

func (s *AllowOnceStore) save(entries []types.AllowOnceEntry) error {
	if s.path == "" {
		return nil
	}
	if err := os.MkdirAll(filepath.Dir(s.path), 0o700); err != nil {
		return err
	}
	data, err := json.MarshalIndent(entries, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(s.path, data, 0o600)
}
