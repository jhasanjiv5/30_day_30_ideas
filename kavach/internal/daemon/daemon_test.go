package daemon

import (
	"context"
	"path/filepath"
	"testing"
	"time"

	"github.com/kavach-sec/kavach/internal/engine"
	"github.com/kavach-sec/kavach/internal/types"
)

func TestDaemonUnixSocketAndVerdictCache(t *testing.T) {
	kavachDir := t.TempDir()
	eng, err := engine.New(engine.Options{KavachDir: kavachDir})
	if err != nil {
		t.Fatalf("engine.New: %v", err)
	}

	sockPath := filepath.Join(kavachDir, "kavach.sock")
	srv := NewServer(eng)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	errCh := make(chan error, 1)
	go func() {
		errCh <- srv.ListenAndServe(ctx, sockPath, "")
	}()

	// Wait briefly for socket to appear
	deadline := time.Now().Add(2 * time.Second)
	in := types.EvalInput{
		Event:   types.EventUserPromptSubmit,
		Content: "AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE",
	}

	var v1 types.Verdict
	var ok bool
	for time.Now().Before(deadline) {
		v1, ok = EvaluateViaSocket(ctx, sockPath, in, time.Second)
		if ok {
			break
		}
		time.Sleep(25 * time.Millisecond)
	}
	if !ok {
		t.Fatalf("failed to reach daemon over unix socket")
	}
	if v1.Action != types.ActionBlock || v1.CacheHit {
		t.Fatalf("expected uncached BLOCK on first request, got action=%s cacheHit=%v", v1.Action, v1.CacheHit)
	}

	v2, ok := EvaluateViaSocket(ctx, sockPath, in, time.Second)
	if !ok || !v2.CacheHit || v2.Action != types.ActionBlock {
		t.Fatalf("expected cached BLOCK on second request, got ok=%v cacheHit=%v action=%s", ok, v2.CacheHit, v2.Action)
	}

	cancel()
	if err := <-errCh; err != nil {
		t.Fatalf("ListenAndServe returned error: %v", err)
	}
}
