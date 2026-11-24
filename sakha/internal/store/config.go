package store

import (
	"encoding/json"
	"errors"
	"os"

	"github.com/jhasanjiv5/30_day_30_ideas/sakha/internal/paths"
)

// Config holds user-tunable settings (~/.sakha/config.json).
type Config struct {
	// Evidence needed before a habit is proposed, by signal type.
	ExplicitThreshold   int `json:"explicit_threshold"`
	CorrectionThreshold int `json:"correction_threshold"`
	PatternThreshold    int `json:"pattern_threshold"`
	PatternMinSessions  int `json:"pattern_min_sessions"`
	// Confirmed habits with no new evidence for this many days are re-offered for review.
	DecayDays int `json:"decay_days"`
	// Contradictions that send a confirmed habit back for review.
	ContradictionLimit int `json:"contradiction_limit"`
	// Local model used for pattern analysis (via Ollama). Empty disables the model.
	OllamaURL   string `json:"ollama_url"`
	OllamaModel string `json:"ollama_model"`
	UseModel    bool   `json:"use_model"`
	// Export targets refreshed after every change: claude-code, claude-ai, cursor, copilot, codex.
	Targets []string `json:"targets"`
	// Maximum words per generated skill file.
	SkillWordBudget int `json:"skill_word_budget"`
	// Pipe stored text through `kavach scan --redact` when Kavach is installed.
	UseKavach bool `json:"use_kavach"`
}

// DefaultConfig returns the documented defaults.
func DefaultConfig() Config {
	return Config{
		ExplicitThreshold:   1,
		CorrectionThreshold: 2,
		PatternThreshold:    3,
		PatternMinSessions:  2,
		DecayDays:           60,
		ContradictionLimit:  2,
		OllamaURL:           "http://127.0.0.1:11434",
		OllamaModel:         "qwen2.5:1.5b",
		UseModel:            true,
		Targets:             []string{"claude-code", "claude-ai"},
		SkillWordBudget:     120,
		UseKavach:           true,
	}
}

func configFile() string { return paths.Join("config.json") }

// LoadConfig reads the config, filling missing fields with defaults.
func LoadConfig() (Config, error) {
	cfg := DefaultConfig()
	b, err := os.ReadFile(configFile())
	if errors.Is(err, os.ErrNotExist) {
		return cfg, nil
	}
	if err != nil {
		return cfg, err
	}
	if err := json.Unmarshal(b, &cfg); err != nil {
		return DefaultConfig(), err
	}
	return cfg, nil
}

// SaveConfig writes the config file (used by `sakha install` to create the defaults).
func SaveConfig(cfg Config) error {
	if err := paths.Ensure(); err != nil {
		return err
	}
	return writeAtomic(configFile(), cfg)
}
