SRC := $(wildcard src/*.*)
OUTDIR = ../server/priv/static
OUTPUT = $(OUTDIR)/client.js $(OUTDIR)/index.html $(OUTDIR)/client.css

.PHONY = devserver build watch test clean

devserver:
	gleam run -m lustre/dev start

$(OUTPUT): $(SRC)
	gleam run -m lustre/dev build --outdir=$(OUTDIR)

build: $(OUTPUT)

test: $(SRC)
	gleam test

watch:
	watchexec -w src --wrap-process none 'make test && make build'

clean:
	gleam clean
