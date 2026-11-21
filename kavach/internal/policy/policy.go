package policy

import (
	"fmt"
	"path/filepath"
	"strings"

	"github.com/kavach-sec/kavach/internal/config"
	"github.com/kavach-sec/kavach/internal/types"
)

// Evaluate applies policy tiers, rule overrides, allowlists, and allow-once entries
// to raw detector findings, returning the consolidated Verdict action and updated findings.
func Evaluate(pol config.Policy, in types.EvalInput, raw []types.Finding, allowOnce *config.AllowOnceStore) (types.Action, types.Tier, []types.Finding, []string) {
	if len(raw) == 0 {
		return types.ActionAllow, "", nil, nil
	}

	// Path/test-fixture allowlist check (applies when scanning a file path).
	if in.FilePath != "" && (matchesAnyPattern(in.FilePath, pol.Allowlist.Paths) || matchesAnyPattern(in.FilePath, pol.Allowlist.TestFixtures)) {
		out := make([]types.Finding, len(raw))
		for i, f := range raw {
			f.AllowListed = true
			f.AllowReason = "path allowlisted"
			out[i] = f
		}
		return types.ActionAllow, "", out, nil
	}

	allowRules := toSet(pol.Allowlist.Rules)
	allowFPs := toSet(pol.Allowlist.Fingerprints)

	evaluated := make([]types.Finding, 0, len(raw))
	var highestTier types.Tier
	activeCount := 0
	var fixOptions []string
	seenFix := make(map[string]struct{})
	addFix := func(opt string) {
		if opt == "" {
			return
		}
		if _, ok := seenFix[opt]; !ok {
			seenFix[opt] = struct{}{}
			fixOptions = append(fixOptions, opt)
		}
	}

	for _, f := range raw {
		// Apply configured tier by rule override or category default.
		if t, ok := pol.RuleOverrides[f.RuleID]; ok && t != "" {
			f.Tier = t
		} else if catTier := pol.TierForCategory(f.Category); catTier != "" && f.Category != types.CategoryPII {
			f.Tier = catTier
		}

		// Rule allowlist
		if _, ok := allowRules[f.RuleID]; ok {
			f.AllowListed = true
			f.AllowReason = "rule allowlisted in policy"
			evaluated = append(evaluated, f)
			continue
		}

		// Fingerprint allowlist
		if _, ok := allowFPs[f.Fingerprint]; ok {
			f.AllowListed = true
			f.AllowReason = "fingerprint allowlisted in policy"
			evaluated = append(evaluated, f)
			continue
		}

		// Allow-once token consumption
		if allowOnce != nil {
			if entry, ok := allowOnce.Consume(f.Fingerprint); ok {
				f.AllowListed = true
				f.AllowReason = fmt.Sprintf("allow-once (%s)", entry.Reason)
				evaluated = append(evaluated, f)
				continue
			}
		}

		activeCount++
		if tierRank(f.Tier) > tierRank(highestTier) {
			highestTier = f.Tier
		}

		if f.Placeholder != "" {
			addFix(fmt.Sprintf("Replace %s with placeholder %s", f.Preview, f.Placeholder))
		}
		if f.Remediation != "" {
			addFix(f.Remediation)
		}
		if f.Fingerprint != "" {
			addFix(fmt.Sprintf("Allow once (logged): kavach allow-once %s --reason \"<justification>\"", f.Fingerprint))
		}

		evaluated = append(evaluated, f)
	}

	if activeCount == 0 {
		return types.ActionAllow, "", evaluated, nil
	}

	return tierToAction(highestTier), highestTier, evaluated, fixOptions
}

func tierToAction(t types.Tier) types.Action {
	switch t {
	case types.TierHigh:
		return types.ActionBlock
	case types.TierMedium:
		return types.ActionWarn
	case types.TierLow:
		return types.ActionLog
	default:
		return types.ActionWarn
	}
}

func tierRank(t types.Tier) int {
	switch t {
	case types.TierLow:
		return 1
	case types.TierMedium:
		return 2
	case types.TierHigh:
		return 3
	default:
		return 0
	}
}

func toSet(items []string) map[string]struct{} {
	m := make(map[string]struct{}, len(items))
	for _, s := range items {
		s = strings.TrimSpace(s)
		if s != "" {
			m[s] = struct{}{}
		}
	}
	return m
}

func matchesAnyPattern(target string, patterns []string) bool {
	norm := filepath.ToSlash(target)
	base := filepath.Base(norm)
	for _, p := range patterns {
		p = filepath.ToSlash(strings.TrimSpace(p))
		if p == "" {
			continue
		}
		if matched, err := filepath.Match(p, norm); err == nil && matched {
			return true
		}
		if matched, err := filepath.Match(p, base); err == nil && matched {
			return true
		}
		if strings.Contains(norm, strings.TrimSuffix(p, "/*")) && strings.HasSuffix(p, "/*") {
			return true
		}
	}
	return false
}
