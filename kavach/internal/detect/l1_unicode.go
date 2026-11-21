package detect

import (
	"fmt"
	"strings"
	"unicode/utf8"

	"github.com/kavach-sec/kavach/internal/redact"
	"github.com/kavach-sec/kavach/internal/types"
)

// UnicodeScanner detects invisible Unicode smuggling (Tag chars, zero-width chars,
// bidirectional Trojan-Source overrides, and variation selector smuggling).
type UnicodeScanner struct{}

// NewUnicodeScanner constructs a Unicode smuggling detector.
func NewUnicodeScanner() *UnicodeScanner {
	return &UnicodeScanner{}
}

// Scan inspects text for suspicious Unicode control/invisible characters.
func (u *UnicodeScanner) Scan(text, location, salt string) []types.Finding {
	if text == "" {
		return nil
	}
	var (
		tagCount       int
		tagDecoded     strings.Builder
		bidiCount      int
		zwCount        int
		vsCount        int
		firstTagOffset = -1
		firstBidiOff   = -1
		firstZWOff     = -1
		firstVSOff     = -1
	)

	var prevRune rune
	for idx, r := range text {
		switch {
		case r >= 0xE0000 && r <= 0xE007F:
			tagCount++
			if firstTagOffset < 0 {
				firstTagOffset = idx
			}
			if r >= 0xE0020 && r <= 0xE007E {
				tagDecoded.WriteRune(r - 0xE0000)
			}
		case isBidiControl(r):
			bidiCount++
			if firstBidiOff < 0 {
				firstBidiOff = idx
			}
		case isZeroWidth(r):
			// Allow UTF-8 BOM at byte 0.
			if r == 0xFEFF && idx == 0 {
				prevRune = r
				continue
			}
			// Allow legitimate emoji ZWJ sequences (U+200D between emoji codepoints).
			if r == 0x200D && isEmoji(prevRune) {
				nextRune, _ := utf8.DecodeRuneInString(text[idx+utf8.RuneLen(r):])
				if isEmoji(nextRune) {
					prevRune = r
					continue
				}
			}
			zwCount++
			if firstZWOff < 0 {
				firstZWOff = idx
			}
		case isVariationSelector(r):
			vsCount++
			if firstVSOff < 0 {
				firstVSOff = idx
			}
		}
		prevRune = r
	}

	var findings []types.Finding

	if tagCount >= 2 {
		preview := fmt.Sprintf("U+E00xx (%d tag chars)", tagCount)
		if decoded := strings.TrimSpace(tagDecoded.String()); decoded != "" {
			preview = fmt.Sprintf("tag-smuggled(%s)", redact.Preview(decoded))
		}
		loc := fmtLoc(location, text, firstTagOffset)
		fp := redact.Fingerprint(salt, fmt.Sprintf("unicode-tag:%s:%d", loc, tagCount))
		findings = append(findings, types.Finding{
			RuleID:      "unicode-tag-smuggling",
			Title:       "Unicode Tag Character Smuggling",
			Category:    types.CategoryUnicode,
			Layer:       types.LayerL1,
			Tier:        types.TierHigh,
			Confidence:  0.99,
			Location:    loc,
			Preview:     preview,
			Fingerprint: fp,
			Explanation: fmt.Sprintf("Detected %d invisible Unicode Tag characters (U+E0000–U+E007F) at %s, commonly used to smuggle hidden instructions.", tagCount, loc),
			Remediation: "Strip invisible Unicode Tag characters before passing text to the model.",
		})
	}

	if bidiCount >= 1 {
		loc := fmtLoc(location, text, firstBidiOff)
		fp := redact.Fingerprint(salt, fmt.Sprintf("unicode-bidi:%s:%d", loc, bidiCount))
		findings = append(findings, types.Finding{
			RuleID:      "unicode-bidi-override",
			Title:       "Bidirectional Control Character (Trojan Source)",
			Category:    types.CategoryUnicode,
			Layer:       types.LayerL1,
			Tier:        types.TierHigh,
			Confidence:  0.96,
			Location:    loc,
			Preview:     fmt.Sprintf("bidi-controls (%d chars)", bidiCount),
			Fingerprint: fp,
			Explanation: fmt.Sprintf("Detected %d bidirectional override/isolate control character(s) at %s, which can disguise code or instructions.", bidiCount, loc),
			Remediation: "Remove bidirectional control characters (U+202A–U+202E, U+2066–U+2069) and inspect the surrounding text.",
		})
	}

	if zwCount >= 2 {
		loc := fmtLoc(location, text, firstZWOff)
		fp := redact.Fingerprint(salt, fmt.Sprintf("unicode-zw:%s:%d", loc, zwCount))
		findings = append(findings, types.Finding{
			RuleID:      "unicode-zero-width",
			Title:       "Zero-Width Character Obfuscation",
			Category:    types.CategoryUnicode,
			Layer:       types.LayerL1,
			Tier:        types.TierHigh,
			Confidence:  0.92,
			Location:    loc,
			Preview:     fmt.Sprintf("zero-width (%d chars)", zwCount),
			Fingerprint: fp,
			Explanation: fmt.Sprintf("Detected %d unexpected zero-width characters (U+200B/200C/200D/2060/FEFF) at %s, often used to evade filters or hide payloads.", zwCount, loc),
			Remediation: "Normalize and strip zero-width characters from the input.",
		})
	}

	if vsCount >= 6 {
		loc := fmtLoc(location, text, firstVSOff)
		fp := redact.Fingerprint(salt, fmt.Sprintf("unicode-vs:%s:%d", loc, vsCount))
		findings = append(findings, types.Finding{
			RuleID:      "unicode-variation-smuggling",
			Title:       "Variation Selector Byte Smuggling",
			Category:    types.CategoryUnicode,
			Layer:       types.LayerL1,
			Tier:        types.TierHigh,
			Confidence:  0.90,
			Location:    loc,
			Preview:     fmt.Sprintf("variation-selectors (%d chars)", vsCount),
			Fingerprint: fp,
			Explanation: fmt.Sprintf("Detected %d consecutive/clustered Unicode variation selectors at %s.", vsCount, loc),
			Remediation: "Remove suspicious variation selector sequences before processing.",
		})
	}

	return findings
}

// StripInvisible returns a copy of text with zero-width, tag, and bidi characters removed
// so downstream injection scanners can detect split keywords (e.g. "ig\u200bnore").
func StripInvisible(text string) string {
	var b strings.Builder
	b.Grow(len(text))
	for _, r := range text {
		if (r >= 0xE0000 && r <= 0xE007F) || isZeroWidth(r) || isBidiControl(r) || isVariationSelector(r) {
			continue
		}
		b.WriteRune(r)
	}
	return b.String()
}

func isBidiControl(r rune) bool {
	return (r >= 0x202A && r <= 0x202E) || (r >= 0x2066 && r <= 0x2069)
}

func isZeroWidth(r rune) bool {
	return r == 0x200B || r == 0x200C || r == 0x200D || r == 0x2060 || r == 0xFEFF
}

func isVariationSelector(r rune) bool {
	return (r >= 0xFE00 && r <= 0xFE0F) || (r >= 0xE0100 && r <= 0xE01EF)
}

func isEmoji(r rune) bool {
	return (r >= 0x1F300 && r <= 0x1FAFF) || (r >= 0x2600 && r <= 0x27BF)
}
