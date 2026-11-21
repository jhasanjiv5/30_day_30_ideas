package types

import "time"

// Layer identifies which detection layer produced a finding.
type Layer string

const (
	LayerL0 Layer = "L0"
	LayerL1 Layer = "L1"
	LayerL2 Layer = "L2"
)

// Tier represents the policy severity tier.
type Tier string

const (
	TierLow    Tier = "LOW"
	TierMedium Tier = "MEDIUM"
	TierHigh   Tier = "HIGH"
)

// Action represents the enforcement action derived from policy.
type Action string

const (
	ActionAllow Action = "ALLOW"
	ActionLog   Action = "LOG"
	ActionWarn  Action = "WARN"
	ActionBlock Action = "BLOCK"
)

// Category groups findings for policy configuration and selftest reporting.
type Category string

const (
	CategorySecrets          Category = "secrets"
	CategoryPII              Category = "pii"
	CategoryInjection        Category = "injection"
	CategoryIndirectInject   Category = "indirect_injection"
	CategoryUnicode          Category = "unicode"
	CategoryRiskyCommand     Category = "risky_command"
	CategoryCredentialAccess Category = "credential_access"
	CategoryExfiltration     Category = "exfiltration"
	CategoryUnreviewedMCP    Category = "unreviewed_mcp"
)

// HookEvent identifies the lifecycle event being evaluated.
type HookEvent string

const (
	EventSessionStart     HookEvent = "SessionStart"
	EventUserPromptSubmit HookEvent = "UserPromptSubmit"
	EventPreToolUse       HookEvent = "PreToolUse"
	EventPostToolUse      HookEvent = "PostToolUse"
	EventScan             HookEvent = "Scan"
	EventGateway          HookEvent = "Gateway" // Phase 2 reuse
)

// Finding describes a single security detection without ever storing raw secret values.
type Finding struct {
	RuleID      string   `json:"rule_id"`
	Title       string   `json:"title"`
	Category    Category `json:"category"`
	Layer       Layer    `json:"layer"`
	Tier        Tier     `json:"tier"`
	Confidence  float64  `json:"confidence"`
	Location    string   `json:"location"`
	Preview     string   `json:"preview"`
	Fingerprint string   `json:"fingerprint"`
	Placeholder string   `json:"placeholder,omitempty"`
	Explanation string   `json:"explanation"`
	Remediation string   `json:"remediation"`
	StartOffset int      `json:"start_offset,omitempty"`
	EndOffset   int      `json:"end_offset,omitempty"`
	AllowListed bool     `json:"allow_listed,omitempty"`
	AllowReason string   `json:"allow_reason,omitempty"`
}

// EvalInput is the normalized, source-agnostic input to the Kavach evaluation engine.
// Phase 1 (Claude Code hooks), Phase 2 (local gateway), and Phase 3 (browser extension)
// all construct EvalInput and pass it to the same engine unchanged.
type EvalInput struct {
	Event        HookEvent         `json:"event"`
	SessionID    string            `json:"session_id,omitempty"`
	CWD          string            `json:"cwd,omitempty"`
	Source       string            `json:"source,omitempty"`
	ToolName     string            `json:"tool_name,omitempty"`
	MCPServer    string            `json:"mcp_server,omitempty"`
	MCPSource    string            `json:"mcp_source,omitempty"`
	FilePath     string            `json:"file_path,omitempty"`
	URL          string            `json:"url,omitempty"`
	Command      string            `json:"command,omitempty"`
	Content      string            `json:"content,omitempty"`
	ContentType  string            `json:"content_type,omitempty"`
	Metadata     map[string]string `json:"metadata,omitempty"`
	SkipL2       bool              `json:"skip_l2,omitempty"`
	SkipAuditLog bool              `json:"skip_audit_log,omitempty"`
}

// Verdict is the consolidated decision returned by the Kavach evaluation engine.
type Verdict struct {
	Action           Action    `json:"action"`
	HighestTier      Tier      `json:"highest_tier,omitempty"`
	Findings         []Finding `json:"findings,omitempty"`
	RiskScore        float64   `json:"risk_score"`
	L2Invoked        bool      `json:"l2_invoked,omitempty"`
	L2Verdict        string    `json:"l2_verdict,omitempty"`
	L2Reason         string    `json:"l2_reason,omitempty"`
	CacheHit         bool      `json:"cache_hit,omitempty"`
	DurationMs       float64   `json:"duration_ms"`
	RedactedContent  string    `json:"redacted_content,omitempty"`
	Summary          string    `json:"summary,omitempty"`
	FixOptions       []string  `json:"fix_options,omitempty"`
	EvaluatedAt      time.Time `json:"evaluated_at"`
}

// AllowOnceEntry records an explicit user-approved temporary bypass for a finding fingerprint.
type AllowOnceEntry struct {
	Fingerprint string    `json:"fingerprint"`
	Reason      string    `json:"reason"`
	CreatedAt   time.Time `json:"created_at"`
	ExpiresAt   time.Time `json:"expires_at"`
	UsesLeft    int       `json:"uses_left"`
}
