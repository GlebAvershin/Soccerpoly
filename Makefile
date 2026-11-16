ROJO ?= rojo
LUAU ?= luau
COMPILE ?= luau-compile
ANALYZE ?= luau-analyze

.PHONY: test build verify
test:
	"$(COMPILE)" --null src tests
	"$(ANALYZE)" src/shared/Board.luau src/shared/Rules.luau tests/match.test.luau
	"$(LUAU)" tests/match.test.luau

build:
	mkdir -p dist
	"$(ROJO)" build -o dist/Footbolapolia.rbxl

verify: test build
	git diff --check
