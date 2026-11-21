package engine

import (
	"context"
	"fmt"
	"strings"
	"time"

	"github.com/kavach-sec/kavach/internal/auditlog"
	"github.com/kavach-sec/kavach/internal/config"
	"github.com/kavach-sec/kavach/internal/detect"
	"github.com/kavach-sec/kavach/internal/policy"
	"github.com/kavach-sec/kavach/internal/redact"
	"github.com/kavach-sec/kavach/internal/types"
)

// Engine is Kavach's reusable evaluation core for Phase 1 hooks, CLI scan,
// selftest, and future Phase 2/3 gateway and browser adapters.
type Engine struct {
	kavachDir string
	policy    config.Policy
	salt      string
	secrets   *detect.SecretScanner
	pii       *detect.PIIScanner
	unicode   *detect.UnicodeScanner
	injection *detect.InjectionScanner
	commands  *detect.CommandScanner
	l2        *detect.L2Classifier
	allowOnce *config.AllowOnceStore
	audit     *auditlog.Logger
}

// Options configures an Engine instance.
type Options struct {
	KavachDir string
	Policy    *config.Policy
	Salt      string
	CWD       string
}

// New initializes the Kavach evaluation engine with embedded L0+L1 detectors.
func New(opts Options) (*Engine, error) {
	kavachDir := opts.KavachDir
	var pol config.Policy
	if opts.Policy != nil {
		pol = *opts.Policy
	} else {
		var err error
		pol, err = config.LoadPolicy(kavachDir, opts.CWD)
		if err != nil {
			return nil, err
		}
	}

	salt := opts.Salt
	if salt == "" {
		var err error
		salt, err = redact.LoadOrCreateSalt(kavachDir)
		if err != nil {
			salt = redact.EphemeralSalt()
		}
	}

	secrets, err := detect.NewSecretScanner(kavachDir)
	if err != nil {
		return nil, fmt.Errorf("init secret scanner: %w", err)
	}
	pii, err := detect.NewPIIScanner(pol.PII)
	if err != nil {
		return nil, fmt.Errorf("init PII scanner: %w", err)
	}

	return &Engine{
		kavachDir: kavachDir,
		policy:    pol,
		salt:      salt,
		secrets:   secrets,
		pii:       pii,
		unicode:   detect.NewUnicodeScanner(),
		injection: detect.NewInjectionScanner(secrets),
		commands:  detect.NewCommandScanner(),
		l2:        detect.NewL2Classifier(),
		allowOnce: config.NewAllowOnceStore(kavachDir),
		audit:     auditlog.NewLogger(kavachDir, pol.Log),
	}, nil
}

// Policy returns the active merged policy.
func (e *Engine) Policy() config.Policy {
	return e.policy
}

// SecretRuleCount returns the number of active L0 secret detection rules.
func (e *Engine) SecretRuleCount() int {
	return e.secrets.RuleCount()
}

// AuditLogger returns the audit logger.
func (e *Engine) AuditLogger() *auditlog.Logger {
	return e.audit
}

// Evaluate runs L0 -> L1 -> (uncertain? L2) -> Policy -> Audit Log on any normalized EvalInput.
func (e *Engine) Evaluate(ctx context.Context, in types.EvalInput) types.Verdict {
	start := time.Now()
	var rawFindings []types.Finding
	var riskScore float64

	location := string(in.Event)
	if in.FilePath != "" {
		location = in.FilePath
	} else if in.ToolName != "" {
		location = fmt.Sprintf("%s:%s", in.Event, in.ToolName)
	}

	// 1. PreToolUse checks (commands, credential file access, exfiltration, MCP provenance).
	if in.Event == types.EventPreToolUse {
		cmdFindings := e.commands.ScanToolCall(in, e.policy, e.salt)
		for _, f := range cmdFindings {
			if f.Confidence > riskScore {
				riskScore = f.Confidence
			}
			rawFindings = append(rawFindings, f)
		}
	}

	// 2. Scan text content + command string for L0 secrets/PII and L1 Unicode/injection.
	scanText := in.Content
	if scanText == "" && in.Command != "" {
		scanText = in.Command
	}

	if scanText != "" {
		for _, f := range e.secrets.Scan(scanText, location, e.salt) {
			if f.Confidence > riskScore {
				riskScore = f.Confidence
			}
			rawFindings = append(rawFindings, f)
		}
		for _, f := range e.pii.Scan(scanText, location, e.salt) {
			if f.Confidence > riskScore {
				riskScore = f.Confidence
			}
			rawFindings = append(rawFindings, f)
		}
		for _, f := range e.unicode.Scan(scanText, location, e.salt) {
			if f.Confidence > riskScore {
				riskScore = f.Confidence
			}
			rawFindings = append(rawFindings, f)
		}
		// Run injection heuristics on prompts, tool outputs, and file scans.
		if in.Event != types.EventPreToolUse {
			injFindings, injScore := e.injection.Scan(in.Event, scanText, location, e.salt)
			if injScore > riskScore {
				riskScore = injScore
			}
			rawFindings = append(rawFindings, injFindings...)
		}
	}

	// Also scan Command for secrets/Unicode if both Content and Command were supplied.
	if in.Command != "" && in.Content != "" {
		for _, f := range e.secrets.Scan(in.Command, location, e.salt) {
			if f.Confidence > riskScore {
				riskScore = f.Confidence
			}
			rawFindings = append(rawFindings, f)
		}
		for _, f := range e.unicode.Scan(in.Command, location, e.salt) {
			if f.Confidence > riskScore {
				riskScore = f.Confidence
			}
			rawFindings = append(rawFindings, f)
		}
	}

	// 3. Optional L2 local Ollama classifier: only invoked when enabled AND score falls in uncertain band.
	var l2Invoked bool
	var l2Verdict, l2Reason string
	if !in.SkipL2 && e.policy.L2.Enabled && scanText != "" {
		minS := e.policy.L2.UncertainMinScore
		maxS := e.policy.L2.UncertainMaxScore
		if minS <= 0 {
			minS = 0.35
		}
		if maxS <= 0 {
			maxS = 0.70
		}
		if riskScore >= minS && riskScore < maxS {
			res, err := e.l2.Classify(ctx, e.policy.L2, in.Event, scanText, e.salt)
			if err != nil {
				l2Invoked = true
				l2Verdict = "error"
				l2Reason = "Local classifier could not evaluate an ambiguous payload."
				failure := types.Finding{
					RuleID:      "l2-classifier-error",
					Title:       "Local L2 Classifier Error",
					Category:    types.Category("l2_error"),
					Layer:       types.LayerL2,
					Tier:        types.TierMedium,
					Confidence:  0.5,
					Location:    string(in.Event),
					Preview:     "classifier error",
					Fingerprint: redact.Fingerprint(e.salt, "l2-error:"+string(in.Event)+":"+err.Error()),
					Explanation: l2Reason,
					Remediation: "Check the local Ollama service and model configuration before relying on L2.",
				}
				rawFindings = append(rawFindings, failure)
				if failure.Confidence > riskScore {
					riskScore = failure.Confidence
				}
			} else if res.Invoked {
				l2Invoked = true
				l2Verdict = res.Verdict
				l2Reason = res.Reason
				if res.Finding != nil {
					rawFindings = append(rawFindings, *res.Finding)
					if res.Confidence > riskScore {
						riskScore = res.Confidence
					}
				}
			}
		}
	}

	// 4. Policy evaluation.
	action, highestTier, evaluated, fixOptions := policy.Evaluate(e.policy, in, rawFindings, e.allowOnce)

	redacted := scanText
	if scanText != "" && len(evaluated) > 0 {
		redacted = redact.RedactText(scanText, evaluated)
	}

	verdict := types.Verdict{
		Action:          action,
		HighestTier:     highestTier,
		Findings:        evaluated,
		RiskScore:       riskScore,
		L2Invoked:       l2Invoked,
		L2Verdict:       l2Verdict,
		L2Reason:        l2Reason,
		DurationMs:      float64(time.Since(start).Microseconds()) / 1000.0,
		RedactedContent: redacted,
		Summary:         buildSummary(action, evaluated),
		FixOptions:      fixOptions,
		EvaluatedAt:     time.Now().UTC(),
	}

	if !in.SkipAuditLog && e.audit != nil && len(evaluated) > 0 {
		_ = e.audit.LogVerdict(in, verdict)
	}

	return verdict
}

func buildSummary(action types.Action, findings []types.Finding) string {
	var active []string
	for _, f := range findings {
		if !f.AllowListed {
			active = append(active, fmt.Sprintf("%s (%s, %s)", f.Title, f.Preview, f.Fingerprint))
		}
	}
	if len(active) == 0 {
		return "Clean"
	}
	return fmt.Sprintf("Kavach [%s]: %s", action, strings.Join(active, "; "))
}
