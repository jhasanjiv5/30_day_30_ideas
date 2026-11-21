package daemon

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/kavach-sec/kavach/internal/detect"
	"github.com/kavach-sec/kavach/internal/engine"
	"github.com/kavach-sec/kavach/internal/types"
)

type cacheEntry struct {
	verdict   types.Verdict
	expiresAt time.Time
}

// VerdictCache is a thread-safe bounded cache keyed by SHA-256 content+policy hash.
type VerdictCache struct {
	mu      sync.Mutex
	items   map[string]cacheEntry
	order   []string
	maxSize int
	ttl     time.Duration
	hits    uint64
	misses  uint64
}

// NewVerdictCache initializes an LRU/FIFO-evicting verdict cache.
func NewVerdictCache(maxSize int, ttl time.Duration) *VerdictCache {
	if maxSize <= 0 {
		maxSize = 2048
	}
	if ttl <= 0 {
		ttl = 5 * time.Minute
	}
	return &VerdictCache{
		items:   make(map[string]cacheEntry, maxSize),
		maxSize: maxSize,
		ttl:     ttl,
	}
}

func cacheKey(policyHash string, in types.EvalInput) string {
	h := sha256.New()
	_, _ = h.Write([]byte(policyHash))
	_, _ = h.Write([]byte{0})
	_, _ = h.Write([]byte(in.Event))
	_, _ = h.Write([]byte{0})
	_, _ = h.Write([]byte(in.ToolName))
	_, _ = h.Write([]byte{0})
	_, _ = h.Write([]byte(in.MCPServer))
	_, _ = h.Write([]byte{0})
	_, _ = h.Write([]byte(in.FilePath))
	_, _ = h.Write([]byte{0})
	_, _ = h.Write([]byte(in.Command))
	_, _ = h.Write([]byte{0})
	_, _ = h.Write([]byte(in.Content))
	return hex.EncodeToString(h.Sum(nil))
}

// Get retrieves a non-expired verdict from cache.
func (c *VerdictCache) Get(key string) (types.Verdict, bool) {
	c.mu.Lock()
	defer c.mu.Unlock()
	ent, ok := c.items[key]
	if !ok {
		c.misses++
		return types.Verdict{}, false
	}
	if time.Now().After(ent.expiresAt) {
		delete(c.items, key)
		c.misses++
		return types.Verdict{}, false
	}
	c.hits++
	v := ent.verdict
	v.CacheHit = true
	return v, true
}

// Put stores a verdict in the cache.
func (c *VerdictCache) Put(key string, v types.Verdict) {
	c.mu.Lock()
	defer c.mu.Unlock()
	if _, exists := c.items[key]; !exists {
		if len(c.order) >= c.maxSize {
			oldest := c.order[0]
			c.order = c.order[1:]
			delete(c.items, oldest)
		}
		c.order = append(c.order, key)
	}
	c.items[key] = cacheEntry{
		verdict:   v,
		expiresAt: time.Now().Add(c.ttl),
	}
}

// Stats returns cache counters.
func (c *VerdictCache) Stats() map[string]any {
	c.mu.Lock()
	defer c.mu.Unlock()
	return map[string]any{
		"entries": len(c.items),
		"hits":    c.hits,
		"misses":  c.misses,
	}
}

// Server exposes the local-only Unix socket (or 127.0.0.1 TCP) Kavach daemon.
type Server struct {
	eng   *engine.Engine
	cache *VerdictCache
}

// NewServer wraps an Engine with verdict caching for daemon mode.
func NewServer(eng *engine.Engine) *Server {
	pol := eng.Policy()
	ttl := time.Duration(pol.Daemon.CacheTTLSec) * time.Second
	return &Server{
		eng:   eng,
		cache: NewVerdictCache(pol.Daemon.CacheMaxSize, ttl),
	}
}

// Handler returns the HTTP handler for /health, /evaluate, and /cache/stats.
func (s *Server) Handler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("/health", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(map[string]any{
			"status": "ok",
			"l2":     s.eng.Policy().L2.Enabled,
		})
	})
	mux.HandleFunc("/cache/stats", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(s.cache.Stats())
	})
	mux.HandleFunc("/evaluate", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
			return
		}
		var in types.EvalInput
		if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
			http.Error(w, "invalid JSON", http.StatusBadRequest)
			return
		}
		key := cacheKey(s.eng.Policy().Hash(), in)
		if cached, ok := s.cache.Get(key); ok {
			w.Header().Set("Content-Type", "application/json")
			_ = json.NewEncoder(w).Encode(cached)
			return
		}
		v := s.eng.Evaluate(r.Context(), in)
		// Only cache deterministic/non-allow-once verdicts.
		if v.Action == types.ActionAllow || v.Action == types.ActionBlock || v.Action == types.ActionWarn {
			s.cache.Put(key, v)
		}
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(v)
	})
	return mux
}

// DefaultSocketPath returns ~/.kavach/kavach.sock.
func DefaultSocketPath(kavachDir string) string {
	return filepath.Join(kavachDir, "kavach.sock")
}

// ListenAndServe starts the daemon on a Unix socket (preferred) or 127.0.0.1 TCP address.
func (s *Server) ListenAndServe(ctx context.Context, unixPath, tcpAddr string) error {
	var ln net.Listener
	var err error
	var lc net.ListenConfig
	if tcpAddr != "" {
		if err := detect.ValidateLoopbackEndpoint("http://" + tcpAddr); err != nil {
			return err
		}
		ln, err = lc.Listen(ctx, "tcp", tcpAddr)
		if err != nil {
			return fmt.Errorf("listen tcp %s: %w", tcpAddr, err)
		}
	} else {
		if err := os.MkdirAll(filepath.Dir(unixPath), 0o700); err != nil {
			return err
		}
		_ = os.Remove(unixPath)
		ln, err = lc.Listen(ctx, "unix", unixPath)
		if err != nil {
			return fmt.Errorf("listen unix %s: %w", unixPath, err)
		}
		_ = os.Chmod(unixPath, 0o600)
		defer func() { _ = os.Remove(unixPath) }()
	}

	srv := &http.Server{
		Handler:           s.Handler(),
		ReadHeaderTimeout: 2 * time.Second,
	}
	go func() {
		<-ctx.Done()
		shutCtx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
		defer cancel()
		_ = srv.Shutdown(shutCtx)
	}()

	err = srv.Serve(ln)
	if err != nil && err != http.ErrServerClosed {
		return err
	}
	return nil
}

// EvaluateViaSocket attempts to query a running Kavach Unix socket daemon with a strict timeout.
// Returns (verdict, true) on success, or (_, false) if the daemon is not running.
func EvaluateViaSocket(ctx context.Context, socketPath string, in types.EvalInput, timeout time.Duration) (types.Verdict, bool) {
	if socketPath == "" || strings.TrimSpace(socketPath) == "" {
		return types.Verdict{}, false
	}
	if _, err := os.Stat(socketPath); err != nil {
		return types.Verdict{}, false
	}
	if timeout <= 0 {
		timeout = 4 * time.Second
	}
	client := &http.Client{
		Timeout: timeout,
		Transport: &http.Transport{
			DialContext: func(ctx context.Context, _, _ string) (net.Conn, error) {
				var d net.Dialer
				return d.DialContext(ctx, "unix", socketPath)
			},
		},
	}
	body, err := json.Marshal(in)
	if err != nil {
		return types.Verdict{}, false
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, "http://localhost/evaluate", bytes.NewReader(body))
	if err != nil {
		return types.Verdict{}, false
	}
	req.Header.Set("Content-Type", "application/json")
	resp, err := client.Do(req)
	if err != nil {
		return types.Verdict{}, false
	}
	defer func() { _ = resp.Body.Close() }()
	if resp.StatusCode != http.StatusOK {
		return types.Verdict{}, false
	}
	var v types.Verdict
	if err := json.NewDecoder(resp.Body).Decode(&v); err != nil {
		return types.Verdict{}, false
	}
	return v, true
}
