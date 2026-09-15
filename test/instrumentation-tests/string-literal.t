Tests the string-literal operator, which turns a string literal into ""
and "" into " ". The operator is off by default.

  $ bash ../write_dune_files.sh

Set seed and (full) mutation rate as environment variables, for repeatability
  $ export MUTAML_SEED=896745231
  $ export MUTAML_MUT_RATE=100


Off by default, only the literal " " is mutated, which is the operator
mutaml already had:

  $ cat > test.ml <<'EOF'
  > let greet () = "hello";;
  > let gap () = " ";;
  > assert (greet () ^ gap () = "hello ")
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
  let greet () = "hello"
  let gap () =
    if __is_mutaml_mutant__ "test.ml:gap:space-string:cbda8879:0"
    then ""
    else " "
  ;;assert (((greet ()) ^ (gap ())) = "hello ")

  $ dune exec --no-build ./test.bc


With MUTAML_STRING_LITERAL=true every string literal is mutated:

  $ dune clean
  $ export MUTAML_STRING_LITERAL=true
  $ cat > test.ml <<'EOF'
  > let greet () = "hello";;
  > let empty () = "";;
  > assert (greet () ^ empty () = "hello")
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
  let greet () =
    if __is_mutaml_mutant__ "test.ml:greet:string-literal:774b4c6a:0"
    then ""
    else "hello"
  let empty () =
    if __is_mutaml_mutant__ "test.ml:empty:string-literal:ffe635b2:0"
    then " "
    else ""
  ;;assert (((greet ()) ^ (empty ())) = "hello")

Check that instrumentation hasn't changed the program's behaviour
  $ dune exec --no-build ./test.bc

And that mutation has changed it as expected
  $ MUTAML_MUTANT="test.ml:greet:string-literal:774b4c6a:0" dune exec --no-build ./test.bc
  Fatal error: exception Assert_failure("test.ml", 3, 0)
  [2]


A literal that holds a '%' is left alone, because it may stand where a
format is wanted, and there "" does not typecheck:

  $ dune clean
  $ cat > test.ml <<'EOF'
  > let show n = Printf.sprintf "n is %d" n;;
  > assert (show 1 = "n is 1")
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
  let show n = Printf.sprintf "n is %d" n
  ;;assert ((show 1) = "n is 1")

  $ dune exec --no-build ./test.bc


A format with no conversion in it is mutated, and it still typechecks:

  $ dune clean
  $ cat > test.ml <<'EOF'
  > let show () = Printf.sprintf "plain";;
  > assert (show () = "plain")
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
  let show () =
    Printf.sprintf
      (if __is_mutaml_mutant__ "test.ml:show:string-literal:be13f66a:0"
       then ""
       else "plain")
  ;;assert ((show ()) = "plain")

  $ dune exec --no-build ./test.bc

  $ MUTAML_MUTANT="test.ml:show:string-literal:be13f66a:0" dune exec --no-build ./test.bc
  Fatal error: exception Assert_failure("test.ml", 2, 0)
  [2]


The instrumentation option -string-literal true does the same as the
environment variable:

  $ dune clean
  $ unset MUTAML_STRING_LITERAL
  $ cat > test.ml <<'EOF'
  > let greet () = "hello";;
  > assert (greet () = "hello")
  > EOF
  $ cat > dune <<'EOF'
  > (executable
  >  (name test)
  >  (modes byte)
  >  (ocamlc_flags -dsource)
  >  (instrumentation (backend mutaml -string-literal true)))
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
  let greet () =
    if __is_mutaml_mutant__ "test.ml:greet:string-literal:774b4c6a:0"
    then ""
    else "hello"
  ;;assert ((greet ()) = "hello")

  $ dune exec --no-build ./test.bc
