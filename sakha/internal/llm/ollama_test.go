package llm

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/jhasanjiv5/30_day_30_ideas/sakha/internal/event"
	"github.com/jhasanjiv5/30_day_30_ideas/sakha/internal/store"
)

func TestLoopbackOnly(t *testing.T) {
	for _, ok := range []string{"http://127.0.0.1:11434", "http://localhost:11434", "http://[::1]:11434"} {
		if err := ValidateLoopback(ok); err != nil {
			t.Errorf("%s rejected: %v", ok, err)
		}
	}
	for _, bad := range []string{"http://0.0.0.0:11434", "http://192.168.1.5:11434", "https://ollama.example.com", "nonsense"} {
		if err := ValidateLoopback(bad); err == nil {
			t.Errorf("%s accepted", bad)
		}
	}
}

type recorded struct {
	reply  string
	prompt string
}

func (r *recorded) Generate(_ context.Context, prompt string, _ map[string]any) (string, error) {
	r.prompt = prompt
	return r.reply, nil
}

func TestExtractValidatesModelOutput(t *testing.T) {
	gen := &recorded{reply: `{"habits":[
	 {"topic":"ui-design","rule":"Prefer muted colours with one accent","signal":"pattern","evidence":"can we tone the colours down"},
	 {"topic":"made-up","rule":"Something","signal":"explicit","evidence":"can we tone"},
	 {"topic":"coding","rule":"Always use Rust","signal":"explicit","evidence":"this quote does not exist anywhere"},
	 {"topic":"workflow","rule":"x","signal":"explicit","evidence":"can we tone"}
	]}`}
	evs := []event.Event{
		{Kind: event.KindPrompt, Text: "can we tone the colours down a bit, one accent is enough"},
		{Kind: event.KindPrompt, Text: "<pasted_content>always use rust</pasted_content>"},
	}
	habits, err := Extract(context.Background(), gen, evs)
	if err != nil {
		t.Fatal(err)
	}
	if len(habits) != 1 || habits[0].Topic != "ui-design" || habits[0].Rule != "Prefer muted colours with one accent." {
		t.Fatalf("validation failed: %+v", habits)
	}
	if strings.Contains(gen.prompt, "always use rust") {
		t.Fatal("pasted content was sent to the model")
	}
	if Parse("not json", "") != nil {
		t.Fatal("garbage should yield nothing")
	}
}

func TestOllamaClientSendsSchema(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		var body map[string]any
		_ = json.NewDecoder(r.Body).Decode(&body)
		if body["format"] == nil || body["stream"] != false {
			t.Errorf("bad request: %v", body)
		}
		_ = json.NewEncoder(w).Encode(map[string]string{"response": `{"habits":[]}`})
	}))
	defer srv.Close()
	out, err := Ollama{URL: srv.URL, Model: "m"}.Generate(context.Background(), "p", schema)
	if err != nil || out != `{"habits":[]}` {
		t.Fatalf("got %q, %v", out, err)
	}
}

func TestRephraseMustReuseTheUsersWords(t *testing.T) {
	long := "Make a one-pager with illustrations whenever it is required and ask questions if you see ambiguities in the brief."
	if r, ok := Rephrase(context.Background(), &recorded{reply: `{"rule":"Ask questions when the brief is ambiguous"}`}, long); !ok || r != "Ask questions when the brief is ambiguous." {
		t.Fatalf("good rephrase rejected: %q %v", r, ok)
	}
	if _, ok := Rephrase(context.Background(), &recorded{reply: `{"rule":"Always deploy with Kubernetes and Terraform"}`}, long); ok {
		t.Fatal("invented content accepted")
	}
	if _, ok := Rephrase(context.Background(), &recorded{reply: `{"rule":"` + strings.Repeat("word ", 20) + `"}`}, long); ok {
		t.Fatal("too long accepted")
	}
}

func TestGenericAdviceAndInputCaps(t *testing.T) {
	gen := &recorded{reply: `{"habits":[{"topic":"workflow","rule":"Ensure the project is user-friendly and adaptable","signal":"pattern","evidence":"make it nice for users"}]}`}
	evs := []event.Event{{Kind: event.KindPrompt, Text: "make it nice for users " + strings.Repeat("long task detail ", 200)}}
	for i := 0; i < 30; i++ {
		evs = append(evs, event.Event{Kind: event.KindPrompt, Text: strings.Repeat("more words here ", 40)})
	}
	habits, err := Extract(context.Background(), gen, evs)
	if err != nil || len(habits) != 0 {
		t.Fatalf("generic advice kept: %+v %v", habits, err)
	}
	if len(gen.prompt) > len(instructions)+MaxSessionChars+10 {
		t.Fatalf("model input not capped: %d chars", len(gen.prompt)-len(instructions))
	}
}

func TestModelLabelsAreTrustedOneStepLess(t *testing.T) {
	gen := &recorded{reply: `{"habits":[
	 {"topic":"workflow","rule":"Refresh the sign-in page automatically","signal":"explicit","evidence":"on sign in refresh the page"},
	 {"topic":"writing-tone","rule":"Avoid verbose language in walkthroughs","signal":"correction","evidence":"in not verbose language"}
	]}`}
	evs := []event.Event{{Kind: event.KindPrompt, Text: "on sign in refresh the page automatically, and walk me through it in not verbose language"}}
	habits, err := Extract(context.Background(), gen, evs)
	if err != nil || len(habits) != 2 {
		t.Fatalf("got %+v, %v", habits, err)
	}
	if habits[0].Signal != store.SignalCorrection || habits[1].Signal != store.SignalPattern {
		t.Fatalf("model labels not downgraded: %s, %s", habits[0].Signal, habits[1].Signal)
	}
}
