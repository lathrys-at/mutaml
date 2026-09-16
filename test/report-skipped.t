The attribute `[@mutaml.skip "reason"]` takes a place out of the run.
The preprocessor makes no mutation there, the runner carries the place
from the `.muts` file into its report file, and all three reports name
the place and its reason. A skipped place is outside the score.

Make the two source files, and the directory that the report tool
writes its mutated copies into:

  $ cat > lib.ml <<'EOF'
  > let f x = x + 1
  > EOF
  $ cat > other.ml <<'EOF'
  > let g y = y - 2
  > EOF
  $ mkdir -p _mutations

Write a report file that holds one mutant of `lib.ml` that the test
suite killed, one skipped place in `lib.ml`, and one skipped place in
`other.ml`. No mutant of `other.ml` ran, so that file is in the report
for its skipped place alone:

  $ cat > mutaml-report.json <<'EOF'
  > { "results" :
  > [ { "status" : 1,
  >     "mutant" : { "number" : 0, "binding" : "f", "kind" : "arith-operator",
  >                  "original" : "+", "ordinal" : 0, "repl" : "-",
  >                  "loc" : { "loc_start" : { "pos_fname" : "lib.ml", "pos_lnum" : 1, "pos_bol" : 0, "pos_cnum" : 12 },
  >                            "loc_end"   : { "pos_fname" : "lib.ml", "pos_lnum" : 1, "pos_bol" : 0, "pos_cnum" : 13 },
  >                            "loc_ghost" : false } } } ],
  >   "skipped" :
  > [ { "binding" : "f", "reason" : "the caller never reads this number",
  >     "original" : "x + 1", "ordinal" : 0,
  >     "kinds" : [ "arith-operator", "int-constant" ],
  >     "loc" : { "loc_start" : { "pos_fname" : "lib.ml", "pos_lnum" : 1, "pos_bol" : 0, "pos_cnum" : 10 },
  >               "loc_end"   : { "pos_fname" : "lib.ml", "pos_lnum" : 1, "pos_bol" : 0, "pos_cnum" : 15 },
  >               "loc_ghost" : false } },
  >   { "binding" : "g", "reason" : "no test reads this", "original" : "y - 2",
  >     "ordinal" : 0, "kinds" : [],
  >     "loc" : { "loc_start" : { "pos_fname" : "other.ml", "pos_lnum" : 1, "pos_bol" : 0, "pos_cnum" : 10 },
  >               "loc_end"   : { "pos_fname" : "other.ml", "pos_lnum" : 1, "pos_bol" : 0, "pos_cnum" : 15 },
  >               "loc_ghost" : false } } ] }
  > EOF

The console report names each skipped place, with its reason and with
the operators that the attribute takes out of it. The score counts the
one mutant and neither place:

  $ mutaml-report --no-diff --json-report report.json --markdown summary.md
  Attempting to read from mutaml-report.json...
  Writing the Markdown summary to summary.md
  Writing the JSON report to report.json
  
  Mutaml report summary:
  ----------------------
  
   target                          #mutations      #failed      #timeouts      #passed 
   -------------------------------------------------------------------------------------
   lib.ml                                 1     100.0%    1     0.0%    0     0.0%    0
   =====================================================================================
  
  Places that the attribute took out of the run:
  ----------------------------------------------
  
  "lib.ml", line 1: the caller never reads this number
    The attribute takes these operators out of this place: arith-operator, int-constant.
  "other.ml", line 1: no test reads this
    The attribute takes no operator out of this place.
  
  Mutation score: 100.0% (1 mutations: 1 failed, 0 timed out, 0 passed)

The Markdown summary holds the places in a section of their own. The
table above that section counts mutants only, so `other.ml` has no row
in it:

  $ cat summary.md
  # Mutation report
  
  Mutation score: 100.0% (1 mutant: 1 killed, 0 timed out, 0 crashed, 0 survived).
  
  | file | mutants | killed | timed out | crashed | survived |
  | --- | ---: | ---: | ---: | ---: | ---: |
  | `lib.ml` | 1 | 1 | 0 | 0 | 0 |
  
  The score counts a killed mutant, a mutant that timed out and a
  mutant that a signal ended as caught.
  
  ## Survivors
  
  The test suite caught every mutant.
  
  ## Skipped places
  
  The attribute `[@mutaml.skip]` takes 2 places out of this run. A
  skipped place has no mutant, so it is outside the score and in no
  row of the table above.
  
  ### `lib.ml:f:skip:9ba3ed94:0`
  
  `lib.ml`, line 1.
  
  The reason: the caller never reads this number
  
  The attribute takes these operators out of this place: arith-operator, int-constant.
  
  ### `other.ml:g:skip:9816fe69:0`
  
  `other.ml`, line 1.
  
  The reason: no test reads this
  
  The attribute takes no operator out of this place.

The JSON report gives each place the status `Ignored`, the reason in
`statusReason`, and the operator name `skip`. The viewer leaves a
mutant of that status out of every count:

  $ cat report.json
  {
    "schemaVersion": "2",
    "thresholds": { "high": 100, "low": 0 },
    "framework": { "name": "mutaml", "version": "0.3" },
    "files": {
      "lib.ml": {
        "language": "ocaml",
        "source": "let f x = x + 1\n",
        "mutants": [
          {
            "id": "lib.ml:f:arith-operator:b614c1c7:0",
            "mutatorName": "arith-operator",
            "location": {
              "start": { "line": 1, "column": 13 },
              "end": { "line": 1, "column": 14 }
            },
            "status": "Killed",
            "replacement": "-"
          },
          {
            "id": "lib.ml:f:skip:9ba3ed94:0",
            "mutatorName": "skip",
            "location": {
              "start": { "line": 1, "column": 11 },
              "end": { "line": 1, "column": 16 }
            },
            "status": "Ignored",
            "statusReason": "the caller never reads this number",
            "description": "The attribute takes these operators out of this place: arith-operator, int-constant."
          }
        ]
      },
      "other.ml": {
        "language": "ocaml",
        "source": "let g y = y - 2\n",
        "mutants": [
          {
            "id": "other.ml:g:skip:9816fe69:0",
            "mutatorName": "skip",
            "location": {
              "start": { "line": 1, "column": 11 },
              "end": { "line": 1, "column": 16 }
            },
            "status": "Ignored",
            "statusReason": "no test reads this",
            "description": "The attribute takes no operator out of this place."
          }
        ]
      }
    }
  }

Take the two places away, and the console report has no section for
them:

  $ cat > no-skip.json <<'EOF'
  > { "results" :
  > [ { "status" : 1,
  >     "mutant" : { "number" : 0, "binding" : "f", "kind" : "arith-operator",
  >                  "original" : "+", "ordinal" : 0, "repl" : "-",
  >                  "loc" : { "loc_start" : { "pos_fname" : "lib.ml", "pos_lnum" : 1, "pos_bol" : 0, "pos_cnum" : 12 },
  >                            "loc_end"   : { "pos_fname" : "lib.ml", "pos_lnum" : 1, "pos_bol" : 0, "pos_cnum" : 13 },
  >                            "loc_ghost" : false } } } ] }
  > EOF
  $ mutaml-report --no-diff --markdown no-skip.md no-skip.json
  Attempting to read from no-skip.json...
  Writing the Markdown summary to no-skip.md
  
  Mutaml report summary:
  ----------------------
  
   target                          #mutations      #failed      #timeouts      #passed 
   -------------------------------------------------------------------------------------
   lib.ml                                 1     100.0%    1     0.0%    0     0.0%    0
   =====================================================================================
  
  Mutation score: 100.0% (1 mutations: 1 failed, 0 timed out, 0 passed)

The Markdown summary still has the section, and says that no attribute
took a place out of the run:

  $ tail -n 3 no-skip.md
  ## Skipped places
  
  No attribute takes a place out of this run.
