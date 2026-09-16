The runner tests more than one mutation at a time with -j, and it runs
the test command more than once for one mutation with --repeat.

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

Give the test processes a temporary directory of a name this test knows,
so that the lines below show which directory each test process was given:

  $ mkdir -p outer
  $ TMPDIR="$(pwd)/outer"
  $ export TMPDIR

Write a stand-in test suite. It prints the mutation it was given and the
last part of the path in TMPDIR. It fails for the int-constant mutation
only, and it takes a second for that one, so that the two mutations do
not end in the order of the list:

  $ cat > tests.sh <<'EOF'
  > #!/bin/sh
  > echo "MUTAML_MUTANT=[$MUTAML_MUTANT] TMPDIR=[$(basename "$TMPDIR")]"
  > case "$MUTAML_MUTANT" in
  >   lib.ml:f:int-constant:4fad8996:0) sleep 1; exit 3 ;;
  >   *)     exit 0 ;;
  > esac
  > EOF
  $ chmod +x tests.sh

With one job, which is the default, the runner leaves TMPDIR as it found
it:

  $ mutaml-runner ./tests.sh
  read mut file lib.muts
  Testing without a mutant ... passed
  The limit of a test run is 5 times the run without a mutant, and never less than 10 seconds.
  Testing mutant lib.ml:f:int-constant:4fad8996:0 ... failed
  Testing mutant lib.ml:f:arith-operator:b614c1c7:0 ... passed
  Writing report data to mutaml-report.json
  $ cat _mutations/lib.ml-mutant0.output
  MUTAML_MUTANT=[lib.ml:f:int-constant:4fad8996:0] TMPDIR=[outer]

With two jobs the two mutations run at the same time. The int-constant
mutation ends last, and the runner still prints the two lines in the
order of the mutation list:

  $ rm -rf _mutations mutaml-report.json
  $ mutaml-runner -j 2 ./tests.sh
  read mut file lib.muts
  Testing without a mutant ... passed
  The limit of a test run is 5 times the run without a mutant, and never less than 10 seconds.
  Testing mutant lib.ml:f:int-constant:4fad8996:0 ... failed
  Testing mutant lib.ml:f:arith-operator:b614c1c7:0 ... passed
  Writing report data to mutaml-report.json

Each of the two test processes had a temporary directory of its own, and
each wrote to the output file of the mutation it held:

  $ cat _mutations/lib.ml-mutant0.output
  MUTAML_MUTANT=[lib.ml:f:int-constant:4fad8996:0] TMPDIR=[job1]
  $ cat _mutations/lib.ml-mutant1.output
  MUTAML_MUTANT=[lib.ml:f:arith-operator:b614c1c7:0] TMPDIR=[job2]

The run without a mutation is not one of the jobs, so it kept the
temporary directory that the runner was given:

  $ cat _mutations/baseline-1.output
  MUTAML_MUTANT=[] TMPDIR=[outer]

The runner removed the temporary directories it made:

  $ test -e _mutations/tmp
  [1]

The report holds the two results in the order of the mutation list:

  $ grep -o '"kind":"[^"]*"' mutaml-report.json
  "kind":"int-constant"
  "kind":"arith-operator"

MUTAML_JOBS sets the same number, and -j takes precedence over it:

  $ rm -rf _mutations mutaml-report.json
  $ MUTAML_JOBS=2 mutaml-runner ./tests.sh > /dev/null
  $ cat _mutations/lib.ml-mutant1.output
  MUTAML_MUTANT=[lib.ml:f:arith-operator:b614c1c7:0] TMPDIR=[job2]
  $ rm -rf _mutations mutaml-report.json
  $ MUTAML_JOBS=2 mutaml-runner -j 1 ./tests.sh > /dev/null
  $ cat _mutations/lib.ml-mutant1.output
  MUTAML_MUTANT=[lib.ml:f:arith-operator:b614c1c7:0] TMPDIR=[outer]

A number of jobs below 1, and a value that is not a number, each stop
the run:

  $ mutaml-runner -j 0 ./tests.sh
  The value of -j must be a whole number of jobs above 0.
  [1]
  $ mutaml-runner -j two ./tests.sh
  The value of -j must be a whole number of jobs above 0.
  [1]
  $ MUTAML_JOBS=0 mutaml-runner ./tests.sh
  The value of MUTAML_JOBS must be a whole number of jobs above 0.
  [1]

A test command that starts with dune cannot run more than one at a time,
because dune locks the build directory. The runner says so and stops:

  $ mkdir -p bin
  $ cp tests.sh bin/dune
  $ mutaml-runner -j 2 ./bin/dune
  mutaml-runner runs one test at a time when the test command starts with dune.
  dune locks the build directory, so a second dune cannot run at the same time.
  Give the path of the test executable to run more tests at a time, for example _build/default/test/mytests.exe.
  [1]

One job at a time is safe for such a command, so the runner takes it:

  $ rm -rf _mutations mutaml-report.json
  $ mutaml-runner ./bin/dune
  read mut file lib.muts
  Testing without a mutant ... passed
  The limit of a test run is 5 times the run without a mutant, and never less than 10 seconds.
  Testing mutant lib.ml:f:int-constant:4fad8996:0 ... failed
  Testing mutant lib.ml:f:arith-operator:b614c1c7:0 ... passed
  Writing report data to mutaml-report.json

--repeat runs the test command for one mutation until a run kills it.
The value of a variable that --test-env names may hold the two
characters {}, which the runner replaces by the number of the run. The
suite below fails for the int-constant mutation under the seed 2 only:

  $ cat > seeded.sh <<'EOF'
  > #!/bin/sh
  > echo "MUTAML_MUTANT=[$MUTAML_MUTANT] QCHECK_SEED=[$QCHECK_SEED]"
  > case "$MUTAML_MUTANT:$QCHECK_SEED" in
  >   lib.ml:f:int-constant:4fad8996:0:2) exit 3 ;;
  >   *)     exit 0 ;;
  > esac
  > EOF
  $ chmod +x seeded.sh
  $ rm -rf _mutations mutaml-report.json
  $ mutaml-runner --repeat 3 --test-env 'QCHECK_SEED={}' ./seeded.sh
  read mut file lib.muts
  Testing without a mutant ... passed
  The limit of a test run is 5 times the run without a mutant, and never less than 10 seconds.
  Testing mutant lib.ml:f:int-constant:4fad8996:0 ... failed in run 2 of 3
  Testing mutant lib.ml:f:arith-operator:b614c1c7:0 ... passed in run 3 of 3
  Writing report data to mutaml-report.json

The run without a mutation is run number 1, so it had the seed 1. The
output file of a mutation holds the last run that the runner made for
it: the run that killed the int-constant mutation, and the third run of
the arith-operator mutation, which no run killed:

  $ cat _mutations/baseline-1.output
  MUTAML_MUTANT=[] QCHECK_SEED=[1]
  $ cat _mutations/lib.ml-mutant0.output
  MUTAML_MUTANT=[lib.ml:f:int-constant:4fad8996:0] QCHECK_SEED=[2]
  $ cat _mutations/lib.ml-mutant1.output
  MUTAML_MUTANT=[lib.ml:f:arith-operator:b614c1c7:0] QCHECK_SEED=[3]

The report names, for each mutation, the variables of the run it holds:

  $ grep -o '"test_env":[^]]*]]' mutaml-report.json
  "test_env":[["QCHECK_SEED","2"]]
  "test_env":[["QCHECK_SEED","3"]]

--repeat and -j work together, and the printed order is still the order
of the mutation list:

  $ rm -rf _mutations mutaml-report.json
  $ mutaml-runner -j 2 --repeat 3 --test-env 'QCHECK_SEED={}' ./seeded.sh
  read mut file lib.muts
  Testing without a mutant ... passed
  The limit of a test run is 5 times the run without a mutant, and never less than 10 seconds.
  Testing mutant lib.ml:f:int-constant:4fad8996:0 ... failed in run 2 of 3
  Testing mutant lib.ml:f:arith-operator:b614c1c7:0 ... passed in run 3 of 3
  Writing report data to mutaml-report.json

A number of runs below 1, and a value that is not a number, each stop
the run:

  $ mutaml-runner --repeat 0 ./seeded.sh
  The value of --repeat must be a whole number of runs above 0.
  [1]
  $ mutaml-runner --repeat none ./seeded.sh
  The value of --repeat must be a whole number of runs above 0.
  [1]
