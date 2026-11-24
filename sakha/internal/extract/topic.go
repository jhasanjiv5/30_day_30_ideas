package extract

import (
	"regexp"
)

// topicWords scores which topic a sentence is about. Order matters for ties.
var topicWords = []struct {
	topic string
	re    *regexp.Regexp
}{
	{"ui-design", regexp.MustCompile(`(?i)\b(?:colou?rs?|palettes?|accents?|fonts?|typography|typefaces?|spacing|padding|margins?|layouts?|dark mode|light mode|themes?|buttons?|icons?|ui|ux|design|css|gradients?|shadows?|rounded|corners?|apple[- ]like|minimal(?:ist)?|cards?|headers?|banners?|contrast|hex|pastel|neon|saturat\w*|visuals?|charts?|slides? design|whitespace|grid|sans[- ]serif|serif|bold|blue|green|red|orange|purple|black|white|grey|gray)\b`)},
	{"writing-tone", regexp.MustCompile(`(?i)\b(?:tone|sentences?|wording|words?|phrases?|phrasing|writ(?:e|ing|ten)|formal|casual|concise|short|shorter|verbose|wordy|jargon|emojis?|exclamation|spelling|british|american|paragraphs?|bullets?|bullet points|headings?|prose|voice|passive|speak(?:ing)?|speech|talks?|presentations?|responses?|replies|reply|answers?|summar(?:y|ies)|explain|explanations?|plain language|oxford comma|dashes|em[- ]dash|capitali[sz]\w*|titles?)\b`)},
	{"coding", regexp.MustCompile(`(?i)\b(?:code|coding|functions?|variables?|naming|camel ?case|snake_case|tests?|unit tests?|typescript|javascript|python|golang|go code|swift|rust|java|kotlin|libraries|library|imports?|comments?|lint\w*|type hints?|types|async|errors?|error handling|refactor\w*|classes|class|apis?|dependenc\w+|packages?|modules?|structs?|interfaces?|sql|regex|logging|docstrings?|tabs|spaces|indent\w*|semicolons?|quotes|pytest|unittest|jest|vitest|npm|pip|frameworks?|eval|keys?|secrets?)\b`)},
	{"workflow", regexp.MustCompile(`(?i)\b(?:commits?|committing|pr|prs|pull requests?|branch(?:es)?|push(?:ing)?|plans?|planning|ask(?:ing)? (?:me|first|before)|confirm\w*|steps?|todos?|deploy\w*|review\w*|recaps?|merge\w*|ticket|issue|standup|meetings?|tasks?|checklists?|first|before you|after you|wrap[- ]up)\b`)},
	{"domain", regexp.MustCompile(`(?i)\b(?:my (?:project|company|team|product|startup|thesis|research|lab|client)|our (?:project|company|team|product|users|customers)|stands for|is called|we call|means|acronym|glossary)\b`)},
}

// Classify returns the best-matching topic for text, or def if nothing matches.
func Classify(text, def string) string {
	best, bestN := def, 0
	for _, tw := range topicWords {
		n := len(tw.re.FindAllStringIndex(text, -1))
		if tw.topic == "domain" && n > 0 {
			n += 2 // domain cues are rare and specific
		}
		if n > bestN {
			best, bestN = tw.topic, n
		}
	}
	return best
}
