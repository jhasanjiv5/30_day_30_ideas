package main

import (
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"runtime"
	"strings"
	"syscall"
	"text/tabwriter"
	"time"

	"github.com/kavach-sec/kavach/internal/audit"
	"github.com/kavach-sec/kavach/internal/auditlog"
	"github.com/kavach-sec/kavach/internal/config"
	"github.com/kavach-sec/kavach/internal/daemon"
	"github.com/kavach-sec/kavach/internal/detect"
	"github.com/kavach-sec/kavach/internal/engine"
	"github.com/kavach-sec/kavach/internal/hooks/claude"
	"github.com/kavach-sec/kavach/internal/redact"
	"github.com/kavach-sec/kavach/internal/selftest"
	"github.com/kavach-sec/kavach/internal/types"
)

var (
	version = "0.1.0"
	commit  = "dev"
)

func main() {
	os.Exit(run(os.Args[1:]))
}

func run(args []string) int {
	if len(args) == 0 {
		printUsage()
		return 0
	}

	switch args[0] {
	case "hook":
		return cmdHook(args[1:])
	case "install":
		return cmdInstall(args[1:])
	case "uninstall":
		return cmdUninstall(args[1:])
	case "scan":
		return cmdScan(args[1:])
	case "audit":
		return cmdAudit(args[1:])
	case "selftest":
		return cmdSelftest(args[1:])
	case "doctor":
		return cmdDoctor(args[1:])
	case "log":
		return cmdLog(args[1:])
	case "update-rules":
		return cmdUpdateRules(args[1:])
	case "allow-once":
		return cmdAllowOnce(args[1:])
	case "rotate-salt":
		return cmdRotateSalt(args[1:])
	case "serve":
		return cmdServe(args[1:])
	case "version", "--version", "-v":
		fmt.Printf("kavach %s (%s %s/%s)\n", version, commit, runtime.GOOS, runtime.GOARCH)
		return 0
	case "help", "-h", "--help":
		printUsage()
		return 0
	default:
		fmt.Fprintf(os.Stderr, "kavach: unknown command %q\n\n", args[0])
		printUsage()
		return 2
	}
}

func printUsage() {
	fmt.Print(`Kavach — local security guard for AI agent sessions

Usage:
  kavach <command> [flags]

Commands:
  hook <event>                      Run Claude Code hook (reads JSON on stdin)
  install --claude-code [--user|--project]   Back up settings and install hooks
  uninstall [--user|--project|--all] [--restore-backup] [--purge]
                                    Safely remove Kavach hooks while preserving other apps & modes
  scan <file|-> [--json] [--redact] Scan a file or stdin for secrets/PII/injection
  audit [--json]                    Run local session & token-theft hygiene audit
  selftest [--corpus dir] [--json]  Run red-team + benign benchmark via hooks
  doctor [--json]                   Check binary, hooks, rules, and optional L2
  log [--since 24h] [--limit 50]    View redacted JSONL audit log
  update-rules [--from file]        Sync or import L0 secret rules locally
  allow-once <fp> --reason "..."    Temporarily allow a finding fingerprint
  rotate-salt                       Rotate the local fingerprint hash salt
  serve [--socket path] [--tcp 127.0.0.1:17432]  Run optional local daemon
  version                           Print version information
`)
}

func cmdHook(args []string) int {
	if len(args) < 1 {
		fmt.Fprintln(os.Stderr, "usage: kavach hook <SessionStart|UserPromptSubmit|PreToolUse|PostToolUse>")
		return 2
	}
	stdinBytes, err := io.ReadAll(os.Stdin)
	if err != nil {
		fmt.Fprintf(os.Stderr, "kavach hook: read stdin: %v\n", err)
		return 1
	}

	kavachDir := config.DefaultKavachDir()
	cwd, _ := os.Getwd()
	eng, err := engine.New(engine.Options{KavachDir: kavachDir, CWD: cwd})
	if err != nil {
		fmt.Fprintf(os.Stderr, "kavach hook: init engine: %v\n", err)
		return 1
	}

	out, _, err := claude.HandleHook(context.Background(), eng, kavachDir, args[0], stdinBytes)
	if err != nil {
		fmt.Fprintf(os.Stderr, "kavach hook: %v\n", err)
		return 1
	}
	if out != nil {
		enc := json.NewEncoder(os.Stdout)
		enc.SetEscapeHTML(false)
		if err := enc.Encode(out); err != nil {
			fmt.Fprintf(os.Stderr, "kavach hook: encode output: %v\n", err)
			return 1
		}
	}
	return 0
}

func cmdInstall(args []string) int {
	fs := flag.NewFlagSet("install", flag.ContinueOnError)
	cc := fs.Bool("claude-code", true, "Install hooks for Claude Code")
	project := fs.Bool("project", false, "Install into project .claude/settings.json")
	user := fs.Bool("user", false, "Install into user ~/.claude/settings.json")
	if err := fs.Parse(args); err != nil {
		return 2
	}
	if !*cc {
		fmt.Fprintln(os.Stderr, "kavach install: currently supports --claude-code")
		return 2
	}
	scope := claude.ScopeUser
	if *project && !*user {
		scope = claude.ScopeProject
	}

	kavachDir := config.DefaultKavachDir()
	if _, err := redact.LoadOrCreateSalt(kavachDir); err != nil {
		fmt.Fprintf(os.Stderr, "kavach install: init salt: %v\n", err)
		return 1
	}
	polPath, err := config.EnsureDefaultPolicy(kavachDir)
	if err != nil {
		fmt.Fprintf(os.Stderr, "kavach install: init policy: %v\n", err)
		return 1
	}

	binPath, err := os.Executable()
	if err != nil {
		binPath = "kavach"
	} else if resolved, rErr := filepath.EvalSymlinks(binPath); rErr == nil {
		binPath = resolved
	}

	cwd, _ := os.Getwd()
	entry, err := claude.Install(scope, cwd, kavachDir, binPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "kavach install: %v\n", err)
		return 1
	}

	fmt.Printf("Kavach hooks installed (%s scope)\n", entry.Scope)
	fmt.Printf("  Settings : %s\n", entry.SettingsPath)
	if entry.ExistedBefore {
		fmt.Printf("  Backup   : %s\n", entry.BackupPath)
	}
	fmt.Printf("  Policy   : %s\n", polPath)
	fmt.Printf("  Manifest : %s (sha256:%s…)\n", filepath.Join(kavachDir, "install_manifest.json"), entry.SettingsSHA256[:12])
	fmt.Println("Next: run `kavach doctor` and `kavach selftest`.")
	return 0
}

func cmdUninstall(args []string) int {
	fs := flag.NewFlagSet("uninstall", flag.ContinueOnError)
	_ = fs.Bool("claude-code", true, "Uninstall Claude Code hooks")
	project := fs.Bool("project", false, "Uninstall from project .claude/settings.json")
	user := fs.Bool("user", false, "Uninstall from user ~/.claude/settings.json")
	all := fs.Bool("all", false, "Uninstall all Claude Code scopes recorded in manifest")
	restoreBackup := fs.Bool("restore-backup", false, "Force byte-for-byte pre-Kavach backup restore (discards post-install edits)")
	purge := fs.Bool("purge", false, "Also remove ~/.kavach local state (policy, logs, backups) after unhooking")
	if err := fs.Parse(args); err != nil {
		return 2
	}

	kavachDir := config.DefaultKavachDir()
	cwd, _ := os.Getwd()
	opts := claude.UninstallOptions{RestoreBackup: *restoreBackup}

	var results []claude.UninstallResult
	if *all || *purge {
		res, err := claude.UninstallAll(kavachDir, opts)
		if err != nil {
			fmt.Fprintf(os.Stderr, "kavach uninstall: %v\n", err)
			return 1
		}
		results = res
	} else if !*project && !*user {
		// Smart default: if user did not specify --user or --project, check manifest so
		// `kavach uninstall` works cleanly regardless of which scope they installed.
		manifest, mErr := claude.LoadManifest(kavachDir)
		if mErr != nil || len(manifest.Installs) == 0 {
			fmt.Fprintln(os.Stderr, "kavach uninstall: no Kavach hook installations recorded")
			return 1
		}
		userPath, _ := claude.SettingsPath(claude.ScopeUser, cwd)
		projPath, _ := claude.SettingsPath(claude.ScopeProject, cwd)
		if _, ok := manifest.Installs[userPath]; ok {
			res, err := claude.UninstallWithOptions(claude.ScopeUser, cwd, kavachDir, opts)
			if err != nil {
				fmt.Fprintf(os.Stderr, "kavach uninstall: %v\n", err)
				return 1
			}
			results = append(results, res)
		}
		if _, ok := manifest.Installs[projPath]; ok {
			res, err := claude.UninstallWithOptions(claude.ScopeProject, cwd, kavachDir, opts)
			if err != nil {
				fmt.Fprintf(os.Stderr, "kavach uninstall: %v\n", err)
				return 1
			}
			results = append(results, res)
		}
		if len(results) == 0 {
			res, err := claude.UninstallAll(kavachDir, opts)
			if err != nil {
				fmt.Fprintf(os.Stderr, "kavach uninstall: %v\n", err)
				return 1
			}
			results = res
		}
	} else {
		if *user {
			res, err := claude.UninstallWithOptions(claude.ScopeUser, cwd, kavachDir, opts)
			if err != nil {
				fmt.Fprintf(os.Stderr, "kavach uninstall: %v\n", err)
				return 1
			}
			results = append(results, res)
		}
		if *project {
			res, err := claude.UninstallWithOptions(claude.ScopeProject, cwd, kavachDir, opts)
			if err != nil {
				fmt.Fprintf(os.Stderr, "kavach uninstall: %v\n", err)
				return 1
			}
			results = append(results, res)
		}
	}

	for _, r := range results {
		switch r.Strategy {
		case "surgical_merge":
			fmt.Printf("Removed %d Kavach hook(s) cleanly while preserving your other apps, modes & settings: %s\n", r.HooksRemoved, r.SettingsPath)
			if r.BackupPath != "" {
				fmt.Printf("  Pre-Kavach snapshot kept at: %s\n", r.BackupPath)
			}
		case "restored_backup":
			fmt.Printf("Restored original settings byte-for-byte: %s\n", r.SettingsPath)
		case "removed_created_file":
			fmt.Printf("Removed Kavach-only settings file (none existed before): %s\n", r.SettingsPath)
		}
	}

	if *purge {
		if err := os.RemoveAll(kavachDir); err != nil {
			fmt.Fprintf(os.Stderr, "kavach uninstall: purge %s: %v\n", kavachDir, err)
			return 1
		}
		fmt.Printf("Purged local Kavach state directory: %s (all user apps & Claude modes untouched)\n", kavachDir)
	} else if len(results) > 0 {
		fmt.Printf("Local config & logs kept in %s (pass --purge to also remove them, or remove binary with brew/rm).\n", kavachDir)
	}
	return 0
}

func cmdScan(args []string) int {
	fs := flag.NewFlagSet("scan", flag.ContinueOnError)
	asJSON := fs.Bool("json", false, "Output JSON verdict")
	doRedact := fs.Bool("redact", false, "Print redacted content instead of report")
	if err := fs.Parse(args); err != nil {
		return 2
	}
	if fs.NArg() < 1 {
		fmt.Fprintln(os.Stderr, "usage: kavach scan <file|-> [--json] [--redact]")
		return 2
	}
	target := fs.Arg(0)

	var content []byte
	var err error
	filePath := ""
	if target == "-" {
		content, err = io.ReadAll(os.Stdin)
	} else {
		filePath = target
		content, err = os.ReadFile(target)
	}
	if err != nil {
		fmt.Fprintf(os.Stderr, "kavach scan: %v\n", err)
		return 1
	}

	kavachDir := config.DefaultKavachDir()
	cwd, _ := os.Getwd()
	eng, err := engine.New(engine.Options{KavachDir: kavachDir, CWD: cwd})
	if err != nil {
		fmt.Fprintf(os.Stderr, "kavach scan: %v\n", err)
		return 1
	}

	v := eng.Evaluate(context.Background(), types.EvalInput{
		Event:    types.EventScan,
		FilePath: filePath,
		Content:  string(content),
	})

	if *doRedact {
		fmt.Print(v.RedactedContent)
		return 0
	}
	if *asJSON {
		enc := json.NewEncoder(os.Stdout)
		enc.SetIndent("", "  ")
		_ = enc.Encode(v)
	} else {
		if len(v.Findings) == 0 {
			fmt.Printf("CLEAN (0 findings, %.2f ms)\n", v.DurationMs)
		} else {
			fmt.Printf("ACTION: %s | TIER: %s | FINDINGS: %d | LATENCY: %.2f ms\n\n", v.Action, v.HighestTier, len(v.Findings), v.DurationMs)
			for _, f := range v.Findings {
				status := string(f.Tier)
				if f.AllowListed {
					status = "ALLOWLISTED (" + f.AllowReason + ")"
				}
				fmt.Printf("  [%s] %s (%s)\n", status, f.Title, f.RuleID)
				fmt.Printf("    Location   : %s\n", f.Location)
				fmt.Printf("    Preview    : %s\n", f.Preview)
				fmt.Printf("    Fingerprint: %s\n", f.Fingerprint)
				fmt.Printf("    Fix        : %s\n\n", f.Remediation)
			}
		}
	}
	if v.Action == types.ActionBlock {
		return 2
	}
	return 0
}

func cmdAudit(args []string) int {
	fs := flag.NewFlagSet("audit", flag.ContinueOnError)
	asJSON := fs.Bool("json", false, "Output JSON audit report")
	if err := fs.Parse(args); err != nil {
		return 2
	}
	kavachDir := config.DefaultKavachDir()
	cwd, _ := os.Getwd()
	pol, err := config.LoadPolicy(kavachDir, cwd)
	if err != nil {
		fmt.Fprintf(os.Stderr, "kavach audit: load policy: %v\n", err)
		return 1
	}
	rep := audit.RunFull(kavachDir, cwd, pol)
	if *asJSON {
		enc := json.NewEncoder(os.Stdout)
		enc.SetIndent("", "  ")
		_ = enc.Encode(rep)
		return 0
	}

	fmt.Printf("Kavach Hygiene Audit — Score: %d/100\n", rep.Score)
	if rep.Tampered {
		fmt.Println("WARNING: Hook integrity / tamper alert detected!")
	}
	if len(rep.Findings) == 0 {
		fmt.Println("No session or token-theft risks detected.")
		return 0
	}
	fmt.Printf("Found %d item(s):\n\n", len(rep.Findings))
	for i, f := range rep.Findings {
		fmt.Printf("%d. [%s] %s\n", i+1, f.Severity, f.Title)
		fmt.Printf("   Location: %s\n", f.Location)
		fmt.Printf("   Detail  : %s\n", f.Description)
		fmt.Printf("   Fix     : %s\n\n", f.FixCommand)
	}
	if rep.Tampered {
		return 2
	}
	return 0
}

func cmdSelftest(args []string) int {
	fs := flag.NewFlagSet("selftest", flag.ContinueOnError)
	corpus := fs.String("corpus", "testdata/redteam", "Path to redteam fixture directory")
	asJSON := fs.Bool("json", false, "Output JSON metrics")
	verbose := fs.Bool("v", false, "Print individual missed/FP details")
	if err := fs.Parse(args); err != nil {
		return 2
	}

	res, err := selftest.Run(context.Background(), *corpus)
	if err != nil {
		fmt.Fprintf(os.Stderr, "kavach selftest: %v\n", err)
		return 1
	}
	if *asJSON {
		enc := json.NewEncoder(os.Stdout)
		enc.SetIndent("", "  ")
		_ = enc.Encode(res)
		if !res.PassedThresholds {
			return 1
		}
		return 0
	}

	fmt.Printf("Kavach Self-Test (%d labelled hook fixtures, L0+L1 embedded, 0 network calls)\n\n", res.TotalCases)
	w := tabwriter.NewWriter(os.Stdout, 0, 4, 2, ' ', 0)
	_, _ = fmt.Fprintln(w, "CATEGORY\tTOTAL\tDETECTED\tMISSED\tFALSE POS\tRATE\tp50 (ms)\tp95 (ms)")
	_, _ = fmt.Fprintln(w, "--------\t-----\t--------\t------\t---------\t----\t--------\t--------")
	for _, c := range res.Categories {
		_, _ = fmt.Fprintf(w, "%s\t%d\t%d\t%d\t%d\t%.1f%%\t%.2f\t%.2f\n",
			c.Category, c.Total, c.Detected, c.Missed, c.FalsePositives, c.DetectionRate*100, c.P50Ms, c.P95Ms)
	}
	_ = w.Flush()

	fmt.Printf("\nThresholds:\n")
	fmt.Printf("  Secrets detection   : %.1f%% (target >= 98.0%%)\n", res.SecretsRate*100)
	fmt.Printf("  Risky commands      : %.1f%% (target = 100.0%%)\n", res.RiskyCommandsRate*100)
	fmt.Printf("  Injection + Unicode : %.1f%% (target >= 85.0%%)\n", res.InjectionRate*100)
	fmt.Printf("  False positive rate : %.1f%% (target <= 5.0%%)\n", res.FalsePositiveRate*100)
	fmt.Printf("  Hook latency p50/p95: %.2f ms / %.2f ms (target p95 < 50.0 ms)\n", res.OverallP50Ms, res.OverallP95Ms)

	if *verbose && len(res.Failures) > 0 {
		fmt.Println("\nDetails:")
		for _, f := range res.Failures {
			fmt.Println("  - " + f)
		}
	}

	if !res.PassedThresholds {
		fmt.Println("\nRESULT: FAIL (below threshold)")
		return 1
	}
	fmt.Println("\nRESULT: PASS")
	return 0
}

func cmdDoctor(args []string) int {
	fs := flag.NewFlagSet("doctor", flag.ContinueOnError)
	asJSON := fs.Bool("json", false, "Output JSON diagnostics")
	if err := fs.Parse(args); err != nil {
		return 2
	}

	kavachDir := config.DefaultKavachDir()
	cwd, _ := os.Getwd()
	pol, polErr := config.LoadPolicy(kavachDir, cwd)
	sc, ruleErr := detect.NewSecretScanner(kavachDir)
	installed, tampered, _ := claude.VerifyIntegrity(kavachDir)
	claudeBin, _ := exec.LookPath("claude")
	_, saltErr := os.Stat(filepath.Join(kavachDir, "salt"))
	sockPath := daemon.DefaultSocketPath(kavachDir)
	_, sockErr := os.Stat(sockPath)

	l2Status := "disabled"
	if pol.L2.Enabled {
		if err := detect.ValidateLoopbackEndpoint(pol.L2.Endpoint); err != nil {
			l2Status = "invalid endpoint: " + err.Error()
		} else if pol.L2.Model == "" {
			l2Status = "enabled but l2.model not set in policy.yaml"
		} else {
			client := &http.Client{Timeout: 800 * time.Millisecond}
			req, _ := http.NewRequestWithContext(context.Background(), http.MethodGet, strings.TrimRight(pol.L2.Endpoint, "/")+"/api/tags", nil)
			resp, err := client.Do(req)
			if err != nil {
				l2Status = "unreachable (" + err.Error() + ")"
			} else {
				_ = resp.Body.Close()
				l2Status = fmt.Sprintf("ready (%s @ %s)", pol.L2.Model, pol.L2.Endpoint)
			}
		}
	}

	ruleCount := 0
	if sc != nil {
		ruleCount = sc.RuleCount()
	}

	report := map[string]any{
		"version":           version,
		"os_arch":           runtime.GOOS + "/" + runtime.GOARCH,
		"kavach_dir":        kavachDir,
		"policy_ok":         polErr == nil,
		"salt_ok":           saltErr == nil,
		"l0_rules":          ruleCount,
		"rules_ok":          ruleErr == nil,
		"claude_code_bin":   claudeBin,
		"hooks_installed":   installed,
		"hooks_tampered":    tampered,
		"daemon_socket":     sockPath,
		"daemon_running":    sockErr == nil,
		"l2_status":         l2Status,
	}

	if *asJSON {
		enc := json.NewEncoder(os.Stdout)
		enc.SetIndent("", "  ")
		_ = enc.Encode(report)
		return 0
	}

	fmt.Printf("Kavach Doctor (%s, %s/%s)\n\n", version, runtime.GOOS, runtime.GOARCH)
	fmt.Printf("  [ok] Kavach home   : %s\n", kavachDir)
	fmt.Printf("  [%s] Policy YAML  : %s\n", okMark(polErr == nil), filepath.Join(kavachDir, "policy.yaml"))
	fmt.Printf("  [%s] Hash salt    : %s\n", okMark(saltErr == nil), filepath.Join(kavachDir, "salt"))
	fmt.Printf("  [%s] L0 rules     : %d rules loaded\n", okMark(ruleErr == nil), ruleCount)
	if claudeBin != "" {
		fmt.Printf("  [ok] Claude Code   : %s\n", claudeBin)
	} else {
		fmt.Println("  [--] Claude Code   : `claude` not found on PATH")
	}
	switch {
	case installed && len(tampered) == 0:
		fmt.Println("  [ok] Hook integrity: installed & verified (SHA-256 match)")
	case len(tampered) > 0:
		fmt.Printf("  [!!] Hook integrity: TAMPERED (%s)\n", strings.Join(tampered, ", "))
	default:
		fmt.Println("  [--] Hook integrity: not installed (run `kavach install --claude-code`)")
	}
	if sockErr == nil {
		fmt.Printf("  [ok] Daemon socket : running (%s)\n", sockPath)
	} else {
		fmt.Println("  [--] Daemon socket : not running (optional; L0+L1 work embedded)")
	}
	fmt.Printf("  [..] L2 Ollama     : %s\n", l2Status)

	if len(tampered) > 0 || polErr != nil || ruleErr != nil {
		return 1
	}
	return 0
}

func cmdLog(args []string) int {
	fs := flag.NewFlagSet("log", flag.ContinueOnError)
	sinceStr := fs.String("since", "", "Show entries within duration (e.g. 24h, 30m)")
	limit := fs.Int("limit", 50, "Maximum entries to display")
	asJSON := fs.Bool("json", false, "Output JSONL array")
	if err := fs.Parse(args); err != nil {
		return 2
	}

	var since time.Time
	if *sinceStr != "" {
		d, err := time.ParseDuration(*sinceStr)
		if err != nil {
			fmt.Fprintf(os.Stderr, "kavach log: invalid --since duration %q: %v\n", *sinceStr, err)
			return 2
		}
		since = time.Now().UTC().Add(-d)
	}

	kavachDir := config.DefaultKavachDir()
	pol, _ := config.LoadPolicy(kavachDir, "")
	logger := auditlog.NewLogger(kavachDir, pol.Log)
	entries, err := logger.Query(since, *limit)
	if err != nil {
		fmt.Fprintf(os.Stderr, "kavach log: %v\n", err)
		return 1
	}

	if *asJSON {
		enc := json.NewEncoder(os.Stdout)
		enc.SetIndent("", "  ")
		_ = enc.Encode(entries)
		return 0
	}

	if len(entries) == 0 {
		fmt.Printf("No audit log entries (%s).\n", logger.Path())
		return 0
	}
	w := tabwriter.NewWriter(os.Stdout, 0, 4, 2, ' ', 0)
	_, _ = fmt.Fprintln(w, "TIMESTAMP\tEVENT\tLAYER\tTIER\tACTION\tRULE\tPREVIEW\tFINGERPRINT")
	for _, e := range entries {
		_, _ = fmt.Fprintf(w, "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
			e.Timestamp.Format(time.RFC3339), e.Event, e.Layer, e.Tier, e.Action, e.RuleID, e.Preview, e.Fingerprint)
	}
	_ = w.Flush()
	return 0
}

func cmdUpdateRules(args []string) int {
	fs := flag.NewFlagSet("update-rules", flag.ContinueOnError)
	from := fs.String("from", "", "Optional local rules YAML bundle path")
	if err := fs.Parse(args); err != nil {
		return 2
	}
	kavachDir := config.DefaultKavachDir()
	count, outPath, err := detect.SyncRulesBundle(kavachDir, *from)
	if err != nil {
		fmt.Fprintf(os.Stderr, "kavach update-rules: %v\n", err)
		return 1
	}
	fmt.Printf("Synced %d L0 secret rules to %s (offline/local).\n", count, outPath)
	return 0
}

func cmdAllowOnce(args []string) int {
	fs := flag.NewFlagSet("allow-once", flag.ContinueOnError)
	reason := fs.String("reason", "", "Required justification for temporary allow-once")
	ttl := fs.Duration("ttl", 30*time.Minute, "Expiry duration")
	uses := fs.Int("uses", 1, "Number of allowed uses")
	if err := fs.Parse(args); err != nil {
		return 2
	}
	if fs.NArg() < 1 {
		fmt.Fprintln(os.Stderr, "usage: kavach allow-once <fingerprint> --reason \"...\" [--ttl 30m] [--uses 1]")
		return 2
	}
	fp := fs.Arg(0)
	kavachDir := config.DefaultKavachDir()
	store := config.NewAllowOnceStore(kavachDir)
	entry, err := store.Add(fp, *reason, *ttl, *uses)
	if err != nil {
		fmt.Fprintf(os.Stderr, "kavach allow-once: %v\n", err)
		return 2
	}
	// Also record the allow-once grant in the audit log.
	pol, _ := config.LoadPolicy(kavachDir, "")
	logger := auditlog.NewLogger(kavachDir, pol.Log)
	_ = logger.LogVerdict(types.EvalInput{Event: "AllowOnceGrant"}, types.Verdict{
		Action:      types.ActionAllow,
		EvaluatedAt: time.Now().UTC(),
		Findings: []types.Finding{{
			RuleID:      "allow-once-grant",
			Category:    types.CategorySecrets,
			Layer:       types.LayerL0,
			Tier:        types.TierLow,
			Location:    "cli",
			Preview:     "grant",
			Fingerprint: entry.Fingerprint,
			AllowListed: true,
			AllowReason: entry.Reason,
		}},
	})
	fmt.Printf("Allow-once registered for %s (uses=%d, expires=%s, reason=%q)\n",
		entry.Fingerprint, entry.UsesLeft, entry.ExpiresAt.Format(time.RFC3339), entry.Reason)
	return 0
}

func cmdRotateSalt(args []string) int {
	fs := flag.NewFlagSet("rotate-salt", flag.ContinueOnError)
	if err := fs.Parse(args); err != nil {
		return 2
	}
	kavachDir := config.DefaultKavachDir()
	if _, err := redact.RotateSalt(kavachDir); err != nil {
		fmt.Fprintf(os.Stderr, "kavach rotate-salt: %v\n", err)
		return 1
	}
	fmt.Printf("Rotated local hash salt at %s\n", filepath.Join(kavachDir, "salt"))
	return 0
}

func cmdServe(args []string) int {
	fs := flag.NewFlagSet("serve", flag.ContinueOnError)
	sock := fs.String("socket", "", "Unix socket path (default ~/.kavach/kavach.sock)")
	tcp := fs.String("tcp", "", "Optional loopback TCP address (e.g. 127.0.0.1:17432)")
	if err := fs.Parse(args); err != nil {
		return 2
	}
	kavachDir := config.DefaultKavachDir()
	cwd, _ := os.Getwd()
	eng, err := engine.New(engine.Options{KavachDir: kavachDir, CWD: cwd})
	if err != nil {
		fmt.Fprintf(os.Stderr, "kavach serve: %v\n", err)
		return 1
	}
	sockPath := *sock
	if sockPath == "" {
		sockPath = daemon.DefaultSocketPath(kavachDir)
	}
	srv := daemon.NewServer(eng)
	ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer cancel()

	if *tcp != "" {
		fmt.Printf("Kavach daemon listening on http://%s (loopback-only)\n", *tcp)
	} else {
		fmt.Printf("Kavach daemon listening on unix://%s\n", sockPath)
	}
	if err := srv.ListenAndServe(ctx, sockPath, *tcp); err != nil && !errors.Is(err, context.Canceled) {
		fmt.Fprintf(os.Stderr, "kavach serve: %v\n", err)
		return 1
	}
	return 0
}

func okMark(ok bool) string {
	if ok {
		return "ok"
	}
	return "!!"
}
