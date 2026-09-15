The report tool writes a report in the mutation-testing-elements format,
which a viewer of that format reads.

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

Ask for the report. Three of the four mutations were caught, so the
score is 75 percent and `--fail-under 75` accepts it:

  $ mutaml-report --no-diff --fail-under 75 --json-report mte.json > /dev/null

The report holds the source of each file and every mutation of it. The
version of the tool is left out here, so that a new release of mutaml
does not change this test:

  $ sed 's/"version": "[^"]*"/"version": "VERSION"/' mte.json
  {
    "schemaVersion": "2",
    "thresholds": { "high": 100, "low": 75 },
    "framework": { "name": "mutaml", "version": "VERSION" },
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
            "id": "lib.ml:f:int-constant:4fad8996:0",
            "mutatorName": "int-constant",
            "location": {
              "start": { "line": 1, "column": 15 },
              "end": { "line": 1, "column": 16 }
            },
            "status": "Survived",
            "replacement": "2"
          }
        ]
      },
      "other.ml": {
        "language": "ocaml",
        "source": "let g y = y - 2\n",
        "mutants": [
          {
            "id": "other.ml:g:arith-operator:b75cccd4:0",
            "mutatorName": "arith-operator",
            "location": {
              "start": { "line": 1, "column": 13 },
              "end": { "line": 1, "column": 14 }
            },
            "status": "Timeout",
            "replacement": "+"
          },
          {
            "id": "other.ml:g:int-constant:f3a90cdb:0",
            "mutatorName": "int-constant",
            "location": {
              "start": { "line": 1, "column": 15 },
              "end": { "line": 1, "column": 16 }
            },
            "status": "Killed",
            "replacement": "",
            "statusReason": "signal 11 ended the test process"
          }
        ]
      }
    }
  }

The low threshold of the report is the value of `--fail-under`. Without
that option it is 0:

  $ mutaml-report --no-diff --json-report no-limit.json > /dev/null
  [2]
  $ grep thresholds no-limit.json
    "thresholds": { "high": 100, "low": 0 },

A source file that changed, so that a mutation of it no longer fits the
text, goes into the report without its text. A viewer draws a mutation
over the text of its file, and the text is no longer the text that the
mutation changed:

  $ cat > lib.ml <<'EOF'
  > let f = 1
  > EOF
  $ mutaml-report --no-diff --fail-under 0 --json-report changed.json > /dev/null
  $ grep '"source"' changed.json
        "source": "",
        "source": "let g y = y - 2\n",

A mutation whose source file cannot be read keeps its place in the
report, and the file gets an empty source:

  $ rm lib.ml
  $ mutaml-report --no-diff --fail-under 0 --json-report gone.json > /dev/null
  $ grep '"source"' gone.json
        "source": "",
        "source": "let g y = y - 2\n",
