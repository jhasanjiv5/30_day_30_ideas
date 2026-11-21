package claude

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// Scope identifies user (~/.claude/settings.json) or project (.claude/settings.json) hook installation.
type Scope string

const (
	ScopeUser    Scope = "user"
	ScopeProject Scope = "project"
)

// InstallManifest tracks installed hook settings hashes for tamper detection and clean uninstall.
type InstallManifest struct {
	Installs map[string]InstalledEntry `json:"installs"`
}

// InstalledEntry records one installed Claude Code settings file and its original backup.
type InstalledEntry struct {
	Scope          Scope     `json:"scope"`
	SettingsPath   string    `json:"settings_path"`
	BackupPath     string    `json:"backup_path"`
	ExistedBefore  bool      `json:"existed_before"`
	OrigMode       uint32    `json:"orig_mode"`
	SettingsSHA256 string    `json:"settings_sha256"`
	BinaryPath     string    `json:"binary_path"`
	InstalledAt    time.Time `json:"installed_at"`
}

// SettingsPath resolves the target Claude Code settings.json path for the given scope.
func SettingsPath(scope Scope, projectDir string) (string, error) {
	if scope == ScopeProject {
		if projectDir == "" {
			var err error
			projectDir, err = os.Getwd()
			if err != nil {
				return "", err
			}
		}
		return filepath.Join(projectDir, ".claude", "settings.json"), nil
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(home, ".claude", "settings.json"), nil
}

// Install backs up Claude Code's settings.json byte-for-byte, merges Kavach's 4 hooks
// cleanly into the official Claude Code hooks schema, and records a tamper-detection manifest.
func Install(scope Scope, projectDir, kavachDir, binaryPath string) (InstalledEntry, error) {
	settingsPath, err := SettingsPath(scope, projectDir)
	if err != nil {
		return InstalledEntry{}, err
	}
	if binaryPath == "" {
		binaryPath = "kavach"
	}

	manifest, _ := LoadManifest(kavachDir)
	if manifest.Installs == nil {
		manifest.Installs = make(map[string]InstalledEntry)
	}

	backupsDir := filepath.Join(kavachDir, "backups")
	if err := os.MkdirAll(backupsDir, 0o700); err != nil {
		return InstalledEntry{}, fmt.Errorf("create backups dir: %w", err)
	}

	key := sha256Hex([]byte(settingsPath))[:16]
	backupPath := filepath.Join(backupsDir, key+".settings.json.bak")

	// Preserve original pre-Kavach backup if already installed once, or snapshot current bytes now.
	var existedBefore bool
	var origMode uint32 = 0o600
	if prev, ok := manifest.Installs[settingsPath]; ok {
		existedBefore = prev.ExistedBefore
		origMode = prev.OrigMode
		backupPath = prev.BackupPath
	} else {
		if info, statErr := os.Stat(settingsPath); statErr == nil {
			existedBefore = true
			origMode = uint32(info.Mode().Perm())
			rawOrig, readErr := os.ReadFile(settingsPath)
			if readErr != nil {
				return InstalledEntry{}, fmt.Errorf("read existing settings: %w", readErr)
			}
			if writeErr := os.WriteFile(backupPath, rawOrig, 0o600); writeErr != nil {
				return InstalledEntry{}, fmt.Errorf("write backup: %w", writeErr)
			}
		}
	}

	root := make(map[string]any)
	if raw, readErr := os.ReadFile(settingsPath); readErr == nil && len(strings.TrimSpace(string(raw))) > 0 {
		if unmarshalErr := json.Unmarshal(raw, &root); unmarshalErr != nil {
			return InstalledEntry{}, fmt.Errorf("parse %s: %w", settingsPath, unmarshalErr)
		}
	}

	hooksMap, _ := root["hooks"].(map[string]any)
	if hooksMap == nil {
		hooksMap = make(map[string]any)
	}

	cmdPrefix := shellQuote(binaryPath) + " hook "
	desired := map[string]struct {
		matcher string
		timeout int
	}{
		"SessionStart":     {matcher: "", timeout: 10},
		"UserPromptSubmit": {matcher: "", timeout: 15},
		"PreToolUse":       {matcher: "*", timeout: 15},
		"PostToolUse":      {matcher: "*", timeout: 15},
	}

	for eventName, spec := range desired {
		existingGroups := asSlice(hooksMap[eventName])
		cleaned := removeKavachGroups(existingGroups)
		group := map[string]any{
			"hooks": []any{
				map[string]any{
					"type":    "command",
					"command": cmdPrefix + eventName,
					"timeout": spec.timeout,
				},
			},
		}
		if spec.matcher != "" {
			group["matcher"] = spec.matcher
		}
		cleaned = append(cleaned, group)
		hooksMap[eventName] = cleaned
	}
	root["hooks"] = hooksMap

	if err := os.MkdirAll(filepath.Dir(settingsPath), 0o755); err != nil {
		return InstalledEntry{}, fmt.Errorf("create settings dir: %w", err)
	}
	outBytes, err := json.MarshalIndent(root, "", "  ")
	if err != nil {
		return InstalledEntry{}, err
	}
	outBytes = append(outBytes, '\n')
	if err := os.WriteFile(settingsPath, outBytes, os.FileMode(origMode)); err != nil {
		return InstalledEntry{}, fmt.Errorf("write settings: %w", err)
	}

	entry := InstalledEntry{
		Scope:          scope,
		SettingsPath:   settingsPath,
		BackupPath:     backupPath,
		ExistedBefore:  existedBefore,
		OrigMode:       origMode,
		SettingsSHA256: sha256Hex(outBytes),
		BinaryPath:     binaryPath,
		InstalledAt:    time.Now().UTC(),
	}
	manifest.Installs[settingsPath] = entry
	if err := SaveManifest(kavachDir, manifest); err != nil {
		return InstalledEntry{}, err
	}
	return entry, nil
}

// UninstallResult describes what Uninstall changed and how user settings were preserved.
type UninstallResult struct {
	Scope         Scope  `json:"scope"`
	SettingsPath  string `json:"settings_path"`
	Strategy      string `json:"strategy"` // "restored_backup" | "removed_created_file" | "surgical_merge"
	BackupPath    string `json:"backup_path,omitempty"`
	HooksRemoved  int    `json:"hooks_removed"`
	PreservedApps bool   `json:"preserved_apps"`
}

// UninstallOptions configures safe reversal of Kavach Claude Code hooks.
type UninstallOptions struct {
	RestoreBackup bool // Force byte-for-byte backup restore even if settings.json changed after install
}

// Uninstall restores the original settings.json backup if untouched, or surgically strips only
// Kavach hooks when the user installed other modes, MCP servers, or hooks after Kavach.
func Uninstall(scope Scope, projectDir, kavachDir string) (string, error) {
	res, err := UninstallWithOptions(scope, projectDir, kavachDir, UninstallOptions{})
	if err != nil {
		return "", err
	}
	return res.SettingsPath, nil
}

// UninstallWithOptions safely undoes Kavach hook installation for the given scope.
func UninstallWithOptions(scope Scope, projectDir, kavachDir string, opts UninstallOptions) (UninstallResult, error) {
	settingsPath, err := SettingsPath(scope, projectDir)
	if err != nil {
		return UninstallResult{}, err
	}
	manifest, err := LoadManifest(kavachDir)
	if err != nil {
		return UninstallResult{}, err
	}
	entry, ok := manifest.Installs[settingsPath]
	if !ok {
		return UninstallResult{}, fmt.Errorf("no Kavach installation recorded for %s", settingsPath)
	}
	res, err := uninstallEntry(settingsPath, entry, opts)
	if err != nil {
		return UninstallResult{}, err
	}
	delete(manifest.Installs, settingsPath)
	if err := SaveManifest(kavachDir, manifest); err != nil {
		return UninstallResult{}, err
	}
	return res, nil
}

// UninstallAll safely undoes every Claude Code hook installation recorded in install_manifest.json.
func UninstallAll(kavachDir string, opts UninstallOptions) ([]UninstallResult, error) {
	manifest, err := LoadManifest(kavachDir)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, nil
		}
		return nil, err
	}
	var results []UninstallResult
	for settingsPath, entry := range manifest.Installs {
		res, uErr := uninstallEntry(settingsPath, entry, opts)
		if uErr != nil {
			return results, uErr
		}
		results = append(results, res)
		delete(manifest.Installs, settingsPath)
	}
	if err := SaveManifest(kavachDir, manifest); err != nil {
		return results, err
	}
	return results, nil
}

func uninstallEntry(settingsPath string, entry InstalledEntry, opts UninstallOptions) (UninstallResult, error) {
	res := UninstallResult{
		Scope:        entry.Scope,
		SettingsPath: settingsPath,
	}

	currentBytes, readCurrErr := os.ReadFile(settingsPath)
	unchangedSinceInstall := readCurrErr == nil && sha256Hex(currentBytes) == entry.SettingsSHA256

	// Surgical path: if the user added modes, MCP servers, plugins, permissions, or other hooks
	// after Kavach was installed (and did not pass --restore-backup), remove ONLY Kavach hooks
	// so those post-install apps/modes are never wiped out.
	if !opts.RestoreBackup && !unchangedSinceInstall && readCurrErr == nil {
		var root map[string]any
		if json.Unmarshal(currentBytes, &root) == nil && root != nil {
			removedCount := stripKavachFromRoot(root)
			hasOtherUserData := len(root) > 0
			if removedCount > 0 || hasOtherUserData {
				if !entry.ExistedBefore && len(root) == 0 {
					_ = os.Remove(settingsPath)
					res.Strategy = "removed_created_file"
				} else {
					outBytes, mErr := json.MarshalIndent(root, "", "  ")
					if mErr != nil {
						return UninstallResult{}, fmt.Errorf("marshal updated settings: %w", mErr)
					}
					outBytes = append(outBytes, '\n')
					mode := os.FileMode(entry.OrigMode)
					if mode == 0 {
						mode = 0o600
					}
					if wErr := os.WriteFile(settingsPath, outBytes, mode); wErr != nil {
						return UninstallResult{}, fmt.Errorf("write updated settings: %w", wErr)
					}
					res.Strategy = "surgical_merge"
					res.PreservedApps = true
					if entry.ExistedBefore && entry.BackupPath != "" {
						res.BackupPath = entry.BackupPath
					}
				}
				res.HooksRemoved = removedCount
				return res, nil
			}
		}
	}

	// Byte-for-byte backup restore path (untouched settings since install, missing/empty file, or --restore-backup).
	if entry.ExistedBefore {
		rawBackup, err := os.ReadFile(entry.BackupPath)
		if err != nil {
			return UninstallResult{}, fmt.Errorf("read backup %s: %w", entry.BackupPath, err)
		}
		mode := os.FileMode(entry.OrigMode)
		if mode == 0 {
			mode = 0o600
		}
		if err := os.WriteFile(settingsPath, rawBackup, mode); err != nil {
			return UninstallResult{}, fmt.Errorf("restore backup: %w", err)
		}
		_ = os.Remove(entry.BackupPath)
		res.Strategy = "restored_backup"
	} else {
		_ = os.Remove(settingsPath)
		res.Strategy = "removed_created_file"
	}
	return res, nil
}

// VerifyIntegrity checks all installed Claude Code settings files against recorded SHA-256 hashes.
func VerifyIntegrity(kavachDir string) (installed bool, tampered []string, err error) {
	manifest, loadErr := LoadManifest(kavachDir)
	if loadErr != nil {
		if os.IsNotExist(loadErr) {
			return false, nil, nil
		}
		return false, nil, loadErr
	}
	if len(manifest.Installs) == 0 {
		return false, nil, nil
	}
	installed = true
	for path, entry := range manifest.Installs {
		raw, readErr := os.ReadFile(path)
		if readErr != nil {
			tampered = append(tampered, fmt.Sprintf("%s (missing: %v)", path, readErr))
			continue
		}
		if sha256Hex(raw) != entry.SettingsSHA256 {
			tampered = append(tampered, fmt.Sprintf("%s (hash mismatch)", path))
		}
	}
	return installed, tampered, nil
}

// LoadManifest reads ~/.kavach/install_manifest.json.
func LoadManifest(kavachDir string) (InstallManifest, error) {
	p := filepath.Join(kavachDir, "install_manifest.json")
	data, err := os.ReadFile(p)
	if err != nil {
		return InstallManifest{}, err
	}
	var m InstallManifest
	if err := json.Unmarshal(data, &m); err != nil {
		return InstallManifest{}, err
	}
	return m, nil
}

// SaveManifest persists ~/.kavach/install_manifest.json with 0600 permissions.
func SaveManifest(kavachDir string, m InstallManifest) error {
	if err := os.MkdirAll(kavachDir, 0o700); err != nil {
		return err
	}
	data, err := json.MarshalIndent(m, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(filepath.Join(kavachDir, "install_manifest.json"), data, 0o600)
}

func asSlice(v any) []any {
	s, ok := v.([]any)
	if !ok {
		return nil
	}
	return s
}

func stripKavachFromRoot(root map[string]any) int {
	hooksMap, ok := root["hooks"].(map[string]any)
	if !ok || hooksMap == nil {
		return 0
	}
	removed := 0
	for eventName, rawGroups := range hooksMap {
		groups := asSlice(rawGroups)
		if len(groups) == 0 {
			continue
		}
		cleaned, n := removeKavachGroupsCount(groups)
		removed += n
		if len(cleaned) == 0 {
			delete(hooksMap, eventName)
		} else {
			hooksMap[eventName] = cleaned
		}
	}
	if len(hooksMap) == 0 {
		delete(root, "hooks")
	} else {
		root["hooks"] = hooksMap
	}
	return removed
}

func removeKavachGroups(groups []any) []any {
	cleaned, _ := removeKavachGroupsCount(groups)
	return cleaned
}

func removeKavachGroupsCount(groups []any) ([]any, int) {
	out := make([]any, 0, len(groups))
	removed := 0
	for _, g := range groups {
		gm, ok := g.(map[string]any)
		if !ok {
			out = append(out, g)
			continue
		}
		inner := asSlice(gm["hooks"])
		keptInner := make([]any, 0, len(inner))
		groupRemoved := 0
		for _, h := range inner {
			hm, ok := h.(map[string]any)
			if !ok {
				keptInner = append(keptInner, h)
				continue
			}
			cmd, _ := hm["command"].(string)
			if isKavachHookCommand(cmd) {
				groupRemoved++
				continue
			}
			keptInner = append(keptInner, h)
		}
		removed += groupRemoved
		if len(keptInner) == 0 && groupRemoved > 0 {
			continue
		}
		if groupRemoved > 0 {
			gmCopy := make(map[string]any, len(gm))
			for k, v := range gm {
				gmCopy[k] = v
			}
			gmCopy["hooks"] = keptInner
			out = append(out, gmCopy)
			continue
		}
		out = append(out, g)
	}
	return out, removed
}

func isKavachHookCommand(cmd string) bool {
	return strings.Contains(cmd, "kavach hook ") || strings.Contains(cmd, "kavach' hook ") || strings.Contains(cmd, "kavach\" hook ")
}

func sha256Hex(b []byte) string {
	sum := sha256.Sum256(b)
	return hex.EncodeToString(sum[:])
}

func shellQuote(s string) string {
	if !strings.ContainsAny(s, " \t'\"\\") {
		return s
	}
	return "'" + strings.ReplaceAll(s, "'", "'\\''") + "'"
}
