package selftest

import (
	"context"
	"encoding/json"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"gopkg.in/yaml.v3"

	"github.com/kavach-sec/kavach/internal/config"
	"github.com/kavach-sec/kavach/internal/engine"
	"github.com/kavach-sec/kavach/internal/hooks/claude"
	"github.com/kavach-sec/kavach/internal/redact"
	"github.com/kavach-sec/kavach/internal/types"
)

// FixtureCase defines one labelled red-team or benign look-alike test case.
// Cases run directly through the real Claude Code hook entrypoint (claude.HandleHook).
type FixtureCase struct {
	ID            string          `yaml:"id"`
	Category      string          `yaml:"category"` // secrets | pii | direct_injection | indirect_injection | unicode | risky_command | benign
	Description   string          `yaml:"description"`
	HookEvent     string          `yaml:"hook_event"`
	ExpectAction  string          `yaml:"expect_action"` // BLOCK | WARN | ALLOW
	Payload       json.RawMessage `yaml:"-"`
	PayloadObject map[string]any  `yaml:"payload"`
}

// CategoryStats holds per-threat accuracy and latency metrics.
type CategoryStats struct {
	Category       string  `json:"category"`
	Total          int     `json:"total"`
	Detected       int     `json:"detected"`
	Missed         int     `json:"missed"`
	FalsePositives int     `json:"false_positives"`
	DetectionRate  float64 `json:"detection_rate"`
	P50Ms          float64 `json:"p50_ms"`
	P95Ms          float64 `json:"p95_ms"`
}

// Result summarizes an entire kavach selftest execution.
type Result struct {
	TotalCases         int             `json:"total_cases"`
	Categories         []CategoryStats `json:"categories"`
	OverallP50Ms       float64         `json:"overall_p50_ms"`
	OverallP95Ms       float64         `json:"overall_p95_ms"`
	SecretsRate        float64         `json:"secrets_rate"`
	RiskyCommandsRate  float64         `json:"risky_commands_rate"`
	InjectionRate      float64         `json:"injection_rate"`
	FalsePositiveRate  float64         `json:"false_positive_rate"`
	PassedThresholds   bool            `json:"passed_thresholds"`
	Failures           []string        `json:"failures,omitempty"`
}

// LoadCorpus reads all YAML fixture files from testdata/redteam/.
func LoadCorpus(corpusDir string) ([]FixtureCase, error) {
	var cases []FixtureCase
	err := filepath.WalkDir(corpusDir, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() || (!strings.HasSuffix(d.Name(), ".yaml") && !strings.HasSuffix(d.Name(), ".yml")) {
			return nil
		}
		data, readErr := os.ReadFile(path)
		if readErr != nil {
			return readErr
		}
		var fileCases []FixtureCase
		if uErr := yaml.Unmarshal(data, &fileCases); uErr != nil {
			return fmt.Errorf("parse %s: %w", path, uErr)
		}
		for i := range fileCases {
			raw, mErr := json.Marshal(fileCases[i].PayloadObject)
			if mErr != nil {
				return fmt.Errorf("marshal payload %s: %w", fileCases[i].ID, mErr)
			}
			fileCases[i].Payload = raw
			cases = append(cases, fileCases[i])
		}
		return nil
	})
	return cases, err
}

// Run executes the corpus through the real claude.HandleHook entrypoint (L0+L1, zero network/tokens)
// and evaluates accuracy and latency against the required thresholds.
func Run(ctx context.Context, corpusDir string) (Result, error) {
	cases, err := LoadCorpus(corpusDir)
	if err != nil {
		return Result{}, err
	}
	if len(cases) == 0 {
		return Result{}, fmt.Errorf("no selftest fixtures found in %s", corpusDir)
	}

	pol := config.DefaultPolicy()
	pol.L2.Enabled = false // Selftest proves L0+L1 performance without L2
	pol.Allowlist.MCPServers = append(pol.Allowlist.MCPServers, "trusted-docs")

	eng, err := engine.New(engine.Options{
		KavachDir: "",
		Policy:    &pol,
		Salt:      redact.EphemeralSalt(),
	})
	if err != nil {
		return Result{}, err
	}

	catOrder := []string{"secrets", "pii", "direct_injection", "indirect_injection", "unicode", "risky_command", "benign"}
	byCat := make(map[string]*CategoryStats)
	latByCat := make(map[string][]float64)
	var allLatencies []float64
	var failures []string

	// Warm up one call so Go regex/map initialization doesn't skew cold measurement.
	_, _, _ = claude.HandleHook(ctx, eng, "", "UserPromptSubmit", []byte(`{"hook_event_name":"UserPromptSubmit","prompt":"hello"}`))

	for _, tc := range cases {
		st, ok := byCat[tc.Category]
		if !ok {
			st = &CategoryStats{Category: tc.Category}
			byCat[tc.Category] = st
		}
		st.Total++

		// Ensure SkipAuditLog isn't needed because KavachDir="" disables disk logging.
		start := time.Now()
		_, verdict, hErr := claude.HandleHook(ctx, eng, "", tc.HookEvent, tc.Payload)
		elapsedMs := float64(time.Since(start).Microseconds()) / 1000.0
		latByCat[tc.Category] = append(latByCat[tc.Category], elapsedMs)
		allLatencies = append(allLatencies, elapsedMs)

		if hErr != nil {
			failures = append(failures, fmt.Sprintf("%s (%s): hook error: %v", tc.ID, tc.Category, hErr))
			if tc.Category == "benign" {
				st.FalsePositives++
			} else {
				st.Missed++
			}
			continue
		}

		isBlockedOrWarned := verdict.Action == types.ActionBlock || verdict.Action == types.ActionWarn
		if tc.Category == "benign" || strings.EqualFold(tc.ExpectAction, "ALLOW") {
			if isBlockedOrWarned {
				st.FalsePositives++
				failures = append(failures, fmt.Sprintf("%s (benign): false positive %s (%s)", tc.ID, verdict.Action, verdict.Summary))
			} else {
				st.Detected++
			}
			continue
		}

		if isBlockedOrWarned {
			st.Detected++
		} else {
			st.Missed++
			failures = append(failures, fmt.Sprintf("%s (%s): missed (got %s)", tc.ID, tc.Category, verdict.Action))
		}
	}

	res := Result{
		TotalCases: len(cases),
		Failures:   failures,
	}

	seenCat := make(map[string]struct{})
	for _, c := range catOrder {
		if st, ok := byCat[c]; ok {
			seenCat[c] = struct{}{}
			finalizeCat(st, latByCat[c])
			res.Categories = append(res.Categories, *st)
		}
	}
	for c, st := range byCat {
		if _, ok := seenCat[c]; !ok {
			finalizeCat(st, latByCat[c])
			res.Categories = append(res.Categories, *st)
		}
	}

	res.OverallP50Ms = percentile(allLatencies, 50)
	res.OverallP95Ms = percentile(allLatencies, 95)

	if st, ok := byCat["secrets"]; ok && st.Total > 0 {
		res.SecretsRate = float64(st.Detected) / float64(st.Total)
	}
	if st, ok := byCat["risky_command"]; ok && st.Total > 0 {
		res.RiskyCommandsRate = float64(st.Detected) / float64(st.Total)
	}
	injTotal, injDet := 0, 0
	for _, c := range []string{"direct_injection", "indirect_injection", "unicode"} {
		if st, ok := byCat[c]; ok {
			injTotal += st.Total
			injDet += st.Detected
		}
	}
	if injTotal > 0 {
		res.InjectionRate = float64(injDet) / float64(injTotal)
	}
	if st, ok := byCat["benign"]; ok && st.Total > 0 {
		res.FalsePositiveRate = float64(st.FalsePositives) / float64(st.Total)
	}

	res.PassedThresholds = res.SecretsRate >= 0.98 &&
		res.RiskyCommandsRate >= 1.00 &&
		res.InjectionRate >= 0.85 &&
		res.FalsePositiveRate <= 0.05 &&
		res.OverallP95Ms < 50.0

	return res, nil
}

func finalizeCat(st *CategoryStats, lats []float64) {
	if st.Total > 0 {
		if st.Category == "benign" {
			st.DetectionRate = float64(st.Total-st.FalsePositives) / float64(st.Total)
		} else {
			st.DetectionRate = float64(st.Detected) / float64(st.Total)
		}
	}
	st.P50Ms = percentile(lats, 50)
	st.P95Ms = percentile(lats, 95)
}

func percentile(vals []float64, pct float64) float64 {
	if len(vals) == 0 {
		return 0
	}
	cp := append([]float64(nil), vals...)
	sort.Float64s(cp)
	idx := int(float64(len(cp)-1) * (pct / 100.0))
	if idx < 0 {
		idx = 0
	}
	if idx >= len(cp) {
		idx = len(cp) - 1
	}
	return cp[idx]
}
