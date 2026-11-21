package audit

import (
	"bufio"
	"context"
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"github.com/kavach-sec/kavach/internal/config"
	"github.com/kavach-sec/kavach/internal/detect"
	"github.com/kavach-sec/kavach/internal/redact"
	"github.com/kavach-sec/kavach/internal/types"
)

// Finding describes one local session/token-theft hygiene issue with copy-paste remediation.
type Finding struct {
	ID          string     `json:"id"`
	Category    string     `json:"category"`
	Severity    types.Tier `json:"severity"`
	Title       string     `json:"title"`
	Location    string     `json:"location"`
	Preview     string     `json:"preview,omitempty"`
	FixCommand  string     `json:"fix_command"`
	Description string     `json:"description"`
}

// Report summarizes a local kavach audit run.
type Report struct {
	Score      int       `json:"score"`
	Tampered   bool      `json:"tampered"`
	Findings   []Finding `json:"findings"`
	CheckedAt  time.Time `json:"checked_at"`
}

// RunQuick runs a fast subset of checks suitable for SessionStart hooks (<25ms).
func RunQuick(kavachDir, cwd string, pol config.Policy) Report {
	rep := Report{Score: 100, CheckedAt: time.Now().UTC()}
	checkHookIntegrity(kavachDir, &rep)
	checkEnvVars(&rep, redact.EphemeralSalt())
	checkDotEnvFiles(cwd, 1, &rep)
	checkMCPConfigs(cwd, pol, &rep)
	finalizeScore(&rep)
	return rep
}

// RunFull executes all Phase 1 session/token-theft hygiene checks.
func RunFull(kavachDir, cwd string, pol config.Policy) Report {
	rep := Report{Score: 100, CheckedAt: time.Now().UTC()}
	salt, err := redact.LoadOrCreateSalt(kavachDir)
	if err != nil {
		salt = redact.EphemeralSalt()
	}

	checkHookIntegrity(kavachDir, &rep)
	checkCredentialFilePerms(&rep)
	checkEnvVars(&rep, salt)
	checkShellHistory(&rep, salt)
	checkDotEnvFiles(cwd, 3, &rep)
	checkGitHistory(cwd, &rep, salt)
	checkMCPConfigs(cwd, pol, &rep)
	checkLongLivedKeys(&rep)

	finalizeScore(&rep)
	return rep
}

func finalizeScore(rep *Report) {
	deduction := 0
	for _, f := range rep.Findings {
		switch f.Severity {
		case types.TierHigh:
			deduction += 15
		case types.TierMedium:
			deduction += 8
		case types.TierLow:
			deduction += 3
		}
	}
	score := 100 - deduction
	if score < 0 {
		score = 0
	}
	rep.Score = score
	sort.SliceStable(rep.Findings, func(i, j int) bool {
		return tierWeight(rep.Findings[i].Severity) > tierWeight(rep.Findings[j].Severity)
	})
}

func tierWeight(t types.Tier) int {
	switch t {
	case types.TierHigh:
		return 3
	case types.TierMedium:
		return 2
	default:
		return 1
	}
}

func checkHookIntegrity(kavachDir string, rep *Report) {
	if kavachDir == "" {
		return
	}
	manifestPath := filepath.Join(kavachDir, "install_manifest.json")
	data, err := os.ReadFile(manifestPath)
	if err != nil {
		if os.IsNotExist(err) {
			rep.Findings = append(rep.Findings, Finding{
				ID:          "audit-hooks-not-installed",
				Category:    "hook_integrity",
				Severity:    types.TierMedium,
				Title:       "Kavach Claude Code hooks not installed",
				Location:    manifestPath,
				FixCommand:  "kavach install --claude-code --user",
				Description: "No Kavach hook installation manifest was found.",
			})
		}
		return
	}
	var manifest struct {
		Installs map[string]struct {
			SettingsPath   string `json:"settings_path"`
			SettingsSHA256 string `json:"settings_sha256"`
		} `json:"installs"`
	}
	if err := json.Unmarshal(data, &manifest); err != nil || len(manifest.Installs) == 0 {
		rep.Findings = append(rep.Findings, Finding{
			ID:          "audit-hooks-missing",
			Category:    "hook_integrity",
			Severity:    types.TierMedium,
			Title:       "Kavach hook manifest has no active entries",
			Location:    manifestPath,
			FixCommand:  "kavach install --claude-code --user",
			Description: "Install Kavach hooks so prompts and tool calls are protected.",
		})
		return
	}
	for path, entry := range manifest.Installs {
		raw, readErr := os.ReadFile(path)
		if readErr != nil {
			rep.Tampered = true
			rep.Findings = append(rep.Findings, Finding{
				ID:          "audit-hooks-deleted",
				Category:    "hook_integrity",
				Severity:    types.TierHigh,
				Title:       "Claude Code settings file missing after Kavach install",
				Location:    path,
				FixCommand:  "kavach install --claude-code --user",
				Description: "Hook configuration file was removed or moved.",
			})
			continue
		}
		if sha256FileBytes(raw) != entry.SettingsSHA256 {
			rep.Tampered = true
			rep.Findings = append(rep.Findings, Finding{
				ID:          "audit-hooks-tampered",
				Category:    "hook_integrity",
				Severity:    types.TierHigh,
				Title:       "Claude Code settings.json modified outside Kavach",
				Location:    path,
				FixCommand:  "kavach install --claude-code --user",
				Description: "SHA-256 hash of settings.json differs from Kavach install manifest.",
			})
		}
	}
}

func checkCredentialFilePerms(rep *Report) {
	home, err := os.UserHomeDir()
	if err != nil || home == "" {
		return
	}
	candidates := []string{
		filepath.Join(home, ".aws", "credentials"),
		filepath.Join(home, ".netrc"),
		filepath.Join(home, ".kube", "config"),
		filepath.Join(home, ".docker", "config.json"),
		filepath.Join(home, ".npmrc"),
		filepath.Join(home, ".pypirc"),
		filepath.Join(home, ".ssh", "id_rsa"),
		filepath.Join(home, ".ssh", "id_ed25519"),
		filepath.Join(home, ".ssh", "id_ecdsa"),
	}
	for _, p := range candidates {
		info, err := os.Stat(p)
		if err != nil || info.IsDir() {
			continue
		}
		perm := info.Mode().Perm()
		if perm&0o077 != 0 {
			rep.Findings = append(rep.Findings, Finding{
				ID:          "audit-loose-cred-perms",
				Category:    "file_permissions",
				Severity:    types.TierHigh,
				Title:       fmt.Sprintf("Credential file has overly broad permissions (%04o)", perm),
				Location:    p,
				FixCommand:  fmt.Sprintf("chmod 600 %q", p),
				Description: "Group or other users can read/modify this credential file.",
			})
		}
	}
}

func checkEnvVars(rep *Report, salt string) {
	sc, err := detect.NewSecretScanner("")
	if err != nil {
		return
	}
	for _, kv := range os.Environ() {
		parts := strings.SplitN(kv, "=", 2)
		if len(parts) != 2 {
			continue
		}
		name, val := parts[0], parts[1]
		if len(val) < 12 {
			continue
		}
		line := name + "=" + val
		findings := sc.Scan(line, "env:"+name, salt)
		if len(findings) > 0 {
			f := findings[0]
			rep.Findings = append(rep.Findings, Finding{
				ID:          "audit-env-secret",
				Category:    "env_vars",
				Severity:    types.TierMedium,
				Title:       fmt.Sprintf("Live secret in environment variable %s (%s)", name, f.Preview),
				Location:    "env:" + name,
				Preview:     f.Preview,
				FixCommand:  fmt.Sprintf("unset %s", name),
				Description: "Child processes and agent Bash calls inherit exported environment variables.",
			})
		}
	}
}

func checkShellHistory(rep *Report, salt string) {
	home, err := os.UserHomeDir()
	if err != nil || home == "" {
		return
	}
	sc, err := detect.NewSecretScanner("")
	if err != nil {
		return
	}
	histFiles := []string{
		filepath.Join(home, ".zsh_history"),
		filepath.Join(home, ".bash_history"),
		filepath.Join(home, ".local", "share", "fish", "fish_history"),
	}
	for _, hf := range histFiles {
		f, err := os.Open(hf)
		if err != nil {
			continue
		}
		scanner := bufio.NewScanner(f)
		scanner.Buffer(make([]byte, 0, 64*1024), 512*1024)
		lineNo := 0
		hits := 0
		for scanner.Scan() {
			lineNo++
			if hits >= 5 {
				break
			}
			line := scanner.Text()
			if found := sc.Scan(line, hf, salt); len(found) > 0 {
				hits++
				rep.Findings = append(rep.Findings, Finding{
					ID:          "audit-shell-history-secret",
					Category:    "shell_history",
					Severity:    types.TierHigh,
					Title:       fmt.Sprintf("Secret in shell history (%s)", found[0].Preview),
					Location:    fmt.Sprintf("%s:line %d", hf, lineNo),
					Preview:     found[0].Preview,
					FixCommand:  fmt.Sprintf("sed -i.bak '/%s/d' %q && rm -f %q", escapeSed(found[0].Preview), hf, hf+".bak"),
					Description: "Secrets typed on the command line persist in plaintext shell history.",
				})
			}
		}
		_ = f.Close()
	}
}

func checkDotEnvFiles(cwd string, maxDepth int, rep *Report) {
	if cwd == "" {
		return
	}
	baseDepth := strings.Count(filepath.Clean(cwd), string(filepath.Separator))
	_ = filepath.WalkDir(cwd, func(path string, d os.DirEntry, err error) error {
		if err != nil {
			return nil
		}
		if d.IsDir() {
			name := d.Name()
			if name == ".git" || name == "node_modules" || name == "vendor" || name == "dist" {
				return filepath.SkipDir
			}
			curDepth := strings.Count(filepath.Clean(path), string(filepath.Separator)) - baseDepth
			if curDepth > maxDepth {
				return filepath.SkipDir
			}
			return nil
		}
		name := d.Name()
		if (name == ".env" || strings.HasPrefix(name, ".env.")) && !strings.HasSuffix(name, ".example") && !strings.HasSuffix(name, ".template") {
			info, statErr := d.Info()
			if statErr == nil && info.Mode().Perm()&0o077 != 0 {
				rep.Findings = append(rep.Findings, Finding{
					ID:          "audit-dotenv-perms",
					Category:    "dotenv",
					Severity:    types.TierMedium,
					Title:       fmt.Sprintf(".env file has permissive mode (%04o)", info.Mode().Perm()),
					Location:    path,
					FixCommand:  fmt.Sprintf("chmod 600 %q", path),
					Description: "Restrict .env file permissions to owner read/write only.",
				})
			}
		}
		return nil
	})
}

func checkGitHistory(cwd string, rep *Report, salt string) {
	if cwd == "" {
		return
	}
	if _, err := os.Stat(filepath.Join(cwd, ".git")); err != nil {
		return
	}
	sc, err := detect.NewSecretScanner("")
	if err != nil {
		return
	}
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	cmd := exec.CommandContext(ctx, "git", "-C", cwd, "log", "-n", "15", "-p", "--no-color")
	out, err := cmd.Output()
	if err != nil || len(out) == 0 {
		return
	}
	if len(out) > 512*1024 {
		out = out[:512*1024]
	}
	findings := sc.Scan(string(out), "git-history", salt)
	seen := make(map[string]struct{})
	for _, f := range findings {
		if _, ok := seen[f.Fingerprint]; ok {
			continue
		}
		seen[f.Fingerprint] = struct{}{}
		rep.Findings = append(rep.Findings, Finding{
			ID:          "audit-git-history-secret",
			Category:    "git_history",
			Severity:    types.TierHigh,
			Title:       fmt.Sprintf("Secret found in recent git history (%s)", f.Preview),
			Location:    f.Location,
			Preview:     f.Preview,
			FixCommand:  "Rotate the exposed credential immediately and purge from history with `git filter-repo`",
			Description: "Secrets committed to git remain reachable in commit history even after deletion.",
		})
	}
}

func checkMCPConfigs(cwd string, pol config.Policy, rep *Report) {
	allow := make(map[string]struct{}, len(pol.Allowlist.MCPServers))
	for _, s := range pol.Allowlist.MCPServers {
		allow[strings.ToLower(strings.TrimSpace(s))] = struct{}{}
	}
	home, _ := os.UserHomeDir()
	var paths []string
	if home != "" {
		paths = append(paths,
			filepath.Join(home, ".claude.json"),
			filepath.Join(home, ".claude", "settings.json"),
		)
	}
	if cwd != "" {
		paths = append(paths,
			filepath.Join(cwd, ".mcp.json"),
			filepath.Join(cwd, ".claude", "settings.json"),
		)
	}
	seen := make(map[string]struct{})
	for _, p := range paths {
		raw, err := os.ReadFile(p)
		if err != nil {
			continue
		}
		var doc map[string]any
		if err := json.Unmarshal(raw, &doc); err != nil {
			continue
		}
		servers, _ := doc["mcpServers"].(map[string]any)
		for name := range servers {
			lower := strings.ToLower(name)
			if _, ok := allow[lower]; ok {
				continue
			}
			if _, ok := seen[p+":"+lower]; ok {
				continue
			}
			seen[p+":"+lower] = struct{}{}
			rep.Findings = append(rep.Findings, Finding{
				ID:          "audit-unreviewed-mcp",
				Category:    "mcp_servers",
				Severity:    types.TierMedium,
				Title:       fmt.Sprintf("Unreviewed MCP server %q configured", name),
				Location:    p,
				Preview:     name,
				FixCommand:  fmt.Sprintf("# Review %s and add %q under allowlist.mcp_servers in ~/.kavach/policy.yaml", p, name),
				Description: "Unreviewed MCP servers can read files or inject untrusted tool responses into sessions.",
			})
		}
	}
}

func checkLongLivedKeys(rep *Report) {
	home, err := os.UserHomeDir()
	if err != nil || home == "" {
		return
	}
	cutoff := time.Now().Add(-90 * 24 * time.Hour)
	paths := []string{
		filepath.Join(home, ".aws", "credentials"),
		filepath.Join(home, ".ssh", "id_rsa"),
		filepath.Join(home, ".ssh", "id_ed25519"),
		filepath.Join(home, ".npmrc"),
	}
	for _, p := range paths {
		info, err := os.Stat(p)
		if err != nil || info.IsDir() {
			continue
		}
		if info.ModTime().Before(cutoff) {
			ageDays := int(time.Since(info.ModTime()).Hours() / 24)
			rep.Findings = append(rep.Findings, Finding{
				ID:          "audit-long-lived-key",
				Category:    "key_rotation",
				Severity:    types.TierLow,
				Title:       fmt.Sprintf("Credential file unchanged for %d days (>90d rotation window)", ageDays),
				Location:    p,
				FixCommand:  fmt.Sprintf("# Rotate credential at provider and update %s", p),
				Description: "Long-lived static credentials increase blast radius if leaked.",
			})
		}
	}
}

func sha256FileBytes(b []byte) string {
	sum := sha256.Sum256(b)
	return fmt.Sprintf("%x", sum[:])
}

func escapeSed(s string) string {
	return strings.ReplaceAll(s, "/", `\/`)
}
