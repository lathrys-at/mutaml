mutaml-runner --changed-since <rev> tests only the mutations that sit on
a line that the project changed since <rev>. It asks git which lines
those are. Every other mutation is recorded as not run, and the reports
leave it out of the mutation score.

Make a git repository of its own for this test, so that it does not read
the repository that holds mutaml:

  $ git init -q -b main .
  $ git config user.email mutaml@example.com
  $ git config user.name mutaml
  $ git config commit.gpgsign false

Write a source file with two functions, one on each line, and commit it:

  $ cat > lib.ml <<'EOF'
  > let f x = x + 1
  > let g x = x - 2
  > EOF
  $ git add lib.ml
  $ git commit -q -m "the first version of lib.ml"

Change the second line, and leave the first as it was. This is the state
that the build would instrument:

  $ cat > lib.ml <<'EOF'
  > let f x = x + 1
  > let g x = x * 2
  > EOF

Write the files that the preprocessor writes: one mutation on line 1 and
one on line 2. The runner reads them; it does not read the source file:

  $ mkdir -p _build/.mutaml/default
  $ cat > _build/.mutaml/default/lib.muts <<'EOF'
  > { "mutants" :
  >   [ { "number" : 0, "binding" : "f", "kind" : "int-constant",
  >       "original" : "1", "ordinal" : 0, "repl" : "2",
  >       "loc" : { "loc_start" : { "pos_fname" : "lib.ml", "pos_lnum" : 1, "pos_bol" : 0, "pos_cnum" : 14 },
  >                 "loc_end"   : { "pos_fname" : "lib.ml", "pos_lnum" : 1, "pos_bol" : 0, "pos_cnum" : 15 },
  >                 "loc_ghost" : false } },
  >     { "number" : 1, "binding" : "g", "kind" : "int-constant",
  >       "original" : "2", "ordinal" : 0, "repl" : "3",
  >       "loc" : { "loc_start" : { "pos_fname" : "lib.ml", "pos_lnum" : 2, "pos_bol" : 16, "pos_cnum" : 30 },
  >                 "loc_end"   : { "pos_fname" : "lib.ml", "pos_lnum" : 2, "pos_bol" : 16, "pos_cnum" : 31 },
  >                 "loc_ghost" : false } } ],
  >   "skipped" : [] }
  > EOF
  $ cat > _build/.mutaml/default/mutaml-mut-files.txt <<'EOF'
  > lib.muts
  > EOF

Write a stand-in test suite that lets every mutation live:

  $ cat > tests.sh <<'EOF'
  > #!/bin/sh
  > echo "MUTAML_MUTANT=[$MUTAML_MUTANT]"
  > exit 0
  > EOF
  $ chmod +x tests.sh

Without the option, the runner tests both mutations:

  $ mutaml-runner ./tests.sh
  read mut file lib.muts
  Testing without a mutant ... passed
  The limit of a test run is 5 times the run without a mutant, and never less than 10 seconds.
  Testing mutant lib.ml:f:int-constant:4fad8996:0 ... passed
  Testing mutant lib.ml:g:int-constant:626aba84:0 ... passed
  Writing report data to mutaml-report.json

With the option, only the mutation on the line that changed is tested:

  $ rm -rf _mutations mutaml-report.json
  $ mutaml-runner --changed-since HEAD ./tests.sh
  read mut file lib.muts
  1 of the 2 mutations sits on a line that changed since HEAD. The other one is not tested.
  Testing without a mutant ... passed
  The limit of a test run is 5 times the run without a mutant, and never less than 10 seconds.
  Testing mutant lib.ml:g:int-constant:626aba84:0 ... passed
  Writing report data to mutaml-report.json

The mutation that did not run is in the report file, with the field that
says it did not run:

  $ grep -o '"not_run":[a-z]*' mutaml-report.json
  "not_run":true

The report names it in a column of its own, and leaves it out of the
score. One of the mutations that ran lived, so the score is 0 percent:

  $ mutaml-report --no-diff
  Attempting to read from mutaml-report.json...
  
  Mutaml report summary:
  ----------------------
  
   target                          #mutations      #failed      #timeouts      #passed       #not run
   ---------------------------------------------------------------------------------------------------
   lib.ml                                 2       0.0%    0     0.0%    0   100.0%    1             1
   ===================================================================================================
  
  Mutation programs passing the test suite:
  -----------------------------------------
  
  Mutation "lib.ml-mutant1" passed (see "_mutations/lib.ml-mutant1.output")
  Mutation score: 0.0% (1 mutations: 0 failed, 0 timed out, 1 passed; 1 did not run)
  The score is below 100%. Use --fail-under to accept a lower score.
  [2]

The JSON report gives the mutation that did not run the status Ignored,
which the viewer of that format leaves out of every count, with a reason
beside it:

  $ mutaml-report --no-diff --fail-under 0 --json-report report.json > /dev/null
  $ grep -o '"status": "[A-Za-z]*"' report.json
  "status": "Ignored"
  "status": "Survived"
  $ grep -o '"statusReason": "[^"]*"' report.json
  "statusReason": "the mutation does not sit on a line that changed since the revision that mutaml-runner was given"

The Markdown summary has the column too:

  $ mutaml-report --no-diff --fail-under 0 --markdown summary.md > /dev/null
  $ sed -n '/^| file/,/^| `lib/p' summary.md
  | file | mutants | killed | timed out | crashed | survived | not run |
  | --- | ---: | ---: | ---: | ---: | ---: | ---: |
  | `lib.ml` | 2 | 0 | 0 | 0 | 1 | 1 |

A change that touches no file that holds a mutation leaves nothing to
test. The runner says so, runs no test at all, and writes a report in
which every mutation did not run. A run that quietly reports a clean
score over no mutation is the failure this line is here to stop:

  $ git add lib.ml
  $ git commit -q -m "the second version of lib.ml"
  $ echo "a note about the project" > notes.txt
  $ git add notes.txt
  $ rm -rf _mutations mutaml-report.json
  $ mutaml-runner --changed-since HEAD ./tests.sh
  read mut file lib.muts
  No mutation sits on a line that changed since HEAD. None of the 2 mutations is tested.
  Writing report data to mutaml-report.json

The runner ran no test, so it wrote no output of a run:

  $ test -e _mutations/baseline-1.output
  [1]

The report says that there is no score, and it does not end the build:

  $ mutaml-report --no-diff
  Attempting to read from mutaml-report.json...
  
  Mutaml report summary:
  ----------------------
  
   target                          #mutations      #failed      #timeouts      #passed       #not run
   ---------------------------------------------------------------------------------------------------
   lib.ml                                 2       0.0%    0     0.0%    0     0.0%    0             2
   ===================================================================================================
  
  No mutation ran, so this run has no mutation score. Every one of the 2 mutations was left out.

The Markdown summary says the same, and it does not say that the test
suite caught every mutant, because it caught none:

  $ mutaml-report --no-diff --markdown nothing.md > /dev/null
  $ sed -n '1,4p' nothing.md
  # Mutation report
  
  No mutant ran, so this run has no mutation score. Every one of the 2 mutants was left out.
  
  $ sed -n '/^## Survivors/,$p' nothing.md
  ## Survivors
  
  No mutant ran, so there is no survivor to name.
  
  ## Skipped places
  
  No attribute takes a place out of this run.

A source file that git does not track is in no diff against a
revision, so every line of it counts as changed. A new file is the code
that most wants testing, and it must not go untested because nobody ran
git add. Add a second source file with one mutation, and do not add it
to git:

  $ cat > new.ml <<'EOF'
  > let h x = x + 5
  > EOF
  $ cat > _build/.mutaml/default/new.muts <<'EOF'
  > { "mutants" :
  >   [ { "number" : 0, "binding" : "h", "kind" : "int-constant",
  >       "original" : "5", "ordinal" : 0, "repl" : "6",
  >       "loc" : { "loc_start" : { "pos_fname" : "new.ml", "pos_lnum" : 1, "pos_bol" : 0, "pos_cnum" : 14 },
  >                 "loc_end"   : { "pos_fname" : "new.ml", "pos_lnum" : 1, "pos_bol" : 0, "pos_cnum" : 15 },
  >                 "loc_ghost" : false } } ],
  >   "skipped" : [] }
  > EOF
  $ cat > _build/.mutaml/default/mutaml-mut-files.txt <<'EOF'
  > lib.muts
  > new.muts
  > EOF
  $ git status --short new.ml
  ?? new.ml
  $ rm -rf _mutations mutaml-report.json
  $ mutaml-runner --changed-since HEAD ./tests.sh
  read mut file lib.muts
  read mut file new.muts
  1 of the 3 mutations sits on a line that changed since HEAD. The other 2 are not tested.
  Testing without a mutant ... passed
  The limit of a test run is 5 times the run without a mutant, and never less than 10 seconds.
  Testing mutant new.ml:h:int-constant:6311d79c:0 ... passed
  Writing report data to mutaml-report.json

Put the list of mutation files back as it was:

  $ rm new.ml _build/.mutaml/default/new.muts
  $ cat > _build/.mutaml/default/mutaml-mut-files.txt <<'EOF'
  > lib.muts
  > EOF

A revision that git does not know stops the runner with a message:

  $ mutaml-runner --changed-since no-such-revision ./tests.sh
  read mut file lib.muts
  git could not do "git -c core.quotePath=false diff --no-ext-diff --no-textconv --dst-prefix=b/ --unified=0 no-such-revision --". Check that the revision is one that git knows, and that this directory is in a git repository.
  [1]

A git that cannot start stops the runner with a message of its own. A
command that a shell cannot find answers the status 127, and the
stand-in below answers that status:

  $ mkdir -p nogit
  $ cat > nogit/git <<'EOF'
  > #!/bin/sh
  > exit 127
  > EOF
  $ chmod +x nogit/git
  $ PATH="$(pwd)/nogit:$PATH" mutaml-runner --changed-since HEAD ./tests.sh
  read mut file lib.muts
  Could not run git, which --changed-since needs to find the lines that changed - the command git is not on PATH
  [1]
