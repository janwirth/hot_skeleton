.PHONY: all build kompas test dev clean

all: build kompas

build:
	gleam build

kompas:
	bash scripts/build_kompas_js.sh

test:
	gleam test

dev:
	gleam dev

clean:
	rm -rf build kompas/build
