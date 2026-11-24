// Command termshot renders captured terminal text as an SVG "terminal window" for the README.
// Usage: termshot -title "sakha doctor" < output.txt > frame.svg
package main

import (
	"bufio"
	"flag"
	"fmt"
	"os"
	"strings"
	"unicode/utf8"
)

const (
	charW   = 8.4
	lineH   = 19.0
	padX    = 22.0
	topBar  = 38.0
	padY    = 18.0
	maxCols = 112
)

func esc(s string) string {
	r := strings.NewReplacer("&", "&amp;", "<", "&lt;", ">", "&gt;")
	return r.Replace(s)
}

func wrap(line string) []string {
	var out []string
	for utf8.RuneCountInString(line) > maxCols {
		r := []rune(line)
		out = append(out, string(r[:maxCols]))
		line = "    " + string(r[maxCols:])
	}
	return append(out, line)
}

func colour(line string) string {
	t := strings.TrimSpace(line)
	switch {
	case strings.HasPrefix(t, "$ "):
		return "#7ee787"
	case strings.HasPrefix(t, "✓"), strings.Contains(t, "RESULT: PASS"), strings.Contains(t, "✓ kept"), strings.Contains(t, "✓ saved"):
		return "#3fb950"
	case strings.HasPrefix(t, "✗"), strings.Contains(t, "FAIL"), strings.Contains(t, "dropped"):
		return "#ff7b72"
	case strings.HasPrefix(t, "·"), strings.HasPrefix(t, "#"), strings.HasPrefix(t, "──"), strings.HasPrefix(t, "---"):
		return "#8b949e"
	case strings.HasPrefix(t, "["), strings.HasPrefix(t, "“"):
		return "#79c0ff"
	}
	return "#e6edf3"
}

func main() {
	title := flag.String("title", "sakha", "window title")
	flag.Parse()
	var lines []string
	sc := bufio.NewScanner(os.Stdin)
	sc.Buffer(make([]byte, 0, 64*1024), 1024*1024)
	for sc.Scan() {
		lines = append(lines, wrap(strings.ReplaceAll(sc.Text(), "\t", "    "))...)
	}
	for len(lines) > 0 && strings.TrimSpace(lines[len(lines)-1]) == "" {
		lines = lines[:len(lines)-1]
	}
	cols := 60
	for _, l := range lines {
		if n := utf8.RuneCountInString(l); n > cols {
			cols = n
		}
	}
	w := padX*2 + float64(cols)*charW
	h := topBar + padY*2 + float64(len(lines))*lineH
	fmt.Printf(`<svg xmlns="http://www.w3.org/2000/svg" width="%.0f" height="%.0f" viewBox="0 0 %.0f %.0f" role="img" aria-label="%s">
<title>%s</title>
<rect width="100%%" height="100%%" rx="12" fill="#0d1117" stroke="#30363d"/>
<rect width="100%%" height="%.0f" rx="12" fill="#161b22"/><rect y="%.0f" width="100%%" height="12" fill="#161b22"/>
<circle cx="22" cy="19" r="6" fill="#ff5f57"/><circle cx="42" cy="19" r="6" fill="#febc2e"/><circle cx="62" cy="19" r="6" fill="#28c840"/>
<text x="%.0f" y="24" fill="#8b949e" font-family="-apple-system,'Segoe UI',Helvetica,Arial,sans-serif" font-size="13" text-anchor="middle">%s</text>
<g font-family="'SF Mono',Menlo,Consolas,'Liberation Mono',monospace" font-size="13.5" xml:space="preserve" style="white-space:pre">
`, w, h, w, h, esc(*title), esc(*title), topBar, topBar-12, w/2, esc(*title))
	for i, l := range lines {
		y := topBar + padY + float64(i+1)*lineH - 5
		// Non-breaking spaces keep column alignment; SVG renderers collapse normal runs of spaces.
		fmt.Printf(`<text x="%.0f" y="%.0f" fill="%s">%s</text>`+"\n", padX, y, colour(l), strings.ReplaceAll(esc(l), " ", " "))
	}
	fmt.Println("</g>\n</svg>")
}
