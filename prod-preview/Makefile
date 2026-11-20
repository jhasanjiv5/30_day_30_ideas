.PHONY: up down test lint frames keys

up:
	docker compose up --build

down:
	docker compose down

test:
	npm test
	PYTHONPATH=. python3 -m unittest discover -s backend/tests -p "test_*.py"

lint:
	npm run lint
	@if command -v ruff >/dev/null 2>&1; then ruff check backend; else echo "ruff not installed; skipping"; fi

frames:
	node scripts/capture_frames.mjs

keys:
	node scripts/setup_keys.mjs
