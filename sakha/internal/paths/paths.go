// Package paths resolves where Sakha keeps its private data.
package paths

import (
	"os"
	"path/filepath"
)

// Home returns Sakha's data directory: $SAKHA_HOME, or ~/.sakha.
func Home() string {
	if h := os.Getenv("SAKHA_HOME"); h != "" {
		return h
	}
	home, err := os.UserHomeDir()
	if err != nil {
		home = "."
	}
	return filepath.Join(home, ".sakha")
}

// UserHome returns the user's home directory ($HOME), used for agent config files.
func UserHome() string {
	home, err := os.UserHomeDir()
	if err != nil {
		return "."
	}
	return home
}

// Ensure creates Sakha's directory tree with owner-only permissions.
func Ensure() error {
	for _, d := range []string{"", "queue", "writes", "history", "backups", "export"} {
		if err := os.MkdirAll(filepath.Join(Home(), d), 0o700); err != nil {
			return err
		}
	}
	return os.Chmod(Home(), 0o700)
}

// Join builds a path inside Sakha's data directory.
func Join(parts ...string) string {
	return filepath.Join(append([]string{Home()}, parts...)...)
}
