ROJO ?= rojo
LUAU ?= luau
COMPILE ?= luau-compile
ANALYZE ?= luau-analyze
PYTHON ?= python3

.PHONY: test build verify analytics native native-preview
test:
	"$(PYTHON)" scripts/event_studio.py check
	"$(COMPILE)" --null src tests analytics
	"$(ANALYZE)" src/shared/Board.luau src/shared/EventCards.luau src/shared/Experiment.luau src/shared/Rules.luau tests/match.test.luau tests/balance.test.luau analytics/simulate.luau
	"$(LUAU)" tests/match.test.luau
	"$(LUAU)" tests/balance.test.luau
	"$(PYTHON)" tests/analytics_test.py

build:
	mkdir -p dist
	"$(ROJO)" build -o dist/Footbolapolia.rbxl

analytics:
	mkdir -p .tools
	"$(LUAU)" analytics/simulate.luau > .tools/synthetic-events.jsonl
	"$(PYTHON)" analytics/pipeline.py --events .tools/synthetic-events.jsonl

native:
	"$(PYTHON)" scripts/native_preview.py

native-preview:
	"$(PYTHON)" scripts/native_preview.py --preview dist/analytics/cup-odds.ppm

verify: test build analytics native
	git diff --check
