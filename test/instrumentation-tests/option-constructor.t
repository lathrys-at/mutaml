Tests the some-to-none mutation operator, which turns "Some e" into "None"

  $ bash ../write_dune_files.sh

Set seed and (full) mutation rate as environment variables, for repeatability
  $ export MUTAML_SEED=896745231
  $ export MUTAML_MUT_RATE=100


The operator is on by default:

  $ cat > test.ml <<'EOF'
  > let f x = Some x;;
  > assert (f 0 <> None)
  > EOF

  $ bash ../filter_dune_build.sh ./test.bc --instrument-with mutaml
  Running mutaml instrumentation on "test.ml"
  Randomness seed: 896745231   Mutation rate: 100   GADTs enabled: true
  Created 1 mutation of test.ml
  Writing mutation info to test.muts
  
  let __MUTAML_MUTANT__ = Stdlib.Sys.getenv_opt "MUTAML_MUTANT"
  let __is_mutaml_mutant__ m =
    match __MUTAML_MUTANT__ with
    | None -> false
    | Some mutant -> String.equal m mutant
  let f x = if __is_mutaml_mutant__ "test:0" then None else Some x
  ;;assert ((f 0) <> None)

Check that instrumentation hasn't changed the program's behaviour
  $ dune exec --no-build ./test.bc

And that mutation has changed it as expected
  $ MUTAML_MUTANT="test:0" dune exec --no-build ./test.bc
  Fatal error: exception Assert_failure("test.ml", 2, 0)
  [2]


The payload of "Some" is mutated too, and both mutants stand:

  $ dune clean
  $ cat > test.ml <<'EOF'
  > let f n = Some (n + 1);;
  > assert (f 0 = Some 1)
  > EOF

  $ bash ../filter_dune_build.sh ./test.bc --instrument-with mutaml
  Running mutaml instrumentation on "test.ml"
  Randomness seed: 896745231   Mutation rate: 100   GADTs enabled: true
  Created 2 mutations of test.ml
  Writing mutation info to test.muts
  
  let __MUTAML_MUTANT__ = Stdlib.Sys.getenv_opt "MUTAML_MUTANT"
  let __is_mutaml_mutant__ m =
    match __MUTAML_MUTANT__ with
    | None -> false
    | Some mutant -> String.equal m mutant
  let f n =
    if __is_mutaml_mutant__ "test:1"
    then None
    else Some (if __is_mutaml_mutant__ "test:0" then n else n + 1)
  ;;assert ((f 0) = (Some 1))

  $ dune exec --no-build ./test.bc


"None" itself is not mutated, because there is no value to put inside:

  $ dune clean
  $ cat > test.ml <<'EOF'
  > let f () = None;;
  > assert (f () = None)
  > EOF

  $ bash ../filter_dune_build.sh ./test.bc --instrument-with mutaml
  Running mutaml instrumentation on "test.ml"
  Randomness seed: 896745231   Mutation rate: 100   GADTs enabled: true
  Created 0 mutations of test.ml
  Writing mutation info to test.muts
  
  let __MUTAML_MUTANT__ = Stdlib.Sys.getenv_opt "MUTAML_MUTANT"
  let __is_mutaml_mutant__ m =
    match __MUTAML_MUTANT__ with
    | None -> false
    | Some mutant -> String.equal m mutant
  let f () = None
  ;;assert ((f ()) = None)

  $ dune exec --no-build ./test.bc


The environment variable MUTAML_SOME_TO_NONE=false turns the operator off:

  $ dune clean
  $ export MUTAML_SOME_TO_NONE=false
  $ cat > test.ml <<'EOF'
  > let f x = Some x;;
  > assert (f 0 <> None)
  > EOF

  $ bash ../filter_dune_build.sh ./test.bc --instrument-with mutaml
  Running mutaml instrumentation on "test.ml"
  Randomness seed: 896745231   Mutation rate: 100   GADTs enabled: true
  Created 0 mutations of test.ml
  Writing mutation info to test.muts
  
  let __MUTAML_MUTANT__ = Stdlib.Sys.getenv_opt "MUTAML_MUTANT"
  let __is_mutaml_mutant__ m =
    match __MUTAML_MUTANT__ with
    | None -> false
    | Some mutant -> String.equal m mutant
  let f x = Some x
  ;;assert ((f 0) <> None)


The instrumentation option -some-to-none false does the same:

  $ dune clean
  $ unset MUTAML_SOME_TO_NONE
  $ cat > dune <<'EOF'
  > (executable
  >  (name test)
  >  (modes byte)
  >  (ocamlc_flags -dsource)
  >  (instrumentation (backend mutaml -some-to-none false)))
  > EOF

  $ bash ../filter_dune_build.sh ./test.bc --instrument-with mutaml
  Running mutaml instrumentation on "test.ml"
  Randomness seed: 896745231   Mutation rate: 100   GADTs enabled: true
  Created 0 mutations of test.ml
  Writing mutation info to test.muts
  
  let __MUTAML_MUTANT__ = Stdlib.Sys.getenv_opt "MUTAML_MUTANT"
  let __is_mutaml_mutant__ m =
    match __MUTAML_MUTANT__ with
    | None -> false
    | Some mutant -> String.equal m mutant
  let f x = Some x
  ;;assert ((f 0) <> None)


A value that is neither true nor false is refused, and the message names
the environment variable:

  $ dune clean
  $ bash ../write_dune_files.sh
  $ export MUTAML_SOME_TO_NONE=maybe

  $ bash ../filter_dune_build.sh ./test.bc --instrument-with mutaml
  File "dune", line 5, characters 1-35:
  5 |  (instrumentation (backend mutaml)))
       ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Invalid MUTAML_SOME_TO_NONE string: maybe
  $ unset MUTAML_SOME_TO_NONE
