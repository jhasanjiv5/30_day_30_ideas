package detect

import (
	"fmt"
	"regexp"
	"strings"
	"unicode"

	"github.com/kavach-sec/kavach/internal/config"
	"github.com/kavach-sec/kavach/internal/redact"
	"github.com/kavach-sec/kavach/internal/types"
)

var (
	emailRegex = regexp.MustCompile(`\b([A-Za-z0-9._%+\-]{1,64}@[A-Za-z0-9.\-]{2,63}\.[A-Za-z]{2,12})\b`)
	cardRegex  = regexp.MustCompile(`\b((?:\d[ -]?){13,19})\b`)
	phoneRegex = regexp.MustCompile(`(?i)(?:phone|mobile|cell|tel|contact|whatsapp|call)?[:\s]*(\+\d{1,3}[\s\-]?(?:\(\d{2,4}\)|\d{2,4})[\s\-]?\d{3,4}[\s\-]?\d{3,5}|\(\d{3}\)\s*\d{3}[-\s]\d{4})\b`)
)

type compiledNationalID struct {
	cfg config.NationalIDPattern
	re  *regexp.Regexp
}

// PIIScanner implements L0 PII detection (emails, Luhn-validated cards, phones, configurable national IDs).
type PIIScanner struct {
	emailTier     types.Tier
	ignoreDomains map[string]struct{}
	nationalIDs   []compiledNationalID
}

// NewPIIScanner constructs a PII scanner from policy configuration.
func NewPIIScanner(cfg config.PIIConfig) (*PIIScanner, error) {
	emailTier := cfg.EmailTier
	if emailTier == "" {
		emailTier = types.TierMedium
	}
	ignore := make(map[string]struct{}, len(cfg.IgnoreDomains))
	for _, d := range cfg.IgnoreDomains {
		ignore[strings.ToLower(strings.TrimSpace(d))] = struct{}{}
	}
	var compiled []compiledNationalID
	for _, nid := range cfg.NationalIDs {
		re, err := regexp.Compile(nid.Regex)
		if err != nil {
			return nil, fmt.Errorf("compile national ID pattern %s: %w", nid.ID, err)
		}
		compiled = append(compiled, compiledNationalID{cfg: nid, re: re})
	}
	return &PIIScanner{
		emailTier:     emailTier,
		ignoreDomains: ignore,
		nationalIDs:   compiled,
	}, nil
}

// Scan inspects text for PII without ever storing raw values in returned findings.
func (s *PIIScanner) Scan(text, location, salt string) []types.Finding {
	if text == "" {
		return nil
	}
	var findings []types.Finding
	seen := make(map[string]struct{})
	lowerText := strings.ToLower(text)

	// 1. Payment card numbers (strict Luhn check + known BIN prefix).
	for _, loc := range cardRegex.FindAllStringSubmatchIndex(text, -1) {
		start, end := loc[2], loc[3]
		raw := strings.TrimSpace(text[start:end])
		digits := extractDigits(raw)
		if len(digits) < 13 || len(digits) > 19 {
			continue
		}
		if !isLikelyPaymentCard(digits) || !passesLuhn(digits) {
			continue
		}
		fp := redact.Fingerprint(salt, digits)
		if _, ok := seen["pii-card:"+fp]; ok {
			continue
		}
		seen["pii-card:"+fp] = struct{}{}
		locStr := fmtLoc(location, text, start)
		findings = append(findings, types.Finding{
			RuleID:      "pii-payment-card",
			Title:       "Payment Card Number (Luhn-valid)",
			Category:    types.CategoryPII,
			Layer:       types.LayerL0,
			Tier:        types.TierHigh,
			Confidence:  0.96,
			Location:    locStr,
			Preview:     redact.Preview(digits),
			Fingerprint: fp,
			Placeholder: "${PAYMENT_CARD_REDACTED}",
			Explanation: fmt.Sprintf("Detected Luhn-valid payment card number (%s) at %s.", redact.Preview(digits), locStr),
			Remediation: "Remove real or synthetic card numbers before sending to the model, or replace with ${PAYMENT_CARD_REDACTED}.",
			StartOffset: start,
			EndOffset:   end,
		})
	}

	// 2. Configurable National IDs (SSN, Aadhaar, PAN, custom regexes).
	for _, nid := range s.nationalIDs {
		for _, loc := range nid.re.FindAllStringIndex(text, -1) {
			start, end := loc[0], loc[1]
			val := text[start:end]
			if len(nid.cfg.Context) > 0 && !hasNearbyContext(lowerText, start, end, nid.cfg.Context) {
				continue
			}
			fp := redact.Fingerprint(salt, val)
			key := nid.cfg.ID + ":" + fp
			if _, ok := seen[key]; ok {
				continue
			}
			seen[key] = struct{}{}
			tier := nid.cfg.Tier
			if tier == "" {
				tier = types.TierHigh
			}
			locStr := fmtLoc(location, text, start)
			findings = append(findings, types.Finding{
				RuleID:      nid.cfg.ID,
				Title:       nid.cfg.Title,
				Category:    types.CategoryPII,
				Layer:       types.LayerL0,
				Tier:        tier,
				Confidence:  0.93,
				Location:    locStr,
				Preview:     redact.Preview(val),
				Fingerprint: fp,
				Placeholder: redact.Placeholder(nid.cfg.ID),
				Explanation: fmt.Sprintf("Detected %s (%s) at %s.", nid.cfg.Title, redact.Preview(val), locStr),
				Remediation: fmt.Sprintf("Replace with %s or anonymize before sending.", redact.Placeholder(nid.cfg.ID)),
				StartOffset: start,
				EndOffset:   end,
			})
		}
	}

	// 3. Phone numbers (explicit international / US formatted numbers).
	for _, loc := range phoneRegex.FindAllStringSubmatchIndex(text, -1) {
		start, end := loc[2], loc[3]
		val := strings.TrimSpace(text[start:end])
		digits := extractDigits(val)
		if len(digits) < 10 || len(digits) > 15 {
			continue
		}
		fp := redact.Fingerprint(salt, digits)
		if _, ok := seen["pii-phone:"+fp]; ok {
			continue
		}
		seen["pii-phone:"+fp] = struct{}{}
		locStr := fmtLoc(location, text, start)
		findings = append(findings, types.Finding{
			RuleID:      "pii-phone-number",
			Title:       "Phone Number",
			Category:    types.CategoryPII,
			Layer:       types.LayerL0,
			Tier:        types.TierMedium,
			Confidence:  0.85,
			Location:    locStr,
			Preview:     redact.Preview(digits),
			Fingerprint: fp,
			Placeholder: "${PHONE_NUMBER}",
			Explanation: fmt.Sprintf("Detected phone number (%s) at %s.", redact.Preview(digits), locStr),
			Remediation: "Replace personal phone numbers with ${PHONE_NUMBER} or synthetic 555-01xx fixtures.",
			StartOffset: start,
			EndOffset:   end,
		})
	}

	// 4. Email addresses (ignoring configured RFC-2606/noreply domains).
	for _, loc := range emailRegex.FindAllStringSubmatchIndex(text, -1) {
		start, end := loc[2], loc[3]
		val := text[start:end]
		if s.isIgnoredEmail(val) {
			continue
		}
		fp := redact.Fingerprint(salt, strings.ToLower(val))
		if _, ok := seen["pii-email:"+fp]; ok {
			continue
		}
		seen["pii-email:"+fp] = struct{}{}
		locStr := fmtLoc(location, text, start)
		findings = append(findings, types.Finding{
			RuleID:      "pii-email",
			Title:       "Email Address",
			Category:    types.CategoryPII,
			Layer:       types.LayerL0,
			Tier:        s.emailTier,
			Confidence:  0.86,
			Location:    locStr,
			Preview:     redact.Preview(val),
			Fingerprint: fp,
			Placeholder: "${EMAIL_ADDRESS}",
			Explanation: fmt.Sprintf("Detected email address (%s) at %s.", redact.Preview(val), locStr),
			Remediation: "Replace personal email with ${EMAIL_ADDRESS} or an RFC-2606 @example.com address.",
			StartOffset: start,
			EndOffset:   end,
		})
	}

	return findings
}

func (s *PIIScanner) isIgnoredEmail(email string) bool {
	parts := strings.SplitN(strings.ToLower(email), "@", 2)
	if len(parts) != 2 {
		return true
	}
	local, domain := parts[0], parts[1]
	if strings.HasPrefix(local, "noreply") || strings.HasPrefix(local, "no-reply") {
		return true
	}
	if _, ok := s.ignoreDomains[domain]; ok {
		return true
	}
	// Ignore package/file extensions mistakenly matched as TLDs
	for _, badExt := range []string{".png", ".jpg", ".svg", ".ts", ".js", ".go", ".py", ".md", ".yaml", ".json"} {
		if strings.HasSuffix(domain, badExt) {
			return true
		}
	}
	return false
}

func extractDigits(s string) string {
	var b strings.Builder
	for _, r := range s {
		if unicode.IsDigit(r) {
			b.WriteRune(r)
		}
	}
	return b.String()
}

func isLikelyPaymentCard(digits string) bool {
	if len(digits) < 13 || len(digits) > 19 {
		return false
	}
	// Reject repeated single digits like 0000000000000000
	allSame := true
	for i := 1; i < len(digits); i++ {
		if digits[i] != digits[0] {
			allSame = false
			break
		}
	}
	if allSame {
		return false
	}
	// Major IIN prefixes: Visa (4), Mastercard (51-55, 22-27), Amex (34,37), Discover (60,65), JCB (35)
	switch digits[0] {
	case '3', '4', '5', '6':
		return true
	default:
		return false
	}
}

func passesLuhn(digits string) bool {
	sum := 0
	alt := false
	for i := len(digits) - 1; i >= 0; i-- {
		d := int(digits[i] - '0')
		if d < 0 || d > 9 {
			return false
		}
		if alt {
			d *= 2
			if d > 9 {
				d -= 9
			}
		}
		sum += d
		alt = !alt
	}
	return sum%10 == 0
}

func hasNearbyContext(lowerText string, start, end int, keywords []string) bool {
	winStart := start - 80
	if winStart < 0 {
		winStart = 0
	}
	winEnd := end + 80
	if winEnd > len(lowerText) {
		winEnd = len(lowerText)
	}
	window := lowerText[winStart:winEnd]
	for _, kw := range keywords {
		if strings.Contains(window, strings.ToLower(kw)) {
			return true
		}
	}
	return false
}

func fmtLoc(location, text string, offset int) string {
	line := lineNumberAt(text, offset)
	if location == "" {
		return fmt.Sprintf("line %d", line)
	}
	return fmt.Sprintf("%s:line %d", location, line)
}
