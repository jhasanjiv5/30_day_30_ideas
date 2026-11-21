package detect

import (
	"fmt"
	"net/url"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/kavach-sec/kavach/internal/config"
	"github.com/kavach-sec/kavach/internal/redact"
	"github.com/kavach-sec/kavach/internal/types"
)

type cmdRule struct {
	id          string
	title       string
	category    types.Category
	re          *regexp.Regexp
	tier        types.Tier
	explanation string
	remediation string
}

var riskyCommandRules = []cmdRule{
	{
		id:          "cmd-destructive-rm",
		title:       "Destructive Recursive Delete",
		category:    types.CategoryRiskyCommand,
		re:          regexp.MustCompile(`(?i)\brm\s+(?:-[a-z]*r[a-z]*f|-[a-z]*f[a-z]*r|-rf|-fr|--recursive\s+--force|--force\s+--recursive)(?:\s+--no-preserve-root)?\s+(?:/(?:\*|\s|$)|~/?(?:\s|$|\*)|\$HOME/?(?:\s|$|\*)|/etc|/usr|/var|/System|/Users/?(?:\s|$))`),
		tier:        types.TierHigh,
		explanation: "Command performs a destructive recursive force-delete on root, home, or critical system directories.",
		remediation: "Scope deletion explicitly to a specific subdirectory or confirm manually outside the agent.",
	},
	{
		id:          "cmd-disk-wipe",
		title:       "Raw Disk / Filesystem Overwrite",
		category:    types.CategoryRiskyCommand,
		re:          regexp.MustCompile(`(?i)(?:\bmkfs(?:\.[a-z0-9]+)?\b|\bdd\b[^\n]*\bof=/dev/(?:sd|hd|nvme|disk|xvd)|:\(\)\s*\{\s*:\|\:&\s*\}\s*;\s*:)`),
		tier:        types.TierHigh,
		explanation: "Command formats a block device, writes directly to a raw disk device, or runs a fork bomb.",
		remediation: "Never run raw disk formatting or device writes from an automated agent session.",
	},
	{
		id:          "cmd-pipe-to-shell",
		title:       "Remote Script Pipe-to-Shell Execution",
		category:    types.CategoryRiskyCommand,
		re:          regexp.MustCompile(`(?i)(?:\b(?:curl|wget|fetch|http)\b[^\n|;]*\|\s*(?:sudo\s+)?(?:ba|z|da|k|fi)?sh\b|\b(?:ba|z)?sh\s+<\(\s*(?:curl|wget)\b|\beval\s+["']?\$\(\s*(?:curl|wget)\b|\bpython[23]?\s+-c\s+["'][^"']*(?:urllib|requests)[^"']*\b)`),
		tier:        types.TierHigh,
		explanation: "Command downloads remote code and executes it immediately without checksum verification.",
		remediation: "Download the script to a file, inspect its contents and SHA-256 checksum, then execute it.",
	},
	{
		id:          "cmd-chmod-777",
		title:       "World-Writable / SUID Permission Change",
		category:    types.CategoryRiskyCommand,
		re:          regexp.MustCompile(`(?i)\bchmod\s+(?:-[a-zA-Z]+\s+)*(?:0?777|a\+rwx|[ugoa]*\+s)\b`),
		tier:        types.TierHigh,
		explanation: "Command sets world-writable (777) or setuid (+s) permissions, creating privilege-escalation or tampering risk.",
		remediation: "Use least-privilege permissions such as 0600 for secrets/configs or 0755 for executables.",
	},
	{
		id:          "cmd-base64-exec",
		title:       "Obfuscated Base64 Execution",
		category:    types.CategoryRiskyCommand,
		re:          regexp.MustCompile(`(?i)\bbase64\s+(?:-d|-D|--decode)\b[^\n|]*\|\s*(?:sudo\s+)?(?:ba|z)?sh|python[23]?|perl|ruby|node\b`),
		tier:        types.TierHigh,
		explanation: "Command decodes an obfuscated base64 payload and pipes it directly to an interpreter.",
		remediation: "Decode and inspect the payload first instead of executing obfuscated commands.",
	},
	{
		id:          "cmd-reverse-shell",
		title:       "Interactive Reverse Shell Pattern",
		category:    types.CategoryRiskyCommand,
		re:          regexp.MustCompile(`(?i)(?:/dev/(?:tcp|udp)/[0-9a-zA-Z.\-]+/\d+|\bnc\b[^\n]*\s-e\s|\bncat\b[^\n]*\s(?:-e|--exec)\s|\bsocat\b[^\n]*EXEC:)`),
		tier:        types.TierHigh,
		explanation: "Command opens a network socket connected to a shell or command interpreter.",
		remediation: "Block immediately; reverse shells are a primary indicator of remote compromise.",
	},
	{
		id:          "cmd-credential-read",
		title:       "Sensitive Credential / Keychain Access",
		category:    types.CategoryCredentialAccess,
		re:          regexp.MustCompile(`(?i)(?:~|\$HOME|/Users/[^/\s]+|/home/[^/\s]+)?/?(?:\.ssh/id_(?:rsa|ed25519|ecdsa|dsa)|\.aws/credentials|\.netrc|\.kube/config|\.docker/config\.json|\.gnupg/secring|\.npmrc|\.pypirc)|/etc/shadow|\bsecurity\s+find-(?:generic|internet)-password\b`),
		tier:        types.TierHigh,
		explanation: "Command reads sensitive local credential stores, SSH private keys, cloud credentials, or macOS Keychain.",
		remediation: "Avoid exposing local credential files to agent tool execution; pass scoped environment tokens instead.",
	},
	{
		id:          "cmd-env-dump-exfil",
		title:       "Environment / Secret Exfiltration Pipe",
		category:    types.CategoryExfiltration,
		re:          regexp.MustCompile(`(?i)\b(?:env|printenv|set)\b[^\n|]*\|\s*(?:curl|wget|nc|ncat|socat|python|ruby)\b`),
		tier:        types.TierHigh,
		explanation: "Command pipes process environment variables (which often contain API keys) to a network tool.",
		remediation: "Never pipe full environment variables over the network.",
	},
}

var (
	curlExfilRe = regexp.MustCompile(`(?i)\b(?:curl|wget)\b[^\n]*(?:-d\b|--data(?:-[a-z]+)?\b|-F\b|--form\b|-T\b|--upload-file\b|--post-data\b|--post-file\b)[^\n]*?(https?://[^\s"']+)`)
	urlInCmdRe  = regexp.MustCompile(`https?://[^\s"']+`)
	scpRsyncRe  = regexp.MustCompile(`(?i)\b(?:scp|rsync)\b[^\n]*(?:\.ssh|\.aws|\.env|credentials|secret|id_rsa|id_ed25519)[^\n]*@([a-zA-Z0-9.\-]+)`)
)

var sensitiveFilePatterns = []string{
	".ssh/id_rsa",
	".ssh/id_ed25519",
	".ssh/id_ecdsa",
	".ssh/id_dsa",
	".aws/credentials",
	".netrc",
	".kube/config",
	".docker/config.json",
	".pypirc",
	"/etc/shadow",
}

// CommandScanner checks PreToolUse actions (shell commands, file reads, WebFetch, MCP provenance).
type CommandScanner struct{}

// NewCommandScanner constructs an L1 risky action & command detector.
func NewCommandScanner() *CommandScanner {
	return &CommandScanner{}
}

// ScanToolCall evaluates a PreToolUse input against command, credential-access, exfiltration, and MCP rules.
func (c *CommandScanner) ScanToolCall(in types.EvalInput, pol config.Policy, salt string) []types.Finding {
	var findings []types.Finding
	seen := make(map[string]struct{})
	add := func(f types.Finding) {
		key := f.RuleID + ":" + f.Fingerprint
		if _, ok := seen[key]; ok {
			return
		}
		seen[key] = struct{}{}
		findings = append(findings, f)
	}

	// 1. Shell command inspection (Bash / PowerShell).
	if cmd := strings.TrimSpace(in.Command); cmd != "" {
		for _, rule := range riskyCommandRules {
			if loc := rule.re.FindStringIndex(cmd); loc != nil {
				matched := cmd[loc[0]:loc[1]]
				fp := redact.Fingerprint(salt, rule.id+":"+cmd)
				add(types.Finding{
					RuleID:      rule.id,
					Title:       rule.title,
					Category:    rule.category,
					Layer:       types.LayerL1,
					Tier:        rule.tier,
					Confidence:  0.97,
					Location:    fmt.Sprintf("tool:%s", in.ToolName),
					Preview:     redact.Preview(matched),
					Fingerprint: fp,
					Explanation: rule.explanation,
					Remediation: rule.remediation,
				})
			}
		}

		// Check curl/wget POST/upload to unknown hosts.
		if matches := curlExfilRe.FindAllStringSubmatch(cmd, -1); len(matches) > 0 {
			for _, m := range matches {
				if len(m) < 2 {
					continue
				}
				host := extractHost(m[1])
				if host != "" && !isAllowedHost(host, pol.Allowlist.Hosts) {
					fp := redact.Fingerprint(salt, "exfil-host:"+host)
					add(types.Finding{
						RuleID:      "cmd-exfil-unknown-host",
						Title:       "Outbound Data Upload to Unknown Host",
						Category:    types.CategoryExfiltration,
						Layer:       types.LayerL1,
						Tier:        types.TierHigh,
						Confidence:  0.92,
						Location:    fmt.Sprintf("tool:%s", in.ToolName),
						Preview:     host,
						Fingerprint: fp,
						Explanation: fmt.Sprintf("Command sends local data via HTTP upload/POST to unallowlisted host %q.", host),
						Remediation: fmt.Sprintf("Verify destination %q; add to allowlist.hosts in .kavach.yaml if trusted.", host),
					})
				}
			}
		}

		// Check scp/rsync of sensitive files to external hosts.
		if m := scpRsyncRe.FindStringSubmatch(cmd); len(m) >= 2 {
			host := m[1]
			if !isAllowedHost(host, pol.Allowlist.Hosts) {
				fp := redact.Fingerprint(salt, "scp-exfil:"+host)
				add(types.Finding{
					RuleID:      "cmd-scp-exfiltration",
					Title:       "Credential Exfiltration via SCP/Rsync",
					Category:    types.CategoryExfiltration,
					Layer:       types.LayerL1,
					Tier:        types.TierHigh,
					Confidence:  0.95,
					Location:    fmt.Sprintf("tool:%s", in.ToolName),
					Preview:     host,
					Fingerprint: fp,
					Explanation: fmt.Sprintf("Command copies credential files via scp/rsync to %q.", host),
					Remediation: "Block credential transfer to remote hosts.",
				})
			}
		}

		// Check pipe-to-shell when URL is present across subshells.
		_ = urlInCmdRe
	}

	// 2. File tool path inspection (Read / Edit / Write).
	if fpPath := strings.TrimSpace(in.FilePath); fpPath != "" {
		normPath := filepath.ToSlash(fpPath)
		lowerPath := strings.ToLower(normPath)
		for _, pat := range sensitiveFilePatterns {
			if strings.Contains(lowerPath, pat) && !isPathAllowlisted(normPath, pol.Allowlist.Paths) {
				fp := redact.Fingerprint(salt, "cred-file:"+normPath)
				add(types.Finding{
					RuleID:      "tool-credential-file-access",
					Title:       "Sensitive Credential File Access",
					Category:    types.CategoryCredentialAccess,
					Layer:       types.LayerL1,
					Tier:        types.TierHigh,
					Confidence:  0.96,
					Location:    fmt.Sprintf("tool:%s (%s)", in.ToolName, filepath.Base(normPath)),
					Preview:     redact.Preview(normPath),
					Fingerprint: fp,
					Explanation: fmt.Sprintf("Tool %s targets sensitive credential file %s.", in.ToolName, normPath),
					Remediation: "Exclude credential files from agent access or add an explicit path allowlist if intentional.",
				})
			}
		}
		// Reading .env directly via Read tool: warn/block unless allowlisted.
		base := strings.ToLower(filepath.Base(normPath))
		if in.ToolName == "Read" && (base == ".env" || strings.HasPrefix(base, ".env.")) && !strings.HasSuffix(base, ".example") && !strings.HasSuffix(base, ".template") {
			if !isPathAllowlisted(normPath, pol.Allowlist.Paths) {
				fp := redact.Fingerprint(salt, "dotenv-read:"+normPath)
				add(types.Finding{
					RuleID:      "tool-dotenv-read",
					Title:       "Reading .env Secrets File",
					Category:    types.CategoryCredentialAccess,
					Layer:       types.LayerL1,
					Tier:        types.TierHigh,
					Confidence:  0.90,
					Location:    fmt.Sprintf("tool:Read (%s)", base),
					Preview:     base,
					Fingerprint: fp,
					Explanation: fmt.Sprintf("Reading %s would send raw environment secrets to the model context.", base),
					Remediation: "Read .env.example instead, or allowlist the file path if it contains no live secrets.",
				})
			}
		}
	}

	// 3. WebFetch URL check for embedded secrets in query params or suspicious IP/exfil URLs.
	if rawURL := strings.TrimSpace(in.URL); rawURL != "" {
		if u, err := url.Parse(rawURL); err == nil {
			q := strings.ToLower(u.RawQuery)
			if strings.Contains(q, "token=") || strings.Contains(q, "api_key=") || strings.Contains(q, "secret=") || strings.Contains(q, "aws_") {
				if len(u.RawQuery) > 24 && !isAllowedHost(u.Hostname(), pol.Allowlist.Hosts) {
					fp := redact.Fingerprint(salt, "url-exfil:"+u.Hostname())
					add(types.Finding{
						RuleID:      "url-query-exfiltration",
						Title:       "Potential Secret Exfiltration in URL Query",
						Category:    types.CategoryExfiltration,
						Layer:       types.LayerL1,
						Tier:        types.TierHigh,
						Confidence:  0.88,
						Location:    "tool:WebFetch",
						Preview:     u.Hostname() + "?…",
						Fingerprint: fp,
						Explanation: fmt.Sprintf("WebFetch URL to %q carries sensitive query parameter names.", u.Hostname()),
						Remediation: "Inspect URL parameters before allowing outbound fetch.",
					})
				}
			}
		}
	}

	// 4. Unreviewed / unknown MCP server check.
	mcpName := strings.TrimSpace(in.MCPServer)
	if mcpName == "" && strings.HasPrefix(in.ToolName, "mcp__") {
		parts := strings.SplitN(in.ToolName, "__", 3)
		if len(parts) >= 2 {
			mcpName = parts[1]
		}
	}
	if mcpName != "" && !isMCPAllowlisted(mcpName, pol.Allowlist.MCPServers) {
		fp := redact.Fingerprint(salt, "mcp:"+mcpName+":"+in.MCPSource)
		srcInfo := in.MCPSource
		if srcInfo == "" {
			srcInfo = "unknown"
		}
		add(types.Finding{
			RuleID:      "unreviewed-mcp-server",
			Title:       "Unreviewed MCP Server Invocation",
			Category:    types.CategoryUnreviewedMCP,
			Layer:       types.LayerL1,
			Tier:        pol.TierForCategory(types.CategoryUnreviewedMCP),
			Confidence:  0.88,
			Location:    fmt.Sprintf("mcp:%s (source:%s)", mcpName, srcInfo),
			Preview:     mcpName,
			Fingerprint: fp,
			Explanation: fmt.Sprintf("Tool call targets MCP server %q (provenance: %s), which is not in Kavach's reviewed allowlist.", mcpName, srcInfo),
			Remediation: fmt.Sprintf("Review the MCP server definition and add %q under allowlist.mcp_servers in ~/.kavach/policy.yaml or .kavach.yaml.", mcpName),
		})
	}

	return findings
}

func extractHost(rawURL string) string {
	u, err := url.Parse(rawURL)
	if err != nil {
		return ""
	}
	return strings.ToLower(u.Hostname())
}

func isAllowedHost(host string, allowlist []string) bool {
	host = strings.ToLower(strings.TrimSpace(host))
	if host == "" {
		return false
	}
	for _, allowed := range allowlist {
		allowed = strings.ToLower(strings.TrimSpace(allowed))
		if allowed == "" {
			continue
		}
		if host == allowed || (strings.HasPrefix(allowed, "*.") && strings.HasSuffix(host, allowed[1:])) {
			return true
		}
	}
	return false
}

func isPathAllowlisted(path string, patterns []string) bool {
	for _, pat := range patterns {
		if pat == "" {
			continue
		}
		if matched, err := filepath.Match(pat, path); err == nil && matched {
			return true
		}
		if strings.HasSuffix(path, pat) || strings.Contains(path, pat) {
			return true
		}
	}
	return false
}

func isMCPAllowlisted(name string, allowlist []string) bool {
	lower := strings.ToLower(strings.TrimSpace(name))
	for _, a := range allowlist {
		if strings.ToLower(strings.TrimSpace(a)) == lower {
			return true
		}
	}
	return false
}
