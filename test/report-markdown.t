The report tool writes a Markdown summary for the page of a CI job.

Make the two source files that the mutations belong to, and the
directory that the report tool writes its mutated copies into:

  $ cat > lib.ml <<'EOF'
  > let f x = x + 1
  > EOF
  $ cat > other.ml <<'EOF'
  > let g y = y - 2
  > EOF
  $ mkdir -p _mutations

Write a report that holds one mutation of each outcome. The mutation of
`lib.ml` that changes `+` into `-` failed, the one that changes `1` into
`2` passed, the mutation of `other.ml` that changes `-` into `+` timed
out, and the one that takes `2` away ended with signal 11:

  $ cat > mutaml-report.json <<'EOF'
  > [ { "status" : 1,
  >     "mutant" : { "number" : 0, "binding" : "f", "kind" : "arith-operator",
  >                  "original" : "+", "ordinal" : 0, "repl" : "-",
  >                  "loc" : { "loc_start" : { "pos_fname" : "lib.ml", "pos_lnum" : 1, "pos_bol" : 0, "pos_cnum" : 12 },
  >                            "loc_end"   : { "pos_fname" : "lib.ml", "pos_lnum" : 1, "pos_bol" : 0, "pos_cnum" : 13 },
  >                            "loc_ghost" : false } } },
  >   { "status" : 0,
  >     "mutant" : { "number" : 1, "binding" : "f", "kind" : "int-constant",
  >                  "original" : "1", "ordinal" : 0, "repl" : "2",
  >                  "loc" : { "loc_start" : { "pos_fname" : "lib.ml", "pos_lnum" : 1, "pos_bol" : 0, "pos_cnum" : 14 },
  >                            "loc_end"   : { "pos_fname" : "lib.ml", "pos_lnum" : 1, "pos_bol" : 0, "pos_cnum" : 15 },
  >                            "loc_ghost" : false } } },
  >   { "status" : 124,
  >     "mutant" : { "number" : 0, "binding" : "g", "kind" : "arith-operator",
  >                  "original" : "-", "ordinal" : 0, "repl" : "+",
  >                  "loc" : { "loc_start" : { "pos_fname" : "other.ml", "pos_lnum" : 1, "pos_bol" : 0, "pos_cnum" : 12 },
  >                            "loc_end"   : { "pos_fname" : "other.ml", "pos_lnum" : 1, "pos_bol" : 0, "pos_cnum" : 13 },
  >                            "loc_ghost" : false } } },
  >   { "status" : 139,
  >     "mutant" : { "number" : 1, "binding" : "g", "kind" : "int-constant",
  >                  "original" : "2", "ordinal" : 0, "repl" : null,
  >                  "loc" : { "loc_start" : { "pos_fname" : "other.ml", "pos_lnum" : 1, "pos_bol" : 0, "pos_cnum" : 14 },
  >                            "loc_end"   : { "pos_fname" : "other.ml", "pos_lnum" : 1, "pos_bol" : 0, "pos_cnum" : 15 },
  >                            "loc_ghost" : false } } } ]
  > EOF

Ask for the summary. Three of the four mutations were caught, so the
score is 75 percent and `--fail-under 75` accepts it:

  $ mutaml-report --no-diff --fail-under 75 --markdown summary.md > /dev/null

The summary holds the score, one row for each source file, a row for
the total, and the one mutation that passed with its name and its diff:

  $ cat summary.md
  # Mutation report
  
  Mutation score: 75.0% (4 mutants: 1 killed, 1 timed out, 1 crashed, 1 survived).
  
  | file | mutants | killed | timed out | crashed | survived |
  | --- | ---: | ---: | ---: | ---: | ---: |
  | `lib.ml` | 2 | 1 | 0 | 0 | 1 |
  | `other.ml` | 2 | 0 | 1 | 1 | 0 |
  | **total** | 4 | 1 | 1 | 1 | 1 |
  
  The score counts a killed mutant, a mutant that timed out and a
  mutant that a signal ended as caught.
  
  ## Survivors
  
  ### `lib.ml:f:int-constant:4fad8996:0`
  
  `lib.ml`, line 1.
  
  ```diff
  --- lib.ml
  +++ lib.ml (mutant lib.ml:f:int-constant:4fad8996:0)
  @@ -1 +1 @@
  -let f x = x + 1
  +let f x = x + 2
  ```

A mutation whose source file cannot be read keeps its place in the
summary, which says why it has no diff:

  $ rm lib.ml
  $ mutaml-report --no-diff --fail-under 0 --markdown gone.md > /dev/null
  $ sed -n '/^## Survivors/,$p' gone.md
  ## Survivors
  
  ### `lib.ml:f:int-constant:4fad8996:0`
  
  `lib.ml`, line 1.
  
  The source file `lib.ml` could not be read, so there is no diff here.
