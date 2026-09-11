Tests mutation of the Boolean connectives && and ||

  $ bash ../write_dune_files.sh

Set seed and (full) mutation rate as environment variables, for repeatability
  $ export MUTAML_SEED=896745231
  $ export MUTAML_MUT_RATE=100


Test &&:

  $ cat > test.ml <<'EOF'
  > let f a b = a && b;;
  > assert (not (f true false))
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
  let f a b =
    let __MUTAML_TMP0__ () = b in
    if __is_mutaml_mutant__ "test:0"
    then a || (__MUTAML_TMP0__ ())
    else a && (__MUTAML_TMP0__ ())
  ;;assert (not (f true false))

Check that instrumentation hasn't changed the program's behaviour
  $ dune exec --no-build ./test.bc

And that mutation has changed it as expected
  $ MUTAML_MUTANT="test:0" dune exec --no-build ./test.bc
  Fatal error: exception Assert_failure("test.ml", 2, 0)
  [2]



Test ||:

  $ cat > test.ml <<'EOF'
  > let f a b = a || b;;
  > assert (f true false)
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
  let f a b =
    let __MUTAML_TMP0__ () = b in
    if __is_mutaml_mutant__ "test:0"
    then a && (__MUTAML_TMP0__ ())
    else a || (__MUTAML_TMP0__ ())
  ;;assert (f true false)

  $ dune exec --no-build ./test.bc

  $ MUTAML_MUTANT="test:0" dune exec --no-build ./test.bc
  Fatal error: exception Assert_failure("test.ml", 2, 0)
  [2]



The connectives ask for their right operand only when their left
operand does not decide the answer, and they ask for the left operand
first. Instrumentation must not change either of those, as long as no
mutant is active. The program below prints which operand it evaluates.

  $ cat > test.ml <<'EOF'
  > let left () = print_endline "left"; false
  > let right () = print_endline "right"; true
  > let () = if left () && right () then print_endline "yes" else print_endline "no"
  > EOF

Without instrumentation, the program asks for the left operand only:

  $ bash ../filter_dune_build.sh ./test.bc
  let left () = print_endline "left"; false
  let right () = print_endline "right"; true
  let () =
    if (left ()) && (right ()) then print_endline "yes" else print_endline "no"

  $ dune exec --no-build ./test.bc
  left
  no

With instrumentation and no mutant active, it does the same:

  $ bash ../filter_dune_build.sh ./test.bc --instrument-with mutaml
  Running mutaml instrumentation on "test.ml"
  Randomness seed: 896745231   Mutation rate: 100   GADTs enabled: true
  Created 6 mutations of test.ml
  Writing mutation info to test.muts
  
  let __MUTAML_MUTANT__ = Stdlib.Sys.getenv_opt "MUTAML_MUTANT"
  let __is_mutaml_mutant__ m =
    match __MUTAML_MUTANT__ with
    | None -> false
    | Some mutant -> String.equal m mutant
  let left () =
    if __is_mutaml_mutant__ "test:1" then () else print_endline "left";
    if __is_mutaml_mutant__ "test:0" then true else false
  let right () =
    if __is_mutaml_mutant__ "test:3" then () else print_endline "right";
    if __is_mutaml_mutant__ "test:2" then false else true
  let () =
    if
      let __MUTAML_TMP2__ =
        let __MUTAML_TMP0__ = left () in
        let __MUTAML_TMP1__ () = right () in
        if __is_mutaml_mutant__ "test:4"
        then __MUTAML_TMP0__ || (__MUTAML_TMP1__ ())
        else __MUTAML_TMP0__ && (__MUTAML_TMP1__ ()) in
      (if __is_mutaml_mutant__ "test:5"
       then not __MUTAML_TMP2__
       else __MUTAML_TMP2__)
    then print_endline "yes"
    else print_endline "no"

  $ dune exec --no-build ./test.bc
  left
  no

With the mutant of the connective active, && becomes ||, so the left
operand no longer decides the answer and the right operand runs:

  $ MUTAML_MUTANT="test:4" dune exec --no-build ./test.bc
  left
  right
  yes


The same for ||, which asks for its right operand only when its left
operand is false:

  $ cat > test.ml <<'EOF'
  > let left () = print_endline "left"; true
  > let right () = print_endline "right"; false
  > let () = if left () || right () then print_endline "yes" else print_endline "no"
  > EOF

Without instrumentation:

  $ bash ../filter_dune_build.sh ./test.bc
  let left () = print_endline "left"; true
  let right () = print_endline "right"; false
  let () =
    if (left ()) || (right ()) then print_endline "yes" else print_endline "no"

  $ dune exec --no-build ./test.bc
  left
  yes

With instrumentation and no mutant active:

  $ bash ../filter_dune_build.sh ./test.bc --instrument-with mutaml
  Running mutaml instrumentation on "test.ml"
  Randomness seed: 896745231   Mutation rate: 100   GADTs enabled: true
  Created 6 mutations of test.ml
  Writing mutation info to test.muts
  
  let __MUTAML_MUTANT__ = Stdlib.Sys.getenv_opt "MUTAML_MUTANT"
  let __is_mutaml_mutant__ m =
    match __MUTAML_MUTANT__ with
    | None -> false
    | Some mutant -> String.equal m mutant
  let left () =
    if __is_mutaml_mutant__ "test:1" then () else print_endline "left";
    if __is_mutaml_mutant__ "test:0" then false else true
  let right () =
    if __is_mutaml_mutant__ "test:3" then () else print_endline "right";
    if __is_mutaml_mutant__ "test:2" then true else false
  let () =
    if
      let __MUTAML_TMP2__ =
        let __MUTAML_TMP0__ = left () in
        let __MUTAML_TMP1__ () = right () in
        if __is_mutaml_mutant__ "test:4"
        then __MUTAML_TMP0__ && (__MUTAML_TMP1__ ())
        else __MUTAML_TMP0__ || (__MUTAML_TMP1__ ()) in
      (if __is_mutaml_mutant__ "test:5"
       then not __MUTAML_TMP2__
       else __MUTAML_TMP2__)
    then print_endline "yes"
    else print_endline "no"

  $ dune exec --no-build ./test.bc
  left
  yes

With the mutant of the connective active, || becomes &&:

  $ MUTAML_MUTANT="test:4" dune exec --no-build ./test.bc
  left
  right
  no


MUTAML_CONNECTIVE=false leaves && and || alone:

  $ dune clean
  $ export MUTAML_CONNECTIVE=false
  $ cat > test.ml <<'EOF'
  > let f a b = a && b;;
  > assert (not (f true false))
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
  let f a b = a && b
  ;;assert (not (f true false))
