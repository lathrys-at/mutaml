Create dune-project file
  $ echo "(lang dune 2.9)" > dune-project

Create a dune file enabling instrumentation
  $ cat > dune <<'EOF'
  > (executable
  >  (name b)
  >  (modules a b)
  >  (modes byte)
  >  (ocamlc_flags -dsource)
  >  (instrumentation (backend mutaml))
  > )
  > EOF

Make an a.ml-file:
  $ cat > a.ml <<'EOF'
  > let () = Printf.printf "hello from A!\n"
  > let x = 3
  > let res = 2 * x = 6
  > let () = assert res
  > EOF

Make an b.ml-file:
  $ cat > b.ml <<'EOF'
  > open A
  > let () = Printf.printf "hello from B!\n"
  > let res = x = 1 + 2
  > let () = assert res
  > EOF

Confirm file creations
  $ ls *.ml dune*
  a.ml
  b.ml
  dune
  dune-project

Set seed and (full) mutation rate as environment variables, for repeatability
  $ export MUTAML_SEED=896745231
  $ export MUTAML_MUT_RATE=100

----------------------------------------------------------------------------------
Test mutation of an 'assert false':
----------------------------------------------------------------------------------

#  $ dune build ./b.bc --instrument-with mutaml
  $ bash ../filter_dune_build.sh ./b.bc --instrument-with mutaml
  Running mutaml instrumentation on "b.ml"
  Randomness seed: 896745231   Mutation rate: 100   GADTs enabled: true
  Created 2 mutations of b.ml
  Writing mutation info to b.muts
  Running mutaml instrumentation on "a.ml"
  Randomness seed: 896745231   Mutation rate: 100   GADTs enabled: true
  Created 5 mutations of a.ml
  Writing mutation info to a.muts
  
  let __MUTAML_MUTANT__ = Stdlib.Sys.getenv_opt "MUTAML_MUTANT"
  let __is_mutaml_mutant__ m =
    match __MUTAML_MUTANT__ with
    | None -> false
    | Some mutant -> String.equal m mutant
  let () = Printf.printf "hello from A!\n"
  let x =
    if __is_mutaml_mutant__ "a.ml:x:int-constant:3f492773:0" then 4 else 3
  let res =
    let __MUTAML_TMP0__ =
      if __is_mutaml_mutant__ "a.ml:res:int-constant:b9aa1da3:0" then 7 else 6 in
    let __MUTAML_TMP2__ =
      let __MUTAML_TMP1__ =
        if __is_mutaml_mutant__ "a.ml:res:int-constant:626aba84:0"
        then 3
        else 2 in
      if __is_mutaml_mutant__ "a.ml:res:arith-operator:e3c439c3:0"
      then __MUTAML_TMP1__ + x
      else __MUTAML_TMP1__ * x in
    if __is_mutaml_mutant__ "a.ml:res:compare-negation:abd7c5bb:0"
    then __MUTAML_TMP2__ <> __MUTAML_TMP0__
    else __MUTAML_TMP2__ = __MUTAML_TMP0__
  let () = assert res
  
  let __MUTAML_MUTANT__ = Stdlib.Sys.getenv_opt "MUTAML_MUTANT"
  let __is_mutaml_mutant__ m =
    match __MUTAML_MUTANT__ with
    | None -> false
    | Some mutant -> String.equal m mutant
  open A
  let () = Printf.printf "hello from B!\n"
  let res =
    let __MUTAML_TMP0__ =
      if __is_mutaml_mutant__ "b.ml:res:arith-identity:046a2612:0"
      then 2
      else 1 + 2 in
    if __is_mutaml_mutant__ "b.ml:res:compare-negation:a736046d:0"
    then x <> __MUTAML_TMP0__
    else x = __MUTAML_TMP0__
  let () = assert res


  $ ls _build/default
  a.ml
  a.pp.ml
  b.bc
  b.ml
  b.pp.ml

  $ ls _build/.mutaml/default
  a.muts
  b.muts
  mutaml-build-id.txt
  mutaml-mut-files.lock
  mutaml-mut-files.txt

  $ dune exec --no-build -- ./b.bc
  hello from A!
  hello from B!

  $ MUTAML_MUTANT="a.ml:x:int-constant:3f492773:0" dune exec --no-build -- ./b.bc
  hello from A!
  Fatal error: exception Assert_failure("a.ml", 4, 9)
  [2]
  $ MUTAML_MUTANT="a.ml:res:int-constant:b9aa1da3:0" dune exec --no-build -- ./b.bc
  hello from A!
  Fatal error: exception Assert_failure("a.ml", 4, 9)
  [2]
  $ MUTAML_MUTANT="a.ml:res:int-constant:626aba84:0" dune exec --no-build -- ./b.bc
  hello from A!
  Fatal error: exception Assert_failure("a.ml", 4, 9)
  [2]
  $ MUTAML_MUTANT="a.ml:res:arith-operator:e3c439c3:0" dune exec --no-build -- ./b.bc
  hello from A!
  Fatal error: exception Assert_failure("a.ml", 4, 9)
  [2]

  $ MUTAML_MUTANT="b.ml:res:arith-identity:046a2612:0" dune exec --no-build -- ./b.bc
  hello from A!
  hello from B!
  Fatal error: exception Assert_failure("b.ml", 4, 9)
  [2]
  $ MUTAML_MUTANT="b.ml:res:compare-negation:a736046d:0" dune exec --no-build -- ./b.bc
  hello from A!
  hello from B!
  Fatal error: exception Assert_failure("b.ml", 4, 9)
  [2]
