.PHONY: all clean test doc examples

all:
	dune build

clean:
	dune clean

doc:
	dune build @doc
