Check that report tool fails when run without a test command:
  $ mutaml-runner
  Usage: mutaml-runner [options] <test-command>
  [1]

Try to supply an invalid command as argument, but still missing a mutation file:
  $ mutaml-runner scooby-doo.sh
  Could not read file mutaml-mut-files.txt - _build/.mutaml/default/mutaml-mut-files.txt: No such file or directory
  [1]

Now create the missing mutation file:
  $ mkdir -p _build/.mutaml/default
  $ touch _build/.mutaml/default/mutaml-mut-files.txt
and try again:
  $ mutaml-runner scooby-doo.sh
  No files were listed in mutaml-mut-files.txt
  [1]

Try passing a non-existing muts-file:
  $ mutaml-runner --muts somefile.muts scooby-doo.sh
  Could not read file somefile.muts - _build/.mutaml/default/somefile.muts: No such file or directory
  [1]

Create a mutation file with a non-existing entry:
  $ cat > _build/.mutaml/default/mutaml-mut-files.txt <<'EOF'
  > somefile.muts
  > EOF
and try again:
  $ mutaml-runner scooby-doo.sh
  read mut file somefile.muts
  Could not read file somefile.muts - _build/.mutaml/default/somefile.muts: No such file or directory
  [1]

Create a corresponding mutation file with an empty list of mutations:
  $ cat > _build/.mutaml/default/somefile.muts <<'EOF'
  > []
  > EOF

Check that it was created:
  $ ls _build/.mutaml/default
  mutaml-mut-files.txt
  somefile.muts

Now confirm that it is rejected by the report tool:
  $ mutaml-runner scooby-doo.sh
  read mut file somefile.muts
  Warning: No mutations were listed in somefile.muts
  Did not find any mutations across the files listed in mutaml-mut-files.txt
  [1]

Create a corresponding mutation file with a dummy mutation:
  $ cat > _build/.mutaml/default/somefile.muts <<'EOF'
  > [{ "number"   : 0,
  >    "binding"  : "f",
  >    "kind"     : "bool-constant",
  >    "original" : "",
  >    "ordinal"  : 0,
  >    "repl"     : "false",
  >    "loc"    : {
  >      "loc_start" : { "pos_fname" : "somefile.ml", "pos_lnum" : 1, "pos_bol" : 1, "pos_cnum" : 1 },
  >      "loc_end"   : { "pos_fname" : "somefile.ml", "pos_lnum" : 2, "pos_bol" : 2, "pos_cnum" : 2 },
  >      "loc_ghost" : false
  >   }
  > }]
  > EOF

The runner skips a mutation file whose source file is not there, so make
the source file as well:
  $ touch somefile.ml

Now try running again with a broken command:
  $ mutaml-runner scooby-doo.sh
  read mut file somefile.muts
  Testing without a mutant ... Command not found: failed to run the test command "scooby-doo.sh"
  [1]



Run with an unknown build context passed as environment variable:
  $ export MUTAML_BUILD_CONTEXT="_build/in-a-galaxy-far-far-away"
  $ mutaml-runner true
  Could not read file mutaml-mut-files.txt - _build/.mutaml/in-a-galaxy-far-far-away/mutaml-mut-files.txt: No such file or directory
  [1]



Run with an unknown build context passed as command line option:
  $ mutaml-runner --build-context _build/foofoo true
  Could not read file mutaml-mut-files.txt - _build/.mutaml/foofoo/mutaml-mut-files.txt: No such file or directory
  [1]

Check that --timeout rejects a value that is not a whole number:
  $ mutaml-runner --timeout two true
  The value of --timeout must be a whole number of seconds above 0.
  [1]

Check that --timeout rejects 0 seconds:
  $ mutaml-runner --timeout 0 true
  The value of --timeout must be a whole number of seconds above 0.
  [1]

Check that MUTAML_TIMEOUT rejects the same values, and says which variable is wrong:
  $ MUTAML_TIMEOUT=-5 mutaml-runner true
  The value of MUTAML_TIMEOUT must be a whole number of seconds above 0.
  [1]

Check that --test-env rejects a value that is not an assignment:
  $ mutaml-runner --test-env QCHECK_SEED true
  The value of --test-env must have the form NAME=VALUE.
  [1]

Check that --test-env rejects a name that no variable may have:
  $ mutaml-runner --test-env 2SEED=1 true
  2SEED is not a name that a variable may have. A variable name holds letters, digits and the character _, and it does not start with a digit.
  [1]

Check that --baseline-env rejects a value that is not an assignment:
  $ mutaml-runner --baseline-env QCHECK_SEED true
  The value of --baseline-env must have the form NAME=VALUE.
  [1]

Check that --baseline-env rejects a name that no variable may have:
  $ mutaml-runner --baseline-env 2SEED=1 true
  2SEED is not a name that a variable may have. A variable name holds letters, digits and the character _, and it does not start with a digit.
  [1]
