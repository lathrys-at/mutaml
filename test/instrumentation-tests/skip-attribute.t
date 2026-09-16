The attribute `[@mutaml.skip "reason"]` marks a place that the
preprocessor must not mutate. The preprocessor makes no mutation
inside such a place, writes the place and its reason in the `.muts`
file, and takes the attribute out of the program it instruments. The
reason is a string, and it is not optional.

  $ bash ../write_dune_files.sh

  $ export MUTAML_SEED=896745231
  $ export MUTAML_MUT_RATE=100

On an expression
----------------

Two functions hold the same `if`. The attribute marks the second one:

  $ cat > test.ml <<'EOF'
  > let classify n = if n < 0 then "less" else "more"
  > let label n = (if n < 0 then "less" else "more")[@mutaml.skip "the caller reads both branches the same"]
  > let () = print_endline (classify 3 ^ label 4)
  > EOF

  $ bash ../filter_dune_build.sh ./test.bc --instrument-with mutaml > with-skip.txt
  $ grep -v '^ *$' with-skip.txt
  Running mutaml instrumentation on "test.ml"
  Randomness seed: 896745231   Mutation rate: 100   GADTs enabled: true
  Created 5 mutations of test.ml
  Skipped 1 place in test.ml
  Writing mutation info to test.muts
  let __MUTAML_MUTANT__ = Stdlib.Sys.getenv_opt "MUTAML_MUTANT"
  let __is_mutaml_mutant__ m =
    match __MUTAML_MUTANT__ with
    | None -> false
    | Some mutant -> String.equal m mutant
  let classify n =
    if
      let __MUTAML_TMP1__ =
        let __MUTAML_TMP0__ =
          if __is_mutaml_mutant__ "test.ml:classify:int-constant:92be9951:0"
          then 1
          else 0 in
        if __is_mutaml_mutant__ "test.ml:classify:compare-boundary:f0986ce8:0"
        then n <= __MUTAML_TMP0__
        else n < __MUTAML_TMP0__ in
      (if __is_mutaml_mutant__ "test.ml:classify:if-condition:06a44f91:0"
       then not __MUTAML_TMP1__
       else __MUTAML_TMP1__)
    then "less"
    else "more"
  let label n = if n < 0 then "less" else "more"
  let () =
    print_endline
      ((classify
          (if __is_mutaml_mutant__ "test.ml:toplevel:int-constant:3f492773:0"
           then 4
           else 3))
         ^
         (label
            (if __is_mutaml_mutant__ "test.ml:toplevel:int-constant:31e37bfa:0"
             then 5
             else 4)))

The `.muts` file holds the place, the reason, and the operators that
the preprocessor would have used inside the place:

  $ grep -o '"binding":"[a-z_]*","reason":"[^"]*"' _build/.mutaml/default/test.muts
  "binding":"label","reason":"the caller reads both branches the same"
  $ grep -o '"kinds":\[[^]]*\]' _build/.mutaml/default/test.muts
  "kinds":["int-constant","compare-boundary","if-condition"]

A skipped place does not move the name of any other mutation of the
file. Take the attribute away and compare the names:

  $ grep -o '"test.ml:[a-z_]*:[a-z-]*:[0-9a-f]*:[0-9]*"' with-skip.txt | sort -u > with-skip-names.txt
  $ cat > test.ml <<'EOF'
  > let classify n = if n < 0 then "less" else "more"
  > let label n = if n < 0 then "less" else "more"
  > let () = print_endline (classify 3 ^ label 4)
  > EOF
  $ bash ../filter_dune_build.sh ./test.bc --instrument-with mutaml > no-skip.txt
  $ grep -o '"test.ml:[a-z_]*:[a-z-]*:[0-9a-f]*:[0-9]*"' no-skip.txt | sort -u > no-skip-names.txt
  $ comm -23 with-skip-names.txt no-skip-names.txt
  $ comm -13 with-skip-names.txt no-skip-names.txt
  "test.ml:label:compare-boundary:f0986ce8:0"
  "test.ml:label:if-condition:06a44f91:0"
  "test.ml:label:int-constant:92be9951:0"

On a let binding
----------------

  $ cat > test.ml <<'EOF'
  > let label n = if n < 0 then "less" else "more"
  > [@@mutaml.skip "the caller reads both branches the same"]
  > let other n = n + 1
  > let () = print_endline (label 4 ^ string_of_int (other 2))
  > EOF

  $ bash ../filter_dune_build.sh ./test.bc --instrument-with mutaml | grep -v '^ *$'
  Running mutaml instrumentation on "test.ml"
  Randomness seed: 896745231   Mutation rate: 100   GADTs enabled: true
  Created 3 mutations of test.ml
  Skipped 1 place in test.ml
  Writing mutation info to test.muts
  let __MUTAML_MUTANT__ = Stdlib.Sys.getenv_opt "MUTAML_MUTANT"
  let __is_mutaml_mutant__ m =
    match __MUTAML_MUTANT__ with
    | None -> false
    | Some mutant -> String.equal m mutant
  let label n = if n < 0 then "less" else "more"
  let other n =
    if __is_mutaml_mutant__ "test.ml:other:arith-identity:f8aa5f2a:0"
    then n
    else n + 1
  let () =
    print_endline
      ((label
          (if __is_mutaml_mutant__ "test.ml:toplevel:int-constant:31e37bfa:0"
           then 5
           else 4))
         ^
         (string_of_int
            (other
               (if
                  __is_mutaml_mutant__
                    "test.ml:toplevel:int-constant:626aba84:0"
                then 3
                else 2))))
  $ grep -o '"binding":"[a-z_]*","reason":"[^"]*"' _build/.mutaml/default/test.muts
  "binding":"label","reason":"the caller reads both branches the same"

On a structure item
-------------------

  $ cat > test.ml <<'EOF'
  > module Messages = struct
  >   let greet n = if n < 0 then "hello" else "hi"
  > end [@@mutaml.skip "no test reads these texts"]
  > let () = print_endline (Messages.greet 1)
  > EOF

  $ bash ../filter_dune_build.sh ./test.bc --instrument-with mutaml | grep -v '^ *$'
  Running mutaml instrumentation on "test.ml"
  Randomness seed: 896745231   Mutation rate: 100   GADTs enabled: true
  Created 1 mutation of test.ml
  Skipped 1 place in test.ml
  Writing mutation info to test.muts
  let __MUTAML_MUTANT__ = Stdlib.Sys.getenv_opt "MUTAML_MUTANT"
  let __is_mutaml_mutant__ m =
    match __MUTAML_MUTANT__ with
    | None -> false
    | Some mutant -> String.equal m mutant
  module Messages = struct let greet n = if n < 0 then "hello" else "hi" end
  let () =
    print_endline
      (Messages.greet
         (if __is_mutaml_mutant__ "test.ml:toplevel:int-constant:50c5a5ff:0"
          then 0
          else 1))
  $ grep -o '"binding":"[a-z_]*","reason":"[^"]*"' _build/.mutaml/default/test.muts
  "binding":"toplevel","reason":"no test reads these texts"

A place that holds nothing to mutate
------------------------------------

The list of operators is then empty, which says that the attribute
takes nothing away:

  $ cat > test.ml <<'EOF'
  > let name () = (print_string "x")[@mutaml.skip "nothing to mutate here"]
  > let () = name ()
  > EOF

  $ bash ../filter_dune_build.sh ./test.bc --instrument-with mutaml | grep -v '^ *$'
  Running mutaml instrumentation on "test.ml"
  Randomness seed: 896745231   Mutation rate: 100   GADTs enabled: true
  Created 0 mutations of test.ml
  Skipped 1 place in test.ml
  Writing mutation info to test.muts
  let __MUTAML_MUTANT__ = Stdlib.Sys.getenv_opt "MUTAML_MUTANT"
  let __is_mutaml_mutant__ m =
    match __MUTAML_MUTANT__ with
    | None -> false
    | Some mutant -> String.equal m mutant
  let name () = print_string "x"
  let () = name ()
  $ grep -o '"kinds":\[[^]]*\]' _build/.mutaml/default/test.muts
  "kinds":[]

A place inside a place
----------------------

The outer attribute covers the inner one, and the `.muts` file holds
one place and not two:

  $ cat > test.ml <<'EOF'
  > let label n =
  >   (let inner = (if n < 0 then 1 else 2)[@mutaml.skip "the inner reason"] in
  >    inner + 3)[@mutaml.skip "the outer reason"]
  > let () = print_int (label 4)
  > EOF

  $ bash ../filter_dune_build.sh ./test.bc --instrument-with mutaml | grep -v '^ *$'
  Running mutaml instrumentation on "test.ml"
  Randomness seed: 896745231   Mutation rate: 100   GADTs enabled: true
  Created 1 mutation of test.ml
  Skipped 1 place in test.ml
  Writing mutation info to test.muts
  let __MUTAML_MUTANT__ = Stdlib.Sys.getenv_opt "MUTAML_MUTANT"
  let __is_mutaml_mutant__ m =
    match __MUTAML_MUTANT__ with
    | None -> false
    | Some mutant -> String.equal m mutant
  let label n = let inner = if n < 0 then 1 else 2 in inner + 3
  let () =
    print_int
      (label
         (if __is_mutaml_mutant__ "test.ml:toplevel:int-constant:31e37bfa:0"
          then 5
          else 4))
  $ grep -o '"reason":"[^"]*"' _build/.mutaml/default/test.muts
  "reason":"the outer reason"

A reason that is missing
------------------------

  $ cat > test.ml <<'EOF'
  > let label n = (if n < 0 then "less" else "more")[@mutaml.skip]
  > let () = print_endline (label 4)
  > EOF

  $ bash ../filter_dune_build.sh ./test.bc --instrument-with mutaml 2>&1 | grep -A 3 'File "test.ml"'
  File "test.ml", line 1, characters 48-62:
  1 | let label n = (if n < 0 then "less" else "more")[@mutaml.skip]
                                                      ^^^^^^^^^^^^^^
  Error: mutaml: the attribute [@mutaml.skip] needs a reason. Write the reason as a string, as in [@mutaml.skip "the two branches do the same thing"].

An empty reason says nothing, so the preprocessor refuses it too:

  $ cat > test.ml <<'EOF'
  > let label n = (if n < 0 then "less" else "more")[@mutaml.skip ""]
  > let () = print_endline (label 4)
  > EOF

  $ bash ../filter_dune_build.sh ./test.bc --instrument-with mutaml 2>&1 | grep -A 3 'File "test.ml"'
  File "test.ml", line 1, characters 48-65:
  1 | let label n = (if n < 0 then "less" else "more")[@mutaml.skip ""]
                                                      ^^^^^^^^^^^^^^^^^
  Error: mutaml: the attribute [@mutaml.skip] needs a reason. Write the reason as a string, as in [@mutaml.skip "the two branches do the same thing"].

A reason that is not a string:

  $ cat > test.ml <<'EOF'
  > let label n = (if n < 0 then "less" else "more")[@mutaml.skip 7]
  > let () = print_endline (label 4)
  > EOF

  $ bash ../filter_dune_build.sh ./test.bc --instrument-with mutaml 2>&1 | grep -A 3 'File "test.ml"'
  File "test.ml", line 1, characters 48-64:
  1 | let label n = (if n < 0 then "less" else "more")[@mutaml.skip 7]
                                                      ^^^^^^^^^^^^^^^^
  Error: mutaml: the attribute [@mutaml.skip] needs a reason. Write the reason as a string, as in [@mutaml.skip "the two branches do the same thing"].
