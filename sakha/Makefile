VERSION ?= 0.1.0
LDFLAGS := -s -w -X main.version=$(VERSION)

.PHONY: build install test selftest frames fmt-check

build:
	@mkdir -p bin
	CGO_ENABLED=0 go build -trimpath -ldflags "$(LDFLAGS)" -o bin/sakha ./cmd/sakha

install:
	go install -trimpath -ldflags "$(LDFLAGS)" ./cmd/sakha

test:
	go vet ./...
	go test -race ./...

selftest: build
	./bin/sakha selftest

fmt-check:
	@test -z "$$(gofmt -l .)" || (echo "Run gofmt on:"; gofmt -l .; exit 1)

# Renders docs/frames/*.svg from real command output in a throwaway home folder.
frames:
	./scripts/frames.sh
