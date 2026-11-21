package detect

import (
	"encoding/base64"
	"encoding/hex"
	"fmt"
	"regexp"
	"strings"
	"unicode"
	"unicode/utf8"

	"github.com/kavach-sec/kavach/internal/redact"
	"github.com/kavach-sec/kavach/internal/types"
)

type injectionPattern struct {
	id         string
	title      string
	re         *regexp.Regexp
	weight     float64
	tier       types.Tier
	requireCtx bool // if true, downgrade/skip when framed as benign educational discussion on UserPromptSubmit
}

var (
	injectionPatterns = []injectionPattern{
		{
			id:         "inj-ignore-previous",
			title:      "Instruction Override Attempt",
			re:         regexp.MustCompile(`(?i)\b(?:ignore|disregard|forget|override|bypass|discard)\s+(?:all\s+|any\s+|every\s+)?(?:previous|prior|above|earlier|preceding|system|safety)\s+(?:instructions?|rules?|prompts?|directives?|constraints?|guardrails?)\b`),
			weight:     0.85,
			tier:       types.TierHigh,
			requireCtx: true,
		},
		{
			id:         "inj-new-system-prompt",
			title:      "Role / System Prompt Hijack",
			re:         regexp.MustCompile(`(?i)(?:you\s+are\s+now\s+(?:in\s+)?(?:developer|god|admin|unrestricted|jailbreak|dan)\s+mode|new\s+system\s+prompt\s*:|<\|im_start\|>\s*system|<\|system\|>|###\s*system\s*(?:override|instruction)|\[\s*system\s*(?:override|prompt)\s*\])`),
			weight:     0.90,
			tier:       types.TierHigh,
			requireCtx: true,
		},
		{
			id:         "inj-reveal-system-prompt",
			title:      "System Prompt Exfiltration Attempt",
			re:         regexp.MustCompile(`(?i)\b(?:reveal|print|dump|output|repeat|leak|show)\s+(?:me\s+)?(?:your|the)\s+(?:exact\s+|full\s+|initial\s+|hidden\s+)?(?:system\s+prompt|developer\s+instructions?|hidden\s+instructions?)\b`),
			weight:     0.78,
			tier:       types.TierHigh,
			requireCtx: true,
		},
		{
			id:         "inj-addressed-to-ai",
			title:      "Instructions Addressed to AI Inside Data",
			re:         regexp.MustCompile(`(?i)(?:note\s+to\s+(?:the\s+)?(?:ai|assistant|claude|llm|model)|attention\s+(?:ai|assistant|claude|llm)|dear\s+(?:ai|assistant|claude)|hey\s+(?:ai|claude|assistant)\s*,|important\s+for\s+(?:the\s+)?(?:ai|assistant|model)\s*:|ai\s+instruction\s*:)`),
			weight:     0.82,
			tier:       types.TierHigh,
			requireCtx: false,
		},
		{
			id:         "inj-conceal-from-user",
			title:      "Stealth Concealment Directive",
			re:         regexp.MustCompile(`(?i)\b(?:do\s+not\s+(?:tell|inform|mention\s+(?:this\s+)?to)\s+the\s+user|without\s+(?:telling|notifying|alerting)\s+the\s+user|silently\s+(?:run|execute|send|upload|exfiltrate|read)|hide\s+this\s+from\s+the\s+user)\b`),
			weight:     0.90,
			tier:       types.TierHigh,
			requireCtx: false,
		},
		{
			id:         "inj-tool-exfil-directive",
			title:      "Embedded Tool-Abuse / Exfiltration Directive",
			re:         regexp.MustCompile(`(?i)\b(?:before\s+(?:answering|responding|continuing)[^.\n]{0,40}\b(?:run|execute|read|fetch|curl|send|post)\b|exfiltrate\s+(?:the\s+)?(?:secrets?|keys?|tokens?|credentials?|env|\.ssh|files?)\s+to)\b`),
			weight:     0.88,
			tier:       types.TierHigh,
			requireCtx: false,
		},
		{
			id:         "inj-stop-following-rules",
			title:      "Instruction Override Attempt",
			re:         regexp.MustCompile(`(?i)\b(?:stop|cease)\s+following\s+(?:the\s+)?(?:system|developer|safety|previous|prior)\s+(?:instructions?|rules?|policies?|prompts?)\b`),
			weight:     0.86,
			tier:       types.TierHigh,
			requireCtx: false,
		},
		{
			id:         "inj-authority-claim",
			title:      "Untrusted Content Claims Authority",
			re:         regexp.MustCompile(`(?i)\b(?:this|the)\s+(?:page|document|file|content|message)\s+(?:(?:is|should\s+be\s+treated\s+as|takes\s+precedence\s+as)\s+(?:authoritative|trusted|the\s+source\s+of\s+truth|higher\s+priority).{0,160}\b(?:follow|obey|execute|carry\s+out|disclose|reveal|upload|send|print|include)\b|supersedes?\s+(?:all\s+)?(?:previous|prior|earlier)\s+(?:instructions?|rules?|policies?))\b`),
			weight:     0.82,
			tier:       types.TierHigh,
			requireCtx: false,
		},
		{
			id:         "inj-follow-document-instructions",
			title:      "Embedded Instruction-Following Directive",
			re:         regexp.MustCompile(`(?i)\b(?:follow|obey|execute|carry\s+out)\s+(?:all|every|any)\s+(?:instructions?|steps?|commands?)\s+(?:in|from|within|listed\s+in)\s+(?:this|the)\s+(?:document|page|file|message)\b`),
			weight:     0.84,
			tier:       types.TierHigh,
			requireCtx: false,
		},
		{
			id:         "inj-disclose-sensitive-data",
			title:      "Sensitive Data Disclosure Directive",
			re:         regexp.MustCompile(`(?i)\b(?:send|upload|post|transmit|forward|share|email|copy|include|disclose|reveal|print|list|export|dump)\b.{0,80}\b(?:\.env|environment\s+variables?|credentials?|secrets?|tokens?|api\s+keys?|private\s+keys?|ssh\s+(?:keys?|directory|archive)|configuration)\b|\b(?:\.env|environment\s+variables?|credentials?|secrets?|tokens?|api\s+keys?|private\s+keys?|ssh\s+(?:keys?|directory|archive)|configuration)\b.{0,80}\b(?:send|upload|post|transmit|forward|share|email|copy|include|disclose|reveal|print|list|export|dump)\b`),
			weight:     0.88,
			tier:       types.TierHigh,
			requireCtx: false,
		},
	}

	hiddenHTMLCSSRegex = regexp.MustCompile(`(?is)<(?:(?:template|script|noscript)\b[^>]*|[a-z0-9]+\b[^>]*(?:\shidden(?:\s|=|>)|\baria-hidden\s*=\s*["']?true\b|\bstyle\s*=\s*["'][^"']*(?:display\s*:\s*none|visibility\s*:\s*hidden|opacity\s*:\s*0(?:\.0+)?\b|font-size\s*:\s*0(?:px|pt|em)?\b|left\s*:\s*-9\d{3,}px|color\s*:\s*(?:white|#fff(?:fff)?|transparent)|content-visibility\s*:\s*hidden|clip(?:-path)?\s*:\s*(?:rect|inset)\s*\([^)]*\)|text-indent\s*:\s*-?\d{3,}px)[^"']*["'][^>]*))>(.*?)</[a-z0-9]+\s*>`)
	htmlCommentRegex   = regexp.MustCompile(`(?s)<!--(.*?)-->`)
	mdCommentRegex     = regexp.MustCompile(`(?m)^\[//\]:\s*#\s*\((.+)\)$`)
	imperativeActionRe = regexp.MustCompile(`(?i)\b(?:ignore|disregard|execute|run|curl|wget|exfiltrate|send|upload|disclose|reveal|print|include|export|follow|obey|supersedes?|authoritative|credentials?|configuration|environment\s+variables?|api\s+keys?|private\s+keys?|secrets?|tokens?|read\s+~?/?\.ssh|read\s+~?/?\.aws|cat\s+/etc/|\.env|assistant|claude|system\s+prompt|do\s+not\s+tell|tool_use)\b`)

	base64CandidateRe = regexp.MustCompile(`\b([A-Za-z0-9+/]{24,}={0,2})\b`)
	hexCandidateRe    = regexp.MustCompile(`\b([0-9a-fA-F]{32,})\b`)

	educationalFramingRe = regexp.MustCompile(`(?i)\b(?:explain|what\s+is|how\s+does|how\s+do|example\s+of|unit\s+test|test\s+case|detection\s+rule|prevent|mitigate|defend\s+against|article\s+about|paper\s+on|blog\s+post|owasp|llm01)\b`)
)

// InjectionScanner detects direct and indirect prompt injection (L1 heuristics).
type InjectionScanner struct {
	secrets *SecretScanner
}

// NewInjectionScanner constructs an L1 injection scanner.
func NewInjectionScanner(secrets *SecretScanner) *InjectionScanner {
	return &InjectionScanner{secrets: secrets}
}

// Scan inspects text for direct or indirect prompt injection, hidden HTML/CSS directives,
// and encoded base64/hex payloads. Returns findings and an uncertainty score [0..1] for L2 gating.
func (s *InjectionScanner) Scan(event types.HookEvent, text, location, salt string) ([]types.Finding, float64) {
	if text == "" {
		return nil, 0
	}
	// Strip invisible Unicode so split-word evasions ("ig\u200bnore") still match.
	normalized := StripInvisible(text)
	// Strip Claude Code's pasted_content wrapper tags without altering the inner text.
	normalized = stripPastedContentTags(normalized)

	isDataPlane := event == types.EventPostToolUse || event == types.EventScan
	cat := types.CategoryInjection
	if event == types.EventPostToolUse {
		cat = types.CategoryIndirectInject
	}

	var findings []types.Finding
	seen := make(map[string]struct{})
	var maxScore float64

	// 1. Hidden HTML/CSS elements with imperative instructions.
	for _, m := range hiddenHTMLCSSRegex.FindAllStringSubmatchIndex(normalized, -1) {
		inner := strings.TrimSpace(normalized[m[2]:m[3]])
		if inner == "" || !imperativeActionRe.MatchString(inner) {
			continue
		}
		loc := fmtLoc(location, normalized, m[0])
		fp := redact.Fingerprint(salt, "hidden-html:"+inner)
		if _, ok := seen[fp]; ok {
			continue
		}
		seen[fp] = struct{}{}
		maxScore = maxFloat(maxScore, 0.94)
		findings = append(findings, types.Finding{
			RuleID:      "inj-hidden-html-css",
			Title:       "Hidden HTML/CSS Prompt Injection",
			Category:    types.CategoryIndirectInject,
			Layer:       types.LayerL1,
			Tier:        types.TierHigh,
			Confidence:  0.94,
			Location:    loc,
			Preview:     redact.Preview(inner),
			Fingerprint: fp,
			Explanation: fmt.Sprintf("Hidden HTML/CSS block at %s contains AI-directed or imperative instructions (%s).", loc, redact.Preview(inner)),
			Remediation: "Withhold or sanitize hidden HTML/CSS content before passing to the model.",
		})
	}

	// 2. HTML/Markdown comments containing imperative AI directives.
	for _, re := range []*regexp.Regexp{htmlCommentRegex, mdCommentRegex} {
		for _, m := range re.FindAllStringSubmatchIndex(normalized, -1) {
			inner := strings.TrimSpace(normalized[m[2]:m[3]])
			if inner == "" || !imperativeActionRe.MatchString(inner) {
				continue
			}
			// Require either AI-addressing or override/exfil verbs in comments so benign TODO comments don't trigger.
			if !hasStrongCommentSignal(inner) {
				continue
			}
			loc := fmtLoc(location, normalized, m[0])
			fp := redact.Fingerprint(salt, "comment-inj:"+inner)
			if _, ok := seen[fp]; ok {
				continue
			}
			seen[fp] = struct{}{}
			maxScore = maxFloat(maxScore, 0.90)
			findings = append(findings, types.Finding{
				RuleID:      "inj-hidden-comment",
				Title:       "Hidden Comment Prompt Injection",
				Category:    types.CategoryIndirectInject,
				Layer:       types.LayerL1,
				Tier:        types.TierHigh,
				Confidence:  0.90,
				Location:    loc,
				Preview:     redact.Preview(inner),
				Fingerprint: fp,
				Explanation: fmt.Sprintf("HTML/Markdown comment at %s contains hidden instructions targeting the assistant.", loc),
				Remediation: "Strip hidden directive comments before letting the model reason over this document.",
			})
		}
	}

	// 3. Phrase & structure heuristics.
	isEducationalUserPrompt := !isDataPlane && educationalFramingRe.MatchString(normalized)
	for _, pat := range injectionPatterns {
		locs := pat.re.FindAllStringIndex(normalized, -1)
		for _, locIdx := range locs {
			matched := normalized[locIdx[0]:locIdx[1]]
			if pat.requireCtx && isEducationalUserPrompt && isQuotedOrAnalyzed(normalized, locIdx[0], locIdx[1]) {
				// Weak uncertain signal only (candidate for L2 if enabled, not a hard block).
				maxScore = maxFloat(maxScore, 0.42)
				continue
			}
			// If user asks "Explain what 'ignore previous instructions' means" without quotes, check imperative position.
			if pat.requireCtx && isEducationalUserPrompt && locIdx[0] > 12 {
				maxScore = maxFloat(maxScore, 0.42)
				continue
			}

			loc := fmtLoc(location, normalized, locIdx[0])
			fp := redact.Fingerprint(salt, pat.id+":"+strings.ToLower(matched))
			if _, ok := seen[fp]; ok {
				continue
			}
			seen[fp] = struct{}{}
			maxScore = maxFloat(maxScore, pat.weight)
			findings = append(findings, types.Finding{
				RuleID:      pat.id,
				Title:       pat.title,
				Category:    cat,
				Layer:       types.LayerL1,
				Tier:        pat.tier,
				Confidence:  pat.weight,
				Location:    loc,
				Preview:     redact.Preview(matched),
				Fingerprint: fp,
				Explanation: fmt.Sprintf("Detected %s (%s) at %s.", pat.title, redact.Preview(matched), loc),
				Remediation: "Do not forward untrusted instructions to the model; review or strip the flagged directive.",
			})
		}
	}

	// 4. Suspicious Base64 / Hex encoded blobs -> decode and rescan via L0 + L1.
	for _, dec := range extractEncodedBlobs(normalized) {
		if s.secrets != nil {
			for _, sf := range s.secrets.Scan(dec.decoded, location+" (decoded "+dec.encoding+")", salt) {
				sf.Layer = types.LayerL1
				sf.RuleID = "encoded-" + sf.RuleID
				sf.Title = "Encoded " + sf.Title
				maxScore = maxFloat(maxScore, sf.Confidence)
				findings = append(findings, sf)
			}
		}
		for _, pat := range injectionPatterns {
			if pat.re.MatchString(dec.decoded) {
				fp := redact.Fingerprint(salt, "enc-inj:"+dec.encoding+":"+dec.decoded)
				if _, ok := seen[fp]; ok {
					continue
				}
				seen[fp] = struct{}{}
				maxScore = maxFloat(maxScore, 0.93)
				findings = append(findings, types.Finding{
					RuleID:      "inj-encoded-" + dec.encoding,
					Title:       fmt.Sprintf("%s-Encoded Prompt Injection", strings.ToUpper(dec.encoding)),
					Category:    cat,
					Layer:       types.LayerL1,
					Tier:        types.TierHigh,
					Confidence:  0.93,
					Location:    location,
					Preview:     redact.Preview(dec.decoded),
					Fingerprint: fp,
					Explanation: fmt.Sprintf("Decoded %s payload at %s contains prompt injection instructions.", dec.encoding, location),
					Remediation: "Inspect and remove obfuscated encoded instructions before sending to the model.",
				})
			}
		}
	}

	// 5. Mild uncertain heuristic score for ambiguous imperative text in data plane (triggers L2 if enabled).
	if len(findings) == 0 && isDataPlane && hasAmbiguousImperative(normalized) {
		maxScore = maxFloat(maxScore, 0.48)
	}

	return findings, maxScore
}

type decodedBlob struct {
	encoding string
	decoded  string
}

func extractEncodedBlobs(text string) []decodedBlob {
	var out []decodedBlob
	seen := make(map[string]struct{})

	for _, m := range base64CandidateRe.FindAllString(text, 20) {
		if len(m) > 8192 {
			continue
		}
		// Skip common URLs/paths or pure hex strings handled below.
		if strings.Contains(m, "/") && !strings.Contains(m, "=") && len(m) < 32 {
			continue
		}
		raw, err := base64.StdEncoding.DecodeString(m)
		if err != nil {
			raw, err = base64.RawStdEncoding.DecodeString(m)
		}
		if err != nil || len(raw) < 12 || !isPrintableUTF8(raw) {
			continue
		}
		s := string(raw)
		if _, ok := seen[s]; !ok {
			seen[s] = struct{}{}
			out = append(out, decodedBlob{encoding: "base64", decoded: s})
		}
	}

	for _, m := range hexCandidateRe.FindAllString(text, 20) {
		if len(m)%2 != 0 || len(m) > 8192 {
			continue
		}
		raw, err := hex.DecodeString(m)
		if err != nil || len(raw) < 12 || !isPrintableUTF8(raw) {
			continue
		}
		s := string(raw)
		if _, ok := seen[s]; !ok {
			seen[s] = struct{}{}
			out = append(out, decodedBlob{encoding: "hex", decoded: s})
		}
	}
	return out
}

func isPrintableUTF8(b []byte) bool {
	if !utf8.Valid(b) {
		return false
	}
	printable := 0
	total := 0
	for _, r := range string(b) {
		total++
		if unicode.IsPrint(r) || r == '\n' || r == '\r' || r == '\t' {
			printable++
		}
	}
	return total > 0 && float64(printable)/float64(total) >= 0.85
}

func hasStrongCommentSignal(inner string) bool {
	lower := strings.ToLower(inner)
	signals := []string{
		"ignore previous", "ignore all", "disregard", "assistant", "claude",
		"system prompt", "do not tell", "exfiltrate", "curl ", "wget ",
		"~/.ssh", "~/.aws", "/etc/passwd", "note to ai", "hey ai",
		"authoritative", "supersedes", "credentials", "configuration",
		"follow every instruction", "upload .env",
	}
	for _, sig := range signals {
		if strings.Contains(lower, sig) {
			return true
		}
	}
	return false
}

func isQuotedOrAnalyzed(text string, start, end int) bool {
	if start > 0 && (text[start-1] == '\'' || text[start-1] == '"' || text[start-1] == '`') {
		return true
	}
	if end < len(text) && (text[end] == '\'' || text[end] == '"' || text[end] == '`') {
		return true
	}
	return false
}

func hasAmbiguousImperative(text string) bool {
	lower := strings.ToLower(text)
	hits := 0
	for _, kw := range []string{"must immediately", "you must", "do not ask", "execute the following", "new directive", "override"} {
		if strings.Contains(lower, kw) {
			hits++
		}
	}
	return hits >= 2
}

var pastedTagRe = regexp.MustCompile(`(?m)^</?pasted_content(?:\s+id="[^"]*")?>\r?\n?`)

func stripPastedContentTags(text string) string {
	return pastedTagRe.ReplaceAllString(text, "")
}

func maxFloat(a, b float64) float64 {
	if a > b {
		return a
	}
	return b
}
