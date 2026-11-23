.PHONY: up test lint frames

up:
	docker compose up --build

test:
	npm test
	python3 -m unittest discover -s backend/tests -v

lint:
	npm run lint
	@if command -v ruff >/dev/null 2>&1; then ruff check backend; fi
	@if command -v mypy >/dev/null 2>&1; then mypy backend/app; fi

frames:
	node scripts/capture_frames.mjs
