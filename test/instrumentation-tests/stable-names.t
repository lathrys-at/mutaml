The name of a mutant holds the file, the top-level binding, the
mutation operator, a digest of the text it changes, and an ordinal. It
holds no line number and no counter over the file, so a function added
above another leaves the names of the mutants below it as they were.

  $ bash ../write_dune_files.sh

  $ export MUTAML_SEED=896745231
  $ export MUTAML_MUT_RATE=100

Start with one function:

  $ cat > test.ml <<'EOF'
  > let classify x = if x > 10 then "big" else "small"
  > let () = print_endline (classify 3)
  > EOF

  $ bash ../filter_dune_build.sh ./test.bc --instrument-with mutaml > before.txt

The three mutants of classify:

  $ grep -o '"test.ml:classify:[^"]*"' before.txt | sort -u > before-names.txt
  $ cat before-names.txt
  "test.ml:classify:compare-boundary:5a1dd3dc:0"
  "test.ml:classify:if-condition:4fbf3d15:0"
  "test.ml:classify:int-constant:3fe31e01:0"

The counter that named a mutant before this release. It is still in the
record, because it names the file that holds the output of a test run:

  $ tr '{' '\n' < _build/.mutaml/default/test.muts \
  >   | grep -o '"number":[0-9]*,"binding":"[a-z_]*"'
  "number":0,"binding":"classify"
  "number":1,"binding":"classify"
  "number":2,"binding":"classify"
  "number":3,"binding":"toplevel"

Now add a function above classify. Nothing inside classify changes:

  $ cat > test.ml <<'EOF'
  > let double x = x * 2
  > let classify x = if x > 10 then "big" else "small"
  > let () = print_endline (classify 3 ^ string_of_int (double 4))
  > EOF

  $ bash ../filter_dune_build.sh ./test.bc --instrument-with mutaml > after.txt

The names of the mutants of classify are the names they had:

  $ grep -o '"test.ml:classify:[^"]*"' after.txt | sort -u > after-names.txt
  $ diff before-names.txt after-names.txt && echo "the names did not move"
  the names did not move

The counter moved. Every mutant of classify now has a number two higher
than the number it had, so a list of mutants written by the old scheme
would name other code after this edit, and say nothing about it:

  $ tr '{' '\n' < _build/.mutaml/default/test.muts \
  >   | grep -o '"number":[0-9]*,"binding":"[a-z_]*"'
  "number":0,"binding":"double"
  "number":1,"binding":"double"
  "number":2,"binding":"classify"
  "number":3,"binding":"classify"
  "number":4,"binding":"classify"
  "number":5,"binding":"toplevel"
  "number":6,"binding":"toplevel"

Two mutants of one file never take one name. Two mutants that agree in
the file, the binding, the operator and the text differ in the ordinal,
which counts them from 0:

  $ cat > test.ml <<'EOF'
  > let pair b = (if b then 1 else 0, if b then 1 else 0)
  > let () = ignore (pair true)
  > EOF

  $ bash ../filter_dune_build.sh ./test.bc --instrument-with mutaml > twice.txt

  $ grep -o '"test.ml:pair:int-constant:[^"]*"' twice.txt | sort -u
  "test.ml:pair:int-constant:50c5a5ff:0"
  "test.ml:pair:int-constant:50c5a5ff:1"
  "test.ml:pair:int-constant:92be9951:0"
  "test.ml:pair:int-constant:92be9951:1"

A name holds only letters, digits and the characters `_`, `.`, `-`, `/`
and `:`. Every other character of a binding becomes `_`, so two
bindings can take one label: `f'` and `f_` are both `f_`, and the two
operators below are both `__`. Their mutants still take different
names, because the ordinal counts the mutants that agree in every
earlier field of the name:

  $ cat > test.ml <<'EOF'
  > let f_ x = x + 1
  > let f' x = x + 1
  > let ( +| ) a b = a * b
  > let ( *| ) a b = a * b
  > let () = ignore (f_ 1 + f' 1 + (2 +| 3) + (2 *| 3))
  > EOF

  $ bash ../filter_dune_build.sh ./test.bc --instrument-with mutaml > labels.txt

  $ grep -o '"test.ml:f_:[^"]*"' labels.txt | sort
  "test.ml:f_:arith-identity:2546bcf4:0"
  "test.ml:f_:arith-identity:2546bcf4:1"
  $ grep -o '"test.ml:__:[^"]*"' labels.txt | sort
  "test.ml:__:arith-operator:8e44960b:0"
  "test.ml:__:arith-operator:8e44960b:1"
