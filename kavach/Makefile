BINARY := bin/kavach
VERSION := $(shell git describe --tags --always --dirty 2>/dev/null || echo "0.1.0")
COMMIT := $(shell git rev-parse --short HEAD 2>/dev/null || echo "dev")
LDFLAGS := -s -w -X main.version=$(VERSION) -X main.commit=$(COMMIT)

.PHONY: all build build-darwin-arm64 test lint selftest frames e2e-live clean

all: build test lint selftest

build:
	@mkdir -p bin
	CGO_ENABLED=0 go build -buildvcs=false -ldflags "$(LDFLAGS)" -o $(BINARY) ./cmd/kavach

build-darwin-arm64:
	@mkdir -p dist
	CGO_ENABLED=0 GOOS=darwin GOARCH=arm64 go build -buildvcs=false -ldflags "$(LDFLAGS)" -o dist/kavach-darwin-arm64 ./cmd/kavach
	shasum -a 256 dist/kavach-darwin-arm64 > dist/kavach-darwin-arm64.sha256 2>/dev/null || sha256sum dist/kavach-darwin-arm64 > dist/kavach-darwin-arm64.sha256

test:
	go test -race ./...

lint:
	golangci-lint run

selftest: build
	./$(BINARY) selftest

frames: build
	@mkdir -p docs/frames
	@for tape in docs/tapes/*.tape; do \
		echo "Rendering $$tape..."; \
		VHS_NO_SANDBOX=1 PATH="$(CURDIR)/bin:$$PATH" vhs "$$tape"; \
	done

# Optional live test: consumes a few real Anthropic API tokens via `claude -p`.
e2e-live: build
	./scripts/e2e_live.sh "$(CURDIR)/$(BINARY)"

clean:
	rm -rf bin dist
