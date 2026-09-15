The runner runs the test suite without a mutant before it runs any mutant.
It gives every test process the variables that --test-env names, and it
stops a test run that takes longer than --timeout.

Write the files that the preprocessor writes: a mutation file for lib.ml,
and the list of mutation files.

  $ mkdir -p _build/.mutaml/default
  $ cat > lib.ml <<'EOF'
  > let f x = x + 1
  > EOF
  $ cat > _build/.mutaml/default/lib.muts <<'EOF'
  > [ { "number" : 0, "binding" : "f", "kind" : "int-constant",
  >     "original" : "1", "ordinal" : 0, "repl" : "2",
  >     "loc" : { "loc_start" : { "pos_fname" : "lib.ml", "pos_lnum" : 1, "pos_bol" : 0, "pos_cnum" : 14 },
  >               "loc_end"   : { "pos_fname" : "lib.ml", "pos_lnum" : 1, "pos_bol" : 0, "pos_cnum" : 15 },
  >               "loc_ghost" : false } },
  >   { "number" : 1, "binding" : "f", "kind" : "arith-operator",
  >     "original" : "+", "ordinal" : 0, "repl" : "-",
  >     "loc" : { "loc_start" : { "pos_fname" : "lib.ml", "pos_lnum" : 1, "pos_bol" : 0, "pos_cnum" : 12 },
  >               "loc_end"   : { "pos_fname" : "lib.ml", "pos_lnum" : 1, "pos_bol" : 0, "pos_cnum" : 13 },
  >               "loc_ghost" : false } } ]
  > EOF
  $ cat > _build/.mutaml/default/mutaml-mut-files.txt <<'EOF'
  > lib.muts
  > EOF

Write a stand-in test suite. It prints the two variables that it reads,
and it fails for the first of the two mutants only. A mutant is named by
its file, the binding it sits in, the mutation operator that made it, a
digest of the text it changes, and an ordinal:

  $ cat > tests.sh <<'EOF'
  > #!/bin/sh
  > echo "MUTAML_MUTANT=[$MUTAML_MUTANT] QCHECK_SEED=[$QCHECK_SEED]"
  > case "$MUTAML_MUTANT" in
  >   lib.ml:f:int-constant:4fad8996:0) exit 3 ;;
  >   *)     exit 0 ;;
  > esac
  > EOF
  $ chmod +x tests.sh

The runner tests the suite once without a mutant, and then once for each
mutant. The suite fails for the int-constant mutant, which means that the
suite killed it. The suite passes for the arith-operator mutant, which
means that the arith-operator mutant survived:

  $ mutaml-runner --test-env QCHECK_SEED=7 ./tests.sh
  read mut file lib.muts
  Testing without a mutant ... passed
  The limit of a test run is 5 times the run without a mutant, and never less than 10 seconds.
  Testing mutant lib.ml:f:int-constant:4fad8996:0 ... failed
  Testing mutant lib.ml:f:arith-operator:b614c1c7:0 ... passed
  Writing report data to mutaml-report.json

The run without a mutant had the variable set:

  $ cat _mutations/baseline-1.output
  MUTAML_MUTANT=[] QCHECK_SEED=[7]

There was no second run without a mutant, because --baseline-env was not
given:

  $ test -e _mutations/baseline-2.output
  [1]

--baseline-env asks for a second run without a mutant, with the
variables it names set on top of the ones --test-env names. A test suite
that passes under one seed and fails under another gives a mutation
score no meaning, and this finds that out before the mutants run:

  $ mutaml-runner --test-env QCHECK_SEED=7 --baseline-env QCHECK_SEED=8 ./tests.sh
  read mut file lib.muts
  Testing without a mutant ... passed
  Testing without a mutant a second time ... passed
  The limit of a test run is 5 times the run without a mutant, and never less than 10 seconds.
  Testing mutant lib.ml:f:int-constant:4fad8996:0 ... failed
  Testing mutant lib.ml:f:arith-operator:b614c1c7:0 ... passed
  Writing report data to mutaml-report.json
  $ cat _mutations/baseline-1.output
  MUTAML_MUTANT=[] QCHECK_SEED=[7]
  $ cat _mutations/baseline-2.output
  MUTAML_MUTANT=[] QCHECK_SEED=[8]

The runner writes the variables it set beside the result of each mutant:

  $ grep -o '"test_env":[^]]*]]' mutaml-report.json
  "test_env":[["QCHECK_SEED","7"]]
  "test_env":[["QCHECK_SEED","7"]]

The runner names the output of a mutant after the source file that the
mutant belongs to:

  $ ls _mutations
  baseline-1.output
  baseline-2.output
  lib.ml-mutant0.output
  lib.ml-mutant1.output

A path to a mutation file that starts at the root of the file system
gives the same mutant names, and the same results:

  $ rm -rf _mutations mutaml-report.json
  $ mutaml-runner --muts "$(pwd)/_build/.mutaml/default/lib.muts" --test-env QCHECK_SEED=7 ./tests.sh
  Testing without a mutant ... passed
  The limit of a test run is 5 times the run without a mutant, and never less than 10 seconds.
  Testing mutant lib.ml:f:int-constant:4fad8996:0 ... failed
  Testing mutant lib.ml:f:arith-operator:b614c1c7:0 ... passed
  Writing report data to mutaml-report.json

The runner stops a test run that takes longer than the limit, and it
tells such a run from a run that a signal ended. The suite below ends
itself with the signal SEGV for the int-constant mutant. For the
arith-operator mutant it starts a second program, which writes a file
six seconds later, and then waits for half a minute. The limit of three
seconds stops that run:

  $ cat > mixed.sh <<'EOF'
  > #!/bin/sh
  > case "$MUTAML_MUTANT" in
  >   lib.ml:f:int-constant:4fad8996:0) kill -s SEGV $$ ;;
  >   lib.ml:f:arith-operator:b614c1c7:0)
  >     (sleep 6; echo "left behind" > lingering.txt) &
  >     sleep 30 ;;
  >   *)     exit 0 ;;
  > esac
  > EOF
  $ chmod +x mixed.sh
  $ mutaml-runner --timeout 3 ./mixed.sh
  read mut file lib.muts
  Testing without a mutant ... passed
  The limit of a test run is 3 seconds.
  Testing mutant lib.ml:f:int-constant:4fad8996:0 ... crashed
  Testing mutant lib.ml:f:arith-operator:b614c1c7:0 ... timeout
  Writing report data to mutaml-report.json

The shell prints a line of its own when a test process dies by a signal.
That line goes to the output file of the mutant, with the rest of what
the run wrote, and not to the output of the runner:

  $ grep -qi "segmentation fault" _mutations/lib.ml-mutant0.output && echo "the output file holds the line"
  the output file holds the line

The runner stops the other programs that a test run started, and not
only the test command itself. Five seconds later, which is more than the
six seconds that the second program waited for, its file is still not
there:

  $ sleep 5
  $ test -e lingering.txt
  [1]

The runner sends the signal TERM to a run that reaches its limit, and
the signal KILL two seconds later. The test command below does not
answer the signal TERM, so only the signal KILL ends it. The command is
a line of shell and not the path of a script, which the runner reads the
same way:

  $ mutaml-runner --muts lib.muts --timeout 3 "trap '' TERM; while : ; do sleep 1; done"
  Testing without a mutant ... timeout
  The test suite did not pass without a mutant. Its exit status was 124.
  The output of the run is in _mutations/baseline-1.output.
  Every mutant would look killed, so mutaml-runner stops here.
  [1]

Without --timeout the limit follows the run without a mutant: five times
that run, and never less than ten seconds. The suite below takes three
seconds without a mutant, which gives a limit of fifteen seconds, and
eleven seconds for the mutant. A limit of ten seconds would stop the
mutant run; the limit that the measurement gives does not. One mutation
is enough to show it, so this test reads a mutation file of its own:

  $ cat > _build/.mutaml/default/one.muts <<'EOF'
  > [ { "number" : 0, "binding" : "f", "kind" : "int-constant",
  >     "original" : "1", "ordinal" : 0, "repl" : "2",
  >     "loc" : { "loc_start" : { "pos_fname" : "lib.ml", "pos_lnum" : 1, "pos_bol" : 0, "pos_cnum" : 14 },
  >               "loc_end"   : { "pos_fname" : "lib.ml", "pos_lnum" : 1, "pos_bol" : 0, "pos_cnum" : 15 },
  >               "loc_ghost" : false } } ]
  > EOF
  $ cat > slow.sh <<'EOF'
  > #!/bin/sh
  > case "$MUTAML_MUTANT" in
  >   "")    sleep 3 ;;
  >   *)     sleep 11 ;;
  > esac
  > EOF
  $ chmod +x slow.sh
  $ mutaml-runner --muts one.muts ./slow.sh
  Testing without a mutant ... passed
  The limit of a test run is 5 times the run without a mutant, and never less than 10 seconds.
  Testing mutant lib.ml:f:int-constant:4fad8996:0 ... passed
  Writing report data to mutaml-report.json

A test suite that fails without a mutant stops the run. Every mutant
would look killed, so a score would say nothing about the tests:

  $ cat > failing.sh <<'EOF'
  > #!/bin/sh
  > echo "Fatal error: cannot find the file fixtures/example.json"
  > exit 2
  > EOF
  $ chmod +x failing.sh
  $ rm -f mutaml-report.json
  $ mutaml-runner ./failing.sh
  read mut file lib.muts
  Testing without a mutant ... failed
  The test suite did not pass without a mutant. Its exit status was 2.
  The output of the run is in _mutations/baseline-1.output.
  Every mutant would look killed, so mutaml-runner stops here.
  [1]

The runner wrote no report, so no tool can report a score for this run:

  $ test -e mutaml-report.json
  [1]

A test suite that passes in one run without a mutant and fails in the
other also stops the run. The suite below fails for the seed 8:

  $ cat > flaky.sh <<'EOF'
  > #!/bin/sh
  > [ "$QCHECK_SEED" = "8" ] && exit 4
  > exit 0
  > EOF
  $ chmod +x flaky.sh
  $ mutaml-runner --test-env QCHECK_SEED=7 --baseline-env QCHECK_SEED=8 ./flaky.sh
  read mut file lib.muts
  Testing without a mutant ... passed
  Testing without a mutant a second time ... failed
  The test suite ran twice without a mutant. It passed in one run and not in the other.
  The output of the two runs is in _mutations/baseline-1.output and _mutations/baseline-2.output.
  The test suite does not give the same result every time, so a mutation score would have no meaning.
  [1]

The list of mutation files can name a file whose source file is gone,
because dune runs the preprocessor again only for a source file that
changed. The runner says so and tests the rest:

  $ sed -e 's/lib[.]ml/gone.ml/' _build/.mutaml/default/lib.muts > _build/.mutaml/default/gone.muts
  $ cat > _build/.mutaml/default/mutaml-mut-files.txt <<'EOF'
  > gone.muts
  > lib.muts
  > EOF
  $ mutaml-runner --test-env QCHECK_SEED=7 ./tests.sh
  read mut file gone.muts
  read mut file lib.muts
  Skipping gone.muts: the source file gone.ml does not exist
  Testing without a mutant ... passed
  The limit of a test run is 5 times the run without a mutant, and never less than 10 seconds.
  Testing mutant lib.ml:f:int-constant:4fad8996:0 ... failed
  Testing mutant lib.ml:f:arith-operator:b614c1c7:0 ... passed
  Writing report data to mutaml-report.json

When no mutation file is left, the runner stops, because a score over no
mutation at all would say nothing:

  $ cat > _build/.mutaml/default/mutaml-mut-files.txt <<'EOF'
  > gone.muts
  > EOF
  $ mutaml-runner --test-env QCHECK_SEED=7 ./tests.sh
  read mut file gone.muts
  Skipping gone.muts: the source file gone.ml does not exist
  No mutation file is left to test: every source file is gone
  [1]
