Tests the guard-always-true operator, which makes the "when" guard of a
match case always hold. The operator is off by default.

  $ bash ../write_dune_files.sh

Set seed and (full) mutation rate as environment variables, for repeatability
  $ export MUTAML_SEED=896745231
  $ export MUTAML_MUT_RATE=100


Off by default, a guarded case gains no mutant of this operator:

  $ cat > test.ml <<'EOF'
  > let f flag n = match n with
  >   | x when flag -> x
  >   | _ -> "no";;
  > assert (f false "yes" = "no")
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
  let f flag n = match n with | x when flag -> x | _ -> "no"
  ;;assert ((f false "yes") = "no")

  $ dune exec --no-build ./test.bc


With MUTAML_GUARD_ALWAYS_TRUE=true the guard gains a mutant. The
mutated guard holds whatever the program says, so the case fires when
it must not:

  $ dune clean
  $ export MUTAML_GUARD_ALWAYS_TRUE=true
  $ cat > test.ml <<'EOF'
  > let f flag n = match n with
  >   | x when flag -> x
  >   | _ -> "no";;
  > assert (f false "yes" = "no")
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
  let f flag n =
    match n with
    | x when
        (__is_mutaml_mutant__ "test.ml:f:guard-always-true:de18115f:0") || flag
        -> x
    | _ -> "no"
  ;;assert ((f false "yes") = "no")

Check that instrumentation hasn't changed the program's behaviour
  $ dune exec --no-build ./test.bc

And that the mutant makes the guarded case fire
  $ MUTAML_MUTANT="test.ml:f:guard-always-true:de18115f:0" dune exec --no-build ./test.bc
  Fatal error: exception Assert_failure("test.ml", 4, 0)
  [2]


The mutation that mutaml already had makes a guarded case fire never.
Both mutants are made on the same case, and they are different mutants:

  $ dune clean
  $ cat > test.ml <<'EOF'
  > let f flag n = match n with
  >   | "a" when flag -> "A"
  >   | "b" -> "B"
  >   | _ -> "other";;
  > assert (f false "a" = "other")
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
  let f flag n =
    ((match n with
      | "a" when
          ((__is_mutaml_mutant__ "test.ml:f:guard-always-true:de18115f:0") ||
             flag)
            && (not (__is_mutaml_mutant__ "test.ml:f:omit-case:a9d6604e:0"))
          -> "A"
      | "b" when not (__is_mutaml_mutant__ "test.ml:f:omit-case:525e4809:0") ->
          "B"
      | _ -> "other")
    [@ocaml.warning "-8"])
  ;;assert ((f false "a") = "other")

  $ dune exec --no-build ./test.bc

Mutant 0 makes the guard always hold, so the first case fires
  $ MUTAML_MUTANT="test.ml:f:guard-always-true:de18115f:0" dune exec --no-build ./test.bc
  Fatal error: exception Assert_failure("test.ml", 5, 0)
  [2]

Mutant 2 makes the same case fire never, and no test here catches that
  $ MUTAML_MUTANT="test.ml:f:omit-case:a9d6604e:0" dune exec --no-build ./test.bc


The instrumentation option -guard-always-true true does the same as the
environment variable:

  $ dune clean
  $ unset MUTAML_GUARD_ALWAYS_TRUE
  $ cat > test.ml <<'EOF'
  > let f flag n = match n with
  >   | x when flag -> x
  >   | _ -> "no";;
  > assert (f false "yes" = "no")
  > EOF
  $ cat > dune <<'EOF'
  > (executable
  >  (name test)
  >  (modes byte)
  >  (ocamlc_flags -dsource)
  >  (instrumentation (backend mutaml -guard-always-true true)))
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
  let f flag n =
    match n with
    | x when
        (__is_mutaml_mutant__ "test.ml:f:guard-always-true:de18115f:0") || flag
        -> x
    | _ -> "no"
  ;;assert ((f false "yes") = "no")

  $ dune exec --no-build ./test.bc
