The default value of an optional parameter is an expression, and it is
mutated like any other expression. From ppxlib 0.36 on, one parse tree
constructor holds both the parameters of a function and its cases, so
this test covers the two shapes that constructor takes: a function whose
body is an expression, and a function whose body is a set of cases.

Create dune and dune-project files:
  $ bash ../write_dune_files.sh

Set seed and (full) mutation rate as environment variables, for repeatability
  $ export MUTAML_SEED=896745231
  $ export MUTAML_MUT_RATE=100

A function whose body is an expression:

  $ cat > test.ml <<'EOF'
  > let f ?(x = 1 + 2) () = x
  > let () = print_int (f ())
  > let () = print_newline ()
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
  let f ?(x=
    if __is_mutaml_mutant__ "test.ml:f:arith-identity:046a2612:0"
    then 2
    else 1 + 2) () = x
  let () = print_int (f ())
  let () = print_newline ()



  $ _build/default/test.bc
  3

  $ MUTAML_MUTANT="test.ml:f:arith-identity:046a2612:0" dune exec --no-build -- ./test.bc
  2

A function whose body is a set of cases. The parameter comes before the
cases, and both are mutated:

  $ cat > test.ml <<'EOF'
  > let g ?(x = 1 + 2) = function
  >   | true -> x
  >   | false -> 0
  > let () = print_int (g true)
  > let () = print_newline ()
  > EOF

  $ bash ../filter_dune_build.sh ./test.bc --instrument-with mutaml
  Running mutaml instrumentation on "test.ml"
  Randomness seed: 896745231   Mutation rate: 100   GADTs enabled: true
  Created 3 mutations of test.ml
  Writing mutation info to test.muts
  
  let __MUTAML_MUTANT__ = Stdlib.Sys.getenv_opt "MUTAML_MUTANT"
  let __is_mutaml_mutant__ m =
    match __MUTAML_MUTANT__ with
    | None -> false
    | Some mutant -> String.equal m mutant
  let g ?(x=
    if __is_mutaml_mutant__ "test.ml:g:arith-identity:046a2612:0"
    then 2
    else 1 + 2) =
    function
    | true -> x
    | false ->
        if __is_mutaml_mutant__ "test.ml:g:int-constant:92be9951:0"
        then 1
        else 0
  let () =
    print_int
      (g
         (if __is_mutaml_mutant__ "test.ml:toplevel:bool-constant:5bf88c8b:0"
          then false
          else true))
  let () = print_newline ()



  $ _build/default/test.bc
  3

  $ MUTAML_MUTANT="test.ml:g:arith-identity:046a2612:0" dune exec --no-build -- ./test.bc
  2
