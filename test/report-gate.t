The report tool prints a mutation score and exits with an error when the
score is too low.

Make the source file that the mutations belong to, and the directory that
the report tool writes its mutated copies into:

  $ cat > lib.ml <<'EOF'
  > let f x = x + 1
  > EOF
  $ mkdir -p _mutations

Write a report in which one mutation failed and one timed out. A mutation
that timed out counts with the mutations that failed, so the score is 100
percent and the report tool exits with 0:

  $ cat > caught.json <<'EOF'
  > [ { "status" : 1,
  >     "mutant" : { "number" : 0, "binding" : "f", "kind" : "int-constant",
  >                  "original" : "1", "ordinal" : 0, "repl" : "2",
  >                  "loc" : { "loc_start" : { "pos_fname" : "lib.ml", "pos_lnum" : 1, "pos_bol" : 0, "pos_cnum" : 14 },
  >                            "loc_end"   : { "pos_fname" : "lib.ml", "pos_lnum" : 1, "pos_bol" : 0, "pos_cnum" : 15 },
  >                            "loc_ghost" : false } } },
  >   { "status" : 124,
  >     "mutant" : { "number" : 1, "binding" : "f", "kind" : "arith-operator",
  >                  "original" : "+", "ordinal" : 0, "repl" : "-",
  >                  "loc" : { "loc_start" : { "pos_fname" : "lib.ml", "pos_lnum" : 1, "pos_bol" : 0, "pos_cnum" : 12 },
  >                            "loc_end"   : { "pos_fname" : "lib.ml", "pos_lnum" : 1, "pos_bol" : 0, "pos_cnum" : 13 },
  >                            "loc_ghost" : false } } } ]
  > EOF

  $ mutaml-report --no-diff caught.json
  Attempting to read from caught.json...
  
  Mutaml report summary:
  ----------------------
  
   target                          #mutations      #failed      #timeouts      #passed 
   -------------------------------------------------------------------------------------
   lib.ml                                 2      50.0%    1    50.0%    1     0.0%    0
   =====================================================================================
  
  Mutation score: 100.0% (2 mutations: 1 failed, 1 timed out, 0 passed)

Write a report in which one mutation failed and one passed. The score is
50 percent. Without --fail-under the report tool demands 100 percent, so
it exits with 2:

  $ cat > survivor.json <<'EOF'
  > [ { "status" : 1,
  >     "mutant" : { "number" : 0, "binding" : "f", "kind" : "int-constant",
  >                  "original" : "1", "ordinal" : 0, "repl" : "2",
  >                  "loc" : { "loc_start" : { "pos_fname" : "lib.ml", "pos_lnum" : 1, "pos_bol" : 0, "pos_cnum" : 14 },
  >                            "loc_end"   : { "pos_fname" : "lib.ml", "pos_lnum" : 1, "pos_bol" : 0, "pos_cnum" : 15 },
  >                            "loc_ghost" : false } } },
  >   { "status" : 0,
  >     "mutant" : { "number" : 1, "binding" : "f", "kind" : "arith-operator",
  >                  "original" : "+", "ordinal" : 0, "repl" : "-",
  >                  "loc" : { "loc_start" : { "pos_fname" : "lib.ml", "pos_lnum" : 1, "pos_bol" : 0, "pos_cnum" : 12 },
  >                            "loc_end"   : { "pos_fname" : "lib.ml", "pos_lnum" : 1, "pos_bol" : 0, "pos_cnum" : 13 },
  >                            "loc_ghost" : false } } } ]
  > EOF

  $ mutaml-report --no-diff survivor.json
  Attempting to read from survivor.json...
  
  Mutaml report summary:
  ----------------------
  
   target                          #mutations      #failed      #timeouts      #passed 
   -------------------------------------------------------------------------------------
   lib.ml                                 2      50.0%    1     0.0%    0    50.0%    1
   =====================================================================================
  
  Mutation programs passing the test suite:
  -----------------------------------------
  
  Mutation "lib.ml-mutant1" passed (see "_mutations/lib.ml-mutant1.output")
  Mutation score: 50.0% (2 mutations: 1 failed, 0 timed out, 1 passed)
  The score is below 100%. Use --fail-under to accept a lower score.
  [2]

A score equal to the value of --fail-under is not below it, so the report
tool exits with 0:

  $ mutaml-report --no-diff --fail-under 50 survivor.json
  Attempting to read from survivor.json...
  
  Mutaml report summary:
  ----------------------
  
   target                          #mutations      #failed      #timeouts      #passed 
   -------------------------------------------------------------------------------------
   lib.ml                                 2      50.0%    1     0.0%    0    50.0%    1
   =====================================================================================
  
  Mutation programs passing the test suite:
  -----------------------------------------
  
  Mutation "lib.ml-mutant1" passed (see "_mutations/lib.ml-mutant1.output")
  Mutation score: 50.0% (2 mutations: 1 failed, 0 timed out, 1 passed)

A score below the value of --fail-under makes the report tool exit with 2:

  $ mutaml-report --no-diff --fail-under 50.1 survivor.json
  Attempting to read from survivor.json...
  
  Mutaml report summary:
  ----------------------
  
   target                          #mutations      #failed      #timeouts      #passed 
   -------------------------------------------------------------------------------------
   lib.ml                                 2      50.0%    1     0.0%    0    50.0%    1
   =====================================================================================
  
  Mutation programs passing the test suite:
  -----------------------------------------
  
  Mutation "lib.ml-mutant1" passed (see "_mutations/lib.ml-mutant1.output")
  Mutation score: 50.0% (2 mutations: 1 failed, 0 timed out, 1 passed)
  The score is below 50.1%.
  [2]

The value 0 accepts every score:

  $ mutaml-report --no-diff --fail-under 0 survivor.json
  Attempting to read from survivor.json...
  
  Mutaml report summary:
  ----------------------
  
   target                          #mutations      #failed      #timeouts      #passed 
   -------------------------------------------------------------------------------------
   lib.ml                                 2      50.0%    1     0.0%    0    50.0%    1
   =====================================================================================
  
  Mutation programs passing the test suite:
  -----------------------------------------
  
  Mutation "lib.ml-mutant1" passed (see "_mutations/lib.ml-mutant1.output")
  Mutation score: 50.0% (2 mutations: 1 failed, 0 timed out, 1 passed)

A mutation that a signal ended counts with the mutations that failed,
because the signal is a fault that the test suite found. The report
tool names it as well, because a signal ends a test process for a
reason that is not a failing test:

  $ cat > crashed.json <<'EOF'
  > [ { "status" : 1,
  >     "mutant" : { "number" : 0, "binding" : "f", "kind" : "int-constant",
  >                  "original" : "1", "ordinal" : 0, "repl" : "2",
  >                  "loc" : { "loc_start" : { "pos_fname" : "lib.ml", "pos_lnum" : 1, "pos_bol" : 0, "pos_cnum" : 14 },
  >                            "loc_end"   : { "pos_fname" : "lib.ml", "pos_lnum" : 1, "pos_bol" : 0, "pos_cnum" : 15 },
  >                            "loc_ghost" : false } } },
  >   { "status" : 139,
  >     "mutant" : { "number" : 1, "binding" : "f", "kind" : "arith-operator",
  >                  "original" : "+", "ordinal" : 0, "repl" : "-",
  >                  "loc" : { "loc_start" : { "pos_fname" : "lib.ml", "pos_lnum" : 1, "pos_bol" : 0, "pos_cnum" : 12 },
  >                            "loc_end"   : { "pos_fname" : "lib.ml", "pos_lnum" : 1, "pos_bol" : 0, "pos_cnum" : 13 },
  >                            "loc_ghost" : false } } } ]
  > EOF

  $ mutaml-report --no-diff crashed.json
  Attempting to read from crashed.json...
  
  Mutaml report summary:
  ----------------------
  
   target                          #mutations      #failed      #timeouts      #passed 
   -------------------------------------------------------------------------------------
   lib.ml                                 2     100.0%    2     0.0%    0     0.0%    0
   =====================================================================================
  
  Mutation programs that a signal ended:
  -------------------------------------
  
  Mutation "lib.ml-mutant1" ended with status 139 (see "_mutations/lib.ml-mutant1.output")
  
  Mutation score: 100.0% (2 mutations: 2 failed, 0 timed out, 0 passed)
